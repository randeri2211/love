-- Caves as a network(see docs/game-design: Caves): big open hubs joined by winding tunnels, tendrils branching off the hubs
-- and now and then an entrance climbing to the surface, plus small air pockets in the rock
-- The world is cut into regions of REGION tiles. A region's hub comes only from the seed and the region, so neighbors
-- know each other's hubs and agree on the tunnels between them(a tunnel belongs to the region left of or above it)
-- A region is carved once into a grid of open cells from its own features and its neighbors'(they reach across), then
-- kept, so asking about a tile is a table lookup. Tile rows grow downward like love coordinates(ty)
-- Settings come from the biome at a spot(biome.caves, see biomes): startDepth, hubChance, hubSize {min, max},
-- tunnelWidth {min, max}, tendrils, entranceChance, pockets(noise threshold, nil for none)
local CaveNetwork = {}

CaveNetwork.REGION = 96         -- Tiles a region is across
local CONNECT_CHANCE = 0.8      -- How often a hub joins the hub of the region right of it or under it
local DIAGONAL_CHANCE = 0.25    -- And the one down and to the right
local TUNNEL_WANDER = 16        -- Most tiles a tunnel bends away from the straight line between its hubs
local ENTRANCE_REACH = 80       -- Hubs this close to the surface can have an entrance
local NORMAL, ENTRANCE = 1, 2   -- What a carved cell is: a cave(only below the cave depth) or an entrance(up to the surface)

