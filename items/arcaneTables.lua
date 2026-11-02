local Items = require "items.items"
local Tools = require "items.tools"

-- What the arcane table does(see blocks/arcaneTable): wands and staves are put together and taken apart here
-- Its data is {kind = "Wand" or "Staff", inputs = {part stacks or false}}, the output is always worked out from the inputs:
-- filled inputs show the tool, taking it uses them up, putting a tool in the output lays its parts out in the inputs
local ArcaneTables = {}


function ArcaneTables.new()
    return {kind = "Wand", inputs = {false, false, false, false}}
end


function ArcaneTables.isEmpty(station)
    for i, stack in ipairs(station.inputs) do
        if stack then
            return false
        end
    end
    return true
end


function ArcaneTables.output(station)
    -- The tool the inputs make, nil until every slot holds the right part
    local names = {}
    for i = 1, #Tools.LAYOUTS[station.kind] do
        names[i] = station.inputs[i] and station.inputs[i].item
    end
    return Tools.build(station.kind, names)
end


function ArcaneTables.setKind(station, kind)
    -- Switches between wand and staff, only while the slots are empty(the parts dont fit the other layout)
    if not ArcaneTables.isEmpty(station) then
        return false, "Take the parts out first"
    end
    station.kind = kind
    return true
end


function ArcaneTables.clickInput(station, index, held)
    -- A click on input slot index with held in the hand(nil for empty), returns the new held stack and a hint
    local slot = station.inputs[index]
    if held == nil then
        -- Taking a part out, the tool in the output goes with it
        station.inputs[index] = false
        return slot or nil
    end
    if not Tools.fits(station.kind, index, held.item) then
        return held, "That part doesnt go there"
    end
    if not slot then
        -- One part goes in, the rest stays in the hand
        station.inputs[index] = Items.copy(held, 1)
        held.count = held.count - 1
        return held.count > 0 and held or nil
    end
    if held.count == 1 then
        station.inputs[index] = held
        return slot
    end
    return held, "Hold one part to swap it"
end


function ArcaneTables.clickOutput(station, held)
    -- A click on the output: an empty hand takes the tool(using up the parts),
    -- a tool in the hand is taken apart into the empty slots
    if held == nil then
        local tool = ArcaneTables.output(station)
        if tool == nil then
            return nil
        end
        for i = 1, #station.inputs do
            station.inputs[i] = false
        end
        return tool
    end
    local item = ITEM_REGISTRY[held.item]
    if item == nil or item.tool == nil then
        return held, "Only a wand or a staff goes there"
    end
    if not ArcaneTables.isEmpty(station) then
        return held, "Empty the slots to take it apart"
    end
    station.kind = item.tool
    for i, name in ipairs(held.data.parts) do
        station.inputs[i] = {item = name, count = 1}
    end
    return nil
end


function ArcaneTables.dropAll(station, x, y)
    -- Everything in the slots falls out at love x, y(the table was broken)
    for i, stack in ipairs(station.inputs) do
        if stack then
            map.drops:spawn(stack.item, stack.count, x, y, true, nil, stack.data)
            station.inputs[i] = false
        end
    end
end


function ArcaneTables.fromData(data)
    -- A saved table, parts that dont exist anymore are left out
    local station = ArcaneTables.new()
    if type(data) ~= "table" then
        return station
    end
    if Tools.LAYOUTS[data.kind] ~= nil then
        station.kind = data.kind
    end
    for i = 1, #station.inputs do
        local stack = type(data.inputs) == "table" and data.inputs[i]
        if type(stack) == "table" and ITEM_REGISTRY[stack.item] ~= nil then
            station.inputs[i] = {item = stack.item, count = 1}
        end
    end
    return station
end

return ArcaneTables
