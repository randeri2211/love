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
        -- What the marks set(Frost freeze dots and shatter cracks, Poison stack dots, Lightning forks, see below)
        marks = marks or {}
        return {power = 1, duration = 1, freeze = marks.freeze or 0, shatter = marks.shatter or 0,
            stacks = marks.stacks or 0, forks = marks.forks or 0,
            flare = marks.flare or 0, kindle = marks.kindle or 0, spread = marks.spread or 0}
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

Frost.markHelp = {{"dot", "A deeper, shorter slow each, three freeze solid"}, {"crack", "A shorter slow, hits on it shatter harder"}}

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


-- Marks that count one shape: every one drawn well enough adds one step to a setting, up to a most
-- Poison dots allow one more stack each(every stack weaker), Lightning forks one more jump each(every jump weaker)
-- (see the Poison and Lightning entries in magic/elements for the numbers)
local function countedMarks(rune, kind, key, most, describe, help)
    rune.markHelp = {{kind, help}}

    function rune:readMarks(marks)
        local count = 0
        for i, mark in ipairs(marks) do
            if mark.kind == kind and mark.quality >= MIN_MARK_QUALITY then
                count = count + 1
            end
        end
        if count == 0 then
            return nil
        end
        return {[key] = math.min(most, count)}
    end

    function rune:checkMarks(saved)
        local value = type(saved[key]) == "number" and math.max(0, math.min(most, math.floor(saved[key]))) or 0
        if value == 0 then
            return nil
        end
        return {[key] = value}
    end

    function rune:markCost(marks)
        return (marks[key] or 0) * MARK_COMPLEXITY, 0
    end

    function rune:describeMarks(marks)
        return describe(marks[key])
    end
end

countedMarks(RUNE_REGISTRY.Poison, "dot", "stacks", 3, function(count)
    return "stacks up to x" .. (POISON_MAX_STACKS + count) .. ", each weaker"
end, "One more stack each, up to six, every stack a little weaker")
RUNE_REGISTRY.Lightning.markKinds = {"fork"}
countedMarks(RUNE_REGISTRY.Lightning, "fork", "forks", 3, function(count)
    return "jumps to " .. (CHAIN_TARGETS + count) .. ", each weaker"
end, "One more jump each, up to five, every jump a little weaker")


-- Fire marks: flames flare(faster, shorter) and waves smoulder(slower, longer), counting against each other,
-- spirals kindle(starts weaker, grows hotter while it keeps burning), sparks spread it when the burning one dies
-- (see the Fire entry in magic/elements and Statuses.burnFactor and Statuses.died for the numbers)
local Fire = RUNE_REGISTRY.Fire
Fire.markKinds = {"flame", "wave", "spiral", "spark"}
Fire.markHelp = {{"flame", "Burns faster for less time"}, {"wave", "Burns slower for longer, flames and waves cancel"},
    {"spiral", "Starts weaker and grows hotter while it keeps burning"}, {"spark", "Passes on when the burning one dies"}}
local MAX_FLARE = 3
local MAX_KINDLE = 3
local MAX_SPREAD = 3

function Fire:readMarks(marks)
    local counts = {flame = 0, wave = 0, spiral = 0, spark = 0}
    for i, mark in ipairs(marks) do
        if counts[mark.kind] ~= nil and mark.quality >= MIN_MARK_QUALITY then
            counts[mark.kind] = counts[mark.kind] + 1
        end
    end
    if counts.flame + counts.wave + counts.spiral + counts.spark == 0 then
        return nil
    end
    -- Flames and waves cancel out, the cost is for every one drawn
    return {flare = math.max(-MAX_FLARE, math.min(MAX_FLARE, counts.flame - counts.wave)), drawn = counts.flame + counts.wave,
        kindle = math.min(MAX_KINDLE, counts.spiral), spread = math.min(MAX_SPREAD, counts.spark)}
end


function Fire:checkMarks(saved)
    local function clean(value, low, high)
        return type(value) == "number" and math.max(low, math.min(high, math.floor(value))) or 0
    end
    local marks = {flare = clean(saved.flare, -MAX_FLARE, MAX_FLARE), drawn = clean(saved.drawn, 0, 2 * MAX_FLARE + 6),
        kindle = clean(saved.kindle, 0, MAX_KINDLE), spread = clean(saved.spread, 0, MAX_SPREAD)}
    if marks.drawn == 0 and marks.kindle == 0 and marks.spread == 0 then
        return nil
    end
    return marks
end


function Fire:markCost(marks)
    -- Every mark costs like any tuning mark, sparks cost more since they add power
    local complexity = ((marks.drawn or 0) + marks.kindle + marks.spread) * MARK_COMPLEXITY + marks.spread * WILDFIRE_COMPLEXITY
    return complexity, marks.spread * WILDFIRE_MANA
end


function Fire:describeMarks(marks)
    local parts = {}
    if marks.flare > 0 then
        table.insert(parts, "flare +" .. marks.flare)
    elseif marks.flare < 0 then
        table.insert(parts, "smoulder +" .. -marks.flare)
    elseif (marks.drawn or 0) > 0 then
        table.insert(parts, "flames and waves cancel")
    end
    if marks.kindle > 0 then
        table.insert(parts, "kindling +" .. marks.kindle)
    end
    if marks.spread > 0 then
        table.insert(parts, "wildfire x" .. marks.spread)
    end
    return table.concat(parts, ", ")
end
