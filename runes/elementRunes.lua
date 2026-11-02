local Rune = require "runes.rune"
local Elements = require "magic.elements"

-- Element runes(see magic/elements): one modifier per element, at most one of each in a circle
-- They work on every form that hits something, not on Self(the caster would set itself on fire)
-- Their settings are power and duration multipliers, runes before them in the flow change those(see Damage, Size, Weaken)

-- Name, cost and color of each, glyphs drawn as a picture of the element
local RUNES = {
    {
        name = "Fire", complexity = 4, mana = 3, color = {1, 0.45, 0.15},
        -- A flame with three tongues and a small flame inside
        glyph = {
            {"line", 0, -0.9, 0.2, -0.45, 0.45, -0.62, 0.52, -0.1, 0.4, 0.5, 0, 0.78, -0.4, 0.5, -0.52, -0.1, -0.45, -0.62, -0.2, -0.45, 0, -0.9},
            {"line", 0, -0.15, 0.16, 0.25, 0, 0.5, -0.16, 0.25, 0, -0.15},
        },
    },
    {
        name = "Frost", complexity = 4, mana = 3, color = {0.55, 0.85, 1},
        -- A snowflake: three crossed lines, the vertical one with ticks at both ends
        glyph = {
            {"line", 0, -0.85, 0, 0.85},
            {"line", -0.74, -0.42, 0.74, 0.42},
            {"line", -0.74, 0.42, 0.74, -0.42},
            {"line", -0.2, -0.75, 0, -0.55, 0.2, -0.75},
            {"line", -0.2, 0.75, 0, 0.55, 0.2, 0.75},
        },
    },
    {
        name = "Poison", complexity = 4, mana = 3, color = {0.45, 0.9, 0.25},
        -- A flask: stopper, narrow neck opening to a wide bottom, the liquid line across it
        glyph = {
            {"line", -0.15, -0.85, 0.15, -0.85},
            {"line", -0.12, -0.85, -0.12, -0.35, -0.6, 0.6, 0.6, 0.6, 0.12, -0.35, 0.12, -0.85},
            {"line", -0.38, 0.15, 0.38, 0.15},
        },
    },
    {
        name = "Lightning", complexity = 4, mana = 3, color = {1, 0.92, 0.4},
        -- A bolt with its arrow tip at the bottom
        glyph = {
            {"line", 0.3, -0.9, -0.3, 0.0, 0.25, 0.0, -0.3, 0.9},
            {"line", -0.5, 0.55, -0.3, 0.9, 0.0, 0.7},
        },
    },
}

for i, info in ipairs(RUNES) do
    local rune = Rune:new(info.name, "modifier", info.complexity, info.mana, info.color)
    rune.element = info.name    -- Marks it as an element: once per circle, other runes can change it through affects.element
    rune.glyph = info.glyph

    function rune:settings(marks)
        return {power = 1, duration = 1}
    end

    rune.effects = {
        default = function(params, settings)
            Elements.apply(info.name, params, settings)
        end,
        Self = false,
    }
    registerRune(info.name, rune)
end
