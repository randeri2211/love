
local function ManaBar(currentMana, maxMana, manaRegen)
    local manaBar = {}

    manaBar.currentMana = currentMana
    manaBar.maxMana = maxMana
    manaBar.manaRegen = manaRegen

    -- Base values, stats are applied on top of these
    manaBar.baseMaxMana = manaBar.maxMana
    manaBar.baseManaRegen = manaBar.manaRegen

    return manaBar
end

return ManaBar