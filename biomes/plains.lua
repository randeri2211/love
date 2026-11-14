-- Grassy rolling hills, the world as it was before biomes(worlds saved before biomes are all plains)
registerBiome("Plains", {
    kind = "surface",
    weight = 4,                 -- How often it comes up compared to other surface biomes
    terrain = {
        baseRow = 0,            -- Rows above(negative) or below SURFACE_ROW the ground sits
        hillHeight = HILL_HEIGHT,
        roughness = 1,          -- How quickly the hills change, higher is choppier
    },
    blocks = {top = "Grass", filler = "Dirt", fillerDepth = DIRT_DEPTH, stone = "Stone"},
    caves = {startDepth = CAVE_START_DEPTH, tunnel = 0.045, network = 0.04, scale = 0.5, cavern = 0.87},
    -- What grows on it(see world_utils/flora): the tree, how many tree spots get one, the small plant and how many ground tiles get one
    flora = {tree = "Oak", treeChance = 0.55, plant = "TallGrass", plantChance = 0.3},
    ores = {
        {block = "CopperOre", minDepth = ORE_START_DEPTH, threshold = ORE_THRESHOLD},
        {block = "IronOre", minDepth = 28, threshold = 0.79},
    },
    -- The sky and the hills behind it, far to near(see world_utils/background): images in
    -- assets/art*/backgrounds/plains/ that repeat sideways, parallax is how much of the camera movement a layer follows,
    -- rise lifts it on the screen and baseline is the row of its image where its hills meet their flat ground(16 pixel layout)
    background = {
        folder = "plains",
        layers = {
            {file = "far", parallax = 0.1, rise = 110, baseline = 105},
            {file = "middle", parallax = 0.25, rise = 40, baseline = 64},
            {file = "near", parallax = 0.45, rise = -10, baseline = 34},
        },
    },
    -- What can appear here, read by the spawner(see world_utils/spawner): entity, weight, where("surface" or "cave"), group size,
    -- and optionally time("day" or "night", any time when left out)
    spawns = {
        {entity = "Zombie", weight = 10, where = "surface", group = {1, 2}},
        {entity = "SmallSlime", weight = 4, where = "surface", group = {2, 3}},
        {entity = "Slime", weight = 5, where = "surface", group = {1, 2}},
        {entity = "BigSlime", weight = 2, where = "surface", group = {1, 1}},
        {entity = "SkeletonArcher", weight = 4, where = "surface", group = {1, 2}, time = "night"},
    },
})
