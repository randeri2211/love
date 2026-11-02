local Biomes = require "world_utils.biomes"
local Generator = require "world_utils.generator"
local WorldClock = require "world_utils.worldClock"

-- What is behind the world: a sky with parallax silhouettes above ground, dark rock walls below it
-- Silhouette layers move slower than the camera the further away they are, colors come from the biome the camera is in
-- and blend across biome borders, deep down everything fades to the dark of the caves
local Background = {}

-- Silhouette layers, far to near: parallax is how much of the camera movement they follow,
-- height is how many pixels the peaks rise above the horizon(scaled by the biome), roughness how close the peaks are
local LAYERS = {
    {parallax = 0.1, height = 200, base = 110, roughness = 0.004, rim = 6, salt = 3.1},
    {parallax = 0.25, height = 120, base = 40, roughness = 0.008, rim = 4, salt = 7.7},
    {parallax = 0.45, height = 60, base = -10, roughness = 0.016, rim = 4, salt = 12.9},
}
local COLUMN = 4            -- Pixels per silhouette step, chunky like the pixel art tiles
local STEP = 2              -- Peak heights snap to this many pixels
local CAVE_COLOR = {0.05, 0.05, 0.07}
local FADE_FROM = 6         -- Tiles under the surface where the sky starts fading to cave dark
local FADE_TO = 26          -- Tiles under the surface where it is fully dark
local WALL_SHADE = 0.35     -- How dark the rock walls behind caves are
local WALL_START = 2        -- Tiles under the surface where the walls start, the top of a cave dug from the surface shows sky

local STAR_PARALLAX = 0.02  -- Stars are the furthest thing, they barely move
local STAR_FIELD = 2048     -- Pixels before the star pattern repeats sideways
local STAR_TOP = 0.65       -- Part of the screen height stars appear in, from the top

local layerMeshes = {}
local skyMesh = nil
local wallBatch = nil
local stars = nil           -- {x, y(0-1 of the field), size, phase, speed}, made once


local function mix(a, b, t)
    return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t}
end


local function palette(biome)
    -- Worlds made before biomes use the plains look
    return biome.background or BIOME_REGISTRY.Plains.background
end


local function timed(color, tint)
    -- A palette color for now: a biome can give one per moment of the day, a single color is its day look tinted by the time
    if type(color) == "table" and color.day ~= nil then
        return WorldClock.blend(color)
    end
    local t = WorldClock.blend(tint)
    return {color[1] * t[1], color[2] * t[2], color[3] * t[3]}
end


local function blended(tx)
    -- Background of the biome at a column for the time of day, mixed with its neighbor near a border like the terrain
    local biome, neighbor, share = Biomes.surface(tx, map.seed, map.settings)
    local a, b = palette(biome), palette(neighbor)
    local result = {
        skyTop = mix(timed(b.skyTop, SKY_TINT), timed(a.skyTop, SKY_TINT), share),
        skyBottom = mix(timed(b.skyBottom, SKY_TINT), timed(a.skyBottom, SKY_TINT), share),
        height = b.height + (a.height - b.height) * share,
        layers = {},
    }
    for i = 1, #LAYERS do
        local la, lb = a.layers[i], b.layers[i]
        result.layers[i] = {
            color = mix(timed(lb.color, HILL_TINT), timed(la.color, HILL_TINT), share),
            rim = mix(timed(lb.rim, HILL_TINT), timed(la.rim, HILL_TINT), share),
        }
    end
    return result
end


local function quad(vertices, x1, y1, x2, y2, color)
    -- Two triangles of a rectangle for a triangles mesh
    local r, g, b = color[1], color[2], color[3]
    table.insert(vertices, {x1, y1, 0, 0, r, g, b, 1})
    table.insert(vertices, {x2, y1, 0, 0, r, g, b, 1})
    table.insert(vertices, {x2, y2, 0, 0, r, g, b, 1})
    table.insert(vertices, {x1, y1, 0, 0, r, g, b, 1})
    table.insert(vertices, {x2, y2, 0, 0, r, g, b, 1})
    table.insert(vertices, {x1, y2, 0, 0, r, g, b, 1})
end


