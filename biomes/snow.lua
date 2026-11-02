-- Tall sharp snowy hills
registerBiome("Snow", {
    kind = "surface",
    weight = 3,
    terrain = {baseRow = -6, hillHeight = 26, roughness = 1.5},
    blocks = {top = "Snow", filler = "Dirt", fillerDepth = DIRT_DEPTH, stone = "Stone"},
    caves = {startDepth = CAVE_START_DEPTH, tunnel = 0.045, network = 0.04, scale = 0.5, cavern = 0.88},
    flora = {tree = "Pine", treeChance = 0.6},
    ores = {
        {block = "IronOre", minDepth = ORE_START_DEPTH, threshold = ORE_THRESHOLD},
        {block = "CopperOre", minDepth = 25, threshold = 0.8},
    },
    -- Sky and the far, mid and near silhouettes behind it(see world_utils/background), height scales the peaks
    background = {
        skyTop = {0.48, 0.6, 0.84}, skyBottom = {0.86, 0.91, 0.98}, height = 1.5,
        layers = {
            {color = {0.68, 0.74, 0.88}, rim = {0.97, 0.98, 1}},
            {color = {0.54, 0.62, 0.76}, rim = {0.93, 0.95, 1}},
            {color = {0.42, 0.5, 0.62}, rim = {0.88, 0.92, 0.98}},
        },
    },
    spawns = {
        {entity = "Zombie", weight = 8, where = "surface", group = {1, 3}},
    },
})
