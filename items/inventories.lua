local Items = require "items.items"
local Inventory = require "components.inventory"
local Tools = require "items.tools"

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


function Inventories.addStack(inventory, stack)
    -- Puts a whole stack in, returns how many didnt fit
    -- A stack with data(a wand) keeps it and goes in an empty slot of its own, others top up stacks like add
    if stack.data == nil then
        return Inventories.add(inventory, stack.item, stack.count)
    end
    for i, slot in ipairs(inventory.slots) do
        if not slot then
            inventory.slots[i] = Items.copy(stack)
            return 0
        end
    end
    return stack.count
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


function Inventories.isEmpty(inventory)
    for i, slot in ipairs(inventory.slots) do
        if slot then
            return false
        end
    end
    return true
end


-- Moving between inventories(a chest and the player), what doesnt fit stays where it was
function Inventories.moveSlot(from, index, to)
    -- The stack in a slot of from goes into to, returns true when any of it moved
    local slot = from.slots[index]
    if not slot then
        return false
    end
    local left = Inventories.addStack(to, slot)
    if left == slot.count then
        return false
    end
    if left > 0 then
        slot.count = left
    else
        from.slots[index] = false
    end
    return true
end


function Inventories.storeAll(from, to, matchingOnly, skip)
    -- Every slot of from into to, skip(index) leaves a slot out(the hotbar, locked slots)
    -- matchingOnly only moves items to already has, so a sorted chest stays sorted, returns how many stacks moved
    local moved = 0
    for i = 1, #from.slots do
        local slot = from.slots[i]
        if slot and not (skip ~= nil and skip(i)) and (not matchingOnly or Inventories.count(to, slot.item) > 0) then
            if Inventories.moveSlot(from, i, to) then
                moved = moved + 1
            end
        end
    end
    return moved
end


function Inventories.toData(inventory)
    local slots, locked = {}, {}
    for i, slot in ipairs(inventory.slots) do
        slots[i] = slot and Items.copy(slot) or false
    end
    for index in pairs(inventory.locked or {}) do
        table.insert(locked, index)
    end
    return {size = inventory.size, slots = slots, locked = locked}
end


function Inventories.fromData(data, size)
    -- Items that dont exist anymore are dropped, counts are kept inside the stack size
    -- size is how many slots it has(a chest), the player inventory by default
    local inventory = Inventory(size or INVENTORY_SIZE)
    for i, index in ipairs(type(data) == "table" and type(data.locked) == "table" and data.locked or {}) do
        if type(index) == "number" and index >= 1 and index <= inventory.size then
            inventory.locked[index] = true
        end
    end
    for i, slot in ipairs(type(data) == "table" and data.slots or {}) do
        if i > inventory.size then
            break
        end
        if type(slot) == "table" and ITEM_REGISTRY[slot.item] ~= nil and type(slot.count) == "number" then
            local count = math.max(1, math.min(Items.maxStack(slot.item), math.floor(slot.count)))
            -- Tools whose parts dont exist anymore are dropped too
            if ITEM_REGISTRY[slot.item].tool == nil or Tools.isValid(slot) then
                inventory.slots[i] = Items.copy(slot, count)
            end
        end
    end
    return inventory
end

return Inventories
