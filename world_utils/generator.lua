local Biomes = require "world_utils.biomes"

-- Picks the block for every tile from the world seed and settings, the same seed always gives the same world
-- Tile coordinates: tx is the column, ty the row(rows grow downward like love coordinates)
-- What the ground looks like comes from the biome(see world_utils/biomes and the biomes folder)
local Generator = {}


local function offset(seed, salt)
    -- Moves each noise layer to its own spot in the noise field so the layers dont line up
    return (seed % 10007) * 0.913 + salt
end


local function biomeRow(biome, tx, seed)
    -- Surface row a biome would have in this column, two layers of noise make rolling hills(smaller rows are higher)
    -- Every biome reads the same noise, so blending two of them at a border stays smooth
    local terrain = biome.terrain
    local hills = love.math.noise(tx * 0.012 * terrain.roughness, offset(seed, 0)) * 0.7
        + love.math.noise(tx * 0.05 * terrain.roughness, offset(seed, 11.3)) * 0.3
    return SURFACE_ROW + terrain.baseRow - hills * terrain.hillHeight
end


function Generator.surfaceRow(tx, seed, settings)
    -- Row of the top block in a column, blended with the next biome near a border
    local biome, neighbor, share = Biomes.surface(tx, seed, settings)
    local row = biomeRow(biome, tx, seed) * share + biomeRow(neighbor, tx, seed) * (1 - share)
    return math.floor(row + 0.5)
end


function Generator.isCave(tx, ty, depth, seed, caves)
    -- Open space underground: long tunnels where a noise layer crosses its middle, and rounder caverns
    -- caves comes from the biome: {startDepth, tunnel width, cavern threshold}
    if depth < caves.startDepth then
        return false
    end
    local tunnel = math.abs(love.math.noise(tx * 0.03, ty * 0.05, offset(seed, 31.7)) * 2 - 1)
    if tunnel < caves.tunnel then
        return true
    end
    return love.math.noise(tx * 0.025, ty * 0.035, offset(seed, 77.1)) > caves.cavern
end


local function ore(tx, ty, depth, seed, ores)
    -- First ore of the biome whose noise is high enough here, nil for none
    for i, o in ipairs(ores) do
        if depth >= o.minDepth and love.math.noise(tx * 0.21, ty * 0.21, offset(seed, 57.9 + (i - 1) * 13.1)) > o.threshold then
            return o.block
        end
    end
    return nil
end


function Generator.tile(tx, ty, seed, bottomRow, settings)
    -- Block name for a tile, nil for air
    if ty > bottomRow - BEDROCK_ROWS then
        return "Bedrock"
    end

    local surface = Generator.surfaceRow(tx, seed, settings)
    if ty < surface then
        return nil
    end
    local depth = ty - surface

    -- Deep down the underground layers decide, the border wobbles so it isnt a straight line
    local wobble = math.floor(love.math.noise(tx * 0.08, offset(seed, 91.3)) * UNDERGROUND_WOBBLE)
    local biome = Biomes.underground(depth - wobble, settings)
    local surfaceBiome = biome == nil
    if surfaceBiome then
        -- Blocks switch biome a few tiles left or right of the border on every row, so biomes dont meet in a straight wall
        local shift = math.floor((love.math.noise(ty * 0.15, offset(seed, 43.9)) * 2 - 1) * BIOME_BLOCK_WOBBLE + 0.5)
        biome = Biomes.surface(tx + shift, seed, settings)
    end

    if Generator.isCave(tx, ty, depth, seed, biome.caves) then
        return nil
    end
    if surfaceBiome then
        if depth == 0 then
            return biome.blocks.top
        elseif depth <= biome.blocks.fillerDepth then
            return biome.blocks.filler
        end
    end
    return ore(tx, ty, depth, seed, biome.ores) or biome.blocks.stone
end

return Generator
