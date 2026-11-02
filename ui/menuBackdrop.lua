local Background = require "world_utils.background"
local WorldClock = require "world_utils.worldClock"
local MagicCircle = require "magic.magicCircle"
local Spell = require "magic.spell"
local Theme = require "ui.theme"

-- The living picture behind the menus: the game sky drifting sideways at night,
-- mana motes rising from the hills and a big magic circle turning slowly behind the title
local MenuBackdrop = {}

local MENU_PHASE = 0.86         -- Time of day of the menu sky(0 midnight), early night so the stars are out
local DRIFT_SPEED = 25          -- Pixels a second the view moves sideways
local LIFT = 800                -- Pixels the view sits above the plain ground, so the hills are low on the screen
local MOTE_COUNT = 70
local MOTE_COLORS = {Theme.COLORS.glow, Theme.COLORS.gold, {0.75, 0.55, 1, 1}}
local CIRCLE_SPIN = 0.05        -- Radians a second
local CIRCLE_ALPHA = 0.28

local time = 0
local motes = nil
local circleSpell = nil


local function newMote(w, h, anywhere)
    -- A mote starts under the screen(or anywhere on it the first time) and rises
    return {
        x = love.math.random() * w,
        y = anywhere and love.math.random() * h or h + love.math.random() * 40,
        speed = 12 + love.math.random() * 30,
        sway = love.math.random() * math.pi * 2,
        size = love.math.random() < 0.25 and 3 or 2,
        color = MOTE_COLORS[love.math.random(#MOTE_COLORS)],
    }
end


function MenuBackdrop.update(dt)
    time = time + dt
    local w, h = love.graphics.getDimensions()
    if motes == nil then
        motes = {}
        for i = 1, MOTE_COUNT do
            table.insert(motes, newMote(w, h, true))
        end
    end
    for i, mote in ipairs(motes) do
        mote.y = mote.y - mote.speed * dt
        mote.x = mote.x + math.sin(time * 0.8 + mote.sway) * 10 * dt
        if mote.y < -10 then
            motes[i] = newMote(w, h, false)
        end
    end
end


local function drawCircle(x, y, radius)
    -- One spell with every slot filled, so the circle shows all its rings
    if circleSpell == nil then
        circleSpell = Spell:new("Bullet", {"Split", "Gravity", "Rebound", "Speed", "Damage", "Size"})
    end
    love.graphics.push("all")
    love.graphics.translate(x, y)
    love.graphics.rotate(time * CIRCLE_SPIN)
    -- radius is where the slots sit
    MagicCircle.draw(circleSpell, 0, 0, radius / MagicCircle.RING_RADIUS, {alpha = CIRCLE_ALPHA, time = time, particles = false})
    love.graphics.pop()
end


function MenuBackdrop.draw(circleX, circleY, circleRadius)
    -- The sky of the world in the background at the menu time, the circle is left out when circleX is nil
    local w, h = love.graphics.getDimensions()

    -- The sky reads the time of the map, it goes back after drawing
    local worldTime = map.time
    map.time = MENU_PHASE * WorldClock.dayLength()
    Background.drawSky(time * DRIFT_SPEED, SURFACE_ROW * TILE_SIZE - LIFT)
    map.time = worldTime

    if circleX ~= nil then
        drawCircle(circleX, circleY, circleRadius)
    end

    love.graphics.push("all")
    for i, mote in ipairs(motes or {}) do
        local fade = math.min(1, mote.y / (h * 0.5))      -- Motes fade out as they rise
        love.graphics.setColor(mote.color[1], mote.color[2], mote.color[3], 0.8 * fade)
        love.graphics.rectangle("fill", math.floor(mote.x), math.floor(mote.y), mote.size, mote.size)
    end
    -- Darker at the edges so the panels stand out
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.pop()
end

return MenuBackdrop
