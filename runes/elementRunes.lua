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
        -- Marks only Frost reads so far(freeze dots and shatter cracks, see below)
        return {power = 1, duration = 1, freeze = marks and marks.freeze or 0, shatter = marks and marks.shatter or 0}
    end

    rune.effects = {
        default = function(params, settings)
            Elements.apply(info.name, params, settings)
        end,
        Self = false,
    }
    registerRune(info.name, rune)
end


-- Frost marks: dots freeze deeper for less time(three dots freeze solid), zigzag cracks freeze shorter and shatter harder
-- (see the Frost entry in magic/elements for the numbers)
local Frost = RUNE_REGISTRY.Frost
local MIN_MARK_QUALITY = 0.25       -- Marks drawn worse than this dont count
local MAX_FREEZE = 3
local MAX_SHATTER = 3
local MARK_COMPLEXITY = 1           -- Per mark

function Frost:readMarks(marks)
    local freeze, shatter = 0, 0
    for i, mark in ipairs(marks) do
        if mark.quality >= MIN_MARK_QUALITY then
            if mark.kind == "dot" then
                freeze = freeze + 1
            elseif mark.kind == "crack" then
                shatter = shatter + 1
            end
        end
    end
    if freeze == 0 and shatter == 0 then
        return nil
    end
    return {freeze = math.min(MAX_FREEZE, freeze), shatter = math.min(MAX_SHATTER, shatter)}
end


function Frost:checkMarks(saved)
    local function clean(value, most)
        return type(value) == "number" and math.max(0, math.min(most, math.floor(value))) or 0
    end
    local marks = {freeze = clean(saved.freeze, MAX_FREEZE), shatter = clean(saved.shatter, MAX_SHATTER)}
    if marks.freeze == 0 and marks.shatter == 0 then
        return nil
    end
    return marks
end


function Frost:markCost(marks)
    return (marks.freeze + marks.shatter) * MARK_COMPLEXITY, 0
end


function Frost:describeMarks(marks)
    local parts = {}
    if marks.freeze > 0 then
        table.insert(parts, marks.freeze >= MAX_FREEZE and "freezes solid" or ("freeze +" .. marks.freeze))
    end
    if marks.shatter > 0 then
        table.insert(parts, "shatter +" .. marks.shatter)
    end
    return table.concat(parts, ", ")
end
