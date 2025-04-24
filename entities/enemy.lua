local Entity = require "entities.entity"

local Enemy = Entity:new()
registerEntity("Enemy",Enemy)

function Enemy:new(x, y)
    -- Enemy Attributes
    local enemy = Entity:new(x, y, 20)
    setmetatable(enemy,self)
    self.__index = self

    if x == nil or y == nil then
        return enemy
    end

    enemy.radius = 50
    enemy.height = enemy.radius * 2
    enemy.hpBar.regen = 1   -- Enemies do not regen health by default?
    enemy.name = "Enemy"
    enemy.lastPos = {x, y}

    enemy.shape = love.physics.newCircleShape(enemy.radius)
    enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape, 1)
    enemy.fixture:setCategory(ENEMY_CATEGORY)
    enemy.fixture:setGroupIndex(-ENEMY_CATEGORY)
    
    -- Enemy Init
    enemy.body:setGravityScale(1)
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


function Enemy:isFixture(fixture)
    return fixture == self.fixture
end

function Enemy:destroy()
    Entity.destroy(self)
    map.enemies:removeEnemy(self)
end

function Enemy:update(dt)
    Entity.update(self,dt)
    groundRay(self)
    local vx, vy = self.body:getLinearVelocity()
    local px, py = player.body:getWorldCenter()
    local x, y = self.body:getWorldCenter()
    
    if px - x > 0 then
        vx = self.movement.maxSpeed
    else
        vx = -self.movement.maxSpeed
    end

    if (y - py > TILE_SIZE * 2 and self.grounded) or -- Player too high and can jump
    x == self.lastPos[1] then                        -- Havent moved,might be stuck on a block
        vy = -self.movement.jumpHeight
    end

    self.body:setLinearVelocity(vx, vy)

    self.lastPos = {x, y}


end

return Enemy