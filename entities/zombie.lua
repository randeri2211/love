local Enemy = require "entities.enemy"
local Entity = require "entities.entity"
local Movement = require "components.movement"
local Humanoid = require "animations.humanoid"

-- A slow humanoid that shambles toward the player with its arms out, the same body as the player
local Zombie = Enemy:new()
registerEntity("Zombie", Zombie)

local ARM_BONES = {"right_hand", "left_hand"}
local ARM_REACH = math.rad(12)      -- Arms point a little below level, reaching for the player
local ARM_SPREAD = math.rad(6)      -- Small angle between the arms so they dont draw on top of each other
local ARM_BOB = math.rad(7)         -- How far the arms sway while it walks
local WALK_CYCLE = 1.4              -- Seconds per shuffling step cycle
-- Swipe shown when a touch hits the player: arms snap up, swing down past level, then settle back
local SWIPE_RAISE = math.rad(65)    -- How far the arms go up
local SWIPE_STRIKE = math.rad(40)   -- How far past level they swing down
local SWIPE_UP_TIME = 0.08
local SWIPE_DOWN_TIME = 0.1
local SWIPE_RECOVER_TIME = 0.3

-- Short dragging steps with a nodding head, the arms come from the arm pose instead(see armSetup)
local WALK = {
    right = {
        {0, {head = 6}},
        {0.25, {head = 12, right_leg = 20, left_leg = -20}},
        {0.5, {head = 6}},
        {0.75, {head = 12, right_leg = -20, left_leg = 20}},
        {1, {head = 6}},
    },
    left = {
        {0, {head = -6}},
        {0.25, {head = -12, right_leg = 20, left_leg = -20}},
        {0.5, {head = -6}},
        {0.75, {head = -12, right_leg = -20, left_leg = 20}},
        {1, {head = -6}},
    },
}


function Zombie:new(x, y)
    local zombie = Entity:new(x, y, ZOMBIE_HP)
    setmetatable(zombie, self)
    self.__index = self

    if x == nil or y == nil then
        return zombie
    end
    zombie.name = "Zombie"
    zombie.width = PLAYER_WIDTH
    zombie.height = PLAYER_HEIGHT
    zombie.radius = zombie.width / 2
    zombie.movement = Movement(ZOMBIE_SPEED, BASE_JUMP_HEIGHT)
    zombie.hpBar.regen = 0
    zombie.contactDamage = ZOMBIE_CONTACT_DAMAGE    -- Hurts the player by touching them(see Player:checkContactDamage)
    zombie.direction = "right"
    zombie.walkTime = 0     -- Drives the arm sway

    zombie:setBody()
    zombie:animationSetup()
    return zombie
end


function Zombie:setBody()
    -- Same capsule as the player: a box with a circle at the top and bottom, so it slides up over block edges
    self.body:setFixedRotation(true)
    self.body:setSleepingAllowed(false)
    self.body:setGravityScale(1)
    self.body:setLinearDamping(LINEAR_DAMPING)

    local shapes = {
        love.physics.newRectangleShape(self.width * 0.9, self.height - self.radius * 2),
        love.physics.newCircleShape(0, -(self.height - self.width) / 2, self.radius),
        love.physics.newCircleShape(0, (self.height - self.width) / 2, self.radius),
    }
    self.fixtures = {}
    for i, shape in ipairs(shapes) do
        local fixture = love.physics.newFixture(self.body, shape, 1)
        fixture:setCategory(ENEMY_CATEGORY)
        fixture:setGroupIndex(-ENEMY_CATEGORY)
        fixture:setRestitution(0)
        fixture:setUserData(self)       -- Contacts and queries find the zombie straight from its fixtures
        self.fixtures[i] = fixture
    end
end


function Zombie:isFixture(fixture)
    for i, own in ipairs(self.fixtures) do
        if own == fixture then
            return true
        end
    end
    return false
end


-- Animation
function Zombie:animationSetup()
    self.anim = Humanoid.build(self.width, self.height, ZOMBIE_SKIN)
    self.animations = {
        right = Humanoid.walk(self.anim, WALK_CYCLE, WALK.right),
        left = Humanoid.walk(self.anim, WALK_CYCLE, WALK.left),
    }
    local transformer = self.anim.actor:GetTransformer()
    transformer:SetTransform("walk", self.animations.right.animation)
    transformer:SetPower("walk", 0)
    self:armSetup()
    self:face(self.direction)
end


function Zombie:armSetup()
    -- Arms held out in front over the walk, on the hand bones only(like the player cast pose)
    local transformer = self.anim.actor:GetTransformer()
    self.armPose = {right_hand = {rotation = 0}, left_hand = {rotation = 0}}
    transformer:SetTransform("arms", self.armPose, ARM_BONES)
    transformer:SetPriority("arms", 1, ARM_BONES)
    transformer:SetPower("arms", 1)
end


function Zombie:face(direction)
    if direction ~= self.facing then
        self.facing = direction
        self.anim.actor:GetTransformer():SetTransform("walk", self.animations[direction].animation)
        Humanoid.face(self.anim, direction)
    end
end


function Zombie:swipeArmAngle()
    -- Extra arm angle for the swipe, positive is down in front for a zombie facing right, mirrored when facing left
    local swipe = self.swipe
    if swipe == nil then
        return 0
    end
    local t = swipe.time
    local angle
    if t < SWIPE_UP_TIME then
        angle = -SWIPE_RAISE * t / SWIPE_UP_TIME
    elseif t < SWIPE_UP_TIME + SWIPE_DOWN_TIME then
        local p = (t - SWIPE_UP_TIME) / SWIPE_DOWN_TIME
        angle = -SWIPE_RAISE + (SWIPE_STRIKE + SWIPE_RAISE) * p
    else
        local p = math.min(1, (t - SWIPE_UP_TIME - SWIPE_DOWN_TIME) / SWIPE_RECOVER_TIME)
        angle = SWIPE_STRIKE * (1 - p)
    end
    return swipe.side * angle
