local Rune = require "runes.rune"

local SpeedRune = Rune:new("Speed", "modifier", 3, 1, {0.3, 0.6, 1})
registerRune("Speed", SpeedRune)
SpeedRune.lore = "Two chevrons, both impatient."    -- A line of lore, the grimoire shows it

-- Double chevron pointing forward
SpeedRune.glyph = {
    {"line", -0.65, -0.55, -0.15, 0, -0.65, 0.55},
    {"line", -0.05, -0.55, 0.45, 0, -0.05, 0.55},
}

SpeedRune.effects = {
    -- Faster projectile
    Bullet = function(params)
        params.speed = params.speed * 1.5
    end,
    -- A beam is already instant, so it reaches further
    Laser = function(params)
        params.reach = params.reach * 1.5
    end,
    -- Haste, the caster walks faster while it lasts
    Self = function(params)
        params.haste = params.haste * 1.4
    end,
    -- No Area or Trap entry, they dont travel
}

return SpeedRune
