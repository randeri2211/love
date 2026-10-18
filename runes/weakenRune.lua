local Rune = require "runes.rune"

local WeakenRune = Rune:new("Weaken", "modifier", 1, 0, {0.6, 0.6, 0.68})
registerRune("Weaken", WeakenRune)

-- Two chevrons pointing down
WeakenRune.glyph = {
    {"line", -0.55, -0.5, 0, -0.05, 0.55, -0.5},
    {"line", -0.55, 0.05, 0, 0.5, 0.55, 0.05},
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
