local Inventories = require "items.inventories"
local Items = require "items.items"
local ManaNetwork = require "world_utils.manaNetwork"

-- Processing stations(see docs/game-design: Mana network, step 7): a station like the Forge works on its own over time,
-- turning what is in its input slot into its output slot by the processes registered for it(PROCESS_REGISTRY,
-- see registerProcess), while making things stays an instant list(see items/crafting)
-- Unpowered it burns fuel(wood) from its fuel slot while it works. With a mana network in reach that has mana it is
-- powered: it uses STATION_MANA a second instead of fuel, works STATION_POWERED_SPEED times faster, can do the
-- processes that need mana, and takes its inputs from the chests next to it and puts its outputs in them
-- A station keeps {input, fuel, output}(stacks or false), progress(seconds into the current item) and burn(seconds of
-- fuel left), its block update runs this(near the player or in a running chunk, see world_utils/simulation)
local Processing = {}


function Processing.forInput(station, name)
    -- The process a station does with an item, nil when it does nothing with it
    for i, process in ipairs(PROCESS_REGISTRY) do
        if process.station == station and process.input.item == name then
            return process
        end
    end
    return nil
end


function Processing.ofStation(station)
    -- Every process of a station, for its screen
    local list = {}
    for i, process in ipairs(PROCESS_REGISTRY) do
        if process.station == station then
            table.insert(list, process)
        end
    end
    return list
end


function Processing.fuel(name)
    -- Seconds of work an item burns for, nil when it doesnt burn
    local item = ITEM_REGISTRY[name]
    if item ~= nil and item.group == "Wood" then
        return WOOD_FUEL
    end
    return nil
end


local function outputRoom(station, process)
    -- True when the output slot can take what the process makes
    local out = station.output
    return not out or (out.item == process.output.item and out.count + process.output.count <= Items.maxStack(out.item))
end


local function neighborChests(station)
    -- The chests touching the station, beside, above or below
    local chests = {}
    for i, side in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
        local block = map:get(station.mx + side[1], station.my + side[2])
        if block ~= nil and block.chest and block.inventory ~= nil then
            table.insert(chests, block)
        end
    end
    return chests
end


local function useChests(station)
    -- A powered station empties its output into the chests next to it and fills its input from them
    local chests = neighborChests(station)
    local out = station.output
    for i, chest in ipairs(chests) do
        if out then
            out.count = Inventories.add(chest.inventory, out.item, out.count)
            if out.count <= 0 then
                out = false
            end
        end
    end
    station.output = out
    local input = station.input
    for i, chest in ipairs(chests) do
        for j, slot in ipairs(chest.inventory.slots) do
            if slot and Processing.forInput(station.name, slot.item) ~= nil and (not input or input.item == slot.item) then
                local room = Items.maxStack(slot.item) - (input and input.count or 0)
                local moved = math.min(room, slot.count)
                if moved > 0 then
                    Inventories.remove(chest.inventory, slot.item, moved)
                    input = input or {item = slot.item, count = 0}
                    input.count = input.count + moved
                end
            end
        end
    end
    station.input = input
end


function Processing.update(station, dt)
    -- One step of a station's work: power, chests, fuel and progress. Sets station.state for its screen and tooltip
    local cx, cy = station.x + station.width / 2, station.y + station.height / 2
    local node = ManaNetwork.nodeNear(cx, cy)
    local powered = node ~= nil and ManaNetwork.stored(node) > 0
    station.powered = powered
    if powered then
        station.chestTimer = (station.chestTimer or 0) - dt
        if station.chestTimer <= 0 then
            station.chestTimer = STATION_CHEST_INTERVAL
            useChests(station)
        end
    end

    local input = station.input
    local process = input and Processing.forInput(station.name, input.item)
    if not process then     -- An empty input slot is false, not nil
        station.progress, station.state = 0, input and "It does nothing with that" or "Idle"
        return
    end
    if input.count < process.input.count then
        station.progress, station.state = 0, string.format("Needs %d %s", process.input.count, Items.displayName(process.input.item))
        return
    end
    if not outputRoom(station, process) then
        station.state = "Output full"
        return
    end
    if process.needsMana and not powered then
        station.progress, station.state = 0, "Needs a mana network"
        return
    end

    -- Paid for: mana when powered, else fuel(a new piece is burned when the last one is out)
    if powered and ManaNetwork.drain(node, STATION_MANA * dt) then
        station.state = "Working (powered)"
    else
        powered = false
        if station.burn <= 0 then
            local fuel = station.fuel
            local seconds = fuel and Processing.fuel(fuel.item)
            if not seconds then     -- An empty fuel slot is false, not nil
                station.state = "Needs fuel"
                return
            end
            fuel.count = fuel.count - 1
            station.fuel = fuel.count > 0 and fuel or false
            station.burn = seconds
        end
        station.burn = station.burn - dt
        station.state = "Working"
    end

    station.progress = station.progress + dt * (powered and STATION_POWERED_SPEED or 1)
    -- (a hair under counts: adding up frame times lands just short, a piece of fuel would then miss its last item)
    if station.progress >= process.time - 1e-6 then
        station.progress = station.progress - process.time     -- The overshoot carries on, or a piece of fuel falls short
        input.count = input.count - process.input.count
        station.input = input.count > 0 and input or false
        local out = station.output
        if out then
            out.count = out.count + process.output.count
        else
            station.output = {item = process.output.item, count = process.output.count}
        end
        if powered then
            ManaNetwork.flow(node, cx, cy)
        end
    end
end

return Processing
