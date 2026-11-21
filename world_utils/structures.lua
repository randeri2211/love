local Generator = require "world_utils.generator"
local Biomes = require "world_utils.biomes"
local Levels = require "components.stats.levels"
local Inventories = require "items.inventories"

-- Structures placed by world generation(see docs/game-design: Early game), from the structures folder(registerStructure)
-- Every type has its own grid of cells along the world: the seed decides if a cell has one and where in the cell,
-- like tree spots(see world_utils/flora). A chunk being made asks which structures overlap it and writes in its part
-- of their blueprints, so a structure across several chunks always comes out whole and the same
-- A structure is {def, id, tx, ty(top left tile), w, h, level}, its guards spawn when their chunk is made,
-- the map remembers how many died(map.structures[id]), when the last one does the structure is cleared for good
--
-- A def is registered with:
--   where = "surface" or "cave", cell = tiles per grid cell, chance = how often a cell has one, priority(rarer first)
--   biomes = {Plains = true...} or nil for any(surface ones), depth = {min, max} tiles underground(cave ones)
--   ground = the blueprint row that sits on the surface, maxSlope = how uneven the ground under it may be
--   blueprint = rows of characters, legend = what each character is:
--     a block name, false for air(carved out), nothing for keeping what the world has there,
--     {chest = block name}, {glyph = true}, {guard = true}(air with a guard standing in it), {ore = true}(def.ore(depth))
--   decays = {[character] = chance} blocks of ruins left out, guards = {{entity, weight}} or by biome name,
--   backWall = {[character] = true} cells with a wall drawn behind them(backWallTile, see Structures.drawBackWalls),
--   loot = {{item, min, max, chance}} for its chests, title = its name in messages
--   find(def, cell, seed, settings) = the column it starts at, nil when its cell has none: for a structure placed by
--     something other than chance(a lair on a ley line crossing), it then sits on the surface like a surface one
--   version = the lowest STRUCTURES_VERSION a world needs to have it(older worlds already saved chunks without it)
--   glyph = the rune its glyph walls teach(a boss rune, never taught anywhere else, see Structures.bossRunes)
--   boss, summon = the boss its altar({altar = true}) summons and the item that does it(see blocks/summoningAltar),
--     beating the boss clears the structure and unseals its glyph walls, {door = true} cells are air that a Lair Seal
--     closes while the boss is fought(see blocks/lairSeal)
--   fill = {[character] = block name}: under a column whose bottom blueprint cell is that character, the block fills
--     down to the ground, so it never stands over a slope with air under it(found.fill = the ground row per column,
--     found.extra = how many rows the deepest one goes past the blueprint)
local Structures = {}

local cache = {}            -- Structures worked out so far by def name and cell, false for an empty cell
local cacheSeed = nil


local function hash(seed, i, salt)
    -- Repeatable number from 0 to 1
    local v = math.sin(i * 12.9898 + (seed % 10007) * 0.731 + salt * 78.233) * 43758.5453
    return v - math.floor(v)
end


local function overlaps(a, b)
    return a.tx < b.tx + b.w and b.tx < a.tx + a.w and a.ty < b.ty + b.h + (b.extra or 0) and b.ty < a.ty + a.h + (a.extra or 0)
end


local function build(def, index, cell)
    -- The structure of one grid cell, false when the cell has none
    local seed, settings = map.seed, map.settings
    local salt = index * 17.3
    if hash(seed, cell, salt) >= def.chance then
        return false
    end
    local w, h = #def.blueprint[1], #def.blueprint
    local margin = 4
    local tx = cell * def.cell + margin + math.floor(hash(seed, cell, salt + 1) * math.max(1, def.cell - w - margin * 2))
    if def.find ~= nil then
        tx = def.find(def, cell, seed, settings)
        if tx == nil then
            return false
        end
    end
    local center = tx + math.floor(w / 2)
    -- Never on top of where the world starts
    if math.abs(center) < STRUCTURE_SPAWN_CLEAR then
        return false
    end
    local ground = Generator.surfaceRow(center, seed, settings)
    local ty
    if def.where == "surface" then
        if def.biomes ~= nil and not def.biomes[Biomes.surface(center, seed, settings).name] then
            return false
        end
        -- Only where the ground is flat enough under it
        for column = tx, tx + w - 1 do
            if def.maxSlope ~= nil and math.abs(Generator.surfaceRow(column, seed, settings) - ground) > def.maxSlope then
                return false
            end
        end
        ty = ground - (def.ground - 1)
    else
        local depth = def.depth[1] + math.floor(hash(seed, cell, salt + 2) * (def.depth[2] - def.depth[1]))
        ty = ground + depth
    end
    local found = {def = def, id = def.name .. ":" .. cell, tx = tx, ty = ty, w = w, h = h, cell = cell,
        biome = Biomes.surface(center, seed, settings).name, depth = ty - ground, extra = 0}
    if def.fill ~= nil then
        -- Where the ground is under every column, the fill goes down to it
        found.fill = {}
        for c = 1, w do
            local row = Generator.surfaceRow(tx + c - 1, seed, settings)
            found.fill[c] = row
            found.extra = math.max(found.extra, row - (ty + h - 1))
        end
    end
    return found
