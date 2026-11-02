local Rune = require "runes.rune"

local RepelRune = Rune:new("Repel", "modifier", 3, 2, {0.95, 0.5, 0.2})
registerRune("Repel", RepelRune)

-- Waves of force hitting a target
RepelRune.glyph = {
    {"circle", 0.5, 0, 0.28},
    {"arc", -0.3, 0, 0.5, -1.0, 1.0},
    {"arc", -0.75, 0, 0.5, -1.0, 1.0},
}

RepelRune.effects = {
    -- Hits shove harder, the way the spell was going(see Form:hit), every form hits so this works on all of them
    default = function(params)
        params.knockback = params.knockback * 2
    end,
}

return RepelRune
