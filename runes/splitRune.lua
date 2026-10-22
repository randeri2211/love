local Rune = require "runes.rune"
local Strokes = require "magic.strokes"

local SplitRune = Rune:new("Split", "modifier", 8, 5, {0.6, 1, 0.4})
registerRune("Split", SplitRune)

-- One path forking into two
SplitRune.glyph = {
    {"line", -0.8, 0, -0.05, 0},
    {"line", -0.05, 0, 0.6, -0.55},
    {"line", -0.05, 0, 0.6, 0.55},
    {"circle", 0.6, -0.55, 0.13},
    {"circle", 0.6, 0.55, 0.13},
}

-- Marks: arrows drawn around the rune set the projectile count, and how wide they fan out sets the spread
-- Both scale with how well the rune is drawn(see Rune.WHOLE_PARAMS)
local MAX_COUNT = 8                 -- Most projectiles one Split can make
local MIN_SPREAD = math.rad(5)      -- Arrows drawn on top of each other still fan out a little
local EXTRA_COMPLEXITY = 4          -- Cost of each projectile past the 2 a plain Split makes
local EXTRA_MANA = 2.5
local MIN_MARK_QUALITY = 0.25       -- Arrows drawn worse than this dont count

function SplitRune:readMarks(marks)
    -- marks are from Strokes.readMarks: {kind, quality, angle, outward(arrows only), strokes}
    -- Returns {count, spread}, spread nil when the arrows dont make a fan(then the form keeps its own)
    -- nil when the marks dont say anything to Split
    -- Only arrows pointing away from the rune count, inward arrows are left free for later
    local arrows = {}
    for i, mark in ipairs(marks) do
        if mark.kind == "arrow" and mark.outward and mark.quality >= MIN_MARK_QUALITY then
            table.insert(arrows, mark)
        end
    end
    if #arrows == 0 then
        return nil
    end

    local result = {count = math.max(2, math.min(MAX_COUNT, #arrows))}
    -- Arrows drawn evenly all the way around span 360 * (n - 1) / n, which is exactly a ring of projectiles
    if #arrows >= 2 then
        result.spread = math.max(MIN_SPREAD, Strokes.angleSpan(arrows))
    end
    return result
end


function SplitRune:checkMarks(saved)
    -- Saved marks are only trusted inside the limits readMarks can give
    if type(saved.count) ~= "number" then
        return nil
    end
    local marks = {count = math.max(2, math.min(MAX_COUNT, math.floor(saved.count)))}
    if type(saved.spread) == "number" then
        marks.spread = math.max(MIN_SPREAD, math.min(2 * math.pi, saved.spread))
    end
    return marks
end


function SplitRune:markCost(marks)
    local extra = marks.count - 2
    return extra * EXTRA_COMPLEXITY, extra * EXTRA_MANA
end


function SplitRune:describeMarks(marks)
    if marks.spread ~= nil then
        return string.format("%d projectiles, %.0f degree fan", marks.count, math.deg(marks.spread))
    end
    return marks.count .. " projectiles"
end


function SplitRune:settings(marks)
    -- 2 projectiles without marks, the fan is the drawn one or the form own, spreadScale is how Focus narrows it
    return {
        count = marks and marks.count or 2,
        spread = marks and marks.spread,
        spreadScale = 1,
    }
end


local function split(params, settings, fans)
    -- Multiplies the projectiles, every projectile keeps the full damage
    params.count = params.count * settings.count
    if fans then
        params.spread = (settings.spread or params.spread) * settings.spreadScale
    end
end

SplitRune.effects = {
    -- More projectiles
    Bullet = function(params, settings)
        split(params, settings, true)
    end,
    -- More beams in a fan
    Laser = function(params, settings)
        split(params, settings, true)
    end,
    -- Cluster of smaller bursts(scattered, so the drawn fan isnt used)
    Area = function(params, settings)
        split(params, settings, false)
        params.areaRadius = params.areaRadius * 0.75
    end,
    -- Small minefield
    Trap = function(params, settings)
        split(params, settings, false)
    end,
}

return SplitRune
