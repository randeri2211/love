local Block = require "blocks.block"

Block2 = Block:new()
registerBlock("Block2",Block2)

function Block2:new(x, y, width, height)
    -- Block Variables
    local block2 = Block:new(x, y, width, height)
    setmetatable(block2, self)
    self.__index = self

    block2.imagePath = "PANELING_SMALL"
    block2.name = "Block2"
    block2.image = BLOCK_IMG[block2.imagePath]
    block2.tooltipText = "Block2?"

    return block2
end

return Block2