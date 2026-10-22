local Form = require "forms.form"

local Bullet = Form:new()

function Bullet:new(caster, params, x, y, dirX, dirY)
    local bullet = Form:new(caster)
    setmetatable(bullet,self)
    self.__index = self

    if caster == nil then
        return bullet
    end

    -- Values from the compiled spell params
    bullet.mass = 1
    bullet.form = "bullet"
    bullet.radius = params.radius
    bullet.speed = params.speed
    bullet.lifetime = params.lifetime
    bullet.damage = params.damage
    bullet.terrainDamage = params.terrainDamage
    bullet.color = params.color
    bullet.gravityScale = params.gravityScale   -- Gravity makes the bullet fall in an arc
    bullet.bounces = params.bounces             -- Rebound, contacts left before the bullet breaks
    bullet.pierce = params.pierce               -- Enemies and blocks left it can pass through
    bullet.pierced = {}                         -- Fixtures it is passing through, their contacts stay off
    bullet.imagePath = params.imagePath
    bullet.image = BLOCK_IMG[bullet.imagePath]

    bullet:shoot(x, y, dirX, dirY)
    return bullet
end


function Bullet:updateVel()
    -- multiply by speed
    self.vel = {self.direction[1] * self.speed, self.direction[2] * self.speed}
    -- print("velx "..tostring(self.vel[1]).."\nvely "..tostring(self.vel[2]))
    self.body:setLinearVelocity(self.vel[1], self.vel[2])
end


function Bullet:shoot(x, y, dirX, dirY)
    -- Direction comes normalized from the spell
    self.direction = {dirX, dirY}
    self.body = love.physics.newBody(p_world, x + self.radius * self.direction[1], y + self.radius * self.direction[2], "dynamic")
    self.body:setBullet(true)
    self.body:setGravityScale(self.gravityScale)
    self.body:setLinearDamping(0)
    self.body:setMass(self.mass)

    self.shape = love.physics.newCircleShape(self.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    self.fixture:setCategory(SPELLS_CATEGORY)
    self.fixture:setGroupIndex(-SPELLS_CATEGORY)

    -- Bouncing bullets keep their speed off every surface
    if self.bounces > 0 then
        self.fixture:setRestitution(1)
        self.fixture:setFriction(0)
    end

    -- Multiply the direction by speed
    self:updateVel()
end


function Bullet:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self:expire()
    end
end


function Bullet:getDirection()
    -- Current flight direction, gravity and bounces change it from the cast direction
    local vx, vy = self.body:getLinearVelocity()
    local size = math.sqrt(vx * vx + vy * vy)
    if size < 0.001 then
        return self.direction[1], self.direction[2]
    end
    return vx / size, vy / size
end


function Bullet:onContact(fixture, entity, contact)
    if self.pierced[fixture] then
        return
    end
    local dx, dy = self:getDirection()

    -- Pierce, enemies and blocks are hit and passed through(children keep the bullet direction)
    -- Blocks take the terrain damage as usual, every block or enemy passed uses one pierce
    if self.pierce > 0 and entity ~= nil then
        self.pierce = self.pierce - 1
        self.pierced[fixture] = true
        contact:setEnabled(false)
        local x, y = self.body:getWorldCenter()
        self:hit(entity, x, y, dx, dy)
        return
    end

    -- Child spells bounce off the hit surface(reflect the direction across the normal, works for either normal sign)
    local nx, ny = contact:getNormal()
    local dot = dx * nx + dy * ny
    -- Children start at the contact point, the bullet center is up to a radius away from it
    local x, y = contact:getPositions()
    if x == nil then
        x, y = self.body:getWorldCenter()
    end
    self:hit(entity, x, y, dx - 2 * dot * nx, dy - 2 * dot * ny)

    if self.bounces > 0 then
        -- Rebound, the physics bounces the body off the surface
        self.bounces = self.bounces - 1
    else
        spells:destroy(self)
    end
end


function Bullet:preSolve(fixture, contact)
    -- Physics turns contacts back on every step, so the ones it is piercing are turned off again
    if self.pierced[fixture] then
        contact:setEnabled(false)
    end
end


function Bullet:draw()
    function circleStencil()
        local x, y = self.body:getWorldCenter()
        local radius = self.shape:getRadius()
        love.graphics.circle("fill", x, y, radius)
    end
    local vx, vy = self.body:getLinearVelocity()
    local s = math.sqrt(vx * vx + vy * vy)
    -- Apply the stencil
    love.graphics.stencil(circleStencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local x, y = self.body:getWorldCenter()
    -- Draw the square image tinted with the spell color
    love.graphics.setColor(self.color)
    love.graphics.draw(self.image, x - self.radius, y - self.radius, 0, self.radius * 2 / self.image:getWidth(), self.radius * 2 / self.image:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    -- Remove the stencil
    love.graphics.setStencilTest()
end


function Bullet:isFixture(fixture)
    return self.fixture == fixture
end


function Bullet:destroy()
    self.body:destroy()
end

return Bullet
