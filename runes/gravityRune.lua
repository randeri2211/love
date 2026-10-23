local Rune = require "runes.rune"

local GravityRune = Rune:new("Gravity", "modifier", 1, 1, {0.55, 0.55, 1})
registerRune("Gravity", GravityRune)

-- Weight falling onto the ground
GravityRune.glyph = {
    {"line", 0, -0.85, 0, 0.35},
    {"line", -0.32, 0.05, 0, 0.37, 0.32, 0.05},
    {"line", -0.72, 0.68, 0.72, 0.68},
}

-- Marks: one arrow sets which way gravity pulls, in the world(an arrow up makes the spell fall up whichever way it is aimed)
-- Without an arrow it pulls down, Area pulls toward its center so the arrow doesnt change it
local MIN_MARK_QUALITY = 0.25
local ARROW_COMPLEXITY = 1

function GravityRune:readMarks(marks)
    local arrows = {}
    for i, mark in ipairs(marks) do
        if mark.kind == "arrow" and mark.quality >= MIN_MARK_QUALITY then
            table.insert(arrows, mark)
        end
    end
    if #arrows > 1 then
        return nil, "Only one arrow on Gravity"
    end
    if #arrows == 0 then
        return nil
    end
    return {direction = arrows[1].direction}
end


function GravityRune:checkMarks(saved)
    if type(saved.direction) ~= "number" then
        return nil
    end
    return {direction = saved.direction % (2 * math.pi)}
end


function GravityRune:markCost(marks)
    return ARROW_COMPLEXITY, 0
end


function GravityRune:describeMarks(marks)
    -- Nearest of 8 directions(pad y goes down, so -90 degrees is up)
    local names = {"right", "down right", "down", "down left", "left", "up left", "up", "up right"}
    local index = math.floor((marks.direction % (2 * math.pi)) / (math.pi / 4) + 0.5) % 8 + 1
    return "falls " .. names[index]
end


function GravityRune:settings(marks)
    if marks and marks.direction then
        return {x = math.cos(marks.direction), y = math.sin(marks.direction)}
    end
    return {x = 0, y = 1}
end


local function pullWay(params, settings)
    -- The last Gravity rune with an arrow decides the way, plain ones keep it
    if settings.x ~= 0 or settings.y ~= 1 then
        params.gravityX, params.gravityY = settings.x, settings.y
    end
end


local function strengthen(value)
    -- The first rune switches it on, every other rune doubles it
    if value == 0 then
        return 1
    end
    return value * 2
end

local function discount(params)
    -- The spell stops resisting gravity, so it is cheaper to hold together
    params.complexityScale = params.complexityScale * 0.85
    params.manaScale = params.manaScale * 0.85
end

-- No Trap entry, traps already sit on the ground
GravityRune.effects = {
    Bullet = function(params, settings)
        params.gravityScale = strengthen(params.gravityScale)   -- Falls in an arc
        pullWay(params, settings)
        discount(params)
    end,
    Laser = function(params, settings)
        params.bend = strengthen(params.bend)                   -- Beam curves toward the gravity way
        pullWay(params, settings)
        discount(params)
    end,
    Area = function(params)
        -- Gravity well that pulls enemies in, and lasts longer to do it
        params.pull = strengthen(params.pull)
        params.lifetime = params.lifetime * 3
        discount(params)
    end,
}

return GravityRune
