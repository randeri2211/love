-- Woodworking station: rods for wands and large rods for staves(see docs/game-design)
local WOODS = {"Oak", "Pine"}

for i, wood in ipairs(WOODS) do
    registerRecipe({output = wood .. "Rod", inputs = {{item = wood .. "Wood", count = 4}},
        station = "WoodworkingStation", tier = 1, category = "Wand parts"})
    registerRecipe({output = "Large" .. wood .. "Rod", inputs = {{item = wood .. "Wood", count = 8}},
        station = "WoodworkingStation", tier = 1, category = "Wand parts"})
end
