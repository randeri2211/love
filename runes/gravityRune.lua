local Rune = require "runes.rune"

local GravityRune = Rune:new("Gravity", "modifier", 1, 1, {0.55, 0.55, 1})
registerRune("Gravity", GravityRune)

-- Weight falling onto the ground
GravityRune.glyph = {
    {"line", 0, -0.85, 0, 0.35},
    {"line", -0.32, 0.05, 0, 0.37, 0.32, 0.05},
    {"line", -0.72, 0.68, 0.72, 0.68},
}

local function strengthen(value)
    -- The first rune switches it on, every other rune doubles it
    if value == 0 then
        return 1
    end
    return value * 2
end

local function discount(params)
    -- The spell stops resisting gravity, so it is cheaper to hold together
    params.complexityScale = params.complexityScale * 0.85
    params.manaScale = params.manaScale * 0.85
end

-- No Trap entry, traps already sit on the ground
GravityRune.effects = {
    Bullet = function(params)
        params.gravityScale = strengthen(params.gravityScale)   -- Falls in an arc
        discount(params)
    end,
    Laser = function(params)
        params.bend = strengthen(params.bend)                   -- Beam curves down
        discount(params)
    end,
    Area = function(params)
        -- Gravity well that pulls enemies in, and lasts longer to do it
        params.pull = strengthen(params.pull)
        params.lifetime = params.lifetime * 3
        discount(params)
    end,
}

return GravityRune
