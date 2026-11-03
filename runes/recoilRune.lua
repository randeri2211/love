local Rune = require "runes.rune"

local RecoilRune = Rune:new("Recoil", "modifier", 2, 1, {0.95, 0.65, 0.85})
registerRune("Recoil", RecoilRune)

-- An arrow pushed back off a wall
RecoilRune.glyph = {
    {"line", 0.6, -0.65, 0.6, 0.65},
    {"line", 0.3, 0, -0.85, 0},
    {"line", -0.5, -0.38, -0.85, 0, -0.5, 0.38},
}

local LASER_RECOIL = 0.45      -- Held lasers fire many times a second, so each beam pushes this much of a normal recoil

-- Marks: one arrow sets which way it pushes, drawn as if facing right(up stays up, forward follows the facing)
-- On a projectile it is the way the caster is pushed, on Self the way the dash goes
local MIN_MARK_QUALITY = 0.25
local ARROW_COMPLEXITY = 1

-- What its marks do, the grimoire shows these
RecoilRune.markHelp = {{"arrow", "One arrow: the way it pushes, drawn facing right"}}

function RecoilRune:readMarks(marks)
    local arrows = {}
    for i, mark in ipairs(marks) do
        if mark.kind == "arrow" and mark.quality >= MIN_MARK_QUALITY then
            table.insert(arrows, mark)
        end
    end
    if #arrows > 1 then
        return nil, "Only one arrow on Recoil"
    end
    if #arrows == 0 then
        return nil
    end
    return {direction = arrows[1].direction}
end


function RecoilRune:checkMarks(saved)
    if type(saved.direction) ~= "number" then
        return nil
    end
    return {direction = saved.direction % (2 * math.pi)}
end


function RecoilRune:markCost(marks)
    return ARROW_COMPLEXITY, 0
end


function RecoilRune:describeMarks(marks)
    -- Nearest of 8 directions, forward is the way it faces(pad y goes down, so -90 degrees is up)
    local names = {"forward", "down forward", "down", "down back", "back", "up back", "up", "up forward"}
    local index = math.floor((marks.direction % (2 * math.pi)) / (math.pi / 4) + 0.5) % 8 + 1
    return "pushes " .. names[index]
end


function RecoilRune:settings(marks)
    if marks and marks.direction then
        return {x = math.cos(marks.direction), y = math.sin(marks.direction)}
    end
    return {x = 0, y = 0}
end


local function aim(params, settings)
    -- The last Recoil rune with an arrow decides the way, plain ones keep it
    if settings.x ~= 0 or settings.y ~= 0 then
        params.recoilDirX, params.recoilDirY = settings.x, settings.y
    end
end


local function strengthen(params, first)
    -- The first rune turns recoil on, every other rune doubles it
    if params.recoil == 0 then
        params.recoil = first
    else
        params.recoil = params.recoil * 2
    end
end

RecoilRune.effects = {
    -- Pushes the caster away from the aim, every form has recoil so this works on all of them
    default = function(params, settings)
        strengthen(params, 1)
        aim(params, settings)
    end,
    -- Held down it is a jet: about as strong as gravity, so it hovers, and rises once Weaken makes it fire faster
    Laser = function(params, settings)
        strengthen(params, LASER_RECOIL)
        aim(params, settings)
    end,
    -- On the caster it is a dash toward the aim instead of a push away from it
    Self = function(params, settings)
        if params.dash == 0 then
            params.dash = 1
        else
            params.dash = params.dash * 2
        end
        aim(params, settings)
    end,
}

return RecoilRune
