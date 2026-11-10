local socket = require "socket"
local Inventories = require "items.inventories"
local Levels = require "components.stats.levels"
local WorldClock = require "world_utils.worldClock"

-- A development link for the Stream Deck plugin(tools/streamdeck): the game listens on DEV_LINK_PORT on this computer only,
-- the plugin connects, sends commands one a line("spawn Slime", "time 22") and gets back "ok <text>" or "error <text>"
-- Twice a second the game sends a status line of name=value pairs the plugin shows on its keys(see status)
-- Nothing here is part of the game, DEV_LINK_PORT = nil turns it off
local DevLink = {}

DevLink.STATUS_INTERVAL = 0.5   -- Seconds between status lines

local server = nil          -- The listening socket, false when the port was taken(another game is open)
local client = nil          -- The connected plugin, one at a time
local statusTimer = 0


local function inWorld()
    return game_state == IN_WORLD_STATE and player ~= nil
end


local function toggle(name, label)
    -- Flips a global true/false setting and tells what it is now
    _G[name] = not _G[name]
    return label .. (_G[name] and " on" or " off")
end


-- Commands by their first word, each gets the other words and returns the reply text, or errors with what went wrong
-- The ones that need a world say so first
local COMMANDS = {}

function COMMANDS.art()
    -- Reads every art file again(see reloadArt), for drawing in LibreSprite with the game open
    local done, failed = reloadArt()
    if #failed > 0 then
        error(string.format("reloaded %d, restart for %s(changed size)", done, table.concat(failed, ", ")))
    end
    return "reloaded " .. done .. " images"
end

function COMMANDS.spawn(args)
    -- An enemy at the mouse, a few with a count: spawn Slime 3
    assert(inWorld(), "not in a world")
    local class = ENTITY_REGISTRY[args[1] or ""]
    assert(class ~= nil, "no entity " .. tostring(args[1]))
    local mx, my = mouseToLove()
    for i = 1, tonumber(args[2]) or 1 do
        map.enemies:addEnemy(class:new(mx + (i - 1) * TILE_SIZE, my))
    end
    return "spawned " .. args[1]
end

function COMMANDS.give(args)
    -- Items into the inventory: give Torch 20
    assert(inWorld(), "not in a world")
    assert(ITEM_REGISTRY[args[1] or ""] ~= nil, "no item " .. tostring(args[1]))
    local count = tonumber(args[2]) or 1
    local left = Inventories.add(player.inventory, args[1], count)
    return string.format("gave %d %s", count - left, args[1])
end

function COMMANDS.time(args)
    -- The time of day by the hour(0 to 24) or by name, the day stays the same
    assert(inWorld(), "not in a world")
    local named = {dawn = 6, morning = 8, noon = 12, dusk = 19, night = 22, midnight = 0}
    local hour = named[args[1] or ""] or tonumber(args[1])
    assert(hour ~= nil, "time takes an hour or dawn, morning, noon, dusk, night, midnight")
    local length = WorldClock.dayLength()
    map.time = math.floor((map.time or 0) / length) * length + (hour % 24) / 24 * length
    return string.format("time %02d:00", hour % 24)
end

function COMMANDS.xp(args)
    assert(inWorld(), "not in a world")
    Levels.gain(player, tonumber(args[1]) or 100)
    return "level " .. player.level
end

function COMMANDS.heal()
    assert(inWorld(), "not in a world")
    player.hpBar.currentHP = player.hpBar.maxHP
    player.manaBar.currentMana = player.manaBar.maxMana
    return "healed"
end

function COMMANDS.tp()
    -- The player to the mouse
    assert(inWorld(), "not in a world")
    local mx, my = mouseToLove()
    player.body:setPosition(mx, my)
    player.body:setLinearVelocity(0, 0)
    return "teleported"
end

function COMMANDS.god()
    return toggle("DEBUG_GOD", "god")
end

function COMMANDS.debug()
    return toggle("DEBUG", "debug")
end

function COMMANDS.onehit()
    return toggle("DEBUG_ONE_HIT_BLOCKS", "one hit blocks")
end

function COMMANDS.save()
    assert(inWorld(), "not in a world")
    saveScene(currentWorld)
    return "saved"
end

function COMMANDS.key(args)
    -- Presses a game key, so every key in keys.lua and the debug keys work from the Stream Deck too
    assert(args[1] ~= nil, "key takes a key name")
    love.keypressed(args[1])
    return "pressed " .. args[1]
end


local function run(line)
    -- One command line into its reply line
    local words = {}
    for word in line:gmatch("%S+") do
        table.insert(words, word)
    end
    local command = COMMANDS[table.remove(words, 1) or ""]
    if command == nil then
        return "error unknown command: " .. line
    end
    local ok, result = pcall(command, words)
    if not ok then
        return "error " .. tostring(result):gsub("^.-:%d+: ", "")     -- Without the file and line of the assert
    end
    return "ok " .. tostring(result)
end


local function status()
    -- The status line: the game state and, in a world, where the player is and how it is doing
    local values = {"state=" .. (inWorld() and "world" or "menu"), "fps=" .. love.timer.getFPS()}
    if inWorld() then
        local x, y = player.body:getWorldCenter()
        local hours = WorldClock.phase() * 24
        local enemies = 0
        for _ in pairs(map.enemies.enemies) do
            enemies = enemies + 1
        end
        table.insert(values, "x=" .. math.floor(x / TILE_SIZE))
        table.insert(values, "y=" .. -math.floor(y / TILE_SIZE))
        table.insert(values, "enemies=" .. enemies)
        table.insert(values, string.format("time=%02d:%02d", math.floor(hours), math.floor((hours % 1) * 60)))
        table.insert(values, "level=" .. player.level)
        table.insert(values, string.format("hp=%d/%d", player.hpBar.currentHP, player.hpBar.maxHP))
        table.insert(values, string.format("mana=%d/%d", player.manaBar.currentMana, player.manaBar.maxMana))
        table.insert(values, "bodies=" .. p_world:getBodyCount())
        table.insert(values, "god=" .. tostring(DEBUG_GOD))
    end
    return "status " .. table.concat(values, " ")
end


local function send(line)
    if client ~= nil and client:send(line .. "\n") == nil then
        client:close()
        client = nil
    end
end


function DevLink.update(dt)
    -- Takes a new plugin connection, runs what it sent and sends the status now and then, never waits on the socket
    if DEV_LINK_PORT == nil or server == false then
        return
    end
    if server == nil then
        server = socket.bind("127.0.0.1", DEV_LINK_PORT) or false
        if server == false then
            print("Dev link: port " .. DEV_LINK_PORT .. " is taken, the Stream Deck stays off for this game")
            return
        end
        server:settimeout(0)
    end

    local newClient = server:accept()
    if newClient ~= nil then
        if client ~= nil then
            client:close()
        end
        client = newClient
        client:settimeout(0)
        statusTimer = 0
    end

    while client ~= nil do
        local line, err = client:receive("*l")
        if line ~= nil then
            local reply = run(line)
            send(reply)
            if inWorld() and uihandler ~= nil then
                uihandler:toast((reply:gsub("^ok ", "")))
            end
        else
            if err == "closed" then
                client:close()
                client = nil
            end
            break
        end
    end

    statusTimer = statusTimer - dt
    if statusTimer <= 0 and client ~= nil then
        statusTimer = DevLink.STATUS_INTERVAL
        send(status())
    end
end

return DevLink
