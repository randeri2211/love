
function HPBar(currentHP, maxHP, regen)
    local hpBar = {}

    hpBar.currentHP = currentHP
    hpBar.maxHP = maxHP
    hpBar.regen = regen

    return hpBar
end