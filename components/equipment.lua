local function Equipment()
    -- What a character wears, one item stack per armor slot or false when empty(see ARMOR_SLOTS)
    -- Changed through items/equipments, this is only the data
    local equipment = {}

    for i, slot in ipairs(ARMOR_SLOTS) do
        equipment[slot.name] = false
    end

    return equipment
end

return Equipment
