local Rune = require "runes.rune"
local Bullet = require "forms.bullet"

local BulletRune = Rune:new("Bullet", "form", 5, 5, {0.9, 0.9, 0.9})
registerRune("Bullet", BulletRune)

BulletRune.form = Bullet

-- A shot with motion lines(shapes in a -1 to 1 box, see MagicCircle.drawGlyph)
BulletRune.glyph = {
    {"circle", 0.3, 0, 0.28},
    {"line", -0.85, -0.3, -0.2, -0.3},
    {"line", -0.95, 0, -0.1, 0},
    {"line", -0.85, 0.3, -0.2, 0.3},
}

-- Shown in the spell editor
BulletRune.stats = {
    {"Speed", "speed", "%.0f"},
    {"Size", "radius", "%.1f"},
    {"Gravity", "gravityScale", "%.1f"},
    {"Bounces", "bounces", "%d"},
    {"Pierce", "pierce", "%d"},
}

function BulletRune:defaults()
    -- Starting values before any modifiers are applied
    -- damage, lifetime, count and spread come from BASE_SPELL_PARAMS
    return {
        speed = 10 * TILE_SIZE * TILES_PER_METER,
        radius = 10,
        gravityScale = 0,           -- Gravity rune makes it fall
        bounces = 0,                -- Rebound rune makes it bounce
        pierce = 0,                 -- Enemies and blocks it passes through before it stops, Pierce rune raises it
        imagePath = "GRASS",
    }
end

-- Marks: an arrow aims the shot(bursts and piercing are the Repeat and Pierce runes)
BulletRune:useAimMarks()

return BulletRune
