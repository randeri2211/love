require "forms.form"

Bullet = Form:new()

function Bullet:new(player, speed, radius, imagePath)
    local bullet = Form:new(player)
    setmetatable(bullet,self)
    self.__index = self

    if player == nil then
        return bullet
    end

    bullet.form = "bullet"
    bullet.radius = radius
    bullet.speed = speed

    local px, py = player.body:getWorldCenter()
    local mx, my = mouseToLove()
    bullet.direction = {mx - px, my - py}
    bullet.body = love.physics.newBody(p_world, px, py, "dynamic")
    bullet.body:setBullet(true)
    bullet.body:setGravityScale(0)
    bullet.body:setLinearDamping(0)
    bullet.body:setMass(0)

    bullet.shape = love.physics.newCircleShape(bullet.radius)
    bullet.fixture = love.physics.newFixture(bullet.body, bullet.shape, 1)
    bullet.fixture:setCategory(SPELLS_CATEGORY)

    -- Normalize the direction vector and multiply by speed
    bullet:updateVel()
    
    bullet.imagePath = imagePath
    bullet.image = BLOCK_IMG[bullet.imagePath]
    return bullet
end


function Bullet:updateVel()
    -- Normalize the direction vector and multiply by speed
    local velSize = math.sqrt(self.direction[1]^2 + self.direction[2]^2)
    self.vel = {self.direction[1] * self.speed / velSize, self.direction[2] * self.speed / velSize}
    -- print("velx "..tostring(self.vel[1]).."\nvely "..tostring(self.vel[2]))
    
    self.body:setLinearVelocity(self.vel[1], self.vel[2])
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