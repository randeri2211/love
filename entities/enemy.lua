require "components.hpBar"
require "entities.entity"

Enemy = Entity:new()
registerEntity("Enemy",Enemy)

function Enemy:new(x, y)
    -- Enemy Attributes
    local enemy = Entity:new(x, y, 100, 0, 0)
    setmetatable(enemy,self)
    self.__index = self
    enemy.radius = 50
    enemy.hpBar = HPBar(50, 50, 0)
    enemy.name = "Enemy"

    if x == nil or y == nil then
        return enemy
    end
    enemy.shape = love.physics.newCircleShape(enemy.radius)
    enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape, 1)

    -- Enemy Init
    enemy.body:setGravityScale(0)
    enemy.body:setSleepingAllowed(false)
    return enemy
end

-- Enemy Functions
function Enemy:draw()
    local x, y = self.body:getWorldCenter()
    love.graphics.circle("fill",x, y,self.radius)
end

function Enemy:move(x, y)
    self.body:setLinearVelocity(x, y)
end    


function Enemy:load(enemyTable)
    -- Loads the enemy from a loaded table
    self.hpBar = enemyTable.hpBar
    self.radius = enemyTable.radius
    self.shape:setRadius(self.radius)
    self.fixture:destroy()
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    
end

function Enemy:wakeUp()
    if self.body:isAwake() == false then
        self.body:wakeUp()
    end
end



