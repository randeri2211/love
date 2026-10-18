local Block = require "blocks.block"
local HPBar = require "components.hpBar"

local OreBlock = Block:new()
registerBlock("Ore", OreBlock)

local SPECK_COLOR = {1, 0.82, 0.3, 1}

function OreBlock:new(x, y, width, height)
    -- Pockets in the deep stone, needs a strong Dig spell
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self

    block.name = "Ore"
    block.tile = "stone"
    block.tint = {0.75, 0.7, 0.65, 1}
    block.damageThreshold = 25
    block.hpBar = HPBar(15, 15, 0)

    return block
end


function OreBlock:draw()
    -- Stone with gold specks, placed from the block position so every ore block keeps the same look
    Block.draw(self)
    local s = self.width / 8
    love.graphics.setColor(SPECK_COLOR)
    for i = 1, 3 do
        local hash = (self.mx * 73 + self.my * 151 + i * 47) % 64
        local px = hash % 7
        local py = math.floor(hash / 8) % 7
        love.graphics.rectangle("fill", self.x + px * s, self.y + py * s, s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return OreBlock
