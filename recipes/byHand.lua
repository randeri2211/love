-- Recipes that need no station, the first stations are made here
-- Inputs name an item, or a group any of whose items count(group = "Wood" takes Oak Wood or Pine Wood)
registerRecipe({output = "WoodworkingStation", inputs = {{group = "Wood", count = 10}}, tier = 1, category = "Stations"})
registerRecipe({output = "BlankScroll", inputs = {{item = "PlantFiber", count = 2}}, tier = 1, category = "Scrolls"})
registerRecipe({output = "Torch", count = 4, inputs = {{group = "Wood", count = 1}}, tier = 1, category = "Light"})
registerRecipe({output = "Forge", inputs = {{item = "Stone", count = 20}, {group = "Wood", count = 4}}, tier = 1, category = "Stations"})
