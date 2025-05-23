local Enemy = require "entities.enemy"

local Enemy1 = Enemy:new()
registerEntity("Enemy1",Enemy1)

function Enemy1:new(x, y)
    local enemy1 = Enemy:new(x, y)
    setmetatable(enemy1,self)
    self.__index = self
    enemy1.fixture:setMask(SPELLS_CATEGORY, ENEMY_CATEGORY)
    enemy1.name = "Enemy1"
    print("enemy 1")
    return enemy1
end

function Enemy1:draw()
    love.graphics.setColor(0, 1, 0, 1)
    local x, y = self.body:getWorldCenter()
    love.graphics.circle("fill",x, y,self.radius)
    love.graphics.setColor(1, 1, 1, 1)
end

return Enemy1