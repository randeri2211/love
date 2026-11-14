local Biomes = require "world_utils.biomes"
local Generator = require "world_utils.generator"
local WorldClock = require "world_utils.worldClock"

-- What is behind the world: a sky with parallax layers above ground, dark rock walls below it
-- The sky and its layers are images of the biome the camera is in(its background, see biomes/plains):
-- a sky gradient stretched over the screen, then layers far to near that repeat sideways and move slower than the camera
-- the further away they are, their bottom row reaching down to the bottom of the screen. Paint them in their day colors,
-- the time of day tints them(SKY_TINT, HILL_TINT). Near a biome border the two biomes' backgrounds crossfade,
-- deep down everything fades to the dark of the caves
local Background = {}

local CAVE_COLOR = {0.05, 0.05, 0.07}
local FADE_FROM = 6         -- Tiles under the surface where the sky starts fading to cave dark
local FADE_TO = 26          -- Tiles under the surface where it is fully dark
local WALL_SHADE = 0.35     -- How dark the rock walls behind caves are
local STAR_PARALLAX = 0.02  -- Stars are the furthest thing, they barely move
local STAR_FIELD = 2048     -- Pixels before the star pattern repeats sideways
local STAR_TOP = 0.65       -- Part of the screen height stars appear in, from the top

local images = {}           -- Background images by path, loaded when first drawn
local quads = {}            -- A quad for each layer image, moved every frame instead of made
local canvases = {}         -- Two screen canvases for the crossfade at a biome border
local wallBatch = nil
local stars = nil           -- {x, y(0-1 of the field), size, phase, speed}, made once


local function background(biome)
    -- Worlds made before biomes and biomes without their own(underground ones) use the plains background
    return biome.background or BIOME_REGISTRY.Plains.background
end


local function image(folder, file)
    -- A background image that repeats sideways and stretches its bottom row down
    local path = ART_FOLDER .. "backgrounds/" .. folder .. "/" .. file .. ".png"
    if images[path] == nil then
        local loaded = artImage(path)
        loaded:setWrap("repeat", "clamp")
        if file == "sky" then
            loaded:setFilter("linear", "linear")    -- A smooth gradient, not bands
        end
        images[path] = loaded
    end
    return images[path]
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


local function drawStack(bg, camX, camY, w, h)
    -- One biome's background: its sky, the stars, then its layers far to near
    local sky = image(bg.folder, "sky")
    local tint = WorldClock.blend(SKY_TINT)
    love.graphics.setColor(tint[1], tint[2], tint[3], 1)
    love.graphics.draw(sky, 0, 0, 0, w / sky:getWidth(), h / sky:getHeight())

    local starAlpha = WorldClock.blend(STAR_ALPHA)
    if starAlpha > 0.01 then
        drawStars(camX, w, h, starAlpha)
    end

    -- The horizon sits at the plain ground level, each layer moves up and down slower than the camera too
    local hill = WorldClock.blend(HILL_TINT)
    love.graphics.setColor(hill[1], hill[2], hill[3], 1)
    local horizon = SURFACE_ROW * TILE_SIZE
    for i, layer in ipairs(bg.layers) do
        local layerImage = image(bg.folder, layer.file)
        local baseY = h / 2 + (horizon - camY) * layer.parallax - layer.rise
        local y = math.floor(baseY - layer.baseline * ART_UNIT * ART_SCREEN)
        if y < h then
            local iw, ih = layerImage:getDimensions()
            local quad = quads[layerImage]
            if quad == nil then
                quad = love.graphics.newQuad(0, 0, 1, 1, iw, ih)
                quads[layerImage] = quad
            end
            -- Whole art pixels of scroll, so the layer never sits between pixels
            local scroll = math.floor(camX * layer.parallax / ART_SCREEN) % iw
            quad:setViewport(scroll, 0, math.ceil(w / ART_SCREEN) + 1, math.ceil((h - y) / ART_SCREEN) + 1, iw, ih)
            love.graphics.draw(layerImage, quad, 0, y, 0, ART_SCREEN, ART_SCREEN)
        end
    end
end


local function canvas(i, w, h)
    if canvases[i] == nil or canvases[i]:getWidth() ~= w or canvases[i]:getHeight() ~= h then
        canvases[i] = love.graphics.newCanvas(w, h)
    end
    return canvases[i]
end


function Background.drawSky(camX, camY)
    -- Screen space, before the camera: the background of the biome the camera is in, faded to dark underground
    local w, h = love.graphics.getDimensions()
    local tx = math.floor(camX / TILE_SIZE)
    local biome, neighbor, share = Biomes.surface(tx, map.seed, map.settings)
    local surfaceY = Generator.surfaceRow(tx, map.seed, map.settings) * TILE_SIZE
    local depth = (camY - surfaceY) / TILE_SIZE
    local dark = math.max(0, math.min(1, (depth - FADE_FROM) / (FADE_TO - FADE_FROM)))

    love.graphics.push("all")
    love.graphics.origin()
    if dark < 1 then
        local own, other = background(biome), background(neighbor)
        if share >= 1 or own == other then
            drawStack(own, camX, camY, w, h)
        else
            -- Near a border: both backgrounds whole, then the camera's biome over its neighbor's by how far in it is
            local target = love.graphics.getCanvas()
            for i, bg in ipairs({other, own}) do
                love.graphics.setCanvas(canvas(i, w, h))
                love.graphics.clear(0, 0, 0, 1)
                drawStack(bg, camX, camY, w, h)
            end
            love.graphics.setCanvas(target)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(canvases[1])
            love.graphics.setColor(1, 1, 1, share)
            love.graphics.draw(canvases[2])
        end
    end
    -- Underground the sky fades to the dark of the caves
    if dark > 0 then
        love.graphics.setColor(CAVE_COLOR[1], CAVE_COLOR[2], CAVE_COLOR[3], dark)
        love.graphics.rectangle("fill", 0, 0, w, h)
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
                wallBatch:add(BLOCK_TILES[tile], tx * TILE_SIZE, ty * TILE_SIZE, 0, ART_SCREEN, ART_SCREEN)
            end
        end
    end
    love.graphics.setColor(WALL_SHADE, WALL_SHADE, WALL_SHADE * 1.1, 1)
    love.graphics.draw(wallBatch)
    love.graphics.setColor(1, 1, 1, 1)
end

return Background
