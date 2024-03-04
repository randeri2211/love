require "constants"
require "world.world"
require "components.hpBar"
require "components.manaBar"
require "components.movement"
Player = {}

function Player:new(x, y)
    local player = {}
    setmetatable(player,self)
    self.__index = self
    player.radius = PLAYER_WIDTH / 2
    player.body = love.physics.newBody(p_world, x - TILE_SIZE, y, "dynamic")
    player.shapes = {}
    player.grounded = false
    player.jumping = false
    player.shapes[1] = love.physics.newRectangleShape(PLAYER_WIDTH, PLAYER_HEIGHT - PLAYER_WIDTH)
    player.shapes[2] = love.physics.newCircleShape(0, -(PLAYER_HEIGHT - PLAYER_WIDTH) / 2, player.radius)
    player.shapes[3] = love.physics.newCircleShape(0, (PLAYER_HEIGHT - PLAYER_WIDTH) / 2, player.radius)


    player.fixtures = {}
    player.fixtures[1] = love.physics.newFixture(player.body, player.shapes[1], 1)
    player.fixtures[1]:setCategory(PLAYER_CATEGORY)
    player.fixtures[2] = love.physics.newFixture(player.body, player.shapes[2], 1)
    player.fixtures[2]:setCategory(PLAYER_CATEGORY)
    player.fixtures[3] = love.physics.newFixture(player.body, player.shapes[3], 1)
    player.fixtures[3]:setCategory(PLAYER_CATEGORY)
    player.fixture_check = {}
    player.fixture_check[player.fixtures[1]] = true
    player.fixture_check[player.fixtures[2]] = true
    player.fixture_check[player.fixtures[3]] = true


    player.movement = Movement(4 * TILE_SIZE, 4 * TILE_SIZE)

    player.hpBar = HPBar(100, 100, 1)
    player.manaBar = ManaBar(100, 100, 10)

    -- Player Init
    player.body:setGravityScale(1)
    player.body:setSleepingAllowed(false)
    player.body:setFixedRotation(true)
    player.body:setLinearDamping(LINEAR_DAMPING)
    player.up = true

    return player
end

-- Player Functions
function Player:move(dt)
    -- Increase linear velocity according to speed(does'nt depend on time since its using world)
    local moved = false
    local x,y = self.body:getLinearVelocity()
    if love.keyboard.isDown("d") then
        self.body:setLinearVelocity(self.movement.currentSpeed, y)
        moved = true
    end
    local x,y = self.body:getLinearVelocity()
    if love.keyboard.isDown("a") then
        self.body:setLinearVelocity(-self.movement.currentSpeed, y)
        moved = true
    end


    local x,y = self.body:getLinearVelocity()
    if love.keyboard.isDown("space") then
        if self.grounded then
            self.jumping = true
            self.body:setLinearVelocity(x, - self.movement.jumpHeight)
        elseif self.jumping and self.up then
            self.body:setGravityScale(JUMP_GRAVITY_SCALE)
        else
            self.body:setGravityScale(1)
        end
    else
        self.jumping = false
        self.body:setGravityScale(1)
    end
    
    self:stopNoMove(moved)
    self:upDown()
    -- self:linearDamping(moved)
    self:resetSmallVel()
end


function Player:stopNoMove(moved)
    if moved == false then
        local x, y = self.body:getLinearVelocity()
        self.body:setLinearVelocity(0, y)
    end
end


function Player:upDown()
-- Figuring up direction
    local x,y_after = loveToWorld(self.body:getLinearVelocity())
    if y_after < 0.1 then
        if self.up == true then
            self.up = false
            local x, y = loveToWorld(self.body:getWorldCenter())
            -- print("y:"..y)
        end
    elseif y_after > 0.1 then
        if self.up == false then
            self.up = true
        end            
    end
end


function Player:linearDamping(moved)
    if moved == false and Player.grounded == true then
        self.body:setLinearDamping(2)
    else
        self.body:setLinearDamping(LINEAR_DAMPING)
    end
end


function Player:resetSmallVel()
    -- Resets small velocity values to stop flickering at low speeds
    local x,y = self.body:getLinearVelocity()
    if math.abs(x) < 0.001 then
        x = 0
    end
    if math.abs(y) < 0.001 then
        y = 0
    end
    self.body:setLinearVelocity(x, y)
end


function Player:draw()
    -- Get the world center to base all player drawing on
    for i = 1, #self.shapes do
        -- print(tostring(self.shapes[i]))
        if i == 1 then
            love.graphics.polygon("line", self.body:getWorldPoints(self.shapes[i]:getPoints()))
        else
            local x, y = self.shapes[i]:getPoint()
            local b_x, b_y = self.body:getWorldCenter()
            love.graphics.circle("line", x + b_x, y + b_y, self.radius)
        end
    end
    -- myActor:Draw();
end


function Player:prepSave()
    -- Prep the x and y values for saving(easier than trying to save the box and whatever user data)
    self.x, self.y = self.body:getWorldCenter()
end


function Player:load(playerTable)
    -- Gets a table with all the values from the recursiveLoad and sets the player with them
    self.body:setPosition(playerTable.x, playerTable.y)
    self.movement = playerTable.movement
end



