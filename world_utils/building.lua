local Items = require "items.items"

-- Placing blocks from the selected hotbar slot at a spot in the world
-- Building.target says what would happen at a spot, placing and the preview both use it so they always agree
local Building = {}

local function solidBlockAt(x, y)
    -- A solid block in the tile of a love point(trees and plants dont hold a block up)
    local block = map:blockAt(x, y)
    return block ~= nil and block.solid
end


local function overlapsBody(x1, y1, x2, y2)
    -- True when the player, an enemy or a dropped item is in the box, a block would trap it
    local blocked = false
    p_world:queryBoundingBox(x1 + 1, y1 + 1, x2 - 1, y2 - 1, function(fixture)
        local category = fixture:getCategory()
        if category == PLAYER_CATEGORY or category == ENEMY_CATEGORY or category == ITEM_CATEGORY then
            blocked = true
            return false    -- Stop looking
        end
        return true
    end)
    return blocked
end


function Building.target(player, x, y)
    -- What placing at love x, y would do: {block, slot, tx, ty, mx, my, ok, reason}
    -- nil when the selected hotbar slot doesnt hold a block
    local slot = player.hotbarSlot
    local stack = player.inventory.slots[slot]
    local item = stack and ITEM_REGISTRY[stack.item]
    -- Empty slots are false, not nil
    if not item or item.block == nil then
        return nil
    end
    local tx, ty = math.floor(x / TILE_SIZE), math.floor(y / TILE_SIZE)
    local cx, cy = tx * TILE_SIZE, ty * TILE_SIZE
    local mx, my = loveToMap(cx, cy)
    -- A block bigger than a tile(see blocks/bigBlock) goes up and right from the tile under the mouse
    local footprint = BLOCK_REGISTRY[item.block].footprint or {1, 1}
    local box = {cx, cy + TILE_SIZE - footprint[2] * TILE_SIZE, footprint[1] * TILE_SIZE, footprint[2] * TILE_SIZE}
    local target = {block = item.block, item = stack.item, slot = slot, tx = tx, ty = ty, mx = mx, my = my, box = box, ok = false}

    -- Every tile it would fill, and whether one of them has a solid block next to it(outside of it)
    local blockedBy, supported, outside = nil, false, false
    for i = 0, footprint[1] - 1 do
        for j = 0, footprint[2] - 1 do
            local tileX, tileY = cx + i * TILE_SIZE, cy - j * TILE_SIZE
            local _, tileMy = loveToMap(tileX, tileY)
            local existing = map:blockAt(tileX, tileY)
            if tileMy < 1 or tileMy > map.height then
                outside = true
            elseif existing ~= nil and not existing.replaceable then
                blockedBy = blockedBy or existing
            end
            for k, side in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
                local si, sj = i + side[1], j - side[2]
                local inside = si >= 0 and si < footprint[1] and sj >= 0 and sj < footprint[2]
                if not inside and solidBlockAt(tileX + side[1] * TILE_SIZE, tileY + side[2] * TILE_SIZE) then
                    supported = true
                end
            end
        end
    end

    local px, py = player.body:getWorldCenter()
    if outside then
        target.reason = "Outside the world"
    elseif blockedBy ~= nil then
        -- Small plants make way, a tree is in the way like any block
        target.reason = blockedBy.solid and "Already a block there" or "A tree is in the way"
    elseif distance(px, py, box[1] + box[3] / 2, box[2] + box[4] / 2) > PLACE_REACH then
        target.reason = "Too far"
    elseif not supported then
        target.reason = "Needs a block next to it"
    elseif overlapsBody(box[1], box[2], box[1] + box[3], box[2] + box[4]) then
        target.reason = "Something is in the way"
    else
        target.ok = true
    end
    return target
end


function Building.place(player, x, y)
    -- Places the selected block at love x, y and uses one from the hotbar, true when it was placed
    local target = Building.target(player, x, y)
    if target == nil or not target.ok then
        return false
    end
    -- Plants in the way are cleared first, dropping what they give
    local footprint = BLOCK_REGISTRY[target.block].footprint or {1, 1}
    for i = 0, footprint[1] - 1 do
        for j = 0, footprint[2] - 1 do
            local existing = map:get(target.mx + i, target.my + j)
            if existing ~= nil then
                local item = existing:dropItem()
                if item ~= nil then
                    map.drops:spawn(item, 1, existing.x + existing.width / 2, existing.y + existing.height / 2)
                end
                map:set(target.mx + i, target.my + j, nil)
            end
        end
    end
    local block = map:newBlock(target.block, target.mx, target.my)
    map:set(target.mx, target.my, block)
    if block.placeParts ~= nil then
        block:placeParts()
    end
    local stack = player.inventory.slots[target.slot]
    stack.count = stack.count - 1
    if stack.count <= 0 then
        player.inventory.slots[target.slot] = false
    end
    return true
end


function Building.drawPreview(player, x, y)
    -- World space: the tile the selected block would go in, faint block with a green outline, red with the reason when it cant
    local target = Building.target(player, x, y)
    if target == nil then
        return
    end
    local bx, by, bw, bh = unpack(target.box)
    love.graphics.push("all")
    if target.ok then
        love.graphics.setColor(1, 1, 1, 0.45)
        Items.drawIcon(target.item, bx, by, math.max(bw, bh))
        love.graphics.setColor(PLACE_OK_COLOR)
    else
        love.graphics.setColor(PLACE_BLOCKED_COLOR)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx + 1, by + 1, bw - 2, bh - 2)
    if not target.ok and target.reason ~= nil then
        love.graphics.print(target.reason, bx + bw + 4, by + 4)
    end
    love.graphics.pop()
end

return Building
