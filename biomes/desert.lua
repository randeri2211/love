-- Low sandy dunes over sandstone, dry so it has fewer caves
registerBiome("Desert", {
    kind = "surface",
    weight = 3,
    terrain = {baseRow = 3, hillHeight = 6, roughness = 0.7},
    blocks = {top = "Sand", filler = "Sand", fillerDepth = 7, stone = "Sandstone"},
    caves = {startDepth = 14, tunnel = 0.04, cavern = 0.87},
    ores = {
        {block = "CopperOre", minDepth = ORE_START_DEPTH, threshold = 0.77},
        {block = "GoldOre", minDepth = 30, threshold = 0.8},
    },
    spawns = {
        {entity = "Zombie", weight = 6, where = "surface", group = {1, 1}},
    },
})
