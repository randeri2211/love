-- Tall sharp snowy hills
registerBiome("Snow", {
    kind = "surface",
    weight = 3,
    terrain = {baseRow = -6, hillHeight = 26, roughness = 1.5},
    blocks = {top = "Snow", filler = "Dirt", fillerDepth = DIRT_DEPTH, stone = "Stone"},
    caves = {startDepth = CAVE_START_DEPTH, tunnel = 0.045, network = 0.04, scale = 0.5, cavern = 0.88},
    ores = {
        {block = "IronOre", minDepth = ORE_START_DEPTH, threshold = ORE_THRESHOLD},
        {block = "CopperOre", minDepth = 25, threshold = 0.8},
    },
    spawns = {
        {entity = "Zombie", weight = 8, where = "surface", group = {1, 3}},
    },
})
