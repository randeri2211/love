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
    -- The sky and the hills behind it, far to near(see world_utils/background): images in
    -- assets/art*/backgrounds/desert/ that repeat sideways, parallax is how much of the camera movement a layer follows,
    -- rise lifts it on the screen and baseline is the row of its image where its hills meet their flat ground(16 pixel layout)
    background = {
        folder = "desert",
        layers = {
            {file = "far", parallax = 0.1, rise = 110, baseline = 65},
            {file = "middle", parallax = 0.25, rise = 40, baseline = 40},
            {file = "near", parallax = 0.45, rise = -10, baseline = 22},
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
