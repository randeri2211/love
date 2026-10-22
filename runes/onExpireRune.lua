local Rune = require "runes.rune"

local OnExpireRune = Rune:new("OnExpire", "trigger", 3, TRIGGER_CHAIN_COST.onExpire, {0.6, 0.3, 1})
registerRune("OnExpire", OnExpireRune)

-- Casts the child spell where the spell runs out of lifetime
OnExpireRune.event = "onExpire"

-- Hourglass with the sand run out
OnExpireRune.glyph = {
    {"line", -0.5, -0.75, 0.5, -0.75},
    {"line", -0.5, 0.75, 0.5, 0.75},
    {"line", -0.42, -0.75, 0.42, 0.75},
    {"line", 0.42, -0.75, -0.42, 0.75},
    {"polygon", -0.3, 0.75, 0.3, 0.75, 0, 0.42},
}

return OnExpireRune
