local Equipments = require "items.equipments"
local Tools = require "items.tools"
local Statuses = require "magic.statuses"

local function clampValue(value, low, high)
    return math.max(low, math.min(high, value))
end

local function combatStats(entity)
    -- Strength - Makes worn armor sturdier(more defense from it)
    -- Intelligence - Gives bonus magic damage and small max mana bonus
    -- Wisdom - Gives bonus max mana and slight cooldown reduction
    -- Concentration - Gives bonus mana regen and slight cooldown reduction
    -- Swiftness - Gives movement speed and jump height
    -- Constitution - Gives max hp and a little hp regen

    local combatStats = {}
    combatStats.cooldownReduction = 0

    -- The stats it works with: its own plus what its worn armor adds
    local stats = {}
    local bonus = entity.equipment and Equipments.stats(entity.equipment) or {}
    for stat, value in pairs(entity.stats) do
        stats[stat] = value + (bonus[stat] or 0)
    end
    combatStats.stats = stats
    combatStats.statBonus = bonus

    -- Armor defense blocks part of every hit(see Entity:damage), Strength makes the worn armor give more of it
    local armorDefense = entity.equipment and Equipments.defense(entity.equipment) or 0
    combatStats.defense = armorDefense * math.max(0, 1 + STRENGTH_ARMOR * stats.strength)
    combatStats.damageReduction = Equipments.damageReduction(combatStats.defense)

    -- Element resistances: its own(entity.resistances) plus its armor, each blocks its element like defense blocks the rest
    combatStats.resistances = {}
    combatStats.resistReduction = {}
    local worn = entity.equipment and Equipments.resistances(entity.equipment) or {}
    for i, element in ipairs({"Fire", "Frost", "Poison", "Lightning"}) do
        local value = (entity.resistances and entity.resistances[element] or 0) + (worn[element] or 0)
        combatStats.resistances[element] = value
        combatStats.resistReduction[element] = Equipments.damageReduction(value)
    end

    -- Critical hits, gear can add to them later(the tanning table sets)
    combatStats.critChance = BASE_CRIT_CHANCE + (bonus.critChance or 0)
    combatStats.critMultiplier = CRIT_MULTIPLIER + (bonus.critDamage or 0)

    -- The wand or staff in the hands: the dig cap and what it does to every spell(see items/tools, Spell:shoot)
    combatStats.tool = Tools.effect(entity.equipment)
    combatStats.digCap = combatStats.tool.digCap

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


    -- Intelligence
    local intelligenceMagicDamageModifier = 0.05
    combatStats.magicDamage = 1 + intelligenceMagicDamageModifier * stats.intelligence

    local intelligenceComplexityModifier = 2
    combatStats.maxComplexity = BASE_MAX_COMPLEXITY + intelligenceComplexityModifier * stats.intelligence + combatStats.tool.complexity

    -- Wisdom
    local wisdomMaxManaModifier = 1
    entity.manaBar.maxMana = entity.manaBar.baseMaxMana + wisdomMaxManaModifier * stats.wisdom

    local wisdomCooldownReductionModifier = 0.01
    combatStats.cooldownReduction = combatStats.cooldownReduction + wisdomCooldownReductionModifier * stats.wisdom

    -- Concentration
    local concentrationManaRegenModifier = 1
    entity.manaBar.manaRegen = entity.manaBar.baseManaRegen + concentrationManaRegenModifier * stats.concentration
        + combatStats.tool.manaRegen    -- Wands help keep up with fast casting

    -- Cast speed, how fast cast circles build(see magic/playerCasting), gear can add to it later
    combatStats.castSpeed = math.max(MIN_CAST_SPEED, 1 + CONCENTRATION_CAST_SPEED * stats.concentration + (bonus.castSpeed or 0))

    local concentrationCooldownReductionModifier = 0.01
    combatStats.cooldownReduction = combatStats.cooldownReduction + concentrationCooldownReductionModifier * stats.concentration

    -- Swiftness
    local swiftnessMovespeedModifier = TILE_SIZE * 0.1
    entity.movement.maxSpeed = entity.movement.baseMaxSpeed + swiftnessMovespeedModifier * stats.swiftness

    local swiftnessJumpHeightModifier = TILE_SIZE * 0.1
    entity.movement.jumpHeight = entity.movement.baseJumpHeight + swiftnessJumpHeightModifier * stats.swiftness

    -- Constitution
    local constitutionMaxHPModifier = 1
    entity.hpBar.maxHP = entity.hpBar.baseMaxHP + constitutionMaxHPModifier * stats.constitution
    entity.hpBar.regen = entity.hpBar.baseRegen + CONSTITUTION_HP_REGEN * stats.constitution

    -- Clamp values(negative stats can only lower values down to these minimums)
    combatStats.cooldownReduction = clampValue(combatStats.cooldownReduction, MIN_COOLDOWN_REDUCTION, MAX_COOLDOWN_REDUCTION)
    combatStats.maxComplexity = math.max(combatStats.maxComplexity, MIN_MAX_COMPLEXITY)
    entity.hpBar.regen = math.max(entity.hpBar.regen, 0)
    entity.manaBar.manaRegen = math.max(entity.manaBar.manaRegen, 0)
    entity.hpBar.maxHP = math.max(entity.hpBar.maxHP, 1)
    entity.manaBar.maxMana = math.max(entity.manaBar.maxMana, 1)
    entity.movement.maxSpeed = math.max(entity.movement.maxSpeed, entity.movement.baseMaxSpeed / 10)
    entity.movement.jumpHeight = math.max(entity.movement.jumpHeight, entity.movement.baseJumpHeight / 10)

    -- What every spell gets multiplied by, the stats and the wand or staff together
    -- Spells(Spell:getDamage, getCooldown, getManaCost) and the character screen both read these
    combatStats.spellDamage = combatStats.magicDamage * combatStats.tool.damage
    combatStats.spellCooldown = (1 - combatStats.cooldownReduction) * combatStats.tool.cooldown
    combatStats.spellManaCost = combatStats.tool.manaCost

    -- Buffs from Self spells on it go on top of the stats(a Self effect marks the stats dirty when it starts and ends)
    entity.movement.maxSpeed = entity.movement.maxSpeed * entity:selfBuff("haste") * Statuses.speedFactor(entity)    -- Frost slows
    combatStats.gravityScale = entity:selfBuff("lightness")    -- Below 1 jumps higher and falls slower

    -- Apply the remembered percentages to the new max values
    entity.hpBar.currentHP = hpPercent * entity.hpBar.maxHP
    entity.manaBar.currentMana = manaPercent * entity.manaBar.maxMana

    return combatStats
end

return combatStats