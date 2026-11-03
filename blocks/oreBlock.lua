local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- Every ore is the same block: a stone tile with nuggets drawn over it in the ore color
-- The stone variant and the nugget pattern are picked from the block position, so neighbors look different
local OreBlock = Block:new()

-- Ores by block name: nugget color, the stone they sit in, and how hard they are to dig
local ORES = {
    {name = "CopperOre", color = {0.85, 0.5, 0.25, 1}, host = "stone", threshold = 14, hp = 12},
    {name = "IronOre", color = {0.82, 0.74, 0.68, 1}, host = "stone", threshold = 20, hp = 14},
    {name = "GoldOre", color = {1, 0.82, 0.25, 1}, host = "stone", threshold = 25, hp = 15},
    {name = "DeepGoldOre", color = {1, 0.82, 0.25, 1}, host = "deepstone", threshold = 30, hp = 18},
    {name = "ArcaniteOre", color = {0.4, 0.85, 1, 1}, host = "deepstone", threshold = 35, hp = 20, light = ARCANITE_LIGHT},
}
local PATTERNS = 4      -- ore1 to ore4 in the tilesheet
local HOST_VARIANTS = 3 -- stone1 to stone3, deepstone1 to deepstone3


function OreBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    local ore = self.ore
    block.name = ore.name
    block.tile = ore.host .. block:variant(HOST_VARIANTS, 1)
    block.pattern = "ore" .. block:variant(PATTERNS, 2)
    block.damageThreshold = ore.threshold
    block.hpBar = HPBar(ore.hp, ore.hp, 0)

    return block
end


function OreBlock:draw()
    -- The stone, then the nuggets tinted with the ore color(the pattern tile is grayscale)
    Block.draw(self)
    local quad = BLOCK_TILES[self.pattern]
    local _, _, qw, qh = quad:getViewport()
    love.graphics.setColor(self.ore.color)
    love.graphics.draw(TILESHEET, quad, self.x, self.y, 0, self.width / qw, self.height / qh)
    love.graphics.setColor(1, 1, 1, 1)
end


-- One block class per ore, they only differ in their ore table
for i, ore in ipairs(ORES) do
    local class = OreBlock:new()
    class.ore = ore
    class.light = ore.light     -- Glowing ores light the tiles around them(see world_utils/lighting)
    registerBlock(ore.name, class)
end

return OreBlock
