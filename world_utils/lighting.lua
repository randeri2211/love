local Generator = require "world_utils.generator"
local WorldClock = require "world_utils.worldClock"

-- Light over the world, tile by tile: every tile around the screen gets a colored light level, the world canvas is
-- multiplied by it(see love.draw), so caves are dark unless something lights them
-- Sources: the sky(open air above the cave walls, as bright as the time of day), blocks with a light(torches, glowing ores),
-- the player glow and spells(Form:light)
-- Light spreads from tile to tile losing a little in air and a lot in solid blocks, so the first block of a wall is lit
-- and the inside of the ground stays dark
-- The map part(which tiles are solid, what blocks shine) is only read again when the map changes(map.lightVersion)
-- or the grid moves, the rest is worked out every frame so moving lights follow smoothly
local Lighting = {}

local grid = nil            -- {map, version, x0, y0, w, h, decay, sky, lit, er, eg, eb}, tile x0, y0 is the top left cell
local R, G, B = {}, {}, {}  -- Light of every cell this frame
local imageData, image = nil, nil


local function buildGrid(x0, y0, w, h)
    -- What the map says about every cell: how much light it lets through, whether it sees the sky, the light it gives
    local g = {map = map, version = map.lightVersion, x0 = x0, y0 = y0, w = w, h = h,
        decay = {}, sky = {}, er = {}, eg = {}, eb = {}}
    local cx, cy = map.center.x, map.center.y
    for gx = 1, w do
        local tx = x0 + gx - 1
        -- Open air sees the sky down to the first solid block, until the cave walls start(see Background.drawWalls)
        local wallRow = Generator.surfaceRow(tx, map.seed, map.settings) + WALL_START
        local open = y0 < wallRow
        for gy = 1, h do
            local ty = y0 + gy - 1
            local i = (gy - 1) * w + gx
            local block = map:get(tx + cx + 1, cy + 1 - ty)    -- The tile at love tx, ty(see Map:mapToTile)
            local solid = block ~= nil and block.solid
            if solid then
                open = false
            end
            g.sky[i] = open and ty < wallRow
            g.decay[i] = solid and LIGHT_SOLID_DECAY or LIGHT_AIR_DECAY
            local light = block ~= nil and block.light
            if light then
                g.er[i], g.eg[i], g.eb[i] = light[1], light[2], light[3]
            else
                g.er[i], g.eg[i], g.eb[i] = 0, 0, 0
            end
        end
    end
    -- Cells next to the open sky get the sky light too, so the ground under it isnt dimmed by the step into it
    -- (only the sky light, a torch still fades into the ground as usual)
    g.lit = {}
    for gy = 1, h do
        for gx = 1, w do
            local i = (gy - 1) * w + gx
            g.lit[i] = g.sky[i] or (gx > 1 and g.sky[i - 1]) or (gx < w and g.sky[i + 1])
                or (gy > 1 and g.sky[i - w]) or (gy < h and g.sky[i + w]) or false
        end
    end
    return g
end


local function addLight(x, y, color, strength)
    -- A light at a love point, shared by the four cells around it by how far it is from their centers(fading like it
    -- spreads), so a light that moves, or a player jittering on the edge of a block, brightens and dims cells smoothly
    -- instead of jumping from one cell to the next(the brightest light in a cell wins)
    local g = grid
    local fx, fy = x / TILE_SIZE - 0.5 - g.x0, y / TILE_SIZE - 0.5 - g.y0     -- In cells, 0 is the first cell center
    local cx, cy = math.floor(fx), math.floor(fy)
    for dx = 0, 1 do
        for dy = 0, 1 do
            local gx, gy = cx + dx + 1, cy + dy + 1
            if gx >= 1 and gy >= 1 and gx <= g.w and gy <= g.h then
                local i = (gy - 1) * g.w + gx
                local s = strength * LIGHT_AIR_DECAY ^ (math.abs(fx - cx - dx) + math.abs(fy - cy - dy))
                local r, gr, b = color[1] * s, color[2] * s, color[3] * s
                if r > R[i] then R[i] = r end
                if gr > G[i] then G[i] = gr end
                if b > B[i] then B[i] = b end
            end
        end
    end
end


