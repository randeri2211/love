-- Crafting materials that arent blocks, drawn with a tile of the block they come from
-- Wood from trees, cactus from the desert, fiber from tall grass(see blocks/floraBlock)
registerItem("OakWood", {displayName = "Oak Wood", tile = "oakLog"})
registerItem("PineWood", {displayName = "Pine Wood", tile = "pineLog"})
registerItem("Cactus", {tile = "cactus"})
registerItem("PlantFiber", {displayName = "Plant Fiber", tile = "tallGrass"})

-- Enemy drops(see the loot of each enemy): slime gel for torches and the first ink, bones for later crafting,
-- rotten flesh for regeneration potions once alchemy exists
registerItem("SlimeGel", {displayName = "Slime Gel", icon = "gel", tint = {0.5, 0.95, 0.5, 1}})
registerItem("Bone", {icon = "bone", tint = {0.95, 0.92, 0.84, 1}})
registerItem("RottenFlesh", {displayName = "Rotten Flesh", icon = "flesh", tint = {0.62, 0.72, 0.42, 1}})
-- Wood of any tree counts where a recipe asks for the "Wood" group(see items/crafting)
ITEM_REGISTRY.OakWood.group = "Wood"
ITEM_REGISTRY.PineWood.group = "Wood"

-- Bars smelted from ore at the forge, one bar icon tinted per metal like the armor
local BARS = {
    {name = "CopperBar", tint = {0.95, 0.6, 0.35, 1}},
    {name = "IronBar", tint = {0.8, 0.8, 0.86, 1}},
    {name = "GoldBar", tint = {1, 0.84, 0.3, 1}},
    {name = "ArcaniteBar", tint = {0.45, 0.88, 1, 1}},
}
for i, bar in ipairs(BARS) do
    registerItem(bar.name, {icon = "bar", tint = bar.tint})
end

