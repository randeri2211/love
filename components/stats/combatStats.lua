local function combatStats(entity)
    -- Strength - Gives extra contact damage for now(maybe melee weapons if it suits the genre)
    -- Intelligence - Gives bonus magic damage and small max mana bonus
    -- Wisdom - Gives bonus max mana and slight cooldown reduction
    -- Concentration - Gives bonus mana regen and slight cooldown reduction
    -- Swiftness - Gives movement speed and jump height
    -- Constitution - Gives max hp

    local combatStats = {}
    combatStats.cooldownReduction = 0


    -- Strength
    local strengthContactModifier = 1
    combatStats.contactDamage = entity.stats.strength * strengthContactModifier

    -- Intelligence
    local intelligenceMagicDamageModifier = 0.05
    combatStats.magicDamage = 1 + intelligenceMagicDamageModifier * entity.stats.intelligence

    -- Wisdom
    local wisdomMaxManaModifier = 1
    local percent = entity.manaBar.currentMana / entity.manaBar.maxMana
    entity.manaBar.maxMana = BASE_MANA + wisdomMaxManaModifier * entity.stats.wisdom
    entity.manaBar.currentMana = percent * entity.manaBar.maxMana

    local wisdomCooldownReductionModifier = 0.01
    combatStats.cooldownReduction = combatStats.cooldownReduction + wisdomCooldownReductionModifier * entity.stats.wisdom

    -- Concentration
    local concentrationManaRegenModifier = 1
    entity.manaBar.manaRegen = BASE_MANA_REGEN + concentrationManaRegenModifier * entity.stats.concentration

    local concentrationCooldownReductionModifier = 0.01
    combatStats.cooldownReduction = combatStats.cooldownReduction + concentrationCooldownReductionModifier * entity.stats.concentration
    
    -- Swiftness
    local swiftnessMovespeedModifier = TILE_SIZE * 0.1
    entity.movement.maxSpeed = BASE_MOVE_SPEED + swiftnessMovespeedModifier * entity.stats.swiftness
    
    local swiftnessJumpHeightModifier = TILE_SIZE * 0.1
    entity.movement.jumpHeight = BASE_JUMP_HEIGHT + swiftnessJumpHeightModifier * entity.stats.swiftness

    -- Constitution
    local constitutionMaxHPModifier = 1
    local percent = entity.hpBar.currentHP / entity.hpBar.maxHP
    entity.hpBar.maxHP = BASE_HP + constitutionMaxHPModifier * entity.stats.constitution
    entity.manaBar.currentMana = percent * entity.hpBar.maxHP

    -- Clamp values
    combatStats.cooldownReduction = math.min(combatStats.cooldownReduction, MAX_COOLDOWN_REDUCTION)
    entity.movement.maxSpeed = math.max(entity.movement.maxSpeed, 0)

    return combatStats
end

return combatStats