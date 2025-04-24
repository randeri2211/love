local function HPBar(currentHP, maxHP, regen)
    local hpBar = {}

    hpBar.currentHP = currentHP or 1
    hpBar.maxHP = maxHP or 1
    hpBar.regen = regen or 0

    return hpBar
end

return HPBar