local Items = require "items.items"

-- Placing blocks from the selected hotbar slot at a spot in the world
-- Building.target says what would happen at a spot, placing and the preview both use it so they always agree
local Building = {}

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
    local target = {block = item.block, item = stack.item, slot = slot, tx = tx, ty = ty, mx = mx, my = my, ok = false}

    local px, py = player.body:getWorldCenter()
    if my < 1 or my > map.height then
        target.reason = "Outside the world"
    elseif map:blockAt(cx, cy) ~= nil then
        target.reason = "Already a block there"
    elseif distance(px, py, cx + TILE_SIZE / 2, cy + TILE_SIZE / 2) > PLACE_REACH then
        target.reason = "Too far"
    elseif not (map:blockAt(cx - TILE_SIZE, cy) or map:blockAt(cx + TILE_SIZE, cy)
        or map:blockAt(cx, cy - TILE_SIZE) or map:blockAt(cx, cy + TILE_SIZE)) then
        target.reason = "Needs a block next to it"
    elseif overlapsBody(cx, cy, cx + TILE_SIZE, cy + TILE_SIZE) then
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
    map:set(target.mx, target.my, map:newBlock(target.block, target.mx, target.my))
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
    local cx, cy = target.tx * TILE_SIZE, target.ty * TILE_SIZE
    love.graphics.push("all")
    if target.ok then
        love.graphics.setColor(1, 1, 1, 0.45)
        Items.drawIcon(target.item, cx, cy, TILE_SIZE)
        love.graphics.setColor(PLACE_OK_COLOR)
    else
        love.graphics.setColor(PLACE_BLOCKED_COLOR)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx + 1, cy + 1, TILE_SIZE - 2, TILE_SIZE - 2)
    if not target.ok and target.reason ~= nil then
        love.graphics.print(target.reason, cx + TILE_SIZE + 4, cy + 4, 0, 0.8, 0.8)
    end
    love.graphics.pop()
end

return Building