local function drawMesh(index, vertices)
    -- One mesh per layer, made bigger when the screen needs more columns
    if #vertices == 0 then
        return
    end
    local mesh = layerMeshes[index]
    if mesh == nil or mesh:getVertexCount() < #vertices then
        mesh = love.graphics.newMesh(#vertices, "triangles", "stream")
        layerMeshes[index] = mesh
    end
    mesh:setVertices(vertices)
    mesh:setDrawRange(1, #vertices)
    love.graphics.draw(mesh)
end


local function drawStars(camX, w, h, alpha)
    -- Twinkling pixels over the sky gradient, behind the hills, the same pattern every time
    if stars == nil then
        stars = {}
        local random = love.math.newRandomGenerator(7)
        for i = 1, STAR_COUNT do
            table.insert(stars, {
                x = random:random() * STAR_FIELD, y = random:random() ^ 1.5,    -- More stars higher up
                size = random:random() < 0.15 and 2 or 1,
                phase = random:random() * math.pi * 2, speed = 0.8 + random:random() * 2,
            })
        end
    end
    local time = love.timer.getTime()
    local offset = camX * STAR_PARALLAX
    for i, star in ipairs(stars) do
        local twinkle = 0.55 + 0.45 * math.sin(time * star.speed + star.phase)
        love.graphics.setColor(0.9, 0.92, 1, alpha * twinkle)
        local size = star.size * 2
        -- The field repeats sideways so any screen width is covered
        local x = (star.x - offset) % STAR_FIELD
        while x < w do
            love.graphics.rectangle("fill", math.floor(x), math.floor(star.y * h * STAR_TOP), size, size)
            x = x + STAR_FIELD
        end
    end
end


function Background.drawSky(camX, camY)
    -- Screen space, before the camera: sky gradient and the silhouette layers, faded to dark underground
    local w, h = love.graphics.getDimensions()
    local tx = math.floor(camX / TILE_SIZE)
    local look = blended(tx)
    local surfaceY = Generator.surfaceRow(tx, map.seed, map.settings) * TILE_SIZE
    local depth = (camY - surfaceY) / TILE_SIZE
    local dark = math.max(0, math.min(1, (depth - FADE_FROM) / (FADE_TO - FADE_FROM)))

    love.graphics.push("all")
    love.graphics.origin()

    -- Sky, a gradient from the top of the screen to the horizon
    local top, bottom = mix(look.skyTop, CAVE_COLOR, dark), mix(look.skyBottom, CAVE_COLOR, dark)
    if skyMesh == nil then
        skyMesh = love.graphics.newMesh(4, "fan", "stream")
    end
    skyMesh:setVertices({
        {0, 0, 0, 0, top[1], top[2], top[3], 1},
        {w, 0, 0, 0, top[1], top[2], top[3], 1},
        {w, h, 0, 0, bottom[1], bottom[2], bottom[3], 1},
        {0, h, 0, 0, bottom[1], bottom[2], bottom[3], 1},
    })
    love.graphics.draw(skyMesh)

    if dark < 1 then
        local starAlpha = WorldClock.blend(STAR_ALPHA) * (1 - dark)
        if starAlpha > 0.01 then
            drawStars(camX, w, h, starAlpha)
        end

        -- The horizon sits at the plain ground level, each layer moves up and down slower than the camera too
        local horizon = SURFACE_ROW * TILE_SIZE
        for i, layer in ipairs(LAYERS) do
            local colors = look.layers[i]
            local fill = mix(colors.color, CAVE_COLOR, dark)
            local rim = mix(colors.rim, CAVE_COLOR, dark)
            local baseY = h / 2 + (horizon - camY) * layer.parallax - layer.base
            local offset = camX * layer.parallax
            local vertices = {}
            for x = 0, w + COLUMN, COLUMN do
                -- The same spot of the layer always has the same peak, it scrolls by its parallax
                local lx = math.floor((x + offset) / COLUMN) * COLUMN
                local n = love.math.noise(lx * layer.roughness, layer.salt) * 0.75 + love.math.noise(lx * layer.roughness * 3, layer.salt + 5) * 0.25
                local peak = math.floor((baseY - n * layer.height * look.height) / STEP) * STEP
                local sx = x - (x + offset) % COLUMN
                if peak < h then
                    quad(vertices, sx, peak + layer.rim, sx + COLUMN, h, fill)
                    quad(vertices, sx, peak, sx + COLUMN, peak + layer.rim, rim)
                end
            end
            drawMesh(i, vertices)
        end
    end
    love.graphics.pop()
end


function Background.drawWalls(camX, camY)
    -- World space, inside the camera before the blocks: dark rock behind every tile under the ground,
    -- so caves show a wall instead of the sky(dirt near the surface, stone deeper, deepstone in the deep layer)
    local w, h = love.graphics.getDimensions()
    if wallBatch == nil then
        wallBatch = love.graphics.newSpriteBatch(TILESHEET, 4096, "stream")
    end
    wallBatch:clear()
    local x1, x2 = math.floor((camX - w / 2) / TILE_SIZE) - 1, math.floor((camX + w / 2) / TILE_SIZE) + 1
    local y1, y2 = math.floor((camY - h / 2) / TILE_SIZE) - 1, math.floor((camY + h / 2) / TILE_SIZE) + 1
    for tx = x1, x2 do
        local surface = Generator.surfaceRow(tx, map.seed, map.settings)
        local biome = Biomes.surface(tx, map.seed, map.settings)
        local fillerDepth = biome.blocks.fillerDepth or DIRT_DEPTH
        for ty = math.max(y1, surface + WALL_START), y2 do
            local depth = ty - surface
            local tile
            if depth <= fillerDepth then
                tile = "dirt"
            else
                -- Same variant pick as Block:variant, so walls dont repeat in a grid
                local v = math.sin(tx * 127.1 + ty * 311.7) * 43758.5453
                local variant = math.floor((v - math.floor(v)) * 3) + 1
                tile = (depth >= DEEP_DEPTH and "deepstone" or "stone") .. variant
            end
            if wallBatch:getCount() < wallBatch:getBufferSize() then
                wallBatch:add(BLOCK_TILES[tile], tx * TILE_SIZE, ty * TILE_SIZE, 0, TILE_SIZE / 16, TILE_SIZE / 16)
            end
        end
    end
    love.graphics.setColor(WALL_SHADE, WALL_SHADE, WALL_SHADE * 1.1, 1)
    love.graphics.draw(wallBatch)
    love.graphics.setColor(1, 1, 1, 1)
end

return Background
