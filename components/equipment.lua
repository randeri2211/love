local function Equipment()
    -- What a character wears and holds, one item stack per armor and hand slot or false when empty(see ARMOR_SLOTS, HAND_SLOTS)
    -- Changed through items/equipments, this is only the data
    local equipment = {}

    for i, slot in ipairs(ARMOR_SLOTS) do
        equipment[slot.name] = false
    end
    for i, slot in ipairs(HAND_SLOTS) do
        equipment[slot.name] = false
    end
    for i, slot in ipairs(ACCESSORY_SLOTS) do
        equipment[slot.name] = false
    end

    return equipment
end

return Equipment
