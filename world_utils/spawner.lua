local Biomes = require "world_utils.biomes"
local Generator = require "world_utils.generator"
local WorldClock = require "world_utils.worldClock"

-- Enemies appearing around the player: every SPAWN_INTERVAL a spot just off the screen is tried,
-- the biome there(its surface or underground layer) picks what comes from its spawns list
-- Spawned enemies are temporary: far from the player for a while they are gone, and they are not saved
-- A spawns entry is {entity, weight, where = "surface" or "cave", group = {min, max}, time = "day", "night" or nil for any}
local Spawner = {}

local SURFACE_DEPTH = 3     -- Rows under the ground surface that still count as the surface(dips and hillsides)
local GROUND_TRIES = 24     -- Rows looked above and below the starting row for a floor

local timer = 0


local function solid(tx, ty)
    local block = map:blockAt(tx * TILE_SIZE, ty * TILE_SIZE)
    return block ~= nil and block.solid
end


local function canStand(tx, ty, height)
    -- True when a creature height rows tall can stand in row ty: solid below, air for its body
    if not solid(tx, ty + 1) then
        return false
    end
    for k = 0, height - 1 do
        if solid(tx, ty - k) then
            return false
        end
    end
    return true
end


local function floorAt(tx, startRow, height)
    -- The nearest row to startRow(above or below) where a creature can stand, nil when there is none close
    for offset = 0, GROUND_TRIES do
        if canStand(tx, startRow + offset, height) then
            return startRow + offset
        end
        if offset > 0 and canStand(tx, startRow - offset, height) then
            return startRow - offset
        end
    end
    return nil
end


local function timeFits(entry, night)
    return entry.time == nil or entry.time == "any" or (entry.time == "night") == night
end


local function pick(entries)
    local total = 0
    for i, entry in ipairs(entries) do
        total = total + entry.weight
    end
    local roll = love.math.random() * total
    for i, entry in ipairs(entries) do
        roll = roll - entry.weight
        if roll < 0 then
            return entry
        end
    end
    return entries[#entries]
end


local function nearbySpawned(px, py)
    -- Spawned enemies close enough to count for the cap
    local count = 0
    for i, enemy in ipairs(map.enemies.enemies) do
        if enemy.spawned and not enemy.dying then
            local x, y = enemy.body:getWorldCenter()
            if distance(px, py, x, y) <= SPAWN_CAP_DISTANCE * TILE_SIZE then
                count = count + 1
            end
        end
    end
    return count
end


function Spawner.tryAt(tx, startRow, room)
    -- Tries to spawn a group from the biome at column tx, looking down from startRow for ground, returns how many came
    -- room is how many more fit under the cap, a group never goes over it
    local height = math.ceil(PLAYER_HEIGHT / TILE_SIZE)
    local floor = floorAt(tx, startRow, height)
    if floor == nil then
        return 0
    end
    local surface = Generator.surfaceRow(tx, map.seed, map.settings)
    local depth = floor + 1 - surface
    local where = depth <= SURFACE_DEPTH and "surface" or "cave"
    -- Day keeps the surface calmer, caves dont see the sky
    local night = WorldClock.isNight()
    if where == "surface" and not night and love.math.random() >= SPAWN_DAY_CHANCE then
        return 0
    end
    local biome = Biomes.underground(depth, map.settings) or Biomes.surface(tx, map.seed, map.settings)
    local entries = {}
    for i, entry in ipairs(biome.spawns or {}) do
        if entry.where == where and timeFits(entry, night) and ENTITY_REGISTRY[entry.entity] ~= nil then
            table.insert(entries, entry)
        end
    end
    if #entries == 0 then
        return 0
    end

    local entry = pick(entries)
    local count = math.min(room or math.huge, love.math.random(entry.group[1], entry.group[2]))
    local made = 0
    for i = 0, count - 1 do
        -- The group stands side by side, each on its own ground
        local column = tx + (i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * 2
        local row = floorAt(column, floor - 2, height)
        if row ~= nil then
            local x = column * TILE_SIZE + TILE_SIZE / 2
            local y = (row + 1) * TILE_SIZE - PLAYER_HEIGHT / 2 - 2
            local enemy = ENTITY_REGISTRY[entry.entity]:new(x, y)
            enemy.spawned = true
            map.enemies:addEnemy(enemy)
            made = made + 1
        end
    end
    return made
end


local function despawn(dt, px, py)
    -- Spawned enemies far from the player for long enough are gone(nothing is happening to them, see Enemy:isAwake)
    local gone = {}
    for i, enemy in ipairs(map.enemies.enemies) do
        if enemy.spawned and not enemy.dying then
            local x, y = enemy.body:getWorldCenter()
            if distance(px, py, x, y) > DESPAWN_DISTANCE * TILE_SIZE and not enemy:isAwake() then
                enemy.farTime = (enemy.farTime or 0) + dt
                if enemy.farTime >= DESPAWN_TIME then
                    table.insert(gone, enemy)
                end
            else
                enemy.farTime = 0
            end
        end
    end
    for i, enemy in ipairs(gone) do
        enemy:destroy()
    end
end


function Spawner.update(dt)
    local px, py = player.body:getWorldCenter()
    despawn(dt, px, py)
    if not SPAWNING then
        return
    end
    timer = timer + dt
    if timer < SPAWN_INTERVAL then
        return
    end
    timer = 0
    local room = SPAWN_CAP - nearbySpawned(px, py)
    if room <= 0 then
        return
    end
    -- A spot off the screen to one side, a little above or below the player
    local side = love.math.random() < 0.5 and -1 or 1
    local tx = math.floor(px / TILE_SIZE) + side * love.math.random(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
    local startRow = math.floor(py / TILE_SIZE) + love.math.random(-SPAWN_HEIGHT, SPAWN_HEIGHT)
    Spawner.tryAt(tx, startRow, room)
end

return Spawner
