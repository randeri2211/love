local DEFAULT_STATS = 0
local function Stats(strength, intelligence, wisdom, concentration, swiftness, constitution)
    -- Strength - Gives extra contact damage for now(maybe melee weapons if it suits the genre)
    -- Intelligence - Gives bonus magic damage and small max mana bonus
    -- Wisdom - Gives bonus max mana and slight cooldown reduction
    -- Concentration - Gives bonus mana regen and slight cooldown reduction
    -- Swiftness - Gives movement speed and jump height
    -- Constitution - Gives max hp
    local stats = {}

    stats.strength = strength or DEFAULT_STATS
    stats.intelligence = intelligence or DEFAULT_STATS
    stats.wisdom = wisdom or DEFAULT_STATS
    stats.concentration = concentration or DEFAULT_STATS
    stats.swiftness = swiftness or DEFAULT_STATS
    stats.constitution = constitution or DEFAULT_STATS

    return stats
end

return Stats