local Form = require "forms.form"

local Laser = Form:new()

local SEGMENT = 12          -- The beam is traced in short steps so gravity can bend it
local BEND_PER_PIXEL = 0.004 -- How much one Gravity rune turns the beam down per pixel
local MAX_STEPS = 400       -- Safety stop for the tracing loop

function Laser:new(caster, params, x, y, dirX, dirY)
    local laser = Form:new(caster)
    setmetatable(laser,self)
    self.__index = self

    laser.form = "laser"
    if caster == nil then
        return laser
    end

    -- Values from the compiled spell params
    laser.damage = params.damage
    laser.terrainDamage = params.terrainDamage
    laser.reach = params.reach
    laser.width = params.width
    laser.bounces = params.bounces   -- Rebound, reflections off surfaces
    laser.bend = params.bend         -- Gravity, how much the beam curves down
    laser.lifetime = params.lifetime -- How long the beam stays visible
    laser.duration = params.lifetime
    laser.color = params.color

    laser.x, laser.y = x, y
    laser.direction = {dirX, dirY}
    laser.points = nil      -- Beam path, traced on the first update once the spell is registered

    return laser
end


function Laser:castSegment(x1, y1, x2, y2)
    -- Closest fixture on the segment, ignoring the caster, other spells and things that ignore spells
    local closest = nil
    p_world:rayCast(x1, y1, x2, y2, function(fixture, x, y, xn, yn, fraction)
        local category = fixture:getCategory()
        if category == PLAYER_CATEGORY or category == SPELLS_CATEGORY or fixture:isSensor() then
            return -1   -- Ignore this fixture and keep going
        end
        for i, masked in ipairs({fixture:getMask()}) do
            if masked == SPELLS_CATEGORY then
                return -1
            end
        end
        closest = {x = x, y = y, nx = xn, ny = yn, fixture = fixture}
        return fraction     -- Only look for closer hits from now on
    end)

    if closest ~= nil then
        closest.entity = getEntityFromFixture(closest.fixture)
    end
    return closest
end


function Laser:fire()
    -- Traces the beam, hitting and reflecting off whatever it touches
    local x, y = self.x, self.y
    local dx, dy = self.direction[1], self.direction[2]
    local travelled = 0
    local bounces = self.bounces
    local damaged = {}      -- Each thing is only hit once per beam
    self.points = {x, y}

    for step = 1, MAX_STEPS do
        if travelled >= self.reach then
            break
        end
        local length = math.min(SEGMENT, self.reach - travelled)
        local hit = self:castSegment(x, y, x + dx * length, y + dy * length)

        if hit ~= nil then
            table.insert(self.points, hit.x)
            table.insert(self.points, hit.y)
            travelled = travelled + distance(x, y, hit.x, hit.y)

            -- Reflect across the surface normal(works for either normal sign)
            local dot = dx * hit.nx + dy * hit.ny
            local rx, ry = dx - 2 * dot * hit.nx, dy - 2 * dot * hit.ny
            local key = hit.entity or hit.fixture
            if not damaged[key] then
                damaged[key] = true
                self:hit(hit.entity, hit.x, hit.y, rx, ry)
            end

            if bounces <= 0 then
                break
            end
            bounces = bounces - 1
            dx, dy = rx, ry
            -- Step off the surface so the next ray doesnt start inside it
            x, y = hit.x + dx * 0.5, hit.y + dy * 0.5
        else
            x, y = x + dx * length, y + dy * length
            travelled = travelled + length
            table.insert(self.points, x)
            table.insert(self.points, y)

            -- Gravity bends the beam down a little every step
            if self.bend ~= 0 then
                dy = dy + self.bend * BEND_PER_PIXEL * length
                local size = math.sqrt(dx * dx + dy * dy)
                dx, dy = dx / size, dy / size
            end
        end
    end

    -- onExpire child spells start where the beam ends, going the way it was going
    self.endX, self.endY = x, y
    self.endDirection = {dx, dy}
end


function Laser:update(dt)
    if self.points == nil then
        self:fire()
    end
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self:expire()
    end
end


function Laser:getPosition()
    return self.endX, self.endY
end


function Laser:getDirection()
    return self.endDirection[1], self.endDirection[2]
end


function Laser:draw()
    if self.points == nil or #self.points < 4 then
        return
    end
    local fade = math.max(0, self.lifetime / self.duration)
    local c = self.color

    love.graphics.push("all")
    love.graphics.setLineJoin("bevel")
    -- Wide faint glow, the colored beam, then a bright core
    love.graphics.setBlendMode("add")
    love.graphics.setColor(c[1], c[2], c[3], 0.15 * fade)
    love.graphics.setLineWidth(self.width * 3)
    love.graphics.line(self.points)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(c[1], c[2], c[3], fade)
    love.graphics.setLineWidth(self.width)
    love.graphics.line(self.points)
    love.graphics.setColor(1, 1, 1, 0.8 * fade)
    love.graphics.setLineWidth(math.max(1, self.width * 0.35))
    love.graphics.line(self.points)
    love.graphics.pop()
end

return Laser