end


local function structure(def, index, cell)
    -- The structure of a cell from the cache, rarer types placed first win where two would overlap
    if cacheSeed ~= map.seed then
        cache, cacheSeed = {}, map.seed
    end
    cache[def.name] = cache[def.name] or {}
    local found = cache[def.name][cell]
    if found ~= nil then
        return found
    end
    found = build(def, index, cell)
    if found then
        for j, other in ipairs(STRUCTURE_REGISTRY) do
            if other.priority > def.priority and other.where == def.where then
                for c = math.floor((found.tx - 64) / other.cell), math.floor((found.tx + found.w + 64) / other.cell) do
                    local rival = structure(other, j, c)
                    if rival and overlaps(found, rival) then
                        found = false
                        break
                    end
                end
            end
            if not found then
                break
            end
        end
    end
    cache[def.name][cell] = found
    return found
end


function Structures.inArea(tx1, ty1, tx2, ty2)
    -- Every structure overlapping the tiles tx1, ty1 to tx2, ty2
    local list = {}
    if map.settings == nil or map.settings.structures == nil then
        return list     -- Worlds made before structures dont get them, their saved chunks were made without
    end
    for index, def in ipairs(STRUCTURE_REGISTRY) do
        local w = #def.blueprint[1]
        -- A type newer than the world isnt in it
        local cells = (def.version or 1) <= map.settings.structures and math.floor(tx2 / def.cell) or math.floor((tx1 - w) / def.cell) - 1
        for cell = math.floor((tx1 - w) / def.cell), cells do
            local found = structure(def, index, cell)
            if found and found.tx <= tx2 and found.tx + found.w > tx1 and found.ty <= ty2 and found.ty + found.h + found.extra > ty1 then
                table.insert(list, found)
            end
        end
    end
    return list
end


local function decayed(found, c, r)
    -- True when the ruin is missing this blueprint cell: by its own chance, or because the block under it in the same
    -- wall is missing, so ruins crumble from the top down instead of leaving bricks floating in the air
    local def = found.def
    local char = def.blueprint[r]:sub(c, c)
    local decay = def.decays and def.decays[char]
    if decay == nil then
        return false
    end
    if hash(map.seed, (found.tx + c) * 311 + found.ty + r, 7.7) < decay then
        return true
    end
    local below = def.blueprint[r + 1]
    return below ~= nil and below:sub(c, c) == char and decayed(found, c, r + 1)
end


function Structures.cells(found, tx1, ty1, tx2, ty2)
    -- Every blueprint cell of a structure inside the tiles tx1, ty1 to tx2, ty2 that changes the world:
    -- {tx, ty, entry}, entry is a block name, false for air or a table for something special
    local cells = {}
    local def = found.def
    for r = math.max(1, ty1 - found.ty + 1), math.min(found.h, ty2 - found.ty + 1) do
        local row = def.blueprint[r]
        for c = math.max(1, tx1 - found.tx + 1), math.min(found.w, tx2 - found.tx + 1) do
            local char = row:sub(c, c)
            local entry = def.legend[char]
            if entry ~= nil then
                local tx, ty = found.tx + c - 1, found.ty + r - 1
                -- Ruins miss some of their blocks, always the same ones
                if decayed(found, c, r) then
                    entry = false
                end
                table.insert(cells, {tx = tx, ty = ty, entry = entry})
            end
        end
    end
    -- The fill under it, down to the ground
    if found.fill ~= nil then
        local bottom = def.blueprint[found.h]
        for c = math.max(1, tx1 - found.tx + 1), math.min(found.w, tx2 - found.tx + 1) do
            local block = def.fill[bottom:sub(c, c)]
            if block ~= nil then
                for ty = math.max(ty1, found.ty + found.h), math.min(ty2, found.fill[c]) do
                    table.insert(cells, {tx = found.tx + c - 1, ty = ty, entry = block})
                end
            end
        end
    end
    return cells
