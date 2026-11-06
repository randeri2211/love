local Equipment = require "components.equipment"
local Items = require "items.items"
local Tools = require "items.tools"
local Sets = require "items.sets"

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
    -- Trinkets in the trinket slots, two different ones, a focus in the focus slot
    if slotName == "trinket1" or slotName == "trinket2" then
        if not item.trinket then
            return false, "Only trinkets go there"
        end
        local other = equipment and equipment[slotName == "trinket1" and "trinket2" or "trinket1"]
        if other and other.item == stack.item then
            return false, "You already wear that trinket"
        end
        return true
    end
    if slotName == "focus" then
        if not item.focus then
            return false, "Only a focus goes there"
        end
        return true
    end
    return item.armor ~= nil and item.armor.slot == slotName
end


function Equipments.effects(equipment)
    -- Every effect worn: the trinkets, the focus and the set bonuses turned on(see items/sets for the format)
    local list = {}
    for i, slot in ipairs(ACCESSORY_SLOTS) do
        local stack = equipment[slot.name]
        local item = stack and ITEM_REGISTRY[stack.item]
        if item and item.effect ~= nil then      -- An empty slot is false, not nil
            table.insert(list, item.effect)
        end
    end
    for i, bonus in ipairs(Sets.active(equipment)) do
        table.insert(list, bonus.effect)
    end
    return list
end


function Equipments.defense(equipment)
    local total = 0
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        if stack then
            total = total + ITEM_REGISTRY[stack.item].armor.defense
        end
    end
    for i, effect in ipairs(Equipments.effects(equipment)) do
        total = total + (effect.defense or 0)
    end
    return total
end


function Equipments.stats(equipment)
    -- Stats every worn piece adds up to, by stat name, and what the effects add(castSpeed, critChance, critDamage)
    local total = {}
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        if stack then
            for stat, amount in pairs(ITEM_REGISTRY[stack.item].armor.stats or {}) do
                total[stat] = (total[stat] or 0) + amount
            end
        end
    end
    for i, effect in ipairs(Equipments.effects(equipment)) do
        for stat, amount in pairs(effect.stats or {}) do
            total[stat] = (total[stat] or 0) + amount
        end
        for j, key in ipairs({"castSpeed", "critChance", "critDamage"}) do
            if effect[key] ~= nil then
                total[key] = (total[key] or 0) + effect[key]
            end
        end
    end
    return total
end


function Equipments.casting(equipment)
    -- What the effects do to casting: mana cost and cooldown multipliers, complexity and mana regen added,
    -- and every spell modifier(see Spell:shoot)
    local casting = {manaCost = 1, cooldown = 1, complexity = 0, manaRegen = 0, spells = {}}
    for i, effect in ipairs(Equipments.effects(equipment)) do
        casting.manaCost = casting.manaCost * (effect.manaCost or 1)
        casting.cooldown = casting.cooldown * (effect.cooldown or 1)
        casting.complexity = casting.complexity + (effect.complexity or 0)
        casting.manaRegen = casting.manaRegen + (effect.manaRegen or 0)
        for j, mod in ipairs(effect.spells or {}) do
            table.insert(casting.spells, mod)
        end
    end
    return casting
end


function Equipments.damageReduction(defense)
    -- Part of the damage defense blocks: more defense always helps, but it never blocks everything
    -- Resistances use the same curve, below 0 it is a weakness and the damage grows the same way
    if defense < 0 then
        return -(-defense / (-defense + DEFENSE_SCALE))
    end
    return defense / (defense + DEFENSE_SCALE)
end


function Equipments.resistances(equipment)
    -- Element resistances every worn piece adds up to, by element name(armor.resist)
    local total = {}
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        if stack then
            for element, amount in pairs(ITEM_REGISTRY[stack.item].armor.resist or {}) do
                total[element] = (total[element] or 0) + amount
            end
        end
    end
    for i, effect in ipairs(Equipments.effects(equipment)) do
        for element, amount in pairs(effect.resist or {}) do
            total[element] = (total[element] or 0) + amount
        end
    end
    return total
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
    for i, slot in ipairs(ACCESSORY_SLOTS) do
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
    -- The main hand first, the off hand checks it(a wand cant sit next to a staff)
    for i, slot in ipairs(HAND_SLOTS) do
        local stack = type(data) == "table" and data[slot.name]
        if type(stack) == "table" and Equipments.fits(slot.name, stack, equipment) then
            equipment[slot.name] = Items.copy(stack, 1)
        end
    end
    for i, slot in ipairs(ACCESSORY_SLOTS) do
        local stack = type(data) == "table" and data[slot.name]
        if type(stack) == "table" and Equipments.fits(slot.name, stack, equipment) then
            equipment[slot.name] = {item = stack.item, count = 1}
        end
    end
    return equipment
end

return Equipments
