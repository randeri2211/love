local MagicCircle = require "magic.magicCircle"

local Spells = {}

function Spells:new()
    local spells = {}
    setmetatable(spells,self)
    self.__index = self
    spells.spells = {}
    spells.queue = {}       -- Triggered casts waiting for the physics update to finish
    spells.circles = {}     -- Magic circles fading out where spells were cast

    return spells
end


function Spells:update(dt)
    -- Going backwards so spells removed during update dont skip the next one
    for i = #self.spells, 1, -1 do
        self.spells[i].instance:update(dt)
    end

    -- Age the cast circles and remove the faded ones
    for i = #self.circles, 1, -1 do
        local circle = self.circles[i]
        circle.time = circle.time + dt
        if circle.time >= CAST_CIRCLE_TIME then
            table.remove(self.circles, i)
        end
    end

    self:castQueued()
end


function Spells:addCircle(spell, x, y, dirX, dirY)
    -- Shows the spell magic circle in front of where it was cast
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


function Spells:trigger(instance, event, dirX, dirY)
    -- Queues the child spells of an event(onHit, onExpire) from where the instance is
    local triggers = instance.spell:getParams().triggers[event]
    if triggers == nil then
        return
    end

    local x, y = instance.body:getWorldCenter()
    dirX = dirX or instance.direction[1]
    dirY = dirY or instance.direction[2]
    for i, childSpell in ipairs(triggers) do
        table.insert(self.queue, {spell = childSpell, caster = instance.player, x = x, y = y, dirX = dirX, dirY = dirY})
    end
end


function Spells:castQueued()
    -- Bodies cant be created inside physics callbacks, so triggered spells are cast here instead
    local queue = self.queue
    self.queue = {}
    for i, cast in ipairs(queue) do
        cast.spell:shoot(cast.caster, cast.x, cast.y, cast.dirX, cast.dirY, true)
    end
end


function Spells:draw()
    -- Circles first so projectiles fly over them
    self:drawCircles()
    for i, spell in pairs(self.spells) do
        spell.instance:draw()
    end
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