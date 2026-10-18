local Rune = require "runes.rune"
local Laser = require "forms.laser"

local LaserRune = Rune:new("Laser", "form", 6, 6, {1, 0.35, 0.7})
registerRune("Laser", LaserRune)

LaserRune.form = Laser

-- A source dot and a long beam
LaserRune.glyph = {
    {"dot", -0.7, 0, 0.18},
    {"line", -0.5, 0, 0.92, 0},
    {"line", -0.3, -0.22, 0.75, -0.22},
    {"line", -0.3, 0.22, 0.75, 0.22},
}

-- Shown in the spell editor
LaserRune.stats = {
    {"Reach", "reach", "%.0f"},
    {"Width", "width", "%.1f"},
    {"Bounces", "bounces", "%d"},
    {"Bend", "bend", "%.1f"},
}

function LaserRune:defaults()
    -- Damage over time beam: weak, cheap casts fired quickly while the cast key is held
    return {
        damage = 2,
        reach = 14 * TILE_SIZE,
        width = 4,
        bounces = 0,            -- Rebound rune reflects it
        bend = 0,               -- Gravity rune curves it down
        lifetime = 0.08,        -- How long each beam stays visible, short so rapid casts blend together
        manaScale = 0.1,        -- 10% of the normal mana cost per cast
        cooldownScale = 0.25,   -- Casts 4 times as often
    }
end

return LaserRune
