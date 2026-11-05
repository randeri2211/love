-- Dark hard stone far down, wide caverns and more ore
registerBiome("Deep", {
    kind = "underground",
    fromDepth = DEEP_DEPTH,
    blocks = {stone = "Deepstone"},
    caves = {startDepth = 0, tunnel = 0.055, network = 0.05, scale = 0.5, cavern = 0.8},
    ores = {
        {block = "DeepGoldOre", minDepth = 0, threshold = 0.75},
        {block = "ArcaniteOre", minDepth = 0, threshold = 0.8},
    },
    spawns = {
        {entity = "RottingZombie", weight = 6, where = "cave", group = {2, 3}},
        {entity = "ScorchedZombie", weight = 4, where = "cave", group = {1, 2}},
        {entity = "FrostbittenZombie", weight = 4, where = "cave", group = {1, 2}},
        {entity = "Zombie", weight = 4, where = "cave", group = {2, 3}},
        {entity = "Bat", weight = 6, where = "cave", group = {2, 4}},
        {entity = "SkeletonArcher", weight = 6, where = "cave", group = {1, 3}},
    },
})
