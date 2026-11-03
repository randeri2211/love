local Form = require "forms.form"

-- A mana block: a solid block made of mana, placed into the map(see blocks/manaBlock)
-- Cast directly it appears in front of the hands and moves whoever is in the way(onto it, or next to it),
-- triggered it fills the empty tile in front of what was hit(where an OnHit bullet would start)
-- It lasts its lifetime, Decelerate makes it last longer and past MANA_BLOCK_PERMANENT it stays for good
-- onHit goes off every time it is damaged and onExpire when it is gone, broken or timed out, permanent ones too
-- No room for the block(a solid tile, or a creature in it with nowhere to go) and the cast fails before anything is paid
local BlockForm = Form:new()


local function cellOf(tx, ty)
    -- Map cell of the love tile tx, ty(see Map:mapToTile)
    return tx + map.center.x + 1, map.center.y + 1 - ty
end


local function tileFree(tx, ty, blocked)
    -- True when a block can go in the tile, or a creature can stand in it: air or a plant that makes way
    if blocked ~= nil and tx == blocked[1] and ty == blocked[2] then
        return false
    end
    local block = map:get(cellOf(tx, ty))
    return block == nil or (not block.solid and block.replaceable == true)
end


local function standFree(tx, ty, block)
    -- True when the tile can hold a block or a creature can stand in it(walk-through blocks like a torch are fine)
    if tx == block[1] and ty == block[2] then
        return false
    end
    return not map:isSolid(cellOf(tx, ty))
end


local function creatures()
    -- Everything a block can be placed on top of: the player and the enemies
    local list = {}
    if player ~= nil and not player:isDead() then
        table.insert(list, player)
    end
    for i, enemy in ipairs(map.enemies.enemies) do
        if enemy.body ~= nil and not enemy.body:isDestroyed() and not enemy.dying then
            table.insert(list, enemy)
        end
    end
    return list
end


local function overlapsTile(creature, tx, ty)
    local x, y = creature.body:getWorldCenter()
    local w, h = creature.width or TILE_SIZE, creature.height or TILE_SIZE
    return x + w / 2 > tx * TILE_SIZE and x - w / 2 < (tx + 1) * TILE_SIZE
        and y + h / 2 > ty * TILE_SIZE and y - h / 2 < (ty + 1) * TILE_SIZE
end


local function findSpot(creature, block)
    -- Where the block pushes the creature: only next to where it is, it never goes through a wall
    -- On top of the block first(casting one under yourself lifts you onto it), then a step to either side
    -- (the side it leans to first), the same step up a tile, and last under the block(a block cast at its head)
    -- Returns the body center to move it to, nil when none of them has room for it
    local x, y = creature.body:getWorldCenter()
    local w, h = creature.width or TILE_SIZE, creature.height or TILE_SIZE
    local tilesW, tilesH = math.max(1, math.ceil(w / TILE_SIZE - 0.01)), math.max(1, math.ceil(h / TILE_SIZE - 0.01))
    local fromX, fromY = math.floor(x / TILE_SIZE), math.floor((y + h / 2 - 1) / TILE_SIZE)   -- Column and feet row
    local lean = (x / TILE_SIZE - fromX) < 0.5 and -1 or 1
    local candidates = {
        {block[1], block[2] - 1},
        {fromX + lean, fromY}, {fromX - lean, fromY},
        {fromX + lean, fromY - 1}, {fromX - lean, fromY - 1},
        {block[1], block[2] + tilesH},
    }
    for n, spot in ipairs(candidates) do
        local tx, ty = spot[1], spot[2]     -- Left column and feet row of the creature there
        local fits = true
        for i = 0, tilesW - 1 do
            for j = 0, tilesH - 1 do
                if not standFree(tx + i, ty - j, block) then
                    fits = false
                end
            end
        end
        if fits then
            return (tx + tilesW / 2) * TILE_SIZE, (ty + 1) * TILE_SIZE - h / 2 - 1
        end
    end
    return nil
end


function BlockForm.place(caster, params, x, y, dirX, dirY, triggered)
    -- Where the block goes and who has to move for it(see Spell:shoot), nil when it cant go anywhere
    -- Cast directly it goes in the tile just in front of the hands, where a bullet would start(x, y is the hands),
    -- or in the tile of the hands when that one is solid(aiming into the floor), triggered it goes where the trigger is
    -- Returns {tx, ty, moves = {{creature, x, y}...}}
    local spots = {{x, y}}
    if not triggered then
        local reach = TILE_SIZE * BLOCK_CAST_REACH
        spots = {{x + dirX * reach, y + dirY * reach}, {x, y}}
    end
    local tx, ty = nil, nil
    for i, spot in ipairs(spots) do
        local sx, sy = math.floor(spot[1] / TILE_SIZE), math.floor(spot[2] / TILE_SIZE)
        if tileFree(sx, sy) then
            tx, ty = sx, sy
            break
        end
    end
    if tx == nil then
        return nil
    end
    local moves = {}
    for i, creature in ipairs(creatures()) do
        if overlapsTile(creature, tx, ty) then
            local nx, ny = findSpot(creature, {tx, ty})
            if nx == nil then
                return nil
            end
            table.insert(moves, {creature, nx, ny})
        end
    end
    return {tx = tx, ty = ty, moves = moves}
end


function BlockForm:new(caster, params, x, y, dirX, dirY)
    local form = Form:new(caster)
    setmetatable(form, self)
    self.__index = self

    form.form = "block"
    if caster == nil then
        return form
    end

    local placement = params.placement
    if placement == nil or not tileFree(placement.tx, placement.ty) then
        return nil      -- Something took the tile since the cast checked it(a second block of the same volley)
    end
    for i, move in ipairs(placement.moves) do
        local creature = move[1]
        if creature.body ~= nil and not creature.body:isDestroyed() then
            creature.body:setPosition(move[2], move[3])
            creature.body:setLinearVelocity(0, 0)
        end
    end

    -- The block keeps the spell and its caster, so its onHit and onExpire work timed or permanent(see ManaBlock)
    local mx, my = cellOf(placement.tx, placement.ty)
    local block = map:newBlock("ManaBlock", mx, my)
    block:setup(params.color, params.blockHP, params.glow)
    block.spell = params.spell
    block.byPlayer = caster == player
    block.caster = not block.byPlayer and caster or nil
    block.dirX, block.dirY = dirX, dirY
    if params.lifetime > MANA_BLOCK_PERMANENT then
        -- Lasts forever: saved with the map, no timer
        block.permanent = true
        map:set(mx, my, block)
        return nil
    end
    -- A timed block: this spell is its timer
    form.color = params.color
    form.lifetime = params.lifetime
    form.duration = params.lifetime
    form.block = block
    form.mx, form.my = mx, my
    block.form = form
    map:set(mx, my, block)
    return form
end


function BlockForm:update(dt)
    -- The block left without breaking(its chunk was unloaded far away): the timer ends quietly
    if map:get(self.mx, self.my) ~= self.block then
        self.block.form = nil
        spells:destroy(self)
        return
    end
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        -- Timed out: it breaks like being cleared(what it held up falls, onExpire goes off, the timer ends)
        self.block:breakApart()
    end
end


function BlockForm:getPosition()
    return self.block.x + self.block.width / 2, self.block.y + self.block.height / 2
end


function BlockForm:light(add)
    -- The block itself gives the light(see ManaBlock), so it stays lit once it is permanent too
end

return BlockForm
