local Rune = require "runes.rune"

local WeakenRune = Rune:new("Weaken", "modifier", 1, 0, {0.6, 0.6, 0.68})
registerRune("Weaken", WeakenRune)

-- A minus in a circle, less power(it used to be two chevrons, too close to Speed when drawn)
WeakenRune.glyph = {
    {"circle", 0, 0, 0.7},
    {"line", -0.42, 0, 0.42, 0},
}

WeakenRune.effects = {
    -- Weaker spell that is cheaper and simpler, every form has damage so this works on all of them
    default = function(params)
        params.damage = params.damage * 0.6
        params.complexityScale = params.complexityScale * 0.8
        params.manaScale = params.manaScale * 0.8
    end,
}

return WeakenRune
