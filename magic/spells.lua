local MagicCircle = require "magic.magicCircle"
local ElementFx = require "magic.elementFx"

local Spells = {}

function Spells:new()
    local spells = {}
    setmetatable(spells,self)
    self.__index = self
    spells.spells = {}
    spells.queue = {}       -- Triggered casts waiting for the physics update to finish
    spells.scheduled = {}   -- Things to run later on the game clock, {time, run}(Repeat casts)
    spells.circles = {}     -- Magic circles fading out where spells were cast
    spells.time = 0         -- Game time in seconds, stops while paused(used for cooldowns)

    return spells
end


function Spells:update(dt)
    self.time = self.time + dt

    -- Going backwards so spells removed during update dont skip the next one
    -- Elements trail particles from where the spell is, before it moves(it may be gone after its update)
    for i = #self.spells, 1, -1 do
        local instance = self.spells[i].instance
        if instance.elements ~= nil and instance.fxSpot ~= nil then
            local x, y, spread, rate = instance:fxSpot()
            if x ~= nil then
                ElementFx.trail(instance.elements, x, y, spread, rate, dt)
            end
        end
        instance:update(dt)
    end
    ElementFx.update(dt)

    -- Age the cast circles and remove the faded ones
    for i = #self.circles, 1, -1 do
        local circle = self.circles[i]
        circle.time = circle.time + dt
        if circle.time >= CAST_CIRCLE_TIME then
            table.remove(self.circles, i)
        end
    end

    self:castQueued()

    -- Scheduled things whose time came, run after the loop so they can schedule more
    local due = {}
    for i = #self.scheduled, 1, -1 do
        if self.scheduled[i].time <= self.time then
            table.insert(due, table.remove(self.scheduled, i))
        end
    end
    for i = #due, 1, -1 do
        due[i].run()
    end
end


function Spells:schedule(delay, run)
    -- Runs run() after delay seconds of game time(paused time doesnt count)
    table.insert(self.scheduled, {time = self.time + delay, run = run})
end


function Spells:addCircle(spell, x, y, dirX, dirY, built)
    -- Shows the spell magic circle in front of where it was cast
    -- Casting the same spell again while its circle is still showing keeps that one circle alive
    -- built is true when a wind-up already built the circle, then it starts fully drawn
    for i, circle in ipairs(self.circles) do
        if circle.spell == spell then
            circle.x = x + dirX * CAST_CIRCLE_OFFSET
            circle.y = y + dirY * CAST_CIRCLE_OFFSET
            circle.dirX, circle.dirY = dirX, dirY
            circle.time = built and CAST_DRAW_IN_TIME or math.min(circle.time, CAST_DRAW_IN_TIME)    -- Stays fully drawn without restarting the draw-in
            return
        end
    end
    table.insert(self.circles, {
        spell = spell,
        x = x + dirX * CAST_CIRCLE_OFFSET,
        y = y + dirY * CAST_CIRCLE_OFFSET,
        dirX = dirX,
        dirY = dirY,
        time = 0,
    })
end


function Spells:drawCircles()
    for i, circle in ipairs(self.circles) do
        local t = circle.time / CAST_CIRCLE_TIME   -- Goes from 0 to 1 over the circle life

        -- TODO(human): animate the circle from t, alpha is its opacity, spin is its rotation in radians and size multiplies its scale
        local alpha = 1
        local spin = 0
        local size = 1

        love.graphics.push()
        love.graphics.translate(circle.x, circle.y)
        love.graphics.rotate(spin)
        MagicCircle.draw(circle.spell, 0, 0, CAST_CIRCLE_SCALE * size, {
            alpha = math.max(0, alpha),
            progress = circle.time / CAST_DRAW_IN_TIME,
        })
        love.graphics.pop()
    end
end


function Spells:trigger(instance, event, dirX, dirY, x, y, target)
    -- Queues the child spells of an event(onHit, onExpire), from x, y or where the instance is
    -- target is what the event happened to(the hit enemy), Self children go on it instead of the caster
    local triggers = instance.spell:getParams().triggers[event]
    if triggers == nil then
        return
    end

    if x == nil or y == nil then
        x, y = instance:getPosition()
    end
    if dirX == nil or dirY == nil then
        dirX, dirY = instance:getDirection()
    end
    for i, childSpell in ipairs(triggers) do
        table.insert(self.queue, {spell = childSpell, caster = instance.player, x = x, y = y, dirX = dirX, dirY = dirY, target = target})
    end
end


function Spells:castQueued()
    -- Bodies cant be created inside physics callbacks, so triggered spells are cast here instead
    local queue = self.queue
    self.queue = {}
    for i, cast in ipairs(queue) do
        cast.spell:shoot(cast.caster, cast.x, cast.y, cast.dirX, cast.dirY, true, cast.target)
    end
end


function Spells:draw()
    -- Circles first so projectiles fly over them
    self:drawCircles()
    for i, spell in pairs(self.spells) do
        spell.instance:draw()
    end
    ElementFx.draw()
end


function Spells:getSpellByFixture(fixture)
    for i, spell in pairs(self.spells) do
        if spell.instance:isFixture(fixture) then
            return spell
        end
    end
end


function Spells:destroy(instance)
    for i, spell in pairs(self.spells) do
        if spell.instance == instance then
            spell.instance:destroy()
            table.remove(self.spells, i)
            return true
        end
    end
    return false
end

return Spells