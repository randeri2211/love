local Rune = require "runes.rune"

local PierceRune = Rune:new("Pierce", "modifier", 4, 3, {0.85, 0.9, 1})
registerRune("Pierce", PierceRune)

-- An arrow going through a wall
PierceRune.glyph = {
    {"line", -0.85, 0, 0.85, 0},
    {"line", 0.5, -0.32, 0.85, 0, 0.5, 0.32},
    {"line", -0.15, -0.75, -0.15, 0.75},
    {"line", 0.12, -0.75, 0.12, 0.75},
}

-- Marks: pierce marks(a line crossed at its thirds) add pierces, how many is the sum of how well they are drawn
-- Without marks it passes through one enemy or block
local MIN_MARK_QUALITY = 0.25
local MAX_PIERCE = 8
local EXTRA_COMPLEXITY = 3          -- Per pierce past the plain 1

function PierceRune:readMarks(marks)
    local sum = 0
    for i, mark in ipairs(marks) do
        if mark.kind == "pierce" and mark.quality >= MIN_MARK_QUALITY then
            sum = sum + mark.quality
        end
    end
    local pierce = math.floor(sum + 0.5)
    if pierce < 1 then
        return nil
    end
    return {pierce = math.min(MAX_PIERCE, 1 + pierce)}
end


function PierceRune:checkMarks(saved)
    if type(saved.pierce) ~= "number" then
        return nil
    end
    return {pierce = math.max(1, math.min(MAX_PIERCE, math.floor(saved.pierce)))}
end


function PierceRune:markCost(marks)
    return (marks.pierce - 1) * EXTRA_COMPLEXITY, 0
end


function PierceRune:describeMarks(marks)
    return "pierces " .. marks.pierce
end


function PierceRune:settings(marks)
    return {pierce = marks and marks.pierce or 1}
end


PierceRune.effects = {
    -- Passes through enemies and blocks, every block or enemy passed uses one pierce(Pierce runes add up)
    Bullet = function(params, settings)
        params.pierce = params.pierce + settings.pierce
    end,
    Laser = function(params, settings)
        params.pierce = params.pierce + settings.pierce
    end,
}

return PierceRune
