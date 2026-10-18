local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local StoneBlock = Block:new()
registerBlock("Stone", StoneBlock)

function StoneBlock:new(x, y, width, height)
    -- Most of the underground, plain bullets(10) and lasers(2) cant dig it, a Dig bullet(20) or an Area(20) can
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Stone"
    block.tile = "stone"
    block.tint = {0.85, 0.85, 0.9, 1}
    block.damageThreshold = 12
    block.hpBar = HPBar(10, 10, 0)

    return block
end

return StoneBlock
