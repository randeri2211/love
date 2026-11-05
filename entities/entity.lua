local Movement = require "components.movement"
local HPBar = require "components.hpBar"
local Stats = require "components.stats.stats"
local CombatStats = require "components.stats.combatStats"
local Statuses = require "magic.statuses"
local ManaBar = require "components.manaBar"
local Levels = require "components.stats.levels"

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
    Statuses.update(self, dt)       -- Burning, frozen, poisoned(see magic/statuses)

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

function Entity:damage(damage, power, kind)
    -- kind is the element of the damage(nil for plain damage), armor blocks plain damage and resistances their element
    -- power is only for blocks(their hardness)
    -- Dying entities dont take more hits
    if self.dying then
        return
    end
    self.hpBar.currentHP = self.hpBar.currentHP - damage * (1 - self:damageReduction(kind))
    self:selfHit()
    if self.hpBar.currentHP <= 0 then
        if self.dropLoot ~= nil then
            self:dropLoot()
        end
        Statuses.died(self)     -- A wildfire burn passes on
        -- Enemies that give experience give it to the player, more the higher their level
        if self.xpReward ~= nil then
            Levels.gain(player, self.xpReward * (self.level or 1))
        end
        self:die()
    end
end

function Entity:touchDamage()
    -- What its touch hits for(zombies), Strength makes it stronger
    local touch = self.contactDamage or 0
    return touch * (self.combatStats and self.combatStats.touchScale or 1)
end

function Entity:selfBuff(key)
    -- Product of a buff over every Self spell active on this entity(haste, lightness), 1 without any
    local value = 1
    for effect in pairs(self.selfEffects or {}) do
        value = value * effect[key]
    end
    return value
end

function Entity:damageReduction(kind)
    -- Part of incoming damage its armor blocks, or its resistance to the element of the damage
    local combat = self.combatStats
    if combat == nil then
        return 0
    end
    if kind ~= nil then
        return combat.resistReduction[kind] or 0
    end
    return combat.damageReduction or 0
end

function Entity:gravityScale()
    -- How strongly gravity pulls it, from its combat stats(Self spells can make it lighter)
    return self.combatStats and self.combatStats.gravityScale or 1
end

function Entity:selfHit()
    -- Tells the Self spells on this entity it was hurt, their onHit children fire
    for effect in pairs(self.selfEffects or {}) do
        effect:casterHit()
    end
end

function Entity:die()
    -- Entities with a death animation override this, by default they are just removed
    self:destroy()
end

function Entity:destroy()
    self.body:destroy()
end

function Entity:applyStats()

end

function Entity:isFixture(fixture)
end

return Entity