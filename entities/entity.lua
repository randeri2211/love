require "components.movement"
require "components.hpBar"


local Entity = {}

function Entity:new(x, y, maxHP, moveSpeed, jumpHeight)
    local entity = {}
    setmetatable(entity,self)
    self.__index = self

    entity.type = "Entity"
    if x == nil then
        return entity
    end
    entity.hpBar = HPBar(maxHP, maxHP, 1)
    entity.movement = Movement(moveSpeed, jumpHeight)
    entity.body = love.physics.newBody(p_world, x, y, "dynamic")

    return entity
end

function Entity:update(dt)
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
    self.hpBar.currentHP = self.hpBar.currentHP - damage
    if self.hpBar.currentHP <= 0 then
        self:destroy()
    end
end

function Entity:destroy()
    self.body:destroy()
end

function Entity:isFixture(fixture)
end

return Entity