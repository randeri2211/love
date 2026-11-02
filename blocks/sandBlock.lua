local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local SandBlock = Block:new()
registerBlock("Sand", SandBlock)

function SandBlock:new(x, y, width, height)
    -- Desert ground, soft so anything can dig it
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Sand"
    block.tile = "sand"
    block.damageThreshold = 1
    block.hpBar = HPBar(4, 4, 0)

    return block
end

return SandBlock
