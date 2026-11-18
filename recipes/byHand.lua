-- Recipes that need no station, the first stations are made here
-- Inputs name an item, or a group any of whose items count(group = "Wood" takes Oak Wood or Pine Wood)
registerRecipe({output = "WoodworkingStation", inputs = {{group = "Wood", count = 10}}, tier = 1, category = "Stations"})
registerRecipe({output = "SlimeInk", inputs = {{item = "SlimeGel", count = 2}}, tier = 1, category = "Ink"})
registerRecipe({output = "BoneInk", inputs = {{item = "Bone", count = 2}, {item = "SlimeGel", count = 1}}, tier = 1, category = "Ink"})
registerRecipe({output = "BlankScroll", inputs = {{item = "PlantFiber", count = 2}}, tier = 1, category = "Scrolls"})
registerRecipe({output = "Torch", count = 4, inputs = {{group = "Wood", count = 1}}, tier = 1, category = "Light"})
registerRecipe({output = "Torch", count = 8, inputs = {{group = "Wood", count = 1}, {item = "SlimeGel", count = 1}}, tier = 1, category = "Light"})
registerRecipe({output = "Forge", inputs = {{item = "Stone", count = 20}, {group = "Wood", count = 4}}, tier = 1, category = "Stations"})
