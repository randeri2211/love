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
    laser.bend = params.bend         -- Gravity, how much the beam curves
    laser.gravityX, laser.gravityY = params.gravityX, params.gravityY   -- Way it curves, down unless Gravity has an arrow
    laser.pierce = params.pierce     -- Pierce, enemies and blocks the beam passes through
    laser.lifetime = params.lifetime -- How long the beam stays visible
    laser.duration = params.lifetime
    laser.color = params.color

    laser.x, laser.y = x, y
    laser.direction = {dirX, dirY}
    laser.points = nil      -- Beam path, traced on the first update once the spell is registered
    laser.held = false      -- A held laser stays while its caster holds the cast(see hold)

    return laser
end


function Laser:castSegment(x1, y1, x2, y2, passed)
    -- Closest thing on the segment: blocks from the map(buried blocks have no hitbox), everything else from physics
    -- Ignores the caster, other spells, things that ignore spells and whatever the beam already pierced(passed)
    -- The player and every enemy can be hit, an enemy beam hits the player and other enemies
    local closest = nil
    p_world:rayCast(x1, y1, x2, y2, function(fixture, x, y, xn, yn, fraction)
        local category = fixture:getCategory()
        if category == SPELLS_CATEGORY or category == BLOCKS_CATEGORY or fixture:isSensor() then
            return -1   -- Ignore this fixture and keep going
        end
        for i, masked in ipairs({fixture:getMask()}) do
            if masked == SPELLS_CATEGORY then
                return -1
            end
        end
        local entity = getEntityFromFixture(fixture)
        if entity ~= nil and (passed[entity] or self:isCaster(entity)) then
            return -1
        end
        closest = {x = x, y = y, nx = xn, ny = yn, fixture = fixture, entity = entity, fraction = fraction}
        return fraction     -- Only look for closer hits from now on
    end)

    local block = map:castRay(x1, y1, x2, y2, function(block) return passed[block] end)
    if block ~= nil and (closest == nil or block.fraction < closest.fraction) then
        closest = {x = block.x, y = block.y, nx = block.nx, ny = block.ny, entity = block.block, fraction = block.fraction}
    end
    return closest
end


function Laser:fire()
    -- Traces the beam, hitting and reflecting off whatever it touches
    local x, y = self.x, self.y
    local dx, dy = self.direction[1], self.direction[2]
    local travelled = 0
    local bounces = self.bounces
    local pierce = self.pierce
    local damaged = {}      -- Each thing is only hit once per beam
    local passed = {}       -- Things the beam pierced, it goes on through them
    self.points = {x, y}

    for step = 1, MAX_STEPS do
        if travelled >= self.reach then
            break
        end
        local length = math.min(SEGMENT, self.reach - travelled)
        local hit = self:castSegment(x, y, x + dx * length, y + dy * length, passed)

        if hit ~= nil and pierce > 0 and hit.entity ~= nil then
            -- Pierce, hit it and keep going the same way from where it was hit
            pierce = pierce - 1
            passed[hit.entity] = true
            damaged[hit.entity] = true
            self:tryHit(hit.entity, hit.entity, hit.x, hit.y, dx, dy)
            travelled = travelled + distance(x, y, hit.x, hit.y)
            x, y = hit.x, hit.y
        elseif hit ~= nil then
            table.insert(self.points, hit.x)
            table.insert(self.points, hit.y)
            travelled = travelled + distance(x, y, hit.x, hit.y)

            -- Reflect across the surface normal(works for either normal sign)
            local dot = dx * hit.nx + dy * hit.ny
            local rx, ry = dx - 2 * dot * hit.nx, dy - 2 * dot * hit.ny
            local key = hit.entity or hit.fixture
            if not damaged[key] then
                damaged[key] = true
                self:tryHit(key, hit.entity, hit.x, hit.y, rx, ry, dx, dy)
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

            -- Gravity bends the beam a little every step
            if self.bend ~= 0 then
                dx = dx + self.gravityX * self.bend * BEND_PER_PIXEL * length
                dy = dy + self.gravityY * self.bend * BEND_PER_PIXEL * length
                local size = math.sqrt(dx * dx + dy * dy)
                dx, dy = dx / size, dy / size
            end
        end
    end

    -- onExpire child spells start where the beam ends, going the way it was going
    self.endX, self.endY = x, y
    self.endDirection = {dx, dy}
