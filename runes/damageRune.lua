local Rune = require "runes.rune"

local DamageRune = Rune:new("Damage", "modifier", 4, 3, {1, 0.2, 0.2})
registerRune("Damage", DamageRune)

-- A blade, sharp diamond plus a crossguard
DamageRune.glyph = {
    {"polygon", 0, -0.9, 0.28, 0, 0, 0.9, -0.28, 0},
    {"line", -0.62, 0, 0.62, 0},
}

-- Every element after it in the flow hits harder: hotter burns, more slow, stronger poison and jumps
DamageRune.affects = {
    element = function(settings, strength)
        settings.power = settings.power * 1.5 ^ strength
    end,
}

DamageRune.effects = {
    -- More damage, every form has damage so this works on all of them
    default = function(params)
        params.damage = params.damage * 1.5
    end,
    -- On the caster it heals, the first rune heals SELF_HEAL over the spell and every other rune heals more
    Self = function(params)
        if params.heal == 0 then
            params.heal = SELF_HEAL
        else
            params.heal = params.heal * 1.5
        end
    end,
}

return DamageRune
