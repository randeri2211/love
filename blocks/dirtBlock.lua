local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local DirtBlock = Block:new()
registerBlock("Dirt", DirtBlock)

function DirtBlock:new(x, y, width, height)
    -- The few layers under the grass, anything can dig it
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Dirt"
    block.tile = "dirt"
    block.damageThreshold = 1
    block.hpBar = HPBar(5, 5, 0)

    return block
end

return DirtBlock
