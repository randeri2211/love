local Rune = require "runes.rune"

local SlowRune = Rune:new("Slow", "modifier", 1, 0, {0.45, 0.7, 0.55})
registerRune("Slow", SlowRune)

-- A snail shell spiral
SlowRune.glyph = {
    {"arc", 0, 0, 0.22, 0, 3.14},
    {"arc", 0.11, 0, 0.44, 3.14, 6.28},
    {"arc", -0.11, 0, 0.66, 0, 3.14},
}

local function discount(params)
    -- A slower spell is cheaper and simpler
    params.complexityScale = params.complexityScale * 0.8
    params.manaScale = params.manaScale * 0.8
end

-- The opposite of Speed, so it works on the same forms
SlowRune.effects = {
    Bullet = function(params)
        params.speed = params.speed * 0.6
        discount(params)
    end,
    Laser = function(params)
        params.reach = params.reach * 0.6
        discount(params)
    end,
}

return SlowRune
