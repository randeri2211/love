local Equipment = require "components.equipment"

-- Functions for equipment components(see components/equipment), the equipment itself is only data
local Equipments = {}


function Equipments.fits(slotName, stack)
    -- True when a stack can go in a slot, only armor made for that slot does
    if not stack then
        return false
    end
    local item = ITEM_REGISTRY[stack.item]
    return item ~= nil and item.armor ~= nil and item.armor.slot == slotName
end


function Equipments.defense(equipment)
    local total = 0
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        if stack then
            total = total + ITEM_REGISTRY[stack.item].armor.defense
        end
    end
    return total
end


function Equipments.stats(equipment)
    -- Stats every worn piece adds up to, by stat name
    local total = {}
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        if stack then
            for stat, amount in pairs(ITEM_REGISTRY[stack.item].armor.stats or {}) do
                total[stat] = (total[stat] or 0) + amount
            end
        end
    end
    return total
end


function Equipments.damageReduction(defense)
    -- Part of the damage defense blocks: more defense always helps, but it never blocks everything
    return defense / (defense + DEFENSE_SCALE)
end


function Equipments.toData(equipment)
    local data = {}
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        data[slot.name] = stack and {item = stack.item, count = 1} or false
    end
    return data
end


function Equipments.fromData(data)
    -- Pieces that dont exist anymore or dont fit their slot are left out
    local equipment = Equipment()
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = type(data) == "table" and data[slot.name]
        if type(stack) == "table" and Equipments.fits(slot.name, stack) then
            equipment[slot.name] = {item = stack.item, count = 1}
        end
    end
    return equipment
end

return Equipments
