-- Which biome a place in the world belongs to, from the seed and the world generation settings
-- Surface biomes change from column to column, below UNDERGROUND_DEPTH the underground layers take over by depth
-- Every answer comes from the seed, so nothing about biomes is saved except the settings
local Biomes = {}


-- Worlds saved before biomes(no biomeWidth) keep the settings plains had back then, so changing plains never changes them
local LEGACY = {
    name = "Plains",
    kind = "surface",
    weight = 0,
    terrain = {baseRow = 0, hillHeight = HILL_HEIGHT, roughness = 1},
    blocks = {top = "Grass", filler = "Dirt", fillerDepth = DIRT_DEPTH, stone = "Stone"},
    caves = {startDepth = CAVE_START_DEPTH, tunnel = 0.06, cavern = 0.82},
    ores = {{block = "Ore", minDepth = ORE_START_DEPTH, threshold = ORE_THRESHOLD}},
    spawns = {},
}


local function hash(seed, i, salt)
    -- Repeatable random number from 0 to 1 for a whole number i, different for every seed and salt
    local v = math.sin(i * 127.1 + (seed % 10007) * 311.7 + salt * 74.7) * 43758.5453
    return v - math.floor(v)
end


local sorted = {}   -- Lists by kind, built once(biomes are all registered before the first world is made)

local function sortedBiomes(kind)
    -- Biomes of a kind in name order, so the same seed picks the same biomes whatever order files load in
    if sorted[kind] == nil then
        local list = {}
        for name, biome in pairs(BIOME_REGISTRY) do
            if biome.kind == kind then
                table.insert(list, biome)
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        sorted[kind] = list
    end
    return sorted[kind]
end


local function pick(seed, cell)
    -- Surface biome of a cell, biomes with more weight come up more often
    local list = sortedBiomes("surface")
    local total = 0
    for i, biome in ipairs(list) do
        total = total + biome.weight
    end
    local roll = hash(seed, cell, 1) * total
    for i, biome in ipairs(list) do
        roll = roll - biome.weight
        if roll < 0 then
            return biome
        end
    end
    return list[#list]
end


local function border(seed, cell, width)
    -- Column where a cell starts, nudged so biomes arent all the same size
    return (cell + (hash(seed, cell, 2) - 0.5) * BIOME_BORDER_JITTER) * width
end


function Biomes.surface(tx, seed, settings)
    -- Surface biome of a column, the neighbor it blends into near a border, and how much of its own terrain is used(0.5 to 1)
    -- Worlds made before biomes(no biomeWidth) are all plains, so their unvisited chunks match the ones they saved
    local width = settings and settings.biomeWidth
    if width == nil then
        return LEGACY, LEGACY, 1
    end

    local cell = math.floor(tx / width)
    local left, right = border(seed, cell, width), border(seed, cell + 1, width)
    if tx < left then
        cell, right, left = cell - 1, left, border(seed, cell - 1, width)
    elseif tx >= right then
        cell, left, right = cell + 1, right, border(seed, cell + 2, width)
    end
    local biome = pick(seed, cell)

    -- Near a border the terrain is half one biome and half the other, fully its own BIOME_BLEND tiles in
    local toLeft, toRight = tx - left, right - tx
    if toLeft < BIOME_BLEND and toLeft <= toRight then
        return biome, pick(seed, cell - 1), 0.5 + 0.5 * toLeft / BIOME_BLEND
    elseif toRight < BIOME_BLEND then
        return biome, pick(seed, cell + 1), 0.5 + 0.5 * toRight / BIOME_BLEND
    end
    return biome, biome, 1
end


function Biomes.underground(depth, settings)
    -- Underground layer for a depth under the surface, nil above UNDERGROUND_DEPTH(the surface biome goes down to there)
    if settings == nil or settings.biomeWidth == nil or depth < UNDERGROUND_DEPTH then
        return nil
    end
    local found = nil
    for i, layer in ipairs(sortedBiomes("underground")) do
        -- The deepest layer that has started
        if depth >= layer.fromDepth and (found == nil or layer.fromDepth > found.fromDepth) then
            found = layer
        end
    end
    return found
end


function Biomes.at(tx, ty, seed, settings, surfaceRow)
    -- Biome a tile is in: the underground layer for its depth, or the surface biome of its column
    local layer = Biomes.underground(ty - surfaceRow, settings)
    if layer ~= nil then
        return layer
    end
    return (Biomes.surface(tx, seed, settings))
end

return Biomes
