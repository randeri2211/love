-- Dark hard stone far down, wide caverns and more ore
registerBiome("Deep", {
    kind = "underground",
    fromDepth = DEEP_DEPTH,
    blocks = {stone = "Deepstone"},
    caves = {startDepth = 0, tunnel = 0.08, cavern = 0.74},
    ores = {
        {block = "DeepGoldOre", minDepth = 0, threshold = 0.75},
        {block = "ArcaniteOre", minDepth = 0, threshold = 0.8},
    },
    spawns = {
        {entity = "Zombie", weight = 12, where = "cave", group = {2, 3}},
    },
})
