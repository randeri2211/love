local Map = require "world_utils.map"
local ManaNetwork = require "world_utils.manaNetwork"

-- Chunks that keep running while the player is away(see docs/game-design: Mana network), simulated but not drawn:
-- - every chunk holding a block with simulatesChunk(a Chunk Anchor, machines), for free. Batteries and conduits dont:
--   their chunks stay loaded so the network holds together(see Map:unloadFarChunks) but nothing in them runs,
--   otherwise a line of cheap conduits would keep any chunk running
-- - the chunks around a Chunk Anchor, as far as its radius, while its network pays CHUNK_ANCHOR_MANA a second for each
--   (an anchor that cant pay keeps only its own chunk)
-- A simulated chunk stays loaded and has hitboxes of its own(a hitbox area like an awake enemy's), so enemies, drops,
-- arrows and spells in it move and collide as usual. Nothing spawns there, the spawner stays around the player
-- Blocks with an update(map.tickers) run every frame near the player or in a simulated chunk, not in a chunk that is only
-- loaded
local Simulation = {}

local windows = {}      -- Chunk keys that have a hitbox area now
local windowsOf = nil   -- The map hitbox areas those are in, a loaded world has new ones
local anchorPaid = {}   -- Anchor -> whether it paid this frame


function Simulation.anchorChunks(anchor)
    -- Chunk keys an anchor reaches with its radius
    local _, cx, cy = Map.chunkKey(anchor.mx, anchor.my)
    local keys = {}
    local r = anchor.anchorRadius or 0
    for x = cx - r, cx + r do
        for y = cy - r, cy + r do
            table.insert(keys, x .. "," .. y)
        end
    end
    return keys
end


function Simulation.anchorCost(anchor)
    -- Mana a second an anchor costs: every chunk it adds around its own
    local r = anchor.anchorRadius or 0
    return ((2 * r + 1) ^ 2 - 1) * CHUNK_ANCHOR_MANA
end


function Simulation.isPowered(anchor)
    return anchorPaid[anchor] == true
end


local function wanted(dt)
    -- The simulated chunks this frame, anchors pay for theirs
    local chunks = {}
    for node in pairs(map.manaNodes) do
        if node.simulatesChunk then
            chunks[(Map.chunkKey(node.mx, node.my))] = "free"
        end
    end
    for node in pairs(map.manaNodes) do
        if node.anchorRadius ~= nil then
            local cost = Simulation.anchorCost(node) * dt
            anchorPaid[node] = cost <= 0 or ManaNetwork.drain(node, cost)
            if anchorPaid[node] then
                for i, key in ipairs(Simulation.anchorChunks(node)) do
                    chunks[key] = chunks[key] or "anchor"
                end
            end
        end
    end
    return chunks
end


function Simulation.update(dt)
    if windowsOf ~= map.hitboxWindows then
        windows, anchorPaid, windowsOf = {}, {}, map.hitboxWindows
    end
    local chunks = wanted(dt)
    map.simChunks = chunks
    -- Chunks that start being simulated are loaded and get a hitbox area, ones that stop let go of theirs
    for key in pairs(chunks) do
        if not windows[key] then
            local cx, cy = key:match("^(-?%d+),(-?%d+)$")
            cx, cy = tonumber(cx), tonumber(cy)
            map:getChunk(key, cx, cy)
            local x1, y1, x2, y2 = Map.chunkArea(cx, cy)
            map:updateHitboxes(x1, y1, x2, y2, "sim " .. key)
            windows[key] = true
        end
    end
    for key in pairs(windows) do
        if chunks[key] == nil then
            map:releaseHitboxes("sim " .. key)
            windows[key] = nil
        end
    end
    -- Blocks that do something on their own(a furnace smelting), near the player or where it runs
    local _, pcx, pcy = Map.chunkKey(loveToMap(player.body:getWorldCenter()))
    for block in pairs(map.tickers) do
        local key, cx, cy = Map.chunkKey(block.mx, block.my)
        if chunks[key] ~= nil or math.max(math.abs(cx - pcx), math.abs(cy - pcy)) <= CHUNK_UNLOAD_DISTANCE then
            block:update(dt)
        end
    end
end


function Simulation.chunkBox(key)
    -- Love box of a chunk by key: x, y of its top left, width, height(map y goes up, its top row is its last)
    local cx, cy = key:match("^(-?%d+),(-?%d+)$")
    local x1, y1, x2, y2 = Map.chunkArea(tonumber(cx), tonumber(cy))
    local tx, ty = map:mapToTile(x1, y2)
    return tx * TILE_SIZE, ty * TILE_SIZE, CHUNK_SIZE * TILE_SIZE, CHUNK_SIZE * TILE_SIZE
end


function Simulation.drawOutlines()
    -- World space: an outline around every running chunk while the minimap is open(see UIHandler:map)
    love.graphics.push("all")
    love.graphics.setLineWidth(3)
    for key, kind in pairs(map.simChunks or {}) do
        local x, y, w, h = Simulation.chunkBox(key)
        local c = kind == "free" and SIM_FREE_COLOR or SIM_ANCHOR_COLOR
        love.graphics.setColor(c[1], c[2], c[3], 0.08)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(c)
        love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4)
    end
    love.graphics.pop()
end

return Simulation
