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
    -- Sky and the far, mid and near silhouettes behind it(see world_utils/background), height scales the peaks
    background = {
        skyTop = {0.33, 0.55, 0.9}, skyBottom = {0.72, 0.86, 1}, height = 1,
        layers = {
            {color = {0.56, 0.66, 0.84}, rim = {0.7, 0.78, 0.92}},
            {color = {0.38, 0.56, 0.55}, rim = {0.47, 0.66, 0.6}},
            {color = {0.26, 0.47, 0.3}, rim = {0.36, 0.6, 0.33}},
        },
    },
    -- What can appear here, read by the spawner(see world_utils/spawner): entity, weight, where("surface" or "cave"), group size,
    -- and optionally time("day" or "night", any time when left out)
    spawns = {
        {entity = "Zombie", weight = 10, where = "surface", group = {1, 2}},
    },
})
