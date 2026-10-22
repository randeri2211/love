local Rune = require "runes.rune"

local FocusRune = Rune:new("Focus", "modifier", 4, 3, {1, 1, 0.6})
registerRune("Focus", FocusRune)

-- Lines converging
FocusRune.glyph = {
    {"line", -0.85, -0.6, 0.38, 0},
    {"line", -0.85, 0.6, 0.38, 0},
    {"line", -0.85, 0, 0.38, 0},
    {"circle", 0.6, 0, 0.14},
}

-- Narrows the fan of every Split after it in the flow, a well drawn Focus narrows more
FocusRune.affects = {
    Split = function(settings, strength)
        settings.spreadScale = settings.spreadScale * 0.5 ^ strength
    end,
}

-- Concentrates the spell too, smaller and stronger(no Trap entry, so traps cant use it)
FocusRune.effects = {
    Bullet = function(params)
        params.damage = params.damage * 1.4
        params.radius = params.radius * 0.7
    end,
    Laser = function(params)
        params.width = params.width * 0.6
        params.damage = params.damage * 1.4
    end,
    Area = function(params)
        params.areaRadius = params.areaRadius * 0.7
        params.damage = params.damage * 1.4
    end,
}

return FocusRune
