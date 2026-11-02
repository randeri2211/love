local Entity = require "entities.entity"

local Enemy = Entity:new()
registerEntity("Enemy",Enemy)
-- What it drops when it dies: {item, min, max, chance(0-1, 1 when left out)} per entry, rolled one by one
Enemy.loot = {}

function Enemy:new(x, y)
    -- Enemy Attributes
    local enemy = Entity:new(x, y, 20)
    setmetatable(enemy,self)
    self.__index = self

    if x == nil or y == nil then
        return enemy
    end
    print("enemy")
    enemy.radius = 50
    enemy.height = enemy.radius * 2
    enemy.hpBar.regen = 1   -- Enemies do not regen health by default?
    enemy.name = "Enemy"
    enemy.lastPos = {x, y}

    enemy.shape = love.physics.newCircleShape(enemy.radius)
    enemy.fixture = love.physics.newFixture(enemy.body, enemy.shape, 1)
    enemy.fixture:setCategory(ENEMY_CATEGORY)
    enemy.fixture:setGroupIndex(-ENEMY_CATEGORY)
    enemy.fixture:setUserData(enemy)    -- Contacts find the enemy straight from its fixture
    
    -- Enemy Init
    enemy.body:setGravityScale(1)
    enemy.body:setSleepingAllowed(false)
    return enemy
end

-- Enemy Functions
function Enemy:dropLoot()
    -- Rolls the loot table, every entry that comes up drops min to max of its item where the enemy died
    local x, y = self.body:getWorldCenter()
    for i, entry in ipairs(self.loot) do
        if love.math.random() < (entry.chance or 1) then
            map.drops:spawn(entry.item, love.math.random(entry.min or 1, entry.max or entry.min or 1), x, y)
        end
    end
end


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
    self.statsDirty = true  -- Recalculate combat stats with the loaded values
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
    map:releaseHitboxes(self)
    map.enemies:removeEnemy(self)
end


function Enemy:isAwake()
    -- Something is happening to it: a Self spell is on it, it was hit a moment ago, or it is still flying from that
    if next(self.selfEffects or {}) ~= nil then
        return true
    end
    if self.lastHitTime ~= nil and spells.time - self.lastHitTime < ENEMY_AWAKE_TIME then
        return true
    end
    return self.awake == true and not self.grounded
end


function Enemy:keepLoaded()
    -- Blocks only have hitboxes around the player, an awake enemy keeps an area of its own so it can fly and land anywhere
    -- Once nothing is happening and it is on the ground it lets go of it, and freezes there if the player is far
    -- Returns true when it can move this frame
    local x, y = self.body:getWorldCenter()
    local mx, my = loveToMap(math.floor(x / TILE_SIZE) * TILE_SIZE, math.floor(y / TILE_SIZE) * TILE_SIZE)
    self.awake = self:isAwake()
    if self.awake then
        local r = ENEMY_LOAD_RADIUS
        map:updateHitboxes(mx - r, my - r, mx + r, my + r, self)
    else
        map:releaseHitboxes(self)
    end
    local active = map:inHitboxWindow(mx, my)
    if self.body:isActive() ~= active then
        self.body:setActive(active)
    end
    return active
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