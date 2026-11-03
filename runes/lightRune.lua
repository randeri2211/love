local Rune = require "runes.rune"

local LightRune = Rune:new("Light", "modifier", 1, 1, {1, 0.95, 0.7})
registerRune("Light", LightRune)

-- A sun: a core with four rays
LightRune.glyph = {
    {"circle", 0, 0, 0.32},
    {"line", 0, -0.55, 0, -0.9},
    {"line", 0.55, 0, 0.9, 0},
    {"line", 0, 0.55, 0, 0.9},
    {"line", -0.55, 0, -0.9, 0},
}

-- Cheap and on every form: the spell becomes a real light source in its color(see Form:light), every Light rune
-- reaches further. A Trap with Light is a magic torch while it lasts, Self with Light makes its target glow
LightRune.effects = {
    default = function(params)
        params.glow = params.glow + 1
    end,
}

return LightRune
