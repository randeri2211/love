local Rune = require "runes.rune"
local Area = require "forms.area"

local AreaRune = Rune:new("Area", "form", 6, 7, {0.3, 0.9, 0.8})
registerRune("Area", AreaRune)

AreaRune.form = Area

-- Rings spreading out from a point
AreaRune.glyph = {
    {"circle", 0, 0, 0.16},
    {"arc", 0, 0, 0.48, -2.6, -0.55},
    {"arc", 0, 0, 0.48, 0.55, 2.6},
    {"arc", 0, 0, 0.82, -2.3, -0.85},
    {"arc", 0, 0, 0.82, 0.85, 2.3},
}

-- Shown in the spell editor
AreaRune.stats = {
    {"Radius", "areaRadius", "%.0f"},
    {"Grow time", "expandTime", "%.2fs"},
    {"Pull", "pull", "%.1f"},
}

function AreaRune:defaults()
    -- Burst in front of the cast point, count comes from BASE_SPELL_PARAMS
    return {
        damage = 20,
        areaRadius = 1.5 * TILE_SIZE,
        expandTime = 0.25,      -- Seconds to grow to full size
        lifetime = 0.5,
        pull = 0,               -- Gravity rune turns it into a gravity well
        spread = math.rad(90),  -- Split copies spread wide like a cluster bomb
    }
end

return AreaRune
