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
    bullet.color = params.color
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
    self.body:setGravityScale(0)
    self.body:setLinearDamping(0)
    self.body:setMass(self.mass)

    self.shape = love.physics.newCircleShape(self.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    self.fixture:setCategory(SPELLS_CATEGORY)
    self.fixture:setGroupIndex(-SPELLS_CATEGORY)

    -- Multiply the direction by speed
    self:updateVel()
end


function Bullet:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        spells:trigger(self, "onExpire")
        spells:destroy(self)
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