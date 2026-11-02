local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local SandstoneBlock = Block:new()
registerBlock("Sandstone", SandstoneBlock)

function SandstoneBlock:new(x, y, width, height)
    -- Desert stone, a little softer than stone
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Sandstone"
    block.tile = "sandstone"
    block.damageThreshold = 8
    block.hpBar = HPBar(8, 8, 0)

    return block
end

return SandstoneBlock
