-- Picks the block for every tile from the world seed, the same seed always gives the same world
-- Tile coordinates: tx is the column, ty the row(rows grow downward like love coordinates)
local Generator = {}


local function offset(seed, salt)
    -- Moves each noise layer to its own spot in the noise field so the layers dont line up
    return (seed % 10007) * 0.913 + salt
end


function Generator.surfaceRow(tx, seed)
    -- Row of the top block in a column, two layers of noise make rolling hills(smaller rows are higher)
    local hills = love.math.noise(tx * 0.012, offset(seed, 0)) * 0.7
        + love.math.noise(tx * 0.05, offset(seed, 11.3)) * 0.3
    return math.floor(SURFACE_ROW - hills * HILL_HEIGHT + 0.5)
end


function Generator.isCave(tx, ty, depth, seed)
    -- Open space underground: long tunnels where a noise layer crosses its middle, and rounder caverns
    if depth < CAVE_START_DEPTH then
        return false
    end
    local tunnel = math.abs(love.math.noise(tx * 0.03, ty * 0.05, offset(seed, 31.7)) * 2 - 1)
    if tunnel < 0.06 then
        return true
    end
    return love.math.noise(tx * 0.025, ty * 0.035, offset(seed, 77.1)) > 0.82
end


function Generator.tile(tx, ty, seed, bottomRow)
    -- Block name for a tile, nil for air
    if ty > bottomRow - BEDROCK_ROWS then
        return "Bedrock"
    end

    local surface = Generator.surfaceRow(tx, seed)
    if ty < surface then
        return nil
    end
    local depth = ty - surface
    if Generator.isCave(tx, ty, depth, seed) then
        return nil
    end

    if depth == 0 then
        return "Grass"
    elseif depth <= DIRT_DEPTH then
        return "Dirt"
    elseif depth >= ORE_START_DEPTH and love.math.noise(tx * 0.21, ty * 0.21, offset(seed, 57.9)) > ORE_THRESHOLD then
        return "Ore"
    end
    return "Stone"
end

return Generator
