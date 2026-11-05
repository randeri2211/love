-- Forge: smelts ore into bars, and works bars into armor
local ORE_PER_BAR = 3

-- Ore, the bar it smelts into and its tier(CRAFT_TIERS)
local SMELTING = {
    {ore = "CopperOre", bar = "CopperBar", tier = 2},
    {ore = "IronOre", bar = "IronBar", tier = 3},
    {ore = "GoldOre", bar = "GoldBar", tier = 4},
    {ore = "DeepGoldOre", bar = "GoldBar", tier = 4},
    {ore = "ArcaniteOre", bar = "ArcaniteBar", tier = 5},
}
for i, s in ipairs(SMELTING) do
    registerRecipe({output = s.bar, inputs = {{item = s.ore, count = ORE_PER_BAR}}, station = "Forge", tier = s.tier, category = "Bars"})
end

-- Bars per armor piece, the same for every metal(see items/armor)
local PIECES = {{word = "Helmet", bars = 5}, {word = "Chestplate", bars = 8}, {word = "Leggings", bars = 6}, {word = "Boots", bars = 4}}
local METALS = {{name = "Copper", tier = 2}, {name = "Iron", tier = 3}}
for i, metal in ipairs(METALS) do
    for j, piece in ipairs(PIECES) do
        registerRecipe({output = metal.name .. piece.word, inputs = {{item = metal.name .. "Bar", count = piece.bars}},
            station = "Forge", tier = metal.tier, category = "Armor"})
    end
end

-- Metal wand and staff parts: cores open the next ore, caps and tips change how spells cast(see items/wandParts)
local PART_METALS = {{name = "Copper", tier = 2}, {name = "Iron", tier = 3}, {name = "Gold", tier = 4}}
local PART_BARS = {Core = 4, Cap = 2, Tip = 4}
for i, metal in ipairs(PART_METALS) do
    for _, part in ipairs({"Core", "Cap", "Tip"}) do
        registerRecipe({output = metal.name .. part, inputs = {{item = metal.name .. "Bar", count = PART_BARS[part]}},
            station = "Forge", tier = metal.tier, category = "Wand parts"})
    end
end

-- Chests: each one is the chest before it bound in metal, so a chest grows with the ores
registerRecipe({output = "IronChest", inputs = {{item = "WoodenChest", count = 1}, {item = "IronBar", count = 8}},
    station = "Forge", tier = 3, category = "Storage"})
registerRecipe({output = "ArcaniteChest", inputs = {{item = "IronChest", count = 1}, {item = "ArcaniteBar", count = 8}},
    station = "Forge", tier = 5, category = "Storage"})
