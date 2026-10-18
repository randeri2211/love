local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local GrassBlock = Block:new()
registerBlock("Grass", GrassBlock)

function GrassBlock:new(x, y, width, height)
    -- Top layer of the ground, anything can dig it
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Grass"
    block.tile = "grass"
    block.damageThreshold = 1
    block.hpBar = HPBar(5, 5, 0)

    return block
end

return GrassBlock
