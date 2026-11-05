-- A ruined camp on the surface: broken stone walls, a plank lean-to over a campfire, a wooden chest, three guards
-- The everyday structure, about one every 250 tiles(see world_utils/structures)
registerStructure("RuinedCamp", {
    title = "ruined camp",
    where = "surface",
    cell = 250,
    chance = 0.95,
    priority = 1,
    ground = 6,         -- The stone floor sits on the surface
    maxSlope = 4,       -- The foundation fills dips under the floor, the air rows clear bumps over it
    -- # cracked walls(some missing), B the floor, P planks, F campfire, C chest, z a guard, d foundation
    -- . air(clears trees and hills inside), a space keeps what the world has
    blueprint = {
        ".#.............#.",
        ".#....PPPPPP...#.",
        "##...P......P..##",
        "##...P......P..##",
        "##.zCP.z.F..Pz.##",
        "BBBBBBBBBBBBBBBBB",
        "ddddddddddddddddd",
        "ddddddddddddddddd",
        "ddddddddddddddddd",
        "ddddddddddddddddd",
    },
    legend = {
        ["."] = false,
        ["#"] = "CrackedStoneBricks",
        ["B"] = "StoneBricks",
        ["P"] = "Planks",
        ["F"] = "Campfire",
        ["C"] = {chest = "WoodenChest"},
        ["z"] = {guard = true},
        ["d"] = "Dirt",
    },
    decays = {["#"] = 0.35, ["P"] = 0.15},
    -- Zombies of the biome or skeleton archers
    guards = {
        default = {{"Zombie", 3}, {"SkeletonArcher", 2}},
        Desert = {{"ScorchedZombie", 3}, {"SkeletonArcher", 2}},
        Snow = {{"FrostbittenZombie", 3}, {"SkeletonArcher", 2}},
    },
    loot = {
        {"Torch", 4, 8},
        {"OakWood", 5, 12, 0.6},
        {"CopperBar", 2, 5, 0.6},
        {"IronBar", 1, 3, 0.3},
        {"CopperCore", 1, 1, 0.15},
        {"CopperCap", 1, 1, 0.2},
    },
})