end


function Structures.byId(id)
    -- The structure with an id("UnicornLair:-3"), nil when there is none
    local name, cell = tostring(id):match("^(.-):(%-?%d+)$")
    for index, def in ipairs(STRUCTURE_REGISTRY) do
        if def.name == name then
            return structure(def, index, tonumber(cell)) or nil
        end
    end
    return nil
end


function Structures.doors(found)
    -- The tiles of its {door = true} cells, {tx, ty}
    local list = {}
    for r, row in ipairs(found.def.blueprint) do
        for c = 1, #row do
            local entry = found.def.legend[row:sub(c, c)]
            if type(entry) == "table" and entry.door then
                table.insert(list, {tx = found.tx + c - 1, ty = found.ty + r - 1})
            end
        end
    end
    return list
end


function Structures.bossOf(id)
    -- The living boss of a lair, nil when it isnt summoned
    for i, enemy in ipairs(map.enemies.enemies) do
        if enemy.lairId == id and enemy.boss and not enemy.dying then
            return enemy
        end
    end
    return nil
end


function Structures.sealDoors(id)
    -- Closes a lair's way in with Lair Seals while its boss is fought, they open on their own when it is gone
    local found = Structures.byId(id)
    if found == nil then
        return
    end
    for i, door in ipairs(Structures.doors(found)) do
        local x, y = door.tx + map.center.x + 1, map.center.y + 1 - door.ty
        if map:get(x, y) == nil then
            local seal = map:newBlock("LairSeal", x, y)
            seal.lairId = id
            map:set(x, y, seal)
        end
    end
end


function Structures.drawBackWalls(camX, camY)
    -- World space, before the blocks like the cave walls: the dark wall behind the inside of a building, so its rooms
    -- dont show the sky through them(the light over the world darkens it more away from the torches)
    local w, h = love.graphics.getDimensions()
    local tx1, tx2 = math.floor((camX - w / 2) / TILE_SIZE) - 1, math.floor((camX + w / 2) / TILE_SIZE) + 1
    local ty1, ty2 = math.floor((camY - h / 2) / TILE_SIZE) - 1, math.floor((camY + h / 2) / TILE_SIZE) + 1
    local list = Structures.inArea(tx1, ty1, tx2, ty2)
    if #list == 0 then
        return
    end
    love.graphics.push("all")
    love.graphics.setColor(STRUCTURE_WALL_SHADE, STRUCTURE_WALL_SHADE, STRUCTURE_WALL_SHADE * 1.1, 1)
    for i, found in ipairs(list) do
        local def = found.def
        local quad = def.backWall ~= nil and BLOCK_TILES[def.backWallTile]
        if quad then
            for r = math.max(1, ty1 - found.ty + 1), math.min(found.h, ty2 - found.ty + 1) do
                local row = def.blueprint[r]
                for c = math.max(1, tx1 - found.tx + 1), math.min(found.w, tx2 - found.tx + 1) do
                    if def.backWall[row:sub(c, c)] then
                        love.graphics.draw(TILESHEET, quad, (found.tx + c - 1) * TILE_SIZE, (found.ty + r - 1) * TILE_SIZE, 0, ART_SCREEN, ART_SCREEN)
                    end
                end
            end
        end
    end
    love.graphics.pop()
end


function Structures.level(found)
    -- How strong its guards are, from where it is like any enemy
    return Levels.forPosition((found.tx + found.w / 2) * TILE_SIZE, (found.ty + found.h / 2) * TILE_SIZE)
end


local function rng(found, salt)
    -- A random generator that always gives this structure the same numbers
    local n = 0
    for i = 1, #found.id do
        n = (n * 31 + found.id:byte(i)) % 2147483647
    end
    return love.math.newRandomGenerator((n + map.seed * 7 + salt) % 2147483647)
end


