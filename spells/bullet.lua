require "spells.form"

Bullet = Form:new()

function Bullet:new(player, speed, radius, imagePath)
    local bullet = Form:new(player)
    setmetatable(bullet,self)
    self.__index = self

    if player == nil then
        return bullet
    end

    bullet.radius = radius
    bullet.speed = speed

    local px, py = player.body:getWorldCenter()
    local mx, my = mouseToLove()
    bullet.direction = {mx - px, my - py}
    bullet.body = love.physics.newBody(p_world, px, py, "dynamic")
    bullet.shape = love.physics.newCircleShape(bullet.radius)
    bullet.fixture = love.physics.newFixture(bullet.body, bullet.shape, 1)
    bullet.fixture:setCategory(SPELLS_CATEGORY)

    bullet.body:setLinearVelocity(bullet.direction[1] * bullet.speed, bullet.direction[2] * bullet.speed)

    bullet.imagePath = imagePath
    bullet.image = BLOCK_IMG[bullet.imagePath]
    return bullet
end

function Bullet:update(dt)

end


function Bullet:draw()
    function circleStencil()
        local x, y = self.body:getWorldCenter()
        love.graphics.circle("fill", x, y, self.radius)
    end
    -- Apply the stencil
    love.graphics.stencil(circleStencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local x, y = self.body:getWorldCenter()
    -- Draw the square image
    love.graphics.draw(self.image, x - self.radius, y - self.radius, 0, self.radius * 2 / self.image:getWidth(), self.radius * 2 / self.image:getHeight())
    -- Remove the stencil
    love.graphics.setStencilTest()
end