require "constants"
require "world.world"
require "components.hpBar"
require "components.manaBar"
require "components.movement"
require "entities.entity"
require "keys"
require "system_utils"

Player = Entity:new()
AS = 25
AD = 1
-- AS / (self.movement.currentSpeed * AD) = 0.3

function Player:new(x, y)
    local player = Entity:new(x, y, 100, PLAYER_MOVE_SPEED, PLAYER_JUMP_HEIGHT)
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
    player.direction = ""
    player.last_direction = player.direction

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


    -- player.movement = Movement(4 * TILE_SIZE, 4 * TILE_SIZE)

    -- player.hpBar = HPBar(100, 100, 1)
    player.manaBar = ManaBar(100, 100, 10)

    -- Player Init
    player.body:setGravityScale(1)
    player.body:setSleepingAllowed(false)
    player.body:setFixedRotation(true)
    player.body:setLinearDamping(LINEAR_DAMPING)
    player.up = true
    player:animationSetup()

    return player
end

-- Player Functions
function Player:updateAnimation()
    if self.direction == 'right' then
        self.anim.bones['right_hand']:SetLayer(1)
        self.anim.bones['left_hand']:SetLayer(4)
        self.anim.bones['right_leg']:SetLayer(1)
        self.anim.bones['left_leg']:SetLayer(3)
    elseif self.direction == 'left' then
        self.anim.bones['right_hand']:SetLayer(4)
        self.anim.bones['left_hand']:SetLayer(1)
        self.anim.bones['right_leg']:SetLayer(3)
        self.anim.bones['left_leg']:SetLayer(1)
    end
end

