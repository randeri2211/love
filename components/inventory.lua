local function Inventory(size)
    -- Slots of items, each is {item = name, count = n} or false for an empty slot(false keeps ipairs going)
    -- Changed through items/inventories, this is only the data
    local inventory = {}

    inventory.size = size or INVENTORY_SIZE
    inventory.locked = {}       -- Slot indexes the player locked, storing to chests leaves them where they are
    inventory.slots = {}
    for i = 1, inventory.size do
        inventory.slots[i] = false
    end

    return inventory
end

return Inventory
