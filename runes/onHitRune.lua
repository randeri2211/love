local Rune = require "runes.rune"

local OnHitRune = Rune:new("OnHit", "trigger", 4, TRIGGER_CHAIN_COST.onHit, {1, 0.5, 0})
registerRune("OnHit", OnHitRune)

-- Casts the child spell where the spell hits something
OnHitRune.event = "onHit"

-- Impact starburst, long and short rays
OnHitRune.glyph = {
    {"dot", 0, 0, 0.14},
    {"line", 0.3, 0, 0.88, 0},
    {"line", 0.21, 0.21, 0.39, 0.39},
    {"line", 0, 0.3, 0, 0.88},
    {"line", -0.21, 0.21, -0.39, 0.39},
    {"line", -0.3, 0, -0.88, 0},
    {"line", -0.21, -0.21, -0.39, -0.39},
    {"line", 0, -0.3, 0, -0.88},
    {"line", 0.21, -0.21, 0.39, -0.39},
}

return OnHitRune
