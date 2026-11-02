local Equipment = require "components.equipment"
local Items = require "items.items"
local Tools = require "items.tools"

-- Functions for equipment components(see components/equipment), the equipment itself is only data
local Equipments = {}


function Equipments.fits(slotName, stack, equipment)
    -- True when a stack can go in a slot, or false and why not
    -- Armor only goes in its own slot, the main hand takes a wand or a staff, the off hand a wand next to a wand
    -- A staff takes both hands, so it needs the off hand empty
    if not stack then
        return false
    end
    local item = ITEM_REGISTRY[stack.item]
    if item == nil then
        return false
    end
    if slotName == "mainHand" or slotName == "offHand" then
        if item.tool == nil or not Tools.isValid(stack) then
            return false, "Only wands and staves go in the hands"
        end
        local other = equipment and equipment[slotName == "mainHand" and "offHand" or "mainHand"]
        if slotName == "mainHand" and item.tool == "Staff" and other then
            return false, "A staff takes both hands, empty the off hand first"
        end
        if slotName == "offHand" then
            if item.tool ~= "Wand" then
                return false, "Only a wand goes in the off hand"
            end
            if other and ITEM_REGISTRY[other.item].tool == "Staff" then
                return false, "The staff takes both hands"
            end
        end
        return true
    end
    return item.armor ~= nil and item.armor.slot == slotName
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
    -- Tools keep their parts
    for i, slot in ipairs(HAND_SLOTS) do
        local stack = equipment[slot.name]
        data[slot.name] = stack and Items.copy(stack, 1) or false
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
    -- The main hand first, the off hand checks it(a wand cant sit next to a staff)
    for i, slot in ipairs(HAND_SLOTS) do
        local stack = type(data) == "table" and data[slot.name]
        if type(stack) == "table" and Equipments.fits(slot.name, stack, equipment) then
            equipment[slot.name] = Items.copy(stack, 1)
        end
    end
    return equipment
end

return Equipments
