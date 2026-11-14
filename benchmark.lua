local Generator = require "world_utils.generator"
local Spellbooks = require "magic.spellbooks"
local Scrolls = require "items.scrolls"

-- A performance benchmark(started with --bench, see constants.lua): the same scenarios on the same seed every run,
-- each warmed up for WARMUP seconds and measured for MEASURE seconds with vsync off, so runs before and after a change
-- can be compared. Prints a table and saves it to benchmark.txt in the save folder, then quits
-- Frame time is measured from the start of one update to the start of the next(update, draw and showing the frame),
-- the 1% low is the frame rate of the slowest 1% of frames, what stutter feels like
local Benchmark = {}

Benchmark.WARMUP = 1
Benchmark.MEASURE = 5
Benchmark.SEED = 12345

local scenarios = {}
local current = nil         -- {scenario, phase, clock, frames = {ms}, updates = {ms}, draws = {ms}}
local results = {}
local index = 0
local gameUpdate, gameDraw = nil, nil


-- World helpers
local function cell(tx, ty)
    return tx + map.center.x + 1, map.center.y + 1 - ty
end

local function put(tx, ty, name)
    local x, y = cell(tx, ty)
    local block = name and map:newBlock(name, x, y) or nil
    map:set(x, y, block)
    return block
end

local function freshWorld()
    -- A new world from the benchmark seed, the player standing on the surface at column 0, by day, nothing spawning
    if p_world ~= nil and not p_world:isDestroyed() then
        p_world:destroy()
    end
    initVars({biomeWidth = BIOME_SIZES[DEFAULT_BIOME_SIZE][2], dayLength = DAY_LENGTH, flora = FLORA_VERSION,
        structures = STRUCTURES_VERSION})
    map.seed = Benchmark.SEED
    map.time = 0.5 * DAY_LENGTH
    game_state = IN_WORLD_STATE
    SPAWNING = false
    DEBUG_GOD = true
    uihandler.showMap = false
    local top = Generator.surfaceRow(0, map.seed, map.settings)
    player.body:setPosition(TILE_SIZE / 2, top * TILE_SIZE - PLAYER_HEIGHT)
    player.body:setLinearVelocity(0, 0)
    return top
end

local function arena(top, from, to)
    -- A flat stone floor with open air above it, the player in the middle
    for tx = from, to do
        put(tx, top + 1, "Stone")
        for ty = top - 10, top do
            put(tx, ty, nil)
        end
    end
    player.body:setPosition(TILE_SIZE / 2, top * TILE_SIZE - PLAYER_HEIGHT / 2)
end

local function enemy(name, tx, ty)
    local e = ENTITY_REGISTRY[name]:new(tx * TILE_SIZE, ty * TILE_SIZE)
    e.spawned = false
    map.enemies:addEnemy(e)
    return e
end


-- The scenarios, in order: {name, setup(), update(dt) run every frame}
local function add(name, setup, update)
    table.insert(scenarios, {name = name, setup = setup, update = update})
end

add("Surface, day", function() freshWorld() end)

add("Surface, night", function() freshWorld() map.time = 0 end)

add("Underground cave", function()
    local top = freshWorld() + 80
    for tx = -25, 25 do
        for ty = top - 12, top do
            put(tx, ty, nil)
        end
        put(tx, top + 1, "Stone")
    end
    player.body:setPosition(TILE_SIZE / 2, top * TILE_SIZE - PLAYER_HEIGHT / 2)
end)

add("Walking, new chunks", function() freshWorld() end, function(dt)
    -- 20 tiles a second along the surface, new chunks are made as it goes
    local x = player.body:getX() + 20 * TILE_SIZE * dt
    local top = Generator.surfaceRow(math.floor(x / TILE_SIZE), map.seed, map.settings)
    player.body:setPosition(x, top * TILE_SIZE - PLAYER_HEIGHT)
    player.body:setLinearVelocity(0, 0)
end)

add("40 enemies", function()
    local top = freshWorld()
    arena(top, -30, 30)
    for i = 1, 20 do enemy("Slime", -25 + i * 2.5, top - 2) end
    for i = 1, 10 do enemy("Zombie", -20 + i * 4, top - 1) end
    for i = 1, 5 do enemy("Bat", -10 + i * 4, top - 7) end
    for i = 1, 5 do enemy("SkeletonArcher", -24 + i * 10, top - 1) end
end)

add("Spell storm", function()
    local top = freshWorld()
    arena(top, -30, 30)
end, function(dt)
    -- The player's first spell cast five times a frame in every direction
    local spell = Spellbooks.selectedSpell(player.spellbook)
    for i = 1, 5 do
        local a = love.math.random() * math.pi * 2
        spell.cooldownEnd = nil
        player.manaBar.currentMana = player.manaBar.maxMana
        spell:shoot(player, nil, nil, math.cos(a), math.sin(a))
    end
end)

add("Mana network", function()
    local top = freshWorld()
    arena(top, -40, 40)
    for i = 0, 5 do
        local b = put(-36 + i * 14, top, "ManaBattery")
        b:placeParts()
        b.mana = 5000
        b.feedPlayer = true
    end
    for tx = -38, 38, 4 do
        put(tx, top - 6, "ManaConduit")
    end
end)

