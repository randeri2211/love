local Form = require "forms.form"

local Bullet = Form:new()

function Bullet:new(player, speed, radius, imagePath)
    local bullet = Form:new(player)
    setmetatable(bullet,self)
    self.__index = self

    if player == nil then
        return bullet
    end

    bullet.mass = 1
    bullet.form = "bullet"
    bullet.radius = radius
    bullet.speed = speed
    bullet.lifetime = 2
    bullet.imagePath = imagePath
    bullet.image = BLOCK_IMG[bullet.imagePath]
    return bullet
end


function Bullet:updateVel()
    -- multiply by speed
    self.vel = {self.direction[1] * self.speed, self.direction[2] * self.speed}
    -- print("velx "..tostring(self.vel[1]).."\nvely "..tostring(self.vel[2]))
    self.body:setLinearVelocity(self.vel[1], self.vel[2])
end


function Bullet:shoot()
    local px, py = player.body:getWorldCenter()
    local mx, my = mouseToLove()
    self.direction = {mx - px, my - py}
    local velSize = math.sqrt(self.direction[1]^2 + self.direction[2]^2)
    self.direction = {self.direction[1] / velSize, self.direction[2] / velSize}
    self.body = love.physics.newBody(p_world, px + self.radius * self.direction[1], py + self.radius * self.direction[2], "dynamic")
    self.body:setBullet(true)
    self.body:setGravityScale(0)
    self.body:setLinearDamping(0)
    self.body:setMass(self.mass)

    self.shape = love.physics.newCircleShape(self.radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    self.fixture:setCategory(SPELLS_CATEGORY)
    self.fixture:setGroupIndex(-SPELLS_CATEGORY)

    -- Normalize the direction vector and multiply by speed
    self:updateVel()
end


function Bullet:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
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
    -- Draw the square image
    love.graphics.draw(self.image, x - self.radius, y - self.radius, 0, self.radius * 2 / self.image:getWidth(), self.radius * 2 / self.image:getHeight())
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