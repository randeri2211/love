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
    ores = {
        {block = "CopperOre", minDepth = ORE_START_DEPTH, threshold = ORE_THRESHOLD},
        {block = "IronOre", minDepth = 28, threshold = 0.79},
    },
    -- What can appear here, read by the spawner: entity, weight, where("surface" or "cave"), group size
    spawns = {
        {entity = "Zombie", weight = 10, where = "surface", group = {1, 2}},
    },
})
