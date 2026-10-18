local ManaBar = require "components.manaBar"
local Spellbooks = require "magic.spellbooks"
local Entity = require "entities.entity"
local Animateable = require "animations.animateable"
local Animation = require "animations.animation"

local Player = Entity:new()
AS = 25
AD = 1

-- Cast pose(see Player:castAt)
CAST_HAND_BONES = {"right_hand", "left_hand"}
CAST_HAND_SPREAD = math.rad(8)  -- Small angle between the two hands so they dont draw on top of each other
CAST_POSE_HOLD = 0.3            -- Seconds the hands stay up after the last cast
CAST_POSE_OUT_SPEED = 4         -- How fast it blends back to the walk
-- AS / (self.movement.currentSpeed * AD) = 0.3

function Player:new(x, y, name)
    local player = Entity:new(x, y, BASE_HP)
    setmetatable(player,self)
    self.__index = self

    player.name = name
    player.spawnX, player.spawnY = x, y     -- Where the player comes back after dying

    player.grounded = false
    player.jumping = false
    player.direction = ""
    player.last_direction = player.direction

    player:setScale(1)
    
    player.manaBar = ManaBar(100, 100, 10)
    player.spellbook = Spellbooks.default()    -- Loading a world replaces it with the saved one

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
function Player:debugDraw()
    local bx, by = self.body:getWorldCenter()
    local x, y = self.shapes[2]:getPoint()
    love.graphics.circle("line", bx, by + y, self.radius)
    local x, y = self.shapes[3]:getPoint()
    love.graphics.circle("line", bx, by + y, self.radius)
end

function Player:setBody()
    local x, y = self.body:getWorldCenter()
    self.body = love.physics.newBody(p_world, x, y, "dynamic")
    
    self.shapes = {}
    self.shapes[1] = love.physics.newRectangleShape(self.width * 0.9, self.height - self.radius * 2)
    self.shapes[2] = love.physics.newCircleShape(0, -(self.height - self.width) / 2, self.radius)
    self.shapes[3] = love.physics.newCircleShape(0, (self.height - self.width) / 2, self.radius)

    self.fixtures = {}
    self.fixtures[1] = love.physics.newFixture(self.body, self.shapes[1], 1)
    self.fixtures[1]:setCategory(PLAYER_CATEGORY)
    self.fixtures[1]:setGroupIndex(-PLAYER_CATEGORY)
    self.fixtures[1]:setMask(SPELLS_CATEGORY, PLAYER_CATEGORY)
    self.fixtures[2] = love.physics.newFixture(self.body, self.shapes[2], 1)
    self.fixtures[2]:setCategory(PLAYER_CATEGORY)
    self.fixtures[2]:setGroupIndex(-PLAYER_CATEGORY)
    self.fixtures[2]:setMask(SPELLS_CATEGORY, PLAYER_CATEGORY)
    self.fixtures[3] = love.physics.newFixture(self.body, self.shapes[3], 1)
    self.fixtures[3]:setCategory(PLAYER_CATEGORY)
    self.fixtures[3]:setGroupIndex(-PLAYER_CATEGORY)
    self.fixtures[3]:setMask(SPELLS_CATEGORY, PLAYER_CATEGORY)

    for i, fixture in pairs(self.fixtures) do
        fixture:setRestitution(0)
    end

    self.fixture_check = {}
    -- self.fixture_check[self.fixtures[1]] = true
    self.fixture_check[self.fixtures[2]] = true
    self.fixture_check[self.fixtures[3]] = true

end

function Player:setScale(scale)
    self.scale = scale
    self.width = PLAYER_WIDTH * self.scale
    self.height = PLAYER_HEIGHT * self.scale
    self.radius = self.width / 2
    self:setBody()
end

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
        self.body:setLinearVelocity(self.movement.maxSpeed, y)
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
        self.body:setLinearVelocity(-self.movement.maxSpeed, y)
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

    -- Knockback(like spell recoil) on top of walking
    if self.movement.pushX ~= nil and self.movement.pushX ~= 0 then
        local vx, vy = self.body:getLinearVelocity()
        self.body:setLinearVelocity(vx + self.movement.pushX, vy)
    end

    self:upDown()
    -- self:linearDamping(moved)
    self:resetSmallVel()
end

function Player:interact()
    -- Get mouse position in block coordinates
    local mx, my = mouseToMap()
    -- Get player position in world coordinates
    local px, py = self:mapCenter()
    py = py + 1
    if distance(px, py, mx, my) < INTERACT_DISTANCE then
        local block = map:get(mx, my)
        -- Check if the block implements the interact function
        if block ~= nil and type(block.interact) == "function" then
            block:interact()
        end
    end
end


function Player:update(dt)
    Entity.update(self, dt)
    self:move()
    groundRay(self)
    self:updateCastPose(dt)
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
    self.anim.actor:GetTransformer():GetRoot().translation = {x , y - self.height / 3}
    
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
    if moved == false and self.grounded == true then
        self.body:setLinearDamping(2)
    else
        self.body:setLinearDamping(LINEAR_DAMPING)
    end
