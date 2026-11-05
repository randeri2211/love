-- A slime pit underground: a cave pocket with six slimes in it and an ore vein in its walls and floor
-- Copper higher up, iron deeper down, the ore is the reward(see world_utils/structures)
registerStructure("SlimePit", {
    title = "slime pit",
    where = "cave",
    cell = 250,
    chance = 0.75,
    priority = 1,
    depth = {25, 100},
    -- . air, S stone, o ore, z a slime, a space keeps what the world has
    blueprint = {
        "      ..........      ",
        "   ................   ",
        "  ..................  ",
        " .................... ",
        "......................",
        "o....................o",
        "oo.z..z..z..z..z..z.oo",
        "SoSSSSSSSSoSSSSSSSSoSS",
        " SSoSSSSSSSSSSSSSoSSS ",
    },
    legend = {
        ["."] = false,
        ["S"] = "Stone",
        ["o"] = {ore = true},
        ["z"] = {guard = true},
    },
    ore = function(depth)
        return depth < 70 and "CopperOre" or "IronOre"
    end,
    guards = {{"SmallSlime", 3}, {"Slime", 4}, {"BigSlime", 2}},
})
