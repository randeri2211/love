local ManaShader = require "world_utils.manaShader"

-- The mana network(see docs/game-design: Mana network)
-- Nodes are blocks with manaNode(batteries and conduits), two nodes link when their edges are within MANA_NETWORK_REACH tiles,
-- and nodes linked to each other, directly or through others, are one network
-- The player joins a network through the nearest node in their reach, the batteries of that network are one buffer:
-- - while the player's mana is full, what they regenerate goes into the nearest battery with room instead of being lost
-- - batteries with "Feed the player" on pay the player's spells first(see available and pay), the pool pays the rest
-- Beams of the mana effect show the links(the fewest that join every node, not every pair in reach),
-- and the link to the player while mana moves through it
-- The map keeps every node and never unloads their chunks(see Map:trackNode), so a network works however big it is,
-- it is linked again only when a node is added or removed
local ManaNetwork = {}

local nodes = {}        -- Every node in the map
local networkOf = {}    -- Node -> the node that stands for its network(kept here, not on the blocks, so saving never sees it)
local links = {}        -- Pairs of nodes the beams join, {a, b}
local scanned = nil     -- What the links were made for: {map, version}
local batteries = {}    -- Batteries in the player's network, nearest to the player first
local attached = nil    -- The node the player is joined through, nil when none is in reach
local playerBeam = nil  -- {time left, true when the mana flows to the player}
local flows = {}        -- Short beams from a node to a point where mana was just used: {node, x, y, time left}


local function boxDistance(px, py, node)
    -- Tiles from a love point to the nearest edge of a node
    local x, y, w, h = node:box()
    local dx = math.max(x - px, 0, px - (x + w))
    local dy = math.max(y - py, 0, py - (y + h))
    return math.sqrt(dx * dx + dy * dy) / TILE_SIZE
end


local function nodeDistance(a, b)
    -- Tiles between the nearest edges of two nodes
    local ax, ay, aw, ah = a:box()
    local bx, by, bw, bh = b:box()
    local dx = math.max(ax - (bx + bw), 0, bx - (ax + aw))
    local dy = math.max(ay - (by + bh), 0, by - (ay + ah))
    return math.sqrt(dx * dx + dy * dy) / TILE_SIZE
end


local function stillThere(node)
    return map:get(node.mx, node.my) == node
end


local function link()
    -- Links every node of the map: every pair in reach is linked, a node's network is everything it links to(union find),
    -- and the beams are the shortest links that join each network(Kruskal)
    nodes, networkOf = {}, {}
    for block in pairs(map.manaNodes) do
        table.insert(nodes, block)
        networkOf[block] = block        -- Every node starts as its own network
    end

    local function find(node)
        while networkOf[node] ~= node do
            networkOf[node] = networkOf[networkOf[node]]
            node = networkOf[node]
        end
        return node
    end
    local candidates = {}
    for i = 1, #nodes do
        for j = i + 1, #nodes do
            local d = nodeDistance(nodes[i], nodes[j])
            if d <= MANA_NETWORK_REACH then
                table.insert(candidates, {nodes[i], nodes[j], d})
            end
        end
    end
    table.sort(candidates, function(a, b) return a[3] < b[3] end)
    links = {}
    for i, pair in ipairs(candidates) do
        local ra, rb = find(pair[1]), find(pair[2])
        if ra ~= rb then
            networkOf[rb] = ra
            table.insert(links, pair)
        end
    end
    for i, node in ipairs(nodes) do
        networkOf[node] = find(node)
    end
end


local function join(px, py)
    -- The player's network: the nearest node in reach and the batteries of its network, nearest first
    attached = nil
    local best = math.huge
    for i, node in ipairs(nodes) do
        local d = boxDistance(px, py, node)
        if d <= MANA_NETWORK_REACH and d < best and stillThere(node) then
            attached, best = node, d
        end
    end
    batteries = {}
    if attached == nil then
        return
    end
    local found = {}
    for i, node in ipairs(nodes) do
        if networkOf[node] == networkOf[attached] and node.mana ~= nil and stillThere(node) then
            table.insert(found, {battery = node, distance = boxDistance(px, py, node)})
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    for i, f in ipairs(found) do
        batteries[i] = f.battery
    end
end


local function showBeam(toPlayer)
    playerBeam = {MANA_BEAM_LINGER, toPlayer}
end


local function deposit(amount)
    -- Puts mana into the batteries of the player's network, nearest first, what doesnt fit is lost
    for i, battery in ipairs(batteries) do
        if amount <= 0 then
            return
        end
        local take = math.min(MANA_BATTERY_CAPACITY - battery.mana, amount)
        if take > 0 then
            battery.mana = battery.mana + take
            amount = amount - take
            showBeam(false)
        end
    end
end


function ManaNetwork.update(dt)
    -- Finds the network around the player and moves the regen of a full player into it
    if playerBeam ~= nil then
        playerBeam[1] = playerBeam[1] - dt
        if playerBeam[1] <= 0 then
            playerBeam = nil
        end
    end
    for i = #flows, 1, -1 do
        flows[i][4] = flows[i][4] - dt
        if flows[i][4] <= 0 then
            table.remove(flows, i)
        end
    end
    -- Linked first, machines use their network wherever the player is(see drain)
    if scanned == nil or scanned.map ~= map or scanned.version ~= map.nodesVersion then
        link()
        scanned = {map = map, version = map.nodesVersion}
    end
    if player == nil or player:isDead() then
        attached, batteries = nil, {}
        return
    end
    local px, py = player.body:getWorldCenter()
    join(px, py)
    local bar = player.manaBar
    if bar.currentMana >= bar.maxMana and bar.manaRegen > 0 then
        deposit(bar.manaRegen * dt)
    end
