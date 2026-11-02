local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local DeepstoneBlock = Block:new()
registerBlock("Deepstone", DeepstoneBlock)

function DeepstoneBlock:new(x, y, width, height)
    -- Dark stone of the deep layer, harder than stone
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Deepstone"
    block.tile = "deepstone" .. block:variant(3)
    block.damageThreshold = 18
    block.hpBar = HPBar(14, 14, 0)

    return block
end

return DeepstoneBlock
