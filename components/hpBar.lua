local function HPBar(currentHP, maxHP, regen)
    local hpBar = {}

    hpBar.currentHP = currentHP or 1
    hpBar.maxHP = maxHP or 1
    hpBar.regen = regen or 0

    -- Base values, stats are applied on top of these
    hpBar.baseMaxHP = hpBar.maxHP
    hpBar.baseRegen = hpBar.regen

    return hpBar
end

return HPBar