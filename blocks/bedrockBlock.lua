local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local BedrockBlock = Block:new()
registerBlock("Bedrock", BedrockBlock)

function BedrockBlock:new(x, y, width, height)
    -- Bottom of the world, nothing can dig it
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Bedrock"
    block.tile = "stone"
    block.tint = {0.35, 0.32, 0.4, 1}
    block.damageThreshold = math.huge
    block.hpBar = HPBar(1, 1, 0)

    return block
end

return BedrockBlock
