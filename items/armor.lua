-- Armor items: one icon shape per slot(assets/items.png) tinted by the material
-- armor.slot is the equipment slot it goes in, defense lowers damage taken, stats add to the wearer stats,
-- resist adds element resistances({Fire = 5}, see Equipments.resistances)
local MATERIALS = {
    -- name, tint, defense per slot, stats per slot
    {
        name = "Copper", tint = {0.95, 0.6, 0.35, 1},
        head = {defense = 1, stats = {constitution = 2}},
        chest = {defense = 3, stats = {constitution = 4}},
        legs = {defense = 2, stats = {constitution = 2}},
        feet = {defense = 1, stats = {swiftness = 2}},
    },
    {
        name = "Iron", tint = {0.8, 0.8, 0.86, 1},
        head = {defense = 2, stats = {constitution = 4}},
        chest = {defense = 6, stats = {constitution = 8}},
        legs = {defense = 4, stats = {constitution = 4}},
        feet = {defense = 2, stats = {swiftness = 3}},
    },
}

-- The icon and display word of each slot
local PIECES = {
    head = {icon = "helmet", word = "Helmet"},
    chest = {icon = "chestplate", word = "Chestplate"},
    legs = {icon = "leggings", word = "Leggings"},
    feet = {icon = "boots", word = "Boots"},
}

for i, material in ipairs(MATERIALS) do
    for slot, piece in pairs(PIECES) do
        local values = material[slot]
        registerItem(material.name .. piece.word, {
            displayName = material.name .. " " .. piece.word,
            maxStack = 1,
            icon = piece.icon,      -- In ITEM_TILES(assets/items.png)
            tint = material.tint,
            armor = {slot = slot, defense = values.defense, stats = values.stats, resist = values.resist},
        })
    end
end
