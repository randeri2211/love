local Rune = require "runes.rune"
local Bullet = require "forms.bullet"

local BulletRune = Rune:new("Bullet", "form", 5, 5, {0.9, 0.9, 0.9})
registerRune("Bullet", BulletRune)

BulletRune.form = Bullet

-- A shot with motion lines(shapes in a -1 to 1 box, see MagicCircle.drawGlyph)
BulletRune.glyph = {
    {"dot", 0.3, 0, 0.28},
    {"line", -0.85, -0.3, -0.2, -0.3},
    {"line", -0.95, 0, -0.1, 0},
    {"line", -0.85, 0.3, -0.2, 0.3},
}

function BulletRune:defaults()
    -- Starting values before any modifiers are applied
    return {
        damage = 10,
        speed = 10 * TILE_SIZE * TILES_PER_METER,
        radius = 10,
        lifetime = 2,
        count = 1,                  -- Amount of projectiles per cast
        spread = math.rad(30),      -- Fan angle used when count > 1
        imagePath = "GRASS",
    }
end

return BulletRune
