

function ManaBar(currentMana, maxMana, manaRegen)
    local manaBar = {}

    manaBar.currentMana = currentMana
    manaBar.maxMana = maxMana
    manaBar.manaRegen = manaRegen

    return manaBar
end