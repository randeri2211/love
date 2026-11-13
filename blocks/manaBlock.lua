local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local ManaNetwork = require "world_utils.manaNetwork"

-- A block made of mana by the Block form(see forms/blockForm): solid, in its spell color, no hardness so any spell clears it
-- It drops nothing. It keeps its spell and who cast it, timed or permanent: onHit goes off every time it is damaged and
-- onExpire when it is gone(broken or timed out), cast by its caster and paid from their mana like any trigger
-- A timed block isnt saved(it is gone after loading), a permanent one is saved with its spell
-- Within reach of a mana network(see world_utils/manaNetwork) a timed block's timer is kept full while the network pays
-- for it(see BlockForm:update), and damage it takes is paid in network mana instead of hp, unless the player dealt it
local ManaBlock = Block:new()
ManaBlock.noItem = true     -- Made by a spell, not carried
ManaBlock.drop = false

local BLINK_TIME = 3        -- Seconds before a timed block runs out when it starts to blink


function ManaBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ManaBlock"
    block.damageThreshold = 0
    block.hpBar = HPBar(1, 1, 0)
    block.color = {0.6, 0.8, 1, 1}
    block.form = nil            -- The timer of a timed block(see BlockForm:update)
    block.permanent = false
    block.spell = nil           -- The Block spell that made it, its onHit and onExpire children go off from here
    block.caster = nil          -- Who casts them, a block the player made always uses the player(byPlayer)
    block.byPlayer = false
    block.dirX, block.dirY = 1, 0   -- The way it was cast, triggered children go that way

    return block
end


function ManaBlock:setup(color, hp, glow)
    -- Its spell color and hp(Dig runes raise it), Light runes make it a light source in its color
    self.color = {color[1], color[2], color[3], 1}
    self.hpBar = HPBar(hp, hp, 0)
    if glow > 0 then
        local strength = SPELL_LIGHT + glow * LIGHT_RUNE_GLOW
        self.light = {color[1] * strength, color[2] * strength, color[3] * strength}
    end
end


function ManaBlock:castBy()
    -- Who its triggers cast from, nil when nobody can(the player is dead, or the enemy that made it is gone)
    if self.byPlayer then
        if player ~= nil and not player:isDead() then
            return player
        end
        return nil
    end
    local caster = self.caster
    if caster ~= nil and caster.body ~= nil and not caster.body:isDestroyed() and not caster.dying then
        return caster
    end
    return nil
end


function ManaBlock:fire(event, dirX, dirY)
    -- Its onHit or onExpire children, from its center going dirX, dirY or the way it was cast(the caster pays, see Spell:shoot)
    -- The block is their target, so they pass through it instead of hitting it again(see Form:isCaster)
    local caster = self:castBy()
    if self.spell == nil or caster == nil then
        return
    end
    local source = {spell = self.spell, player = caster}
    spells:trigger(source, event, dirX or self.dirX, dirY or self.dirY, self.x + self.width / 2, self.y + self.height / 2, self)
end


local function alive(creature)
    return creature ~= nil and creature.body ~= nil and not creature.body:isDestroyed() and not creature.dying
        and not (creature.isDead ~= nil and creature:isDead())
end


function ManaBlock:attackDirection(source)
    -- Which way its onHit answers a hit: at whoever attacked it(the caster of the spell, or the creature clawing at it),
    -- back the way the spell came when its caster is gone, nil when nothing is known(it uses the way it was cast)
    if source == nil then
        return nil
    end
    local attacker = source.spell ~= nil and source.player or source
    local cx, cy = self.x + self.width / 2, self.y + self.height / 2
    if alive(attacker) then
        local ax, ay = attacker.body:getWorldCenter()
        local dx, dy = ax - cx, ay - cy
        local size = math.sqrt(dx * dx + dy * dy)
        if size > 0.001 then
            return dx / size, dy / size
        end
    end
    if source.getDirection ~= nil then
        local dx, dy = source:getDirection()
        return -dx, -dy
    end
    return nil
end


local function byThePlayer(source)
    -- True when the player dealt a hit: their own touch, or one of their spells
    return source ~= nil and (source == player or (source.spell ~= nil and source.player == player))
end


