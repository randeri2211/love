local Movement = require "components.movement"
local HPBar = require "components.hpBar"
local Stats = require "components.stats.stats"
local CombatStats = require "components.stats.combatStats"
local ManaBar = require "components.manaBar"

local Entity = {}

function Entity:new(x, y, maxHP)
    local entity = {}
    setmetatable(entity,self)
    self.__index = self

    entity.type = "Entity"
    if x == nil then
        return entity
    end

    entity.hpBar = HPBar(maxHP, maxHP, BASE_HP_REGEN)
    entity.manaBar = ManaBar(BASE_MANA, BASE_MANA, BASE_MANA_REGEN)
    entity.movement = Movement(BASE_MOVE_SPEED, BASE_JUMP_HEIGHT)
    entity.stats = Stats()
    entity.statsDirty = true    -- Calculate combat stats on the first update
    entity.body = love.physics.newBody(p_world, x, y, "dynamic")

    return entity
end

function Entity:update(dt)
    -- Recalculate combat stats only when a stat changed
    if self.statsDirty then
        self.combatStats = CombatStats(self)
        self.statsDirty = false
    end
    self:regen(dt)

    -- Horizontal knockback fades out(old saves dont have pushX)
    local pushX = self.movement.pushX or 0
    pushX = pushX * math.exp(-PUSH_DECAY * dt)
    if math.abs(pushX) < 1 then
        pushX = 0
    end
    self.movement.pushX = pushX

    -- Terminal velocity for gravity only: above MAX_FALL_SPEED the speed gravity added this step is taken back,
    -- so spells and effects can still push an entity into a faster fall, gravity just wont speed it up further
    if self.body ~= nil and not self.body:isDestroyed() then
        local vx, vy = self.body:getLinearVelocity()
        if vy > MAX_FALL_SPEED then
            local gravityAdded = GRAVITY * self.body:getGravityScale() * dt
            self.body:setLinearVelocity(vx, math.max(MAX_FALL_SPEED, vy - gravityAdded))
        end
    end
end

function Entity:push(vx, vy)
    -- Knockback, vertical goes straight into the body and gravity slows it,
    -- horizontal goes into the movement component since movement code sets the horizontal velocity every frame
    self.movement.pushX = (self.movement.pushX or 0) + vx
    local x, y = self.body:getLinearVelocity()
    self.body:setLinearVelocity(x, y + vy)
end

function Entity:addStat(stat, amount)
    -- Changes a stat(negative amounts allowed) and marks combat stats for recalculation
    self.stats[stat] = self.stats[stat] + amount
    self.statsDirty = true
end

function Entity:prepSave()
    -- Prep the x and y values for saving(easier than trying to save the box and whatever user data)
    self.x, self.y = self.body:getWorldCenter()
end

function Entity:regen(dt)
    if self.hpBar ~= nil and self.hpBar.regen ~= 0 then
        self.hpBar.currentHP = math.min(self.hpBar.currentHP + self.hpBar.regen * dt,self.hpBar.maxHP)
    end

    if self.manaBar ~= nil and self.manaBar.manaRegen ~= 0 then
        self.manaBar.currentMana = math.min(self.manaBar.currentMana + self.manaBar.manaRegen * dt,self.manaBar.maxMana)
    end
end

function Entity:damage(damage)
    print(damage)
    print(self.hpBar.currentHP)
    self.hpBar.currentHP = self.hpBar.currentHP - damage
    if self.hpBar.currentHP <= 0 then
        self:destroy()
    end
end

function Entity:destroy()
    self.body:destroy()
end

function Entity:applyStats()

end

function Entity:isFixture(fixture)
end

return Entity