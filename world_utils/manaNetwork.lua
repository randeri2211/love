local ManaShader = require "world_utils.manaShader"

-- The mana network(see docs/game-design: Mana network), for now the mana batteries within MANA_NETWORK_REACH tiles of the player:
-- - while the player's mana is full, what they regenerate goes into the nearest battery with room instead of being lost
-- - batteries with "Feed the player" on pay the player's spells first(see available and pay), the pool pays the rest
-- Batteries in reach are one buffer: mana goes in and out through the nearest one that has room, or has mana
-- A beam of the mana effect shows while mana moves between a battery and the player
local ManaNetwork = {}

local near = {}     -- Batteries in reach of the player this frame, nearest first
local beams = {}    -- Battery -> {time left, true when the mana flows to the player}


local function boxDistance(px, py, battery)
    -- Tiles from a love point to the nearest edge of a battery
    local x, y, w, h = battery:box()
    local dx = math.max(x - px, 0, px - (x + w))
    local dy = math.max(y - py, 0, py - (y + h))
    return math.sqrt(dx * dx + dy * dy) / TILE_SIZE
end


local function findNear(px, py)
    -- Every battery whose edge is within reach of the love point, nearest first
    local found, seen = {}, {}
    local mx, my = loveToMap(px, py)
    local r = MANA_NETWORK_REACH + 2
    for x = mx - r, mx + r do
        for y = my - r, my + r do
            local block = map:get(x, y)
            if block ~= nil and block.name == "BlockPart" then
                block = block:owner()
            end
            if block ~= nil and block.mana ~= nil and not seen[block] then
                seen[block] = true
                local d = boxDistance(px, py, block)
                if d <= MANA_NETWORK_REACH then
                    table.insert(found, {battery = block, distance = d})
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    local list = {}
    for i, f in ipairs(found) do
        list[i] = f.battery
    end
    return list
end


local function stillThere(battery)
    return map:get(battery.mx, battery.my) == battery
end


local function showBeam(battery, toPlayer)
    beams[battery] = {MANA_BEAM_LINGER, toPlayer}
end


local function deposit(amount)
    -- Puts mana into the batteries in reach, nearest first, what doesnt fit is lost
    for i, battery in ipairs(near) do
        if amount <= 0 then
            return
        end
        local take = math.min(MANA_BATTERY_CAPACITY - battery.mana, amount)
        if take > 0 and stillThere(battery) then
            battery.mana = battery.mana + take
            amount = amount - take
            showBeam(battery, false)
        end
    end
end


function ManaNetwork.update(dt)
    -- Finds the batteries around the player and moves the regen of a full player into them
    for battery, beam in pairs(beams) do
        beam[1] = beam[1] - dt
        if beam[1] <= 0 then
            beams[battery] = nil
        end
    end
    if player == nil or player:isDead() then
        near = {}
        return
    end
    near = findNear(player.body:getWorldCenter())
    local bar = player.manaBar
    if bar.currentMana >= bar.maxMana and bar.manaRegen > 0 then
        deposit(bar.manaRegen * dt)
    end
end


function ManaNetwork.inReach()
    -- The batteries in reach of the player, nearest first
    return near
end


local function feeding()
    -- The batteries that pay the player's spells, nearest first
    local list = {}
    for i, battery in ipairs(near) do
        if battery.feedPlayer and battery.mana > 0 and stillThere(battery) then
            table.insert(list, battery)
        end
    end
    return list
end


function ManaNetwork.available(caster)
    -- Mana a caster can spend: its own, and for the player the batteries feeding it
    local mana = caster.manaBar.currentMana
    if caster == player then
        for i, battery in ipairs(feeding()) do
            mana = mana + battery.mana
        end
    end
    return mana
end


function ManaNetwork.pay(caster, amount)
    -- Takes the mana of a cast, the player's from the batteries feeding it first(check available before)
    if caster == player then
        for i, battery in ipairs(feeding()) do
            local take = math.min(battery.mana, amount)
            battery.mana = battery.mana - take
            amount = amount - take
            showBeam(battery, true)
            if amount <= 0 then
                return
            end
        end
    end
    caster.manaBar.currentMana = caster.manaBar.currentMana - amount
end


function ManaNetwork.draw()
    -- World space, over the light: the beams between batteries and the player while mana moves
    if player == nil then
        return
    end
    local px, py = player.body:getWorldCenter()
    for battery, beam in pairs(beams) do
        if stillThere(battery) then
            local x, y, w = battery:box()
            local bx, by = x + w / 2, y + TILE_SIZE / 2
            if beam[2] then
                ManaShader.beam(bx, by, px, py, MANA_BEAM_WIDTH)
            else
                ManaShader.beam(px, py, bx, by, MANA_BEAM_WIDTH)
            end
        end
    end
end

return ManaNetwork