end


function ManaNetwork.batteriesOf(node)
    -- The batteries in a node's network, nearest to the node first
    local found = {}
    local x, y, w, h = node:box()
    local cx, cy = x + w / 2, y + h / 2
    for i, other in ipairs(nodes) do
        if other.mana ~= nil and networkOf[other] ~= nil and networkOf[other] == networkOf[node] and stillThere(other) then
            table.insert(found, {battery = other, distance = boxDistance(cx, cy, other)})
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    local list = {}
    for i, f in ipairs(found) do
        list[i] = f.battery
    end
    return list
end


function ManaNetwork.stored(node)
    -- All the mana in a node's network
    local total = 0
    for i, battery in ipairs(ManaNetwork.batteriesOf(node)) do
        total = total + battery.mana
    end
    return total
end


function ManaNetwork.take(node, amount)
    -- Takes up to amount from a node's network, nearest battery first, and returns what it got
    local got = 0
    for i, battery in ipairs(ManaNetwork.batteriesOf(node)) do
        local take = math.min(battery.mana, amount - got)
        battery.mana = battery.mana - take
        got = got + take
        if got >= amount then
            break
        end
    end
    return got
end


function ManaNetwork.drain(node, amount)
    -- A machine takes mana from its network: all or nothing, true when the network had it all and paid it
    if ManaNetwork.stored(node) < amount then
        return false
    end
    ManaNetwork.take(node, amount)
    return true
end


function ManaNetwork.nodeNear(x, y)
    -- The nearest node whose edge is within reach of a love point, nil when none is
    local best, bestDistance = nil, math.huge
    for i, node in ipairs(nodes) do
        local d = boxDistance(x, y, node)
        if d <= MANA_NETWORK_REACH and d < bestDistance and stillThere(node) then
            best, bestDistance = node, d
        end
    end
    return best
end


function ManaNetwork.flow(node, x, y)
    -- Shows a short beam from a node to a love point, where its mana was just used
    table.insert(flows, {node, x, y, MANA_BEAM_LINGER})
end


function ManaNetwork.inReach()
    -- The batteries in the player's network, nearest first
    return batteries
end


local function feeding()
    -- The batteries that pay the player's spells, nearest first
    local list = {}
    for i, battery in ipairs(batteries) do
        if battery.feedPlayer and battery.mana > 0 and stillThere(battery) then
            table.insert(list, battery)
        end
    end
    return list
end


local function turretNode(caster)
    -- The node a Spell Turret's casts are paid through(see blocks/spellTurret), nil when none is in its reach
    return ManaNetwork.nodeNear(caster.turret:center())
end


function ManaNetwork.available(caster)
    -- Mana a caster can spend: its own, and for the player the batteries feeding it, a turret has its network's
    if caster.turret ~= nil then
        local node = turretNode(caster)
        return node and ManaNetwork.stored(node) or 0
    end
    local mana = caster.manaBar.currentMana
    if caster == player then
        for i, battery in ipairs(feeding()) do
            mana = mana + battery.mana
        end
    end
    return mana
end


function ManaNetwork.pay(caster, amount)
    -- Takes the mana of a cast, the player's from the batteries feeding it first(check available before),
    -- a turret's from its network with a short beam to it
    if caster.turret ~= nil then
        local node = turretNode(caster)
        if node ~= nil then
            ManaNetwork.take(node, amount)
            ManaNetwork.flow(node, caster.turret:center())
        end
        return
    end
    if caster == player then
        for i, battery in ipairs(feeding()) do
            local take = math.min(battery.mana, amount)
            battery.mana = battery.mana - take
            amount = amount - take
            showBeam(true)
            if amount <= 0 then
                return
            end
        end
    end
    caster.manaBar.currentMana = caster.manaBar.currentMana - amount
end


function ManaNetwork.draw()
    -- World space, over the light: the links between nodes, and the link to the player while mana moves through it
    for i, link in ipairs(links) do
        if stillThere(link[1]) and stillThere(link[2]) then
            local ax, ay = link[1]:beamPoint()
            local bx, by = link[2]:beamPoint()
            ManaShader.beam(ax, ay, bx, by, MANA_LINK_WIDTH)
        end
    end
    for i, flow in ipairs(flows) do
        if stillThere(flow[1]) then
            local nx, ny = flow[1]:beamPoint()
            ManaShader.beam(nx, ny, flow[2], flow[3], MANA_LINK_WIDTH)
        end
    end
    if playerBeam ~= nil and attached ~= nil and stillThere(attached) and player ~= nil then
        local px, py = player.body:getWorldCenter()
        local nx, ny = attached:beamPoint()
        if playerBeam[2] then
            ManaShader.beam(nx, ny, px, py, MANA_BEAM_WIDTH)
        else
            ManaShader.beam(px, py, nx, ny, MANA_BEAM_WIDTH)
        end
    end
end

return ManaNetwork
