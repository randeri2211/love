local ManaBar = require "components.manaBar"
local Spellbooks = require "magic.spellbooks"
local Entity = require "entities.entity"
local Humanoid = require "animations.humanoid"
local Inventory = require "components.inventory"
local Equipment = require "components.equipment"
local Statuses = require "magic.statuses"
local Knowledge = require "magic.knowledge"
local Slab = require "libraries.Slab"

local Player = Entity:new()
AS = 25
AD = 1

-- Cast pose(see Player:castAt)
CAST_HAND_BONES = {"right_hand", "left_hand"}
CAST_HAND_SPREAD = math.rad(8)  -- Small angle between the two hands so they dont draw on top of each other
CAST_POSE_HOLD = 0.3            -- Seconds the hands stay up after the last cast
CAST_POSE_OUT_SPEED = 4         -- How fast it blends back to the walk
-- AS / (self.movement.currentSpeed * AD) = 0.3

-- Walk cycle, {part of the cycle, {bone = degrees}}(see Humanoid.walk), hands swing against the legs
PLAYER_WALK = {
    right = {
        {0, {}},
        {0.25, {right_hand = 45, left_hand = -45, right_leg = 30, left_leg = -30}},
        {0.75, {right_hand = -45, left_hand = 45, right_leg = -30, left_leg = 30}},
        {1, {}},
    },
    left = {
        {0, {}},
        {0.25, {right_hand = -45, left_hand = 45, right_leg = 30, left_leg = -30}},
        {0.75, {right_hand = 45, left_hand = -45, right_leg = -30, left_leg = 30}},
        {1, {}},
    },
}

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
    player.inventory = Inventory(INVENTORY_SIZE)    -- Saved in its own file like the spellbook
    player.equipment = Equipment()      -- Worn armor, adds to the stats(see CombatStats)
    player.hotbarSlot = 1               -- Selected hotbar slot, the first row of the inventory
    player.knowledge = Knowledge.new()  -- Runes it knows(see magic/knowledge), saved with the player

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
    Humanoid.face(self.anim, self.direction)
end


local function held(key)
    -- A movement key that is down, unless it is being typed into a text box(the item list filter, a spell name)
    return love.keyboard.isDown(key) and not Slab.IsAnyInputFocused()
end


function Player:move()
    -- Increase linear velocity according to speed(doesn't depend on time since its using world)
    local moved = false
    local x,y = self.body:getLinearVelocity()
    if held(RIGHT_KEY) then
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
    if held(LEFT_KEY) then
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
    if held(JUMP_KEY) then
        self.moving = true
        if self.grounded then
            self.jumping = true
            self.body:setLinearVelocity(x, - self.movement.jumpHeight)
        elseif self.jumping and self.up then
            self.body:setGravityScale(JUMP_GRAVITY_SCALE * self:gravityScale())
        else
            self.body:setGravityScale(self:gravityScale())
        end
    else
        self.jumping = false
        self.body:setGravityScale(self:gravityScale())
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
    self:checkContactDamage(dt)
end


-- Melee Damage
function Player:checkContactDamage(dt)
    -- Anything touching the player with contactDamage hurts it(see meleeHit)
    self.contactImmunity = math.max(0, (self.contactImmunity or 0) - dt)
    if self.contactImmunity == 0 then
        for i, contact in ipairs(self.body:getContacts()) do
            if contact:isTouching() then
                local a, b = contact:getFixtures()
                local other = a:getBody() == self.body and b or a
                local attacker = other:getUserData()
                if attacker ~= nil and (attacker.contactDamage or 0) > 0 then
                    -- The attacker can show the hit, like a zombie swiping
                    if self:meleeHit(attacker, attacker.contactDamage, CONTACT_KNOCKBACK) and attacker.onMeleeHit ~= nil then
                        attacker:onMeleeHit(self)
                    end
                    break
                end
            end
        end
    end

    -- Blinks while immune
    local visible = self.contactImmunity == 0 or math.floor(self.contactImmunity * CONTACT_BLINK_RATE) % 2 == 0
    Humanoid.setAlpha(self.anim, visible and 1 or 0.35)
end


function Player:meleeHit(attacker, damage, knockback)
    -- Enemy bodies hitting the player, a touch or a swing, then no melee hit lands for a moment
    -- The immunity is for melee only, spells and other damage still land, returns true when the hit landed
    if (self.contactImmunity or 0) > 0 then
        return false
    end
    -- A creature with an elemental touch(contactElement) hits with that element and leaves its statuses
    self:damage(damage, nil, attacker.contactElement)
    if attacker.contactElements ~= nil then
        Statuses.apply(self, attacker.contactElements)
    end
    self.contactImmunity = CONTACT_IMMUNITY_TIME
    -- Knocked away from the attacker and a little up
    local x = self.body:getWorldCenter()
    local ax = attacker.body:getWorldCenter()
    local side = x >= ax and 1 or -1
    self:push(side * knockback, -knockback * 0.5)
    return true
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
    Humanoid.place(self.anim, x, y, self.height)
    
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
    self.knowledge = Knowledge.fromData(playerTable.knowledge)     -- Saves from before rune knowledge know the starting runes
    self.statsDirty = true  -- Recalculate combat stats with the loaded values
end

-- Animations

function Player:animationSetup()
    -- The shared humanoid body(see animations/humanoid), spells start at the hand tips(see castOrigin)
    self.anim, self.handLength = Humanoid.build(self.width, self.height, PLAYER_SKIN)
    local x, y = self.body:getWorldCenter()
    self.anim.actor:GetTransformer():GetRoot().translation = {x , y}

    -- One walk cycle per direction, timed by the walking speed
    local cycleTime = 4 * AS / (self.movement.currentSpeed * AD)
    self.animations = {}
    self.animations["right"] = Humanoid.walk(self.anim, cycleTime, PLAYER_WALK.right)
    self.animations["left"] = Humanoid.walk(self.anim, cycleTime, PLAYER_WALK.left)

    -- Choosing animation to display
    self.anim.actor:GetTransformer():SetTransform("player", self.animations["left"].animation)

    -- Cast pose on top of the walk
    self:castSetup()
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
    -- Standing still it turns to face the cast, while walking the walk decides
    if self.direction == "" then
        Humanoid.face(self.anim, dirX < 0 and "left" or "right")
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
    local shoulderY = Humanoid.rootY(self.anim, y, self.height)     -- Hands hang from the top of the torso
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


function Player:damage(damage, power, kind)
    -- Takes damage like any entity, but dying respawns instead of destroying the body
    self.hpBar.currentHP = math.max(0, self.hpBar.currentHP - damage * (1 - self:damageReduction(kind)))
    self:selfHit()
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