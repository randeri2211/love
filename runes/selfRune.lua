local Rune = require "runes.rune"
local Self = require "forms.self"

local SelfRune = Rune:new("Self", "form", 4, 4, {1, 0.9, 0.55})
registerRune("Self", SelfRune)
SelfRune.lore = "Magic turned inward, the caster becomes the page."    -- A line of lore, the grimoire shows it

SelfRune.form = Self

-- A figure inside a ring of light
SelfRune.glyph = {
    {"circle", 0, -0.42, 0.2},
    {"line", 0, -0.2, 0, 0.35},
    {"line", -0.32, 0.05, 0.32, 0.05},
    {"line", 0, 0.35, -0.25, 0.75, 0.25, 0.75, 0, 0.35},
    {"arc", 0, 0, 0.92, -2.5, -0.64},
}

-- It deals no damage(Damage runes heal instead, shown as Heal), the editor leaves that line out
SelfRune.hiddenStats = {damage = true}

-- Shown in the spell editor
SelfRune.stats = {
    {"Duration", "lifetime", "%.1fs"},
    {"Heal", "heal", "%.0f"},
    {"Haste", "haste", "x%.2f"},
    {"Gravity", "lightness", "x%.2f"},
    {"Dash", "dash", "%.1f"},
}

function SelfRune:defaults()
    -- On its own it does nothing, the modifiers give it heal, haste, lightness and a dash
    return {
        damage = 0,
        knockback = 0,
        lifetime = 3,
        heal = 0,               -- Damage runes turn it into healing
        haste = 1,              -- Speed runes
        lightness = 1,          -- Gravity runes
        dash = 0,               -- Recoil runes dash toward the aim
    }
end

return SelfRune
