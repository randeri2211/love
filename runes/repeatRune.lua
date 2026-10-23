local Rune = require "runes.rune"

local RepeatRune = Rune:new("Repeat", "modifier", 6, 3, {1, 0.75, 0.3})
registerRune("Repeat", RepeatRune)

-- A loop arrow coming back around
RepeatRune.glyph = {
    {"arc", 0, 0, 0.62, 0.5, 5.6},
    {"line", 0.46, -0.69, 0.48, -0.39, 0.19, -0.47},
    {"circle", 0, 0, 0.18},
}

-- Marks: every dot adds a repeat, without dots the spell casts twice
-- Repeats come REPEAT_DELAY apart, every one does full damage, each costs more mana than the one before
local MIN_MARK_QUALITY = 0.25       -- Dots drawn worse than this dont count
local MAX_REPEATS = 6
local MANA_FIRST = 0.5              -- The second cast costs half the spell again
local MANA_STEP = 0.25              -- and every cast after that a quarter more than the one before
local EXTRA_COMPLEXITY = 2          -- Per repeat past the plain 2

function RepeatRune:readMarks(marks)
    local dots = 0
    for i, mark in ipairs(marks) do
        if mark.kind == "dot" and mark.quality >= MIN_MARK_QUALITY then
            dots = dots + 1
        end
    end
    if dots == 0 then
        return nil
    end
    return {repeats = math.min(MAX_REPEATS, 2 + dots)}
end


function RepeatRune:checkMarks(saved)
    if type(saved.repeats) ~= "number" then
        return nil
    end
    return {repeats = math.max(2, math.min(MAX_REPEATS, math.floor(saved.repeats)))}
end


function RepeatRune:markCost(marks)
    return (marks.repeats - 2) * EXTRA_COMPLEXITY, 0
end


function RepeatRune:describeMarks(marks)
    return "casts " .. marks.repeats .. " times"
end


function RepeatRune:settings(marks)
    return {repeats = marks and marks.repeats or 2}
end


RepeatRune.effects = {
    -- Every form can repeat: bullets fire in bursts, lasers pulse, areas go off again, traps are laid in a row
    -- Repeat runes multiply, and the mana grows with every extra cast(on the whole spell cost, modifiers included)
    default = function(params, settings)
        params.repeats = params.repeats * settings.repeats
        local cost = 1
        for cast = 2, settings.repeats do
            cost = cost + MANA_FIRST + (cast - 2) * MANA_STEP
        end
        params.manaScale = params.manaScale * cost
    end,
}

return RepeatRune