end


function Player:resetSmallVel()
    -- Resets small velocity values to stop flickering at low speeds
    local x, y = self.body:getLinearVelocity()
    if math.abs(x) < 0.001 then
        x = 0
    end
    if math.abs(y) < 0.001 then
        y = 0
    end
    self.body:setLinearVelocity(x, y)
end


function Player:mapCenter()
    local x, y = self.body:getWorldCenter()
    return loveToMap(x, y)
end


function Player:load(playerTable)
    -- Gets a table with all the values from the recursiveLoad and sets the player with them
    self.body:setPosition(playerTable.x, playerTable.y)
    self.movement = playerTable.movement
    -- The spawn point is where the world first put the player, on its surface
    self.spawnX = playerTable.spawnX or self.spawnX
    self.spawnY = playerTable.spawnY or self.spawnY
    -- Player base movement comes from the constants, so saves made with older values get the current ones
    self.movement.baseMaxSpeed = BASE_MOVE_SPEED
    self.movement.baseJumpHeight = BASE_JUMP_HEIGHT
    self.direction = playerTable.last_direction
    self.last_direction = playerTable.last_direction
    self.hpBar = playerTable.hpBar
    self.manaBar = playerTable.manaBar
    self.statsDirty = true  -- Recalculate combat stats with the loaded values
end

-- Animations

function Player:animationSetup()
    local headHeight = self.height / 6
    local headhWidth = self.width / 3
    local torsoHeight = self.height / 2
    local torsoWidth = self.width / 2
    local legHeight = self.height - torsoHeight - headHeight
    local legWidth = self.width / 3
    local handHeight = torsoHeight * 4 / 3
    self.handLength = handHeight    -- Spells start at the hand tips(see castOrigin)
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

    -- Cast pose on top of the walk
    self:castSetup()
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


-- Cast Pose
function Player:castSetup()
    -- Hands point where the spell goes, layered over the walk on the hand bones only
    local transformer = self.anim.actor:GetTransformer()
    self.castPose = {right_hand = {rotation = 0}, left_hand = {rotation = 0}}
    transformer:SetTransform("cast", self.castPose, CAST_HAND_BONES)
    -- Higher priority than the walk("player") on the hands, so the cast takes them over as it blends in
    transformer:SetPriority("cast", 1, CAST_HAND_BONES)
    self.castPower = 0      -- How much of the cast pose shows, 0 to 1
    self.castHold = 0       -- Seconds the pose stays up after the last cast
end


function Player:castAt(dirX, dirY)
    -- Called for every cast the player makes, aims both hands along the cast direction
    -- Bone angle 0 points down because the skeleton root is rotated 90 degrees
    local angle = math.atan2(dirY, dirX) - math.pi / 2
    -- Shortest way round from hanging down, so aiming up and left doesnt swing the hands all the way around
    if angle < -math.pi then
        angle = angle + 2 * math.pi
    end
    self.castPose.right_hand.rotation = angle - CAST_HAND_SPREAD
    self.castPose.left_hand.rotation = angle + CAST_HAND_SPREAD
    self.castHold = CAST_POSE_HOLD
    -- Hands snap up right away, so the spell comes out of them on the first frame(blending out stays smooth)
    self.castPower = 1
    self.anim.actor:GetTransformer():SetPower("cast", 1)
end


function Player:castOrigin(dirX, dirY)
    -- Where spells start: at the hand tips along the cast direction, between the two raised hands
    -- Worked out from the pose instead of read from the animation, which is still blending in on the first cast
    local x, y = self.body:getWorldCenter()
    local shoulderY = y - self.height / 3      -- Hands hang from the top of the torso(see moveControl)
    return x + dirX * self.handLength, shoulderY + dirY * self.handLength
end


function Player:updateCastPose(dt)
    -- Keeps the pose up while casting and blends it out after the last cast, the walk takes the hands back
    if self.castHold > 0 then
        self.castHold = self.castHold - dt
    else
        self.castPower = math.max(0, self.castPower - CAST_POSE_OUT_SPEED * dt)
    end
    self.anim.actor:GetTransformer():SetPower("cast", self.castPower)
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

function Player:damage(damage)
    -- Takes damage like any entity, but dying respawns instead of destroying the body
    self.hpBar.currentHP = math.max(0, self.hpBar.currentHP - damage)
    if self.hpBar.currentHP <= 0 then
        self:die()
    end
end

function Player:die()
    -- Back to the spawn with full hp and mana, nothing else is lost for now
    self.body:setPosition(self.spawnX, self.spawnY)
    self.body:setLinearVelocity(0, 0)
    self.hpBar.currentHP = self.hpBar.maxHP
    self.manaBar.currentMana = self.manaBar.maxMana
end


return Player