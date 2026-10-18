local Rune = require "runes.rune"

local SplitRune = Rune:new("Split", "modifier", 8, 5, {0.6, 1, 0.4})
registerRune("Split", SplitRune)

-- One path forking into two
SplitRune.glyph = {
    {"line", -0.8, 0, -0.05, 0},
    {"line", -0.05, 0, 0.6, -0.55},
    {"line", -0.05, 0, 0.6, 0.55},
    {"dot", 0.6, -0.55, 0.13},
    {"dot", 0.6, 0.55, 0.13},
}

SplitRune.effects = {
    -- Double the projectiles, each one weaker
    Bullet = function(params)
        params.count = params.count * 2
        params.damage = params.damage * 0.6
    end,
}

return SplitRune
