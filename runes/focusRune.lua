local Rune = require "runes.rune"

local FocusRune = Rune:new("Focus", "modifier", 4, 3, {1, 1, 0.6})
registerRune("Focus", FocusRune)

-- Lines converging
FocusRune.glyph = {
    {"line", -0.85, -0.6, 0.38, 0},
    {"line", -0.85, 0.6, 0.38, 0},
    {"line", -0.85, 0, 0.38, 0},
    {"dot", 0.6, 0, 0.14},
}

-- Concentrates the spell, smaller and stronger(no Trap entry, so traps cant use it)
-- Slot order matters, Focus before Split still sees a single bullet
FocusRune.effects = {
    Bullet = function(params)
        if params.count > 1 then
            params.spread = params.spread * 0.5     -- Tighter fan
        else
            params.damage = params.damage * 1.4
            params.radius = params.radius * 0.7
        end
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
