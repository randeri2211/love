local Rune = require "runes.rune"
local Trap = require "forms.trap"

local TrapRune = Rune:new("Trap", "form", 5, 6, {0.75, 0.55, 0.3})
registerRune("Trap", TrapRune)

TrapRune.form = Trap

-- A diamond with jaws inside
TrapRune.glyph = {
    {"polygon", 0, -0.85, 0.85, 0, 0, 0.85, -0.85, 0},
    {"line", -0.45, 0, -0.22, -0.22, 0, 0, 0.22, -0.22, 0.45, 0},
}

-- Shown in the spell editor
TrapRune.stats = {
    {"Trigger radius", "triggerRadius", "%.0f"},
    {"Arm time", "armTime", "%.2fs"},
    {"Throw speed", "throwSpeed", "%.0f"},
}

function TrapRune:defaults()
    -- Waits on the ground for an enemy, count comes from BASE_SPELL_PARAMS
    return {
        damage = 25,
        triggerRadius = TILE_SIZE,
        armTime = 0.6,          -- Seconds before it can go off
        lifetime = 15,          -- onExpire if nothing walks into it
        throwSpeed = 5 * TILE_SIZE,
        spread = math.rad(60),  -- Split throws a small minefield
    }
end

return TrapRune
