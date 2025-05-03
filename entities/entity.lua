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
    entity.body = love.physics.newBody(p_world, x, y, "dynamic")

    return entity
end

function Entity:update(dt)
    self.combatStats = CombatStats(self)    -- Update combat stats live
    self:regen(dt)
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