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
    -- The sky and the hills behind it, far to near(see world_utils/background): images in
    -- assets/art*/backgrounds/snow/ that repeat sideways, parallax is how much of the camera movement a layer follows,
    -- rise lifts it on the screen and baseline is the row of its image where its hills meet their flat ground(16 pixel layout)
    background = {
        folder = "snow",
        layers = {
            {file = "far", parallax = 0.1, rise = 110, baseline = 155},
            {file = "middle", parallax = 0.25, rise = 40, baseline = 94},
            {file = "near", parallax = 0.45, rise = -10, baseline = 49},
        },
    },
    spawns = {
        {entity = "FrostbittenZombie", weight = 8, where = "surface", group = {1, 3}},
        {entity = "Zombie", weight = 3, where = "surface", group = {1, 2}},
        {entity = "SmallSlime", weight = 3, where = "surface", group = {2, 3}},
        {entity = "Slime", weight = 3, where = "surface", group = {1, 2}},
        {entity = "BigSlime", weight = 1, where = "surface", group = {1, 1}},
        {entity = "SkeletonArcher", weight = 4, where = "surface", group = {1, 2}, time = "night"},
    },
})
