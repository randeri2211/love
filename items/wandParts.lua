-- Parts wands and staves are built from at the arcane table(see items/tools and docs/game-design)
-- part.kind is the slot it goes in, bonus is what it does to every spell cast with the tool:
-- damage, cooldown and manaCost multiply, knockback and complexity add(an off hand wand gives OFF_HAND_SHARE of them)
-- Cores set the dig cap too, the most dig strength a spell cast with the tool has

-- Rods from the woodworking station, plain wood does nothing special, the wood names the tool("Oak Wand")
local WOODS = {
    {name = "Oak", tint = {0.78, 0.58, 0.38, 1}},
    {name = "Pine", tint = {0.62, 0.42, 0.3, 1}},
}
for i, wood in ipairs(WOODS) do
    registerItem(wood.name .. "Rod", {displayName = wood.name .. " Rod", icon = "rod", tint = wood.tint,
        part = {kind = "rod", wood = wood.name, tint = wood.tint, bonus = {}}})
    registerItem("Large" .. wood.name .. "Rod", {displayName = "Large " .. wood.name .. " Rod", icon = "largeRod", tint = wood.tint,
        part = {kind = "largeRod", wood = wood.name, tint = wood.tint, bonus = {}}})
end

-- Cores: how powerful the tool is, every ore makes a core that opens the next ore(see the dig cap table in the design doc)
local CORES = {
    {name = "Wooden", tint = {0.78, 0.58, 0.38, 1}, digCap = 15, complexity = 0},
    {name = "Copper", tint = {0.95, 0.6, 0.35, 1}, digCap = 21, complexity = 5},
    {name = "Iron", tint = {0.8, 0.8, 0.86, 1}, digCap = 26, complexity = 10},
    {name = "Gold", tint = {1, 0.84, 0.3, 1}, digCap = 31, complexity = 15},
}
for i, core in ipairs(CORES) do
    registerItem(core.name .. "Core", {displayName = core.name .. " Core", icon = "core", tint = core.tint,
        part = {kind = "core", digCap = core.digCap, bonus = {complexity = core.complexity}}})
end

-- End caps for wands and tips for staves, one per metal, a tip does twice what the cap of its metal does
local ENDS = {
    {name = "Wooden", tint = {0.78, 0.58, 0.38, 1}, cap = {}, tip = {}},
    {name = "Copper", tint = {0.95, 0.6, 0.35, 1}, cap = {cooldown = 0.9}, tip = {cooldown = 0.8}},
    {name = "Iron", tint = {0.8, 0.8, 0.86, 1}, cap = {knockback = 0.5}, tip = {knockback = 1}},
    {name = "Gold", tint = {1, 0.84, 0.3, 1}, cap = {manaCost = 0.85}, tip = {manaCost = 0.7}},
}
for i, piece in ipairs(ENDS) do
    registerItem(piece.name .. "Cap", {displayName = piece.name .. " Cap", icon = "cap", tint = piece.tint,
        part = {kind = "cap", bonus = piece.cap}})
    registerItem(piece.name .. "Tip", {displayName = piece.name .. " Tip", icon = "tip", tint = piece.tint,
        part = {kind = "tip", bonus = piece.tip}})
end
