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
    {"Burst", "burst", "%d"},
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
        aimOffset = 0,              -- Radians the shot turns from the aim, from an arrow mark
        burst = 1,                  -- Shots in a row per cast, from dot marks
        pierce = 0,                 -- Enemies and blocks it passes through before it stops, from pierce marks
        imagePath = "GRASS",
    }
end

-- Marks
-- An arrow turns the shot from the aim, the way the arrow points(only one, a shot cant go two ways)
-- Every dot adds a shot to a burst, each costing more mana than the last, every shot keeps the full damage
-- Pierce marks(a line crossed at its thirds) let the bullet pass through enemies and blocks, how many is the sum of how well they are drawn
local MIN_MARK_QUALITY = 0.25       -- Marks drawn worse than this dont count
local MAX_BURST = 6
local MAX_PIERCE = 8
local BURST_MANA_FIRST = 0.5        -- The second shot costs half the spell again
local BURST_MANA_STEP = 0.25        -- and every shot after that a quarter more than the one before
local AIM_COMPLEXITY = 1
local BURST_COMPLEXITY = 2          -- Per extra shot
local PIERCE_COMPLEXITY = 3         -- Per enemy or block pierced

function BulletRune:readMarks(marks)
    local arrows, dots, pierce = {}, 0, 0
    for i, mark in ipairs(marks) do
        if mark.quality >= MIN_MARK_QUALITY then
            if mark.kind == "arrow" then
                table.insert(arrows, mark)
            elseif mark.kind == "dot" then
                dots = dots + 1
            elseif mark.kind == "pierce" then
                pierce = pierce + mark.quality
            end
        end
    end
    if #arrows > 1 then
        return nil, "Only one aim arrow on a Bullet"
    end

    local result = {}
    if #arrows == 1 then
        -- 0 is the aim(to the right on the pad), turned to -180 to 180 degrees
        result.aim = (arrows[1].direction + math.pi) % (2 * math.pi) - math.pi
    end
    if dots > 0 then
        result.burst = math.min(MAX_BURST, 1 + dots)
    end
    if math.floor(pierce + 0.5) > 0 then
        result.pierce = math.min(MAX_PIERCE, math.floor(pierce + 0.5))
    end
    if next(result) == nil then
        return nil
    end
    return result
end


function BulletRune:checkMarks(saved)
    local marks = {}
    if type(saved.aim) == "number" then
        marks.aim = math.max(-math.pi, math.min(math.pi, saved.aim))
    end
    if type(saved.burst) == "number" then
        marks.burst = math.max(1, math.min(MAX_BURST, math.floor(saved.burst)))
    end
    if type(saved.pierce) == "number" then
        marks.pierce = math.max(0, math.min(MAX_PIERCE, math.floor(saved.pierce)))
    end
    return marks
end


function BulletRune:markCost(marks)
    local complexity = 0
    if marks.aim ~= nil then
        complexity = complexity + AIM_COMPLEXITY
    end
    complexity = complexity + ((marks.burst or 1) - 1) * BURST_COMPLEXITY + (marks.pierce or 0) * PIERCE_COMPLEXITY
    return complexity, 0
end


function BulletRune:describeMarks(marks)
    local parts = {}
    if marks.aim ~= nil then
        local degrees = math.floor(math.deg(math.abs(marks.aim)) + 0.5)
        table.insert(parts, string.format("aimed %d %s", degrees, marks.aim < 0 and "up" or "down"))
    end
    if marks.burst ~= nil then
        table.insert(parts, marks.burst .. " shot burst")
    end
    if marks.pierce ~= nil then
        table.insert(parts, "pierces " .. marks.pierce)
    end
    return table.concat(parts, ", ")
end


function BulletRune:applyMarks(params, marks)
    params.aimOffset = marks.aim or params.aimOffset
    params.burst = marks.burst or params.burst
    params.pierce = marks.pierce or params.pierce
    -- Every extra shot costs more than the one before, on the whole spell cost(modifiers included)
    local cost = 1
    for shot = 2, params.burst do
        cost = cost + BURST_MANA_FIRST + (shot - 2) * BURST_MANA_STEP
    end
    params.manaScale = params.manaScale * cost
end

return BulletRune
