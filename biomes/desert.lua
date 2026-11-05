-- Low sandy dunes over sandstone, dry so it has fewer caves
registerBiome("Desert", {
    kind = "surface",
    weight = 3,
    terrain = {baseRow = 3, hillHeight = 6, roughness = 0.7},
    blocks = {top = "Sand", filler = "Sand", fillerDepth = 7, stone = "Sandstone"},
    caves = {startDepth = 14, tunnel = 0.035, network = 0.03, scale = 0.5, cavern = 0.9},
    flora = {tree = "Cactus", treeChance = 0.4},
    ores = {
        {block = "CopperOre", minDepth = ORE_START_DEPTH, threshold = 0.77},
        {block = "GoldOre", minDepth = 30, threshold = 0.8},
    },
    -- Sky and the far, mid and near silhouettes behind it(see world_utils/background), height scales the peaks
    background = {
        skyTop = {0.42, 0.6, 0.9}, skyBottom = {1, 0.88, 0.7}, height = 0.6,
        layers = {
            {color = {0.86, 0.72, 0.64}, rim = {0.95, 0.83, 0.74}},
            {color = {0.88, 0.72, 0.5}, rim = {0.96, 0.83, 0.6}},
            {color = {0.8, 0.62, 0.4}, rim = {0.92, 0.76, 0.5}},
        },
    },
    spawns = {
        {entity = "ScorchedZombie", weight = 8, where = "surface", group = {1, 2}},
        {entity = "Zombie", weight = 3, where = "surface", group = {1, 1}},
        {entity = "SmallSlime", weight = 3, where = "surface", group = {2, 3}},
        {entity = "Slime", weight = 4, where = "surface", group = {1, 2}},
        {entity = "BigSlime", weight = 2, where = "surface", group = {1, 1}},
        {entity = "SkeletonArcher", weight = 5, where = "surface", group = {1, 2}, time = "night"},
    },
})
