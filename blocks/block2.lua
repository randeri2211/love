require "blocks.block"
require "assets.assetLoader"
Block2 = Block:new()

function Block2:new(x, y, width, height)
    -- Block Variables
    local block2 = Block:new(x, y, width, height)
    setmetatable(block2, self)
    self.__index = self

    block2.image = PANELING_SMALL

    return block2
end