end


function Zombie:onMeleeHit(target)
    -- Its touch just hurt the target, the arms swipe at them
    local x = self.body:getWorldCenter()
    local side = target.body:getWorldCenter() >= x and 1 or -1
    self:face(side > 0 and "right" or "left")
    self.swipe = {time = 0, side = side}
end


function Zombie:updateAnimation(dt, walking)
    local transformer = self.anim.actor:GetTransformer()
    transformer:SetPower("walk", walking and 1 or 0)
    if walking then
        local vars = transformer:GetVariables("walk")
        vars.time = vars.time + dt
        self.walkTime = self.walkTime + dt
    end

    -- Bone angle 0 points down(the skeleton is turned to stand up), so reaching right is -90 degrees and left is 90
    local forward = self.facing == "right" and -math.pi / 2 + ARM_REACH or math.pi / 2 - ARM_REACH
    local sway = math.sin(self.walkTime * 2 * math.pi / WALK_CYCLE) * ARM_BOB
    if self.swipe ~= nil then
        sway = 0
        self.swipe.time = self.swipe.time + dt
        if self.swipe.time >= SWIPE_UP_TIME + SWIPE_DOWN_TIME + SWIPE_RECOVER_TIME then
            self.swipe = nil
        end
    end
    local swing = self:swipeArmAngle()
    self.armPose.right_hand.rotation = forward - ARM_SPREAD + sway + swing
    self.armPose.left_hand.rotation = forward + ARM_SPREAD - sway + swing

    -- Red flash after a hit
    self.flashTime = math.max(0, (self.flashTime or 0) - dt)
    if self.flashTime > 0 then
        Humanoid.setTint(self.anim, HIT_TINT[1], HIT_TINT[2], HIT_TINT[3])
    else
        Humanoid.setTint(self.anim, 1, 1, 1)
    end

    if self.dying == nil then
        local x, y = self.body:getWorldCenter()
        Humanoid.place(self.anim, x, y, self.height)
    end
    self.anim.actor:Update(dt)
end


-- Behavior
function Zombie:update(dt)
    if self.dying ~= nil then
        self:updateDying(dt)
        return
    end

    -- Blocks only have hitboxes around the player, so a zombie further out waits frozen instead of falling through the ground
    local x, y = self.body:getWorldCenter()
    local active = map:inHitboxWindow(loveToMap(math.floor(x / TILE_SIZE) * TILE_SIZE, math.floor(y / TILE_SIZE) * TILE_SIZE))
    if self.body:isActive() ~= active then
        self.body:setActive(active)
    end
    if not active then
        return
    end

    Entity.update(self, dt)
    groundRay(self)

    local px, py = player.body:getWorldCenter()
    local vx, vy = self.body:getLinearVelocity()
    local dx = px - x
    local side = dx > 0 and 1 or -1

    -- Shambles toward the player once it is close enough to notice them
    local chasing = math.abs(dx) <= ZOMBIE_SIGHT and math.abs(py - y) <= ZOMBIE_SIGHT and math.abs(dx) > self.width / 2
    vx = self.movement.pushX or 0
    if chasing then
        self:face(side > 0 and "right" or "left")
        vx = vx + side * self.movement.maxSpeed
        -- A block in front at its feet with room above it gets stepped up with a hop
        if self.grounded then
            local frontX = x + side * (self.width / 2 + 4)
            local feetY = y + self.height / 2 - 4
            if map:solidAt(frontX, feetY) and not map:solidAt(frontX, feetY - TILE_SIZE * 2) then
                vy = -self.movement.jumpHeight
            end
        end
    end
    self.body:setLinearVelocity(vx, vy)

    self:updateAnimation(dt, chasing)
end


-- Hit and Death
function Zombie:damage(damage)
    if self.dying ~= nil then
        return
    end
    self.flashTime = HIT_FLASH_TIME
    Entity.damage(self, damage)
end


function Zombie:die()
    -- Falls over backwards from where it faced, then fades out(see updateDying)
    local x, y = self.body:getWorldCenter()
    self.dying = 0
    self.swipe = nil
    self.contactDamage = 0
    self.deathFeet = {x, y + self.height / 2}
    self.deathSide = self.facing == "right" and -1 or 1     -- Way the head falls
end


function Zombie:updateDying(dt)
    -- Bodies cant be turned off inside the physics callback that killed it, so it happens here
    if self.body:isActive() then
        self.body:setActive(false)
    end
    self.dying = self.dying + dt

    local fall = math.min(1, self.dying / DEATH_FALL_TIME)
    fall = fall * fall      -- Speeds up as it tips over
    Humanoid.tilt(self.anim, self.deathFeet[1], self.deathFeet[2], self.deathSide * fall * math.pi / 2)

    local fade = math.max(0, (self.dying - DEATH_FALL_TIME) / DEATH_FADE_TIME)
    Humanoid.setAlpha(self.anim, 1 - fade)
    self:updateAnimation(dt, false)

    if fade >= 1 then
        self:destroy()
    end
end


function Zombie:draw()
    self.anim.actor:Draw()
end


function Zombie:load(data)
    -- Position comes from new(x, y), the rest from the save
    self.hpBar = data.hpBar or self.hpBar
    self.statsDirty = true
end

return Zombie