local function spread(g)
    -- Light moves to the next cell losing what the cell it leaves takes, sweeping every row both ways and every column
    -- both ways, a few times so it can turn corners into caves
    local w, h, decay = g.w, g.h, g.decay
    for pass = 1, LIGHT_PASSES do
        for y = 1, h do
            local row = (y - 1) * w
            for x = 2, w do
                local i, j = row + x, row + x - 1
                local d = decay[j]
                local v = R[j] * d if v > R[i] then R[i] = v end
                v = G[j] * d if v > G[i] then G[i] = v end
                v = B[j] * d if v > B[i] then B[i] = v end
            end
            for x = w - 1, 1, -1 do
                local i, j = row + x, row + x + 1
                local d = decay[j]
                local v = R[j] * d if v > R[i] then R[i] = v end
                v = G[j] * d if v > G[i] then G[i] = v end
                v = B[j] * d if v > B[i] then B[i] = v end
            end
        end
        for x = 1, w do
            for y = 2, h do
                local i = (y - 1) * w + x
                local j = i - w
                local d = decay[j]
                local v = R[j] * d if v > R[i] then R[i] = v end
                v = G[j] * d if v > G[i] then G[i] = v end
                v = B[j] * d if v > B[i] then B[i] = v end
            end
            for y = h - 1, 1, -1 do
                local i = (y - 1) * w + x
                local j = i + w
                local d = decay[j]
                local v = R[j] * d if v > R[i] then R[i] = v end
                v = G[j] * d if v > G[i] then G[i] = v end
                v = B[j] * d if v > B[i] then B[i] = v end
            end
        end
    end
end


function Lighting.update()
    -- Works out the light of every cell around the camera for this frame
    local camX, camY = game_cam:position()
    local sw, sh = love.graphics.getDimensions()
    -- The screen plus a margin, so lights just off screen still reach in
    -- The grid snaps to LIGHT_SNAP tiles so walking doesnt read the map again every tile
    local x1 = math.floor((camX - sw / 2) / TILE_SIZE) - LIGHT_MARGIN
    local y1 = math.floor((camY - sh / 2) / TILE_SIZE) - LIGHT_MARGIN
    local x0 = math.floor(x1 / LIGHT_SNAP) * LIGHT_SNAP
    local y0 = math.floor(y1 / LIGHT_SNAP) * LIGHT_SNAP
    local w = math.ceil(sw / TILE_SIZE) + 2 * LIGHT_MARGIN + LIGHT_SNAP + 1
    local h = math.ceil(sh / TILE_SIZE) + 2 * LIGHT_MARGIN + LIGHT_SNAP + 1
    if grid == nil or grid.map ~= map or grid.version ~= map.lightVersion or grid.x0 ~= x0 or grid.y0 ~= y0
        or grid.w ~= w or grid.h ~= h then
        grid = buildGrid(x0, y0, w, h)
    end
    local g = grid

    -- The sky and the blocks first
    local ambient = WorldClock.blend(AMBIENT_LIGHT)
    local lit, er, eg, eb = g.lit, g.er, g.eg, g.eb
    for i = 1, w * h do
        if lit[i] then
            R[i], G[i], B[i] = math.max(ambient[1], er[i]), math.max(ambient[2], eg[i]), math.max(ambient[3], eb[i])
        else
            R[i], G[i], B[i] = er[i], eg[i], eb[i]
        end
    end

    -- Then what moves: the player glow and the spells
    if player ~= nil and not player:isDead() then
        local px, py = player.body:getWorldCenter()
        addLight(px, py, PLAYER_LIGHT, 1)
    end
    for i, spell in pairs(spells.spells) do
        if spell.instance.light ~= nil then
            spell.instance:light(addLight)
        end
    end

    spread(g)

    -- Into the light image, one pixel a cell
    if imageData == nil or imageData:getWidth() ~= w or imageData:getHeight() ~= h then
        imageData = love.image.newImageData(w, h)
        image = nil
    end
    for gy = 1, h do
        local row = (gy - 1) * w
        for gx = 1, w do
            local i = row + gx
            imageData:setPixel(gx - 1, gy - 1, math.min(1, R[i]), math.min(1, G[i]), math.min(1, B[i]), 1)
        end
    end
    if image == nil then
        image = love.graphics.newImage(imageData)
        image:setFilter("linear", "linear")     -- Blends between cells, so light fades smoothly instead of in squares
    else
        image:replacePixels(imageData)
    end
end


function Lighting.draw()
    -- World space, over the world on its canvas: multiplies everything drawn there by the light
    -- Every pixel of the image covers one tile, its center on the tile center
    if image == nil then
        return
    end
    love.graphics.push("all")
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, grid.x0 * TILE_SIZE, grid.y0 * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
    love.graphics.pop()
end


function Lighting.at(x, y)
    -- Light at a love point this frame(r, g, b), or full light where the grid doesnt reach
    local g = grid
    if g == nil then
        return 1, 1, 1
    end
    local gx = math.floor(x / TILE_SIZE) - g.x0 + 1
    local gy = math.floor(y / TILE_SIZE) - g.y0 + 1
    if gx < 1 or gy < 1 or gx > g.w or gy > g.h then
        return 1, 1, 1
    end
    local i = (gy - 1) * g.w + gx
    return R[i], G[i], B[i]
end

return Lighting
