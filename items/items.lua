-- Helpers for items(ITEM_REGISTRY): names and icons
-- An item is a table registered by name: {displayName, maxStack, block(the block it places and looks like), tile}
-- A stack is {item, count} and can carry data of its own(a wand keeps its parts in data), items with data never stack
local Items = {}

local sampleBlocks = {}     -- One block of each block item, drawn as its icon


function Items.get(name)
    return ITEM_REGISTRY[name]
end


function Items.maxStack(name)
    local item = ITEM_REGISTRY[name]
    return item and item.maxStack or ITEM_STACK
end


local function copyData(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = copyData(v)
    end
    return copy
end


function Items.copy(stack, count)
    -- A new stack of the same item with its own copy of the data, count defaults to the same count
    return {item = stack.item, count = count or stack.count, data = copyData(stack.data)}
end


function Items.stackName(stack)
    -- Name of a stack, items can name it from its data(a wand is named after its rod)
    local item = ITEM_REGISTRY[stack.item]
    if item ~= nil and item.describe ~= nil and stack.data ~= nil then
        return item.describe(stack)
    end
    return Items.displayName(stack.item)
end


function Items.displayName(name)
    -- The given display name, or the registry name with spaces before capitals("CopperOre" is "Copper Ore")
    local item = ITEM_REGISTRY[name]
    if item and item.displayName then
        return item.displayName
    end
    return (name:gsub("(%l)(%u)", "%1 %2"))
end


function Items.drawIcon(name, x, y, size, stack)
    -- Icon of an item in a size x size square, block items look like their block(ores with their nuggets)
    -- stack is optional, items can tint their icon from its data(a wand takes the color of its rod)
    local item = ITEM_REGISTRY[name]
    if item == nil then
        love.graphics.draw(BLOCK_IMG.FALLBACK, x, y, 0, size / BLOCK_IMG.FALLBACK:getWidth(), size / BLOCK_IMG.FALLBACK:getHeight())
        return
    end
    if item.block ~= nil then
        local block = sampleBlocks[name]
        if block == nil then
            block = BLOCK_REGISTRY[item.block]:new(0, 0, TILE_SIZE, TILE_SIZE)
            sampleBlocks[name] = block
        end
        block.x, block.y, block.width, block.height = x, y, size, size
        block:draw()
    elseif item.icon ~= nil then
        -- An icon from the item sheet tinted with the item color(one shape serves every material)
        local quad = ITEM_TILES[item.icon]
        local _, _, qw, qh = quad:getViewport()
        local r, g, b, a = love.graphics.getColor()
        local tint = (stack ~= nil and stack.data ~= nil and item.stackTint ~= nil and item.stackTint(stack)) or item.tint or {1, 1, 1, 1}
        love.graphics.setColor(r * tint[1], g * tint[2], b * tint[3], a * (tint[4] or 1))
        love.graphics.draw(ITEM_SHEET, quad, x, y, 0, size / qw, size / qh)
        love.graphics.setColor(r, g, b, a)
    elseif item.tile ~= nil then
        local quad = BLOCK_TILES[item.tile]
        local _, _, qw, qh = quad:getViewport()
        love.graphics.draw(TILESHEET, quad, x, y, 0, size / qw, size / qh)
    end
end

return Items
