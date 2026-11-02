local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local SnowBlock = Block:new()
registerBlock("Snow", SnowBlock)
SnowBlock.drop = "Dirt"     -- The snow on top doesnt come along

function SnowBlock:new(x, y, width, height)
    -- Top layer of snowy hills, soft
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Snow"
    block.tile = "snow"
    block.damageThreshold = 1
    block.hpBar = HPBar(4, 4, 0)

    return block
end

return SnowBlock