function Structures.fillChest(found, chest, index)
    -- Its loot, rolled the same way every time for this chest of this structure
    local r = rng(found, index * 101)
    for i, entry in ipairs(found.def.loot or {}) do
        if ITEM_REGISTRY[entry[1]] ~= nil and r:random() < (entry[4] or 1) then
            Inventories.add(chest.inventory, entry[1], r:random(entry[2], entry[3]))
        end
    end
end


function Structures.bossRunes()
    -- The runes only a boss lair teaches(their glyph), name -> true
    local runes = {}
    for i, def in ipairs(STRUCTURE_REGISTRY) do
        if def.glyph ~= nil then
            runes[def.glyph] = true
        end
    end
    return runes
end


function Structures.glyphRune(found)
    -- The rune its glyph wall teaches: its own(a lair's boss rune), or one the player doesnt start with and no boss
    -- teaches, the same one every time
    if found.def.glyph ~= nil then
        return found.def.glyph
    end
    local boss = Structures.bossRunes()
    local names = {}
    for name in pairs(RUNE_REGISTRY) do
        local starting = boss[name] == true
        for i, start in ipairs(STARTING_RUNES) do
            starting = starting or start == name
        end
        if not starting then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names[rng(found, 7):random(1, #names)]
end


function Structures.guardFor(found, index)
    -- Which enemy guards a spot, from the guard list(by biome when it has one), the same one every time
    local list = found.def.guards
    if list[found.biome] ~= nil then
        list = list[found.biome]
    elseif list.default ~= nil then
        list = list.default
    end
    local total = 0
    for i, entry in ipairs(list) do
        total = total + entry[2]
    end
    local roll = rng(found, 1000 + index):random() * total
    for i, entry in ipairs(list) do
        roll = roll - entry[2]
        if roll < 0 then
            return entry[1]
        end
    end
    return list[#list][1]
end


function Structures.state(id, found)
    -- What the map remembers about a structure: how many guards it has, how many died, whether it is cleared
    local state = map.structures[id]
    if state == nil and found ~= nil then
        state = {guards = found.def.guardCount, killed = 0, cleared = false, title = found.def.title, level = Structures.level(found)}
        map.structures[id] = state
    end
    return state
end


function Structures.guardDied(enemy)
    -- One of its guards is dead, the last one clears it: a message and experience for the player
    local state = Structures.state(enemy.structureId)
    if state == nil or state.cleared then
        return
    end
    state.killed = state.killed + 1
    if state.killed >= state.guards then
        state.cleared = true
        Levels.gain(player, STRUCTURE_XP * (state.level or 1))
        if uihandler ~= nil then
            uihandler:toast(string.format("Cleared the %s, +%d XP", state.title or "structure", STRUCTURE_XP * (state.level or 1)), LEVEL_COLOR)
        end
    end
end


function Structures.isCleared(id)
    -- True once a structure is cleared(a lair once its boss was beaten)
    local state = map.structures[id]
    return state ~= nil and state.cleared == true
end


function Structures.bossDefeated(id)
    -- A lair's boss is dead: the lair is cleared and its glyph walls open, experience the first time
    local state = map.structures[id]
    if state == nil then
        return
    end
    if not state.cleared then
        state.cleared = true
        Levels.gain(player, STRUCTURE_XP * (state.level or 1))
        if uihandler ~= nil then
            uihandler:toast(string.format("The %s is open, +%d XP", state.title or "lair", STRUCTURE_XP * (state.level or 1)), LEVEL_COLOR)
        end
    end
end


function Structures.spawnGuards()
    -- Guards queued while chunks were made(bodies cant be made inside a physics step), spawned at their spot
    -- They keep the structure's level and are saved like any enemy, never despawned
    local queue = map.pendingGuards
    map.pendingGuards = {}
    for i, guard in ipairs(queue) do
        local class = ENTITY_REGISTRY[guard.entity]
        if class ~= nil then
            local x = (guard.tx + 0.5) * TILE_SIZE
            local y = (guard.ty + 1) * TILE_SIZE - PLAYER_HEIGHT / 2 - 2
            local enemy = class:new(x, y)
            if enemy.build ~= nil then
                Levels.setLevel(enemy, guard.level, enemy.build)
            end
            enemy.structureId = guard.id
            map.enemies:addEnemy(enemy)
            enemy:update(0)     -- Its animation is set up before it is first drawn(enemies already updated this frame)
        end
    end
end

return Structures
