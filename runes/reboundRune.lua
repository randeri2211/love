local Rune = require "runes.rune"

local ReboundRune = Rune:new("Rebound", "modifier", 4, 3, {0.4, 1, 1})
registerRune("Rebound", ReboundRune)

-- A path bouncing off walls
ReboundRune.glyph = {
    {"line", -0.85, 0.35, -0.45, -0.4, -0.05, 0.35, 0.35, -0.4, 0.7, 0.2},
    {"line", -0.9, -0.62, 0.9, -0.62},
    {"line", -0.9, 0.62, 0.9, 0.62},
}

local function moreBounces(bounces)
    -- The first rune gives 2 bounces, every other rune doubles them
    if bounces == 0 then
        return 2
    end
    return bounces * 2
end

-- Only forms that travel can bounce, so no Area or Trap entry
ReboundRune.effects = {
    Bullet = function(params)
        params.bounces = moreBounces(params.bounces)
    end,
    Laser = function(params)
        params.bounces = moreBounces(params.bounces)
    end,
}

return ReboundRune