local function band(depth)
    -- Density and size of caves at a depth under the surface, blended between the CAVE_BANDS around it
    local bands = CAVE_BANDS
    if depth <= bands[1].depth then
        return bands[1].density, bands[1].size
    end
    for i = 2, #bands do
        local a, b = bands[i - 1], bands[i]
        if depth < b.depth then
            local t = (depth - a.depth) / (b.depth - a.depth)
            return a.density + (b.density - a.density) * t, a.size + (b.size - a.size) * t
        end
    end
    return bands[#bands].density, bands[#bands].size
end


local function zone(seed, x, y)
    -- The cave zone at a spot: how dense caves are(near solid rock to dense systems) and how big their hubs are,
    -- two slow noises so the two dont follow each other
    local s = (seed % 10007) * 0.71
    local d = love.math.noise(x / CAVE_ZONE_SIZE, y / CAVE_ZONE_SIZE, s + 3.3)
    local z = love.math.noise(x / CAVE_ZONE_SIZE, y / CAVE_ZONE_SIZE, s + 41.7)
    -- Smoothstep from mostly rock(0.1) to dense(1.6), the middle of the noise is about normal
    local t = math.max(0, math.min(1, (d - 0.25) / 0.5))
    local density = 0.1 + 1.5 * t * t * (3 - 2 * t)
    return density, 0.6 + 0.9 * z
end


local carved = {}       -- Region key -> {cells by local index}
local carvedFor = nil   -- The seed the cache is for
local hubs = {}         -- Region key -> its hub or false


local function hash(seed, a, b, salt)
    -- A repeatable number from 0 to 1 for a seed and two whole numbers
    local v = math.sin((seed % 10007) * 12.9898 + a * 78.233 + b * 37.719 + (salt or 0) * 4.581) * 43758.5453
    return v - math.floor(v)
end


local function random(seed, a, b, salt)
    -- A random generator for one thing of the world, the same every time
    return love.math.newRandomGenerator(math.floor(hash(seed, a, b, salt) * 2147483646) + 1)
end


local function hubOf(seed, rx, ry, world)
    -- The hub of a region, false when it has none: {x, y, radius, shape(noise salt), caves(settings there)}
    local key = rx .. "," .. ry
    if hubs[key] == nil then
        local r = random(seed, rx, ry, 1)
        local n = CaveNetwork.REGION
        local x = rx * n + n * (0.15 + 0.7 * r:random())
        local y = ry * n + n * (0.15 + 0.7 * r:random())
        local caves = world.caves(math.floor(x), math.floor(y))
        local hub = false
        -- The biome's chance, changed by the depth band and the cave zone, the size by them too
        local depth = y - world.surface(math.floor(x))
        local bandDensity, bandSize = band(depth)
        local zoneDensity, zoneSize = zone(seed, x, y)
        if caves ~= nil and caves.hubChance ~= nil and r:random() < caves.hubChance * bandDensity * zoneDensity then
            local size = caves.hubSize
            local radius = (size[1] + (size[2] - size[1]) * r:random()) * bandSize * zoneSize
            -- Deep enough for the whole hub under the surface
            if y - radius >= world.surface(math.floor(x)) + caves.startDepth then
                hub = {x = x, y = y, radius = radius, shape = r:random() * 100, caves = caves, rx = rx, ry = ry}
            end
        end
        hubs[key] = hub
    end
    return hubs[key]
end


-- Stamping open cells into a region grid
local function stamp(grid, x0, y0, cx, cy, radius, kind)
    -- A disk of open cells, only the ones inside the region
    local n = CaveNetwork.REGION
    for x = math.max(x0, math.floor(cx - radius)), math.min(x0 + n - 1, math.ceil(cx + radius)) do
        for y = math.max(y0, math.floor(cy - radius)), math.min(y0 + n - 1, math.ceil(cy + radius)) do
            local dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy <= radius * radius then
                local index = (x - x0) * n + (y - y0)
                if grid[index] ~= ENTRANCE then
                    grid[index] = kind
                end
            end
        end
    end
end


local function stampHub(grid, x0, y0, hub)
    -- A blob wider than tall, its edge pushed in and out by noise around it
    local n = CaveNetwork.REGION
    local reach = hub.radius * 1.6
    if hub.x + reach < x0 or hub.x - reach > x0 + n or hub.y + reach < y0 or hub.y - reach > y0 + n then
        return
    end
    for x = math.max(x0, math.floor(hub.x - reach)), math.min(x0 + n - 1, math.ceil(hub.x + reach)) do
        for y = math.max(y0, math.floor(hub.y - reach)), math.min(y0 + n - 1, math.ceil(hub.y + reach)) do
            local dx, dy = (x + 0.5 - hub.x) / 1.4, y + 0.5 - hub.y
            local a = math.atan2(dy, dx)
            local edge = hub.radius * (0.7 + 0.6 * love.math.noise(math.cos(a) * 1.3 + hub.shape, math.sin(a) * 1.3, hub.shape))
            if dx * dx + dy * dy <= edge * edge then
                local index = (x - x0) * n + (y - y0)
                if grid[index] ~= ENTRANCE then
                    grid[index] = NORMAL
                end
            end
        end
    end
end


local function stampTunnel(grid, x0, y0, a, b, salt)
    -- A tunnel from hub a to hub b: it wanders off the straight line and back, thick near its ends, narrow between
    local dx, dy = b.x - a.x, b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    local px, py = -dy / length, dx / length       -- Sideways from the line
    -- A few wide bends along it, never more than TUNNEL_WANDER tiles off the line
    local wander = math.min(length * 0.2, TUNNEL_WANDER)
    local bends = math.max(1.2, length / 50)
    local w1, w2 = a.caves.tunnelWidth, b.caves.tunnelWidth
    for s = 0, math.ceil(length) do
        local t = s / math.ceil(length)
        local side = (love.math.noise(t * bends, salt) * 2 - 1) * wander * math.sin(t * math.pi)
        local cx, cy = a.x + dx * t + px * side, a.y + dy * t + py * side
        -- Its width changes along it: a quick wobble between the two biomes' widths, and a slow swell that now and then
        -- opens it into a small chamber or pinches it to a crawl
        local narrow = math.min(w1[1], w2[1]) + (math.max(w1[2], w2[2]) - math.min(w1[1], w2[1])) * love.math.noise(t * length / 12, salt + 7)
        local swell = 0.6 + 1.0 * love.math.noise(t * length / 35, salt + 13) ^ 2
        local width = narrow * swell + (1 - math.sin(t * math.pi)) * 2      -- Wider where it meets a hub
        stamp(grid, x0, y0, cx, cy, width / 2, NORMAL)
    end
end


local function stampWorm(grid, x0, y0, x, y, angle, length, width, salt, kind, stop)
    -- A tendril: it bends left and right of its way as it goes and gets thinner to a point, its width swelling and
    -- pinching along it, stop(x, y) ends it early(an entrance at the surface)
    -- The bend is the way plus a slow noise, not added up step by step, which would curl it into loops
    for s = 0, length do
        local t = s / length
        local swell = 0.5 + 1.0 * love.math.noise(s / 8, salt + 3)
        stamp(grid, x0, y0, x, y, math.max(0.6, width * swell * (1 - t * 0.8)) / 2, kind)
        if stop ~= nil and stop(x, y) then
            return
        end
        local heading = angle + (love.math.noise(s / 14, salt) * 2 - 1) * 0.9
        x, y = x + math.cos(heading), y + math.sin(heading)
    end
end


local function stampRegionFeatures(grid, x0, y0, seed, rx, ry, world)
    -- What region rx, ry owns, stamped into the grid of the region at x0, y0
    local hub = hubOf(seed, rx, ry, world)
    if not hub then
        return
    end
    stampHub(grid, x0, y0, hub)
    -- Tunnels to the hubs right, under and down-right of it(the other directions belong to those regions)
    for k, step in ipairs({{1, 0, CONNECT_CHANCE}, {0, 1, CONNECT_CHANCE}, {1, 1, DIAGONAL_CHANCE}}) do
        local other = hubOf(seed, rx + step[1], ry + step[2], world)
        if other and hash(seed, rx, ry, 10 + k) < step[3] then
            stampTunnel(grid, x0, y0, hub, other, hash(seed, rx, ry, 20 + k) * 100)
        end
    end
    -- Tendrils off the hub, and sometimes an entrance up to the surface
    local r = random(seed, rx, ry, 3)
    local caves = hub.caves
    for k = 1, caves.tendrils or 0 do
        local angle = r:random() * math.pi * 2
        local x, y = hub.x + math.cos(angle) * hub.radius, hub.y + math.sin(angle) * hub.radius * 0.7
        -- Each tendril its own size, from the biome's narrowest tunnel to a bit over its widest
        local width = caves.tunnelWidth[1] + (caves.tunnelWidth[2] * 1.4 - caves.tunnelWidth[1]) * r:random()
        stampWorm(grid, x0, y0, x, y, angle, 12 + r:random() * 28, width, r:random() * 100, NORMAL)
    end
    -- Entrances come from the surface biome above the hub(the underground layers have none of their own)
    local surface = world.surface(math.floor(hub.x))
    local above = world.caves(math.floor(hub.x), surface + 1)
    if hub.y - surface <= ENTRANCE_REACH and r:random() < (above and above.entranceChance or 0) then
        local angle = -math.pi / 2 + (r:random() * 2 - 1) * 0.6
        local length = hub.y - surface + 40
        stampWorm(grid, x0, y0, hub.x, hub.y - hub.radius * 0.5, angle, length, caves.tunnelWidth[2] + 1, r:random() * 100, ENTRANCE,
            function(x, y) return y < world.surface(math.floor(x)) - 1 end)
    end
end


local function region(seed, rx, ry, world)
    -- The carved cells of a region, made once
    if carvedFor ~= seed then
        carved, hubs, carvedFor = {}, {}, seed
    end
    local key = rx .. "," .. ry
    local grid = carved[key]
    if grid == nil then
        grid = {}
        local n = CaveNetwork.REGION
        -- Features reach up to about a region into their neighbors(tunnels go to the next hub, tendrils and entrances
        -- wander), so the regions around are stamped too
        for ox = -1, 1 do
            for oy = -1, 1 do
                stampRegionFeatures(grid, rx * n, ry * n, seed, rx + ox, ry + oy, world)
            end
        end
        -- An entrance climbs past the region above its hub, from two regions down
        for ox = -1, 1 do
            stampRegionFeatures(grid, rx * n, ry * n, seed, rx + ox, ry + 2, world)
        end
        carved[key] = grid
    end
    return grid
end


function CaveNetwork.isCave(tx, ty, depth, seed, caves, world)
    -- True when the tile is open: a cave of the network(below the cave depth), an entrance, or a small pocket
    -- world gives the surface row of a column and the cave settings at a spot: {surface(tx), caves(tx, ty)}
    local n = CaveNetwork.REGION
    local rx, ry = math.floor(tx / n), math.floor(ty / n)
    local cell = region(seed, rx, ry, world)[(tx - rx * n) * n + (ty - ry * n)]
    if cell == ENTRANCE then
        return depth >= 0
    end
    if depth < caves.startDepth then
        return false
    end
    if cell == NORMAL then
        return true
    end
    return caves.pockets ~= nil and love.math.noise(tx * 0.13, ty * 0.13, (seed % 10007) * 0.37 + 5.1) > caves.pockets
end


return CaveNetwork
