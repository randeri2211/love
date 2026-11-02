-- Woodworking station: rods for wands and large rods for staves(see docs/game-design)
local WOODS = {"Oak", "Pine"}

for i, wood in ipairs(WOODS) do
    registerRecipe({output = wood .. "Rod", inputs = {{item = wood .. "Wood", count = 4}},
        station = "WoodworkingStation", tier = 1, category = "Wand parts"})
    registerRecipe({output = "Large" .. wood .. "Rod", inputs = {{item = wood .. "Wood", count = 8}},
        station = "WoodworkingStation", tier = 1, category = "Wand parts"})
end

-- Wooden parts: the first core(dig cap 15, enough for stone and copper), a plain cap and tip
registerRecipe({output = "WoodenCore", inputs = {{group = "Wood", count = 6}}, station = "WoodworkingStation", tier = 1, category = "Wand parts"})
registerRecipe({output = "WoodenCap", inputs = {{group = "Wood", count = 2}}, station = "WoodworkingStation", tier = 1, category = "Wand parts"})
registerRecipe({output = "WoodenTip", inputs = {{group = "Wood", count = 4}}, station = "WoodworkingStation", tier = 1, category = "Wand parts"})

-- The arcane table puts wands and staves together, it needs no stone(bare hands cant dig stone)
registerRecipe({output = "ArcaneTable", inputs = {{group = "Wood", count = 15}}, station = "WoodworkingStation", tier = 1, category = "Stations"})
