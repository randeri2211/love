local Rune = require "runes.rune"

local SizeRune = Rune:new("Size", "modifier", 3, 2, {1, 0.8, 0.2})
registerRune("Size", SizeRune)

-- A core pushed out to four corner brackets
SizeRune.glyph = {
    {"circle", 0, 0, 0.17},
    {"line", -0.75, -0.35, -0.75, -0.75, -0.35, -0.75},
    {"line", 0.35, -0.75, 0.75, -0.75, 0.75, -0.35},
    {"line", 0.75, 0.35, 0.75, 0.75, 0.35, 0.75},
    {"line", -0.35, 0.75, -0.75, 0.75, -0.75, 0.35},
}

SizeRune.effects = {
    -- Bigger projectile, a bit slower
    Bullet = function(params)
        params.radius = params.radius * 1.5
        params.speed = params.speed * 0.9
    end,
    -- Wider beam
    Laser = function(params)
        params.width = params.width * 1.5
    end,
    -- Bigger burst
    Area = function(params)
        params.areaRadius = params.areaRadius * 1.4
    end,
    -- Bigger trigger zone
    Trap = function(params)
        params.triggerRadius = params.triggerRadius * 1.4
    end,
}

return SizeRune
