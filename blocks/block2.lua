local Block = require "blocks.block"

Block2 = Block:new()
registerBlock("Block2",Block2)

function Block2:new(x, y, width, height)
    -- Block Variables
    local block2 = Block:new(x, y, width, height)
    setmetatable(block2, self)
    self.__index = self

    block2.name = "Block2"
    block2.tile = "slab"
    block2.tooltipText = "Block2?"

    return block2
end

return Block2