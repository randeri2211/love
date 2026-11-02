local Rune = require "runes.rune"

local RecoilRune = Rune:new("Recoil", "modifier", 2, 1, {0.95, 0.65, 0.85})
registerRune("Recoil", RecoilRune)

-- An arrow pushed back off a wall
RecoilRune.glyph = {
    {"line", 0.6, -0.65, 0.6, 0.65},
    {"line", 0.3, 0, -0.85, 0},
    {"line", -0.5, -0.38, -0.85, 0, -0.5, 0.38},
}

local LASER_RECOIL = 0.45      -- Held lasers fire many times a second, so each beam pushes this much of a normal recoil

local function strengthen(params, first)
    -- The first rune turns recoil on, every other rune doubles it
    if params.recoil == 0 then
        params.recoil = first
    else
        params.recoil = params.recoil * 2
    end
end

RecoilRune.effects = {
    -- Pushes the caster away from the aim, every form has recoil so this works on all of them
    default = function(params)
        strengthen(params, 1)
    end,
    -- Held down it is a jet: about as strong as gravity, so it hovers, and rises once Weaken makes it fire faster
    Laser = function(params)
        strengthen(params, LASER_RECOIL)
    end,
}

return RecoilRune
