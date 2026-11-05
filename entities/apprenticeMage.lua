local Zombie = require "entities.zombie"
local Entity = require "entities.entity"
local Movement = require "components.movement"
local ManaBar = require "components.manaBar"
local Spell = require "magic.spell"
local EnemyCasting = require "magic.enemyCasting"

-- Apprentice mages, the first enemies that fight with real spells(see magic/enemyCasting): they guard mage towers,
-- keep their distance like an archer and build a cast circle at the player, a full freeze breaks it
-- Each one knows a fire or a frost bullet, its mana and Intelligence decide how often and how hard it casts
local ApprenticeMage = Zombie:new()
registerEntity("ApprenticeMage", ApprenticeMage)
ApprenticeMage.entityName = "ApprenticeMage"
ApprenticeMage.skin = "apprentice_mage"
ApprenticeMage.hp = MAGE_HP
ApprenticeMage.loot = {}
ApprenticeMage.xpReward = MAGE_XP
-- Where its level's stat points go: spell damage, then mana regen and cast speed, then more mana
ApprenticeMage.build = {intelligence = 4, concentration = 3, wisdom = 2, constitution = 1}

local SPELLS = {"Fire", "Frost"}


function ApprenticeMage:new(x, y)
    local mage = Zombie.new(self, x, y)
    if x == nil or y == nil then
        return mage
    end
    mage.movement = Movement(MAGE_SPEED, BASE_JUMP_HEIGHT)
    mage.contactDamage = MAGE_TOUCH
    mage.manaBar = ManaBar(MAGE_MANA, MAGE_MANA, MAGE_MANA_REGEN)
    -- Its own spell, made new for every mage so each has its own cooldown
    mage.element = SPELLS[love.math.random(1, #SPELLS)]
    mage.spells = {Spell:new("Bullet", {mage.element})}
    mage.statsDirty = true
    return mage
end


function ApprenticeMage:update(dt)
    if self.dying ~= nil then
        self:updateDying(dt)
        return
    end
    if not self:keepLoaded() then
        return
    end
    Entity.update(self, dt)
    EnemyCasting.update(self, dt)
    self:hitManaBlocks(dt)
    groundRay(self)
    self.body:setGravityScale(self:gravityScale())

    -- Keeps its distance while it can see the player, stands still while it builds a circle
    local x, y = self.body:getWorldCenter()
    local px, py = player.body:getWorldCenter()
    local vx, vy = self.body:getLinearVelocity()
    local dx = px - x
    local side = dx > 0 and 1 or -1
    local far = math.abs(dx)
    local walking = false
    vx = self.movement.pushX or 0
    if far <= MAGE_SIGHT and math.abs(py - y) <= MAGE_SIGHT then
        self:face(side > 0 and "right" or "left")
        if self.casting == nil then
            if far < MAGE_RANGE[1] then
                vx, walking = vx - side * self.movement.maxSpeed, true
            elseif far > MAGE_RANGE[2] then
                vx, walking = vx + side * self.movement.maxSpeed, true
            end
        end
    end
    if walking and self.grounded then
        local step = vx > 0 and 1 or -1
        local frontX = x + step * (self.width / 2 + 4)
        local feetY = y + self.height / 2 - 4
        if map:solidAt(frontX, feetY) and not map:solidAt(frontX, feetY - TILE_SIZE * 2) then
            vy = -self.movement.jumpHeight
        end
    end
    self.body:setLinearVelocity(vx, vy)
    self:updateAnimation(dt, walking)
end


function ApprenticeMage:updateAnimation(dt, walking)
    -- The zombie walk, with the arms raised toward its circle while it casts
    Zombie.updateAnimation(self, dt, walking)
    if self.casting ~= nil then
        local x, y = self.body:getWorldCenter()
        local cx, cy = EnemyCasting.circlePosition(self)
        local dx, dy = cx - x, cy - (y - self.height * 0.2)
        local size = math.sqrt(dx * dx + dy * dy)
        if size > 0 then
            local angle = math.atan2(-dx / size, dy / size)
            self.armPose.right_hand.rotation = angle - 0.15
            self.armPose.left_hand.rotation = angle + 0.15
        end
    end
end


function ApprenticeMage:load(data)
    Zombie.load(self, data)
    self.manaBar = data.manaBar or self.manaBar
    -- Its spell is the one it had(a save keeps the element, the spell is made new)
    if data.element ~= nil then
        self.element = data.element
        self.spells = {Spell:new("Bullet", {data.element})}
    end
end

return ApprenticeMage
