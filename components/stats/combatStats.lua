local function clampValue(value, low, high)
    return math.max(low, math.min(high, value))
end

local function combatStats(entity)
    -- Strength - Gives extra contact damage for now(maybe melee weapons if it suits the genre)
    -- Intelligence - Gives bonus magic damage and small max mana bonus
    -- Wisdom - Gives bonus max mana and slight cooldown reduction
    -- Concentration - Gives bonus mana regen and slight cooldown reduction
    -- Swiftness - Gives movement speed and jump height
    -- Constitution - Gives max hp

    local combatStats = {}
    combatStats.cooldownReduction = 0

    -- Fallback for saves made before base values existed
    entity.hpBar.baseMaxHP = entity.hpBar.baseMaxHP or BASE_HP
    entity.hpBar.baseRegen = entity.hpBar.baseRegen or entity.hpBar.regen
    entity.manaBar.baseMaxMana = entity.manaBar.baseMaxMana or BASE_MANA
    entity.manaBar.baseManaRegen = entity.manaBar.baseManaRegen or BASE_MANA_REGEN
    entity.movement.baseMaxSpeed = entity.movement.baseMaxSpeed or BASE_MOVE_SPEED
    entity.movement.baseJumpHeight = entity.movement.baseJumpHeight or BASE_JUMP_HEIGHT

    -- Remember hp and mana percentages so changing the max keeps the same ratio
    local hpPercent = entity.hpBar.currentHP / entity.hpBar.maxHP
    local manaPercent = entity.manaBar.currentMana / entity.manaBar.maxMana


    -- Strength
    local strengthContactModifier = 1
    combatStats.contactDamage = entity.stats.strength * strengthContactModifier

    -- Intelligence
    local intelligenceMagicDamageModifier = 0.05
    combatStats.magicDamage = 1 + intelligenceMagicDamageModifier * entity.stats.intelligence

    local intelligenceComplexityModifier = 2
    combatStats.maxComplexity = BASE_MAX_COMPLEXITY + intelligenceComplexityModifier * entity.stats.intelligence

    -- Wisdom
    local wisdomMaxManaModifier = 1
    entity.manaBar.maxMana = entity.manaBar.baseMaxMana + wisdomMaxManaModifier * entity.stats.wisdom

    local wisdomCooldownReductionModifier = 0.01
    combatStats.cooldownReduction = combatStats.cooldownReduction + wisdomCooldownReductionModifier * entity.stats.wisdom

    -- Concentration
    local concentrationManaRegenModifier = 1
    entity.manaBar.manaRegen = entity.manaBar.baseManaRegen + concentrationManaRegenModifier * entity.stats.concentration

    local concentrationCooldownReductionModifier = 0.01
    combatStats.cooldownReduction = combatStats.cooldownReduction + concentrationCooldownReductionModifier * entity.stats.concentration

    -- Swiftness
    local swiftnessMovespeedModifier = TILE_SIZE * 0.1
    entity.movement.maxSpeed = entity.movement.baseMaxSpeed + swiftnessMovespeedModifier * entity.stats.swiftness

    local swiftnessJumpHeightModifier = TILE_SIZE * 0.1
    entity.movement.jumpHeight = entity.movement.baseJumpHeight + swiftnessJumpHeightModifier * entity.stats.swiftness

    -- Constitution
    local constitutionMaxHPModifier = 1
    entity.hpBar.maxHP = entity.hpBar.baseMaxHP + constitutionMaxHPModifier * entity.stats.constitution

    -- Clamp values(negative stats can only lower values down to these minimums)
    combatStats.cooldownReduction = clampValue(combatStats.cooldownReduction, MIN_COOLDOWN_REDUCTION, MAX_COOLDOWN_REDUCTION)
    combatStats.maxComplexity = math.max(combatStats.maxComplexity, MIN_MAX_COMPLEXITY)
    entity.hpBar.regen = math.max(entity.hpBar.regen, 0)
    entity.manaBar.manaRegen = math.max(entity.manaBar.manaRegen, 0)
    entity.hpBar.maxHP = math.max(entity.hpBar.maxHP, 1)
    entity.manaBar.maxMana = math.max(entity.manaBar.maxMana, 1)
    entity.movement.maxSpeed = math.max(entity.movement.maxSpeed, entity.movement.baseMaxSpeed / 10)
    entity.movement.jumpHeight = math.max(entity.movement.jumpHeight, entity.movement.baseJumpHeight / 10)

    -- Apply the remembered percentages to the new max values
    entity.hpBar.currentHP = hpPercent * entity.hpBar.maxHP
    entity.manaBar.currentMana = manaPercent * entity.manaBar.maxMana

    return combatStats
end

return combatStats