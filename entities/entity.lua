require "components.movement"
require "components.hpBar"
require "world.world"
require "constants"


Entity = {}

function Entity:new(x, y, maxHP, moveSpeed, jumpHeight)
    local entity = {}
    setmetatable(entity,self)
    self.__index = self
    if x ~= nil then
        entity.hpBar = HPBar(maxHP, maxHP, 1)
        entity.movement = Movement(moveSpeed, jumpHeight)
        entity.body = love.physics.newBody(p_world, x, y, "dynamic")
    end
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
    if self.hpBar ~= nil then
        self.hpBar.currentHP = math.min(self.hpBar.currentHP + self.hpBar.regen * dt,self.hpBar.maxHP)
    end

    if self.manaBar ~= nil then
        self.manaBar.currentMana = math.min(self.manaBar.currentMana + self.manaBar.manaRegen * dt,self.manaBar.maxMana)
    end
end