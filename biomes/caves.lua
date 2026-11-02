-- The stone under every surface biome, from UNDERGROUND_DEPTH down to the deep layer
registerBiome("Caves", {
    kind = "underground",
    fromDepth = UNDERGROUND_DEPTH,      -- Tiles under the surface where this layer starts
    blocks = {stone = "Stone"},
    caves = {startDepth = 0, tunnel = 0.05, network = 0.045, scale = 0.5, cavern = 0.85},
    ores = {
        {block = "CopperOre", minDepth = 0, threshold = 0.74},
        {block = "IronOre", minDepth = 0, threshold = 0.77},
        {block = "GoldOre", minDepth = 0, threshold = 0.83},
    },
    spawns = {
        {entity = "Zombie", weight = 10, where = "cave", group = {1, 2}},
    },
})
