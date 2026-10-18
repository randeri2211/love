local Rune = require "runes.rune"

local DamageRune = Rune:new("Damage", "modifier", 4, 3, {1, 0.2, 0.2})
registerRune("Damage", DamageRune)

-- A blade, sharp diamond plus a crossguard
DamageRune.glyph = {
    {"polygon", 0, -0.9, 0.28, 0, 0, 0.9, -0.28, 0},
    {"line", -0.62, 0, 0.62, 0},
}

DamageRune.effects = {
    -- More damage, every form has damage so this works on all of them
    default = function(params)
        params.damage = params.damage * 1.5
    end,
}

return DamageRune
