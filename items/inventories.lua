local Items = require "items.items"
local Inventory = require "components.inventory"

-- Functions for inventory components(see components/inventory), the inventory itself is only data
local Inventories = {}


function Inventories.add(inventory, name, count)
    -- Puts items in, topping up stacks of the same item first, then empty slots
    -- Returns how many didnt fit
    local max = Items.maxStack(name)
    for i, slot in ipairs(inventory.slots) do
        if count <= 0 then
            break
        end
        if slot and slot.item == name and slot.count < max then
            local moved = math.min(count, max - slot.count)
            slot.count = slot.count + moved
            count = count - moved
        end
    end
    for i, slot in ipairs(inventory.slots) do
        if count <= 0 then
            break
        end
        if not slot then
            local moved = math.min(count, max)
            inventory.slots[i] = {item = name, count = moved}
            count = count - moved
        end
    end
    return count
end


function Inventories.canAdd(inventory, name)
    -- True when at least one more of the item fits
    local max = Items.maxStack(name)
    for i, slot in ipairs(inventory.slots) do
        if not slot or (slot.item == name and slot.count < max) then
            return true
        end
    end
    return false
end


function Inventories.count(inventory, name)
    local total = 0
    for i, slot in ipairs(inventory.slots) do
        if slot and slot.item == name then
            total = total + slot.count
        end
    end
    return total
end


function Inventories.remove(inventory, name, count)
    -- Takes items out, from the last stacks first, returns how many were taken
    local taken = 0
    for i = #inventory.slots, 1, -1 do
        local slot = inventory.slots[i]
        if taken >= count then
            break
        end
        if slot and slot.item == name then
            local moved = math.min(count - taken, slot.count)
            slot.count = slot.count - moved
            taken = taken + moved
            if slot.count <= 0 then
                inventory.slots[i] = false
            end
        end
    end
    return taken
end


function Inventories.toData(inventory)
    local slots = {}
    for i, slot in ipairs(inventory.slots) do
        slots[i] = slot and {item = slot.item, count = slot.count} or false
    end
    return {size = inventory.size, slots = slots}
end


function Inventories.fromData(data)
    -- Items that dont exist anymore are dropped, counts are kept inside the stack size
    local inventory = Inventory(INVENTORY_SIZE)
    for i, slot in ipairs(type(data) == "table" and data.slots or {}) do
        if i > inventory.size then
            break
        end
        if type(slot) == "table" and ITEM_REGISTRY[slot.item] ~= nil and type(slot.count) == "number" then
            local count = math.max(1, math.min(Items.maxStack(slot.item), math.floor(slot.count)))
            inventory.slots[i] = {item = slot.item, count = count}
        end
    end
    return inventory
end

return Inventories
