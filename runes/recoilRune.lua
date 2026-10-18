local Rune = require "runes.rune"

local RecoilRune = Rune:new("Recoil", "modifier", 2, 1, {0.95, 0.65, 0.85})
registerRune("Recoil", RecoilRune)

-- An arrow pushed back off a wall
RecoilRune.glyph = {
    {"line", 0.6, -0.65, 0.6, 0.65},
    {"line", 0.3, 0, -0.85, 0},
    {"line", -0.5, -0.38, -0.85, 0, -0.5, 0.38},
}

RecoilRune.effects = {
    -- Pushes the caster away from the aim, the first rune turns it on and every other rune doubles it
    -- Every form has recoil, so this works on all of them
    default = function(params)
        if params.recoil == 0 then
            params.recoil = 1
        else
            params.recoil = params.recoil * 2
        end
    end,
}

return RecoilRune
