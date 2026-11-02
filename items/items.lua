-- Helpers for items(ITEM_REGISTRY): names and icons
-- An item is a table registered by name: {displayName, maxStack, block(the block it places and looks like), tile}
local Items = {}

local sampleBlocks = {}     -- One block of each block item, drawn as its icon


function Items.get(name)
    return ITEM_REGISTRY[name]
end


function Items.maxStack(name)
    local item = ITEM_REGISTRY[name]
    return item and item.maxStack or ITEM_STACK
end


function Items.displayName(name)
    -- The given display name, or the registry name with spaces before capitals("CopperOre" is "Copper Ore")
    local item = ITEM_REGISTRY[name]
    if item and item.displayName then
        return item.displayName
    end
    return (name:gsub("(%l)(%u)", "%1 %2"))
end


function Items.drawIcon(name, x, y, size)
    -- Icon of an item in a size x size square, block items look like their block(ores with their nuggets)
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
    elseif item.tile ~= nil then
        local quad = BLOCK_TILES[item.tile]
        local _, _, qw, qh = quad:getViewport()
        love.graphics.draw(TILESHEET, quad, x, y, 0, size / qw, size / qh)
    end
end

return Items