function Player:move()
    -- Increase linear velocity according to speed(doesn't depend on time since its using world)
    local moved = false
    local x,y = self.body:getLinearVelocity()
    if love.keyboard.isDown(RIGHT_KEY) then
        self.body:setLinearVelocity(self.movement.currentSpeed, y)
        moved = true
        if self.direction ~= 'right' then
            self.direction = 'right'
            self.last_direction = self.direction
            self.anim.actor:GetTransformer():SetTransform("player", self.animations["right"].animation)
            -- self.anim.bones['right_hand']:SetLayer(1)
            -- self.anim.bones['left_hand']:SetLayer(4)
            -- self.anim.bones['right_leg']:SetLayer(1)
            -- self.anim.bones['left_leg']:SetLayer(3)
            self.anim.actor:GetTransformer():SetPower("player", 1)
        end
    end
    local x,y = self.body:getLinearVelocity()
    if love.keyboard.isDown(LEFT_KEY) then
        self.body:setLinearVelocity(-self.movement.currentSpeed, y)
        moved = true
        if self.direction ~= 'left' then
            self.direction = 'left'
            self.last_direction = self.direction
            self.anim.actor:GetTransformer():SetTransform("player", self.animations["left"].animation)
            -- self.anim.bones['right_hand']:SetLayer(4)
            -- self.anim.bones['left_hand']:SetLayer(1)
            -- self.anim.bones['right_leg']:SetLayer(3)
            -- self.anim.bones['left_leg']:SetLayer(1)
            self.anim.actor:GetTransformer():SetPower("player", 1)
        end
    end


    local x,y = self.body:getLinearVelocity()
    if love.keyboard.isDown(JUMP_KEY) then
        self.moving = true
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

    self:moveControl(moved)
    self:upDown()
    -- self:linearDamping(moved)
    self:resetSmallVel()
end

function Player:interact()
    if love.keyboard.isDown(INTERACT_KEY) then
        -- Get mouse position
        local mx, my = mouseToWorld()
        local px, py = loveToWorld(self.body:getWorldCenter())
        print(distance(px, py, mx, my))
        if distance(px, py, mx, my) < INTERACT_DISTANCE then
            mx, my = worldToMap(mx, my)
            if map.map[mx][my] ~= nil then
                -- Check if the block implements the interact function
                if type(map.map[mx][my].interact) == "function" then
                    map.map[mx][my]:interact()
                end
            end
        end
    end
end


function Player:update()
    player:move()
    player:interact()
    groundRay()
end


function Player:moveControl(moved)
    -- Handles movement after keypress
    if moved == false then
        self.anim.actor:GetTransformer():SetPower("player", 0)
        self.direction = ''
        local x, y = self.body:getLinearVelocity()
        self.body:setLinearVelocity(0, y)
    end
    local x, y = self.body:getWorldCenter()
    self.anim.actor:GetTransformer():GetRoot().translation = {x , y - PLAYER_HEIGHT / 2 + TILE_SIZE / 3}
    
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
    -- Determines linear damping at every moment
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


function Player:load(playerTable)
    -- Gets a table with all the values from the recursiveLoad and sets the player with them
    self.body:setPosition(playerTable.x, playerTable.y)
    self.movement = playerTable.movement
    self.direction = playerTable.last_direction
    self.last_direction = playerTable.last_direction
    self.hpBar = playerTable.hpBar
    self.manaBar = playerTable.manaBar
end

-- Animations

function Player:animationSetup()
    -- local path = "assets/paneling_small.png"
    -- local imgData = love.image.newImageData(path)
    -- local path2 = "assets/grass.png"
    -- local imgData2 = love.image.newImageData(path2)

    local headHeight = TILE_SIZE / 3
    local headhWidth = TILE_SIZE / 3
    local torsoHeight = TILE_SIZE 
    local torsoWidth = TILE_SIZE / 2
    local legHeight = PLAYER_HEIGHT - torsoHeight - headHeight
    local legWidth = TILE_SIZE/ 3
    local handHeight = torsoHeight * 4 / 3
    local handWidth = legWidth

    -- Creating a table to hold all the animations
    self.animations = {}
    -- Creating the body
    self.anim = Animateable:new();


    local leftHandData = love.image.newImageData(handHeight, handWidth);
    leftHandData:mapPixel(fullRed)
    
    local rightHandData = love.image.newImageData(handHeight, handWidth);
    rightHandData:mapPixel(fullBlue)

    -- Adding all the bones
    self.anim:addBone("torso", nil, 2, {0, 0}, torsoWidth, torsoHeight)
    self.anim:addBone("head", "torso", 2,{-headHeight, 0}, headhWidth, headHeight)
    self.anim:addBone("right_leg", "torso", 1, {torsoHeight, 0}, legWidth, legHeight)
    self.anim:addBone("left_leg", "torso", 3, {torsoHeight, 0}, legWidth, legHeight)
    self.anim:addBone("right_hand", "torso", 1, {0, 0}, handWidth, handHeight, rightHandData)
    self.anim:addBone( "left_hand", "torso", 4, {0, 0}, handWidth, handHeight, leftHandData)

    -- Creating the actor AFTER adding all the bones
    self.anim:newActor()
    
    -- Setting all the attachments
    self.anim:SetAttachment("head")
    self.anim:SetAttachment("torso")
    self.anim:SetAttachment("right_hand")
    self.anim:SetAttachment("left_hand")
    self.anim:SetAttachment("right_leg")
    self.anim:SetAttachment("left_leg")

    self.anim.actor:GetTransformer():GetRoot().rotation = math.rad(90)
    -- self.anim.actor:GetTransformer():GetRoot().translation = {love.graphics.getWidth() / 2 , love.graphics.getHeight() / 2 - PLAYER_HEIGHT / 2 + headHeight}
    local x, y = self.body:getWorldCenter()
    self.anim.actor:GetTransformer():GetRoot().translation = {x , y}

    -- Creating a new animation for the body
    self.animations["right"] = Animation:new(self.anim.skeleton)
    self.animations["left"] = Animation:new(self.anim.skeleton)

    -- Adding animation frames
    self:rightAnimation()
    self:leftAnimation()

    -- Choosing animation to display
    self.anim.actor:GetTransformer():SetTransform("player", self.animations["left"].animation)
end


function Player:rightAnimation()
    self.animations["right"]:newAnimation()
    self.animations["right"]:AddKeyFrame("head", 0, math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("torso", 0, math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("right_hand", 0, math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("left_hand", 0, math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("right_leg", 0, math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("left_leg", 0, math.rad(0), nil, nil)

    self.animations["right"]:AddKeyFrame("head", 1 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("torso", 1 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("right_hand", 1 * AS / (self.movement.currentSpeed * AD), math.rad(45), nil, nil)
    self.animations["right"]:AddKeyFrame("left_hand", 1 * AS / (self.movement.currentSpeed * AD), math.rad(-45), nil, nil)
    self.animations["right"]:AddKeyFrame("right_leg", 1 * AS / (self.movement.currentSpeed * AD), math.rad(30), nil, nil)
    self.animations["right"]:AddKeyFrame("left_leg", 1 * AS / (self.movement.currentSpeed * AD), math.rad(-30), nil, nil)

    self.animations["right"]:AddKeyFrame("head", 3 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("torso", 3 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("right_hand", 3 * AS / (self.movement.currentSpeed * AD), math.rad(-45), nil, nil)
    self.animations["right"]:AddKeyFrame("left_hand", 3 * AS / (self.movement.currentSpeed * AD), math.rad(45), nil, nil)
    self.animations["right"]:AddKeyFrame("right_leg", 3 * AS / (self.movement.currentSpeed * AD), math.rad(-30), nil, nil)
    self.animations["right"]:AddKeyFrame("left_leg", 3 * AS / (self.movement.currentSpeed * AD), math.rad(30), nil, nil)

    self.animations["right"]:AddKeyFrame("head", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("torso", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("right_hand", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("left_hand", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("right_leg", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["right"]:AddKeyFrame("left_leg", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
end


function Player:leftAnimation()
    self.animations["left"]:newAnimation()
    self.animations["left"]:AddKeyFrame("head", 0, math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("torso", 0, math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("right_hand", 0, math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("left_hand", 0, math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("right_leg", 0, math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("left_leg", 0, math.rad(0), nil, nil)

    self.animations["left"]:AddKeyFrame("head", 1 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("torso", 1 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("right_hand", 1 * AS / (self.movement.currentSpeed * AD), math.rad(-45), nil, nil)
    self.animations["left"]:AddKeyFrame("left_hand", 1 * AS / (self.movement.currentSpeed * AD), math.rad(45), nil, nil)
    self.animations["left"]:AddKeyFrame("right_leg", 1 * AS / (self.movement.currentSpeed * AD), math.rad(30), nil, nil)
    self.animations["left"]:AddKeyFrame("left_leg", 1 * AS / (self.movement.currentSpeed * AD), math.rad(-30), nil, nil)

    self.animations["left"]:AddKeyFrame("head", 3 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("torso", 3 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("right_hand", 3 * AS / (self.movement.currentSpeed * AD), math.rad(45), nil, nil)
    self.animations["left"]:AddKeyFrame("left_hand", 3* AS / (self.movement.currentSpeed * AD), math.rad(-45), nil, nil)
    self.animations["left"]:AddKeyFrame("right_leg", 3 * AS / (self.movement.currentSpeed * AD), math.rad(-30), nil, nil)
    self.animations["left"]:AddKeyFrame("left_leg", 3 * AS / (self.movement.currentSpeed * AD), math.rad(30), nil, nil)

    self.animations["left"]:AddKeyFrame("head", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("torso", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("right_hand", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("left_hand", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("right_leg", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
    self.animations["left"]:AddKeyFrame("left_leg", 4 * AS / (self.movement.currentSpeed * AD), math.rad(0), nil, nil)
end


function fullWhite(x, y, r, g, b, a) 
    return 255, 255, 255, 255
end

function fullBlue(x, y, r, g, b, a)
    return 0, 0, 255, 255
end

function fullRed(x, y, r, g, b, a)
    return 255, 0, 0, 255
end