add("10 turrets, 20 enemies", function()
    local top = freshWorld()
    arena(top, -40, 40)
    local b = put(-2, top, "ManaBattery")
    b:placeParts()
    b.mana = MANA_BATTERY_CAPACITY
    local entry = player.spellbook.spells[1]
    for i = 0, 9 do
        local t = put(-20 + i * 4 + (i >= 5 and 4 or 0), top, "IronArcaneTurret")
        t.scroll = Scrolls.bind(entry.name, entry.spell)
        put(-20 + i * 4 + (i >= 5 and 4 or 0), top - 5, "ManaConduit")
    end
    for i = 1, 20 do
        enemy(i % 2 == 0 and "Slime" or "Zombie", (i % 2 == 0 and -36 or 36) + (i % 5), top - 2)
    end
end, function(dt)
    -- The enemies healed and the battery kept full, so the turrets never stop
    for i, e in pairs(map.enemies.enemies) do
        e.hpBar.currentHP = e.hpBar.maxHP
    end
    for node in pairs(map.manaNodes) do
        if node.mana ~= nil then
            node.mana = MANA_BATTERY_CAPACITY
        end
    end
end)

add("Anchors, 75 far chunks", function()
    local top = freshWorld()
    arena(top, -10, 10)
    local b = put(0, top, "ManaBattery")
    b:placeParts()
    b.mana = MANA_BATTERY_CAPACITY
    -- Three anchors far to the right on a line of conduits, each running 5 x 5 chunks with slimes in them
    for tx = 5, 900, 5 do
        local ty = Generator.surfaceRow(tx, map.seed, map.settings) - 1
        put(tx, ty, "ManaConduit")
    end
    for i, tx in ipairs({300, 600, 900}) do
        local ty = Generator.surfaceRow(tx, map.seed, map.settings) - 1
        local a = put(tx + 1, ty, "ChunkAnchor")
        a.anchorRadius = 2
        for s = 1, 10 do enemy("Slime", tx - 20 + s * 4, ty - 3) end
    end
end, function(dt)
    for node in pairs(map.manaNodes) do
        if node.mana ~= nil then
            node.mana = MANA_BATTERY_CAPACITY
        end
    end
end)

add("Minimap open", function()
    freshWorld()
    uihandler.showMap = true
    uihandler.minimap = uihandler.minimap or require("ui.minimap"):new()
    uihandler.minimap.showGrid = true
    uihandler.minimap.showAnchors = true
end)


-- Running them
local function percentile(list, p)
    local sorted = {}
    for i, v in ipairs(list) do
        sorted[i] = v
    end
    table.sort(sorted)
    return sorted[math.max(1, math.floor(#sorted * p + 0.5))] or 0
end

local function average(list)
    local total = 0
    for i, v in ipairs(list) do
        total = total + v
    end
    return #list > 0 and total / #list or 0
end

local function nextScenario()
    index = index + 1
    local scenario = scenarios[index]
    if scenario == nil then
        return false
    end
    print("Benchmark: " .. scenario.name)
    love.math.setRandomSeed(Benchmark.SEED)
    scenario.setup()
    collectgarbage()
    current = {scenario = scenario, phase = "warmup", clock = 0, frames = {}, updates = {}, draws = {}, last = nil}
    return true
end

local function finish()
    local lines = {
        string.format("Benchmark  %s  (%d s each, vsync off, %s pixel art)", os.date("%Y-%m-%d %H:%M"), Benchmark.MEASURE, ART_PIXELS),
        string.format("%-26s %8s %8s %9s %9s %9s", "Scenario", "Avg FPS", "1% low", "Frame ms", "Update ms", "Draw ms"),
    }
    for i, r in ipairs(results) do
        table.insert(lines, string.format("%-26s %8.0f %8.0f %9.2f %9.2f %9.2f", r.name, r.fps, r.low, r.frame, r.update, r.draw))
    end
    local text = table.concat(lines, "\n")
    print("\n" .. text .. "\n")
    love.filesystem.write("benchmark.txt", text .. "\n")
    print("Saved to " .. love.filesystem.getSaveDirectory() .. "/benchmark.txt")
    love.event.quit()
end


function Benchmark.start()
    -- Takes over update and draw: every frame runs the game, the scenario's own update and the timing
    love.window.setVSync(0)
    gameUpdate, gameDraw = love.update, love.draw
    nextScenario()

    love.update = function(dt)
        local now = love.timer.getTime()
        if current.last ~= nil and current.phase == "measure" then
            table.insert(current.frames, (now - current.last) * 1000)
        end
        current.last = now
        current.clock = current.clock + dt
        if current.phase == "warmup" and current.clock >= Benchmark.WARMUP then
            current.phase, current.clock = "measure", 0
        elseif current.phase == "measure" and current.clock >= Benchmark.MEASURE then
            local frame = average(current.frames)
            table.insert(results, {name = current.scenario.name, frame = frame, fps = 1000 / frame,
                low = 1000 / percentile(current.frames, 0.99), update = average(current.updates), draw = average(current.draws)})
            if not nextScenario() then
                finish()
            end
            return
        end
        if current.scenario.update ~= nil then
            current.scenario.update(dt)
        end
        local t = love.timer.getTime()
        gameUpdate(dt)
        if current.phase == "measure" then
            table.insert(current.updates, (love.timer.getTime() - t) * 1000)
        end
    end

    love.draw = function()
        local t = love.timer.getTime()
        gameDraw()
        if current ~= nil and current.phase == "measure" then
            table.insert(current.draws, (love.timer.getTime() - t) * 1000)
        end
    end
end

return Benchmark