function ManaBlock:damage(dmg, power, source)
    -- Every hit that lands sets off its onHit, aimed back at what hit it, then it takes the damage like any block
    -- A spell another mana block sent off still damages it but doesnt set it off, or blocks would fire at each other
    -- (and back at their own caster) in a chain
    if source == nil or source.fromBlock == nil then
        self:fire("onHit", self:attackDirection(source))
    end
    -- A network in reach pays for the hit, MANA_BLOCK_NETWORK_HIT mana a point of damage, what it cant pay hits the hp
    -- The player's own hits always hurt it, so they can still take their walls down
    if not byThePlayer(source) and dmg > 0 then
        local cx, cy = self.x + self.width / 2, self.y + self.height / 2
        local node = ManaNetwork.nodeNear(cx, cy)
        if node ~= nil then
            local paid = ManaNetwork.take(node, dmg * MANA_BLOCK_NETWORK_HIT) / MANA_BLOCK_NETWORK_HIT
            if paid > 0 then
                ManaNetwork.flow(node, cx, cy)
            end
            dmg = dmg - paid
        end
    end
    Block.damage(self, dmg, power)
end


function ManaBlock:breakApart()
    -- Broken or timed out: nothing drops, onExpire goes off and a timed block stops its timer
    Block.breakApart(self)
    self:fire("onExpire")
    local form = self.form
    if form ~= nil then
        self.form = nil
        spells:destroy(form)
    end
end


function ManaBlock:tooltip()
    local state = "Permanent"
    if self.form ~= nil then
        state = self.form.sustained and "Kept up by a mana network" or string.format("%d s left", math.ceil(self.form.lifetime))
    end
    return string.format("Mana Block\n%d / %d hp\n%s", math.ceil(self.hpBar.currentHP), self.hpBar.maxHP, state)
end


function ManaBlock:isTemporary()
    -- A timed block isnt saved, the map leaves it out(see encodeChunk)
    return self.form ~= nil
end


function ManaBlock:hasOwnState()
    -- Its color, light and spell are its own, so a permanent block is saved whole
    return true
end


function ManaBlock:saveData()
    -- What a permanent block keeps: the block, its look and its spell(as data), never the caster itself
    return {
        name = self.name, x = self.x, y = self.y, width = self.width, height = self.height,
        hpBar = {currentHP = self.hpBar.currentHP, maxHP = self.hpBar.maxHP, regen = 0},
        color = self.color, light = self.light, permanent = self.permanent,
        spell = self.spell and self.spell:toData(), byPlayer = self.byPlayer, dirX = self.dirX, dirY = self.dirY,
    }
end


function ManaBlock:load(data)
    Block.load(self, data)
    self.hpBar = HPBar(data.hpBar.maxHP, data.hpBar.maxHP, 0)
    self.hpBar.currentHP = data.hpBar.currentHP
    self.color = data.color or self.color
    self.light = data.light
    self.permanent = data.permanent
    self.byPlayer = data.byPlayer == true
    self.dirX, self.dirY = data.dirX or 1, data.dirY or 0
    if data.spell ~= nil then
        self.spell = require("magic.spell").fromData(data.spell)
    end
end


function ManaBlock:draw()
    -- A see-through tile of mana with a bright edge, a timed one blinks when it is about to run out
    local c = self.color
    local alpha = 1
    local form = self.form
    if form ~= nil and form.lifetime < BLINK_TIME then
        alpha = 0.55 + 0.45 * math.abs(math.cos(form.lifetime * 5))
    end
    local inset = self.width / 16
    love.graphics.push("all")
    love.graphics.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.85 * alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(c[1], c[2], c[3], 0.35 * alpha)
    love.graphics.rectangle("fill", self.x + inset * 3, self.y + inset * 3, self.width - inset * 6, self.height - inset * 6)
    love.graphics.setColor(0.5 + c[1] * 0.5, 0.5 + c[2] * 0.5, 0.5 + c[3] * 0.5, alpha)
    love.graphics.setLineWidth(inset)
    love.graphics.rectangle("line", self.x + inset / 2, self.y + inset / 2, self.width - inset, self.height - inset)
    love.graphics.pop()
end


registerBlock("ManaBlock", ManaBlock)

return ManaBlock