end


function Laser:tryHit(key, entity, x, y, dirX, dirY, pushX, pushY)
    -- A beam cast once hits everything it touches, a held one hits each thing at most once per interval
    if self.held then
        local last = self.lastHit[key]
        if last ~= nil and spells.time - last < self.interval then
            return
        end
        self.lastHit[key] = spells.time
    end
    self:hit(entity, x, y, dirX, dirY, pushX, pushY)
end


function Laser:hold(angle, interval, manaCost, push)
    -- Makes it a held laser(see Spell:spawnVolley): angle is its place in a Split fan around the aim,
    -- interval the seconds between hits on one thing and between mana payments, push the Recoil of one cast
    self.held = true
    self.holdAngle = angle
    self.interval = math.max(interval, 1 / 60)
    self.manaCost = manaCost
    self.push = push
    self.lastHit = {}           -- When each thing was last hit
    self.payTime = self.interval    -- The first interval was paid by the cast
end


function Laser:release()
    -- The caster let go, the beam fades out and ends like a laser cast once(onExpire children go off where it ends)
    if self.held then
        self.held = false
        self.lifetime = LASER_RELEASE_FADE
        self.duration = LASER_RELEASE_FADE
    end
end


function Laser:updateHeld(dt)
    -- Follows the caster aim every frame, pays and pushes once per interval, runs out with the mana
    local caster = self.player
    local cx, cy = caster.body:getWorldCenter()
    local mx, my = mouseToLove()
    local ax, ay = mx - cx, my - cy
    local size = math.sqrt(ax * ax + ay * ay)
    if size < 0.001 then
        ax, ay, size = 1, 0, 1
    end
    ax, ay = ax / size, ay / size
    local c, s = math.cos(self.holdAngle), math.sin(self.holdAngle)
    local dx, dy = ax * c - ay * s, ax * s + ay * c
    if caster.castOrigin ~= nil then
        self.x, self.y = caster:castOrigin(dx, dy)
    else
        self.x, self.y = cx, cy
    end
    self.direction = {dx, dy}
    if caster.castAt ~= nil then
        caster:castAt(ax, ay)       -- Hands stay up toward the aim
    end

    self.payTime = self.payTime - dt
    if self.payTime <= 0 then
        if caster.manaBar.currentMana < self.manaCost then
            self:release()
            return
        end
        caster.manaBar.currentMana = caster.manaBar.currentMana - self.manaCost
        self.payTime = self.payTime + self.interval
        if self.push ~= nil then
            self.push(ax, ay)
        end
    end
    self:fire()
end


function Laser:update(dt)
    if self.held then
        self:updateHeld(dt)
        return
    end
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


function Laser:light(add)
    -- Every tile along the beam, fading with it
    local points = self.points
    if points == nil or #points < 4 then
        return
    end
    local strength = self:lightStrength(LASER_LIGHT) * math.max(0, self.lifetime / self.duration)
    local color = self.color or {1, 1, 1}
    for i = 1, #points - 3, 2 do
        local x1, y1, x2, y2 = points[i], points[i + 1], points[i + 2], points[i + 3]
        local steps = math.max(1, math.ceil(distance(x1, y1, x2, y2) / TILE_SIZE))
        for s = 0, steps do
            add(x1 + (x2 - x1) * s / steps, y1 + (y2 - y1) * s / steps, color, strength)
        end
    end
end


function Laser:fxSpot()
    -- A random spot along the beam, a long beam sparkles all along
    local points = self.points
    if points == nil or #points < 4 then
        return nil
    end
    local i = love.math.random(1, #points / 2 - 1) * 2 - 1
    local t = love.math.random()
    return points[i] + (points[i + 2] - points[i]) * t, points[i + 1] + (points[i + 3] - points[i + 1]) * t, self.width / 2, 90
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
