require "components.movement"
require "components.hpBar"
require "world.world"
require "constants"


Entity = {}

function Entity:new(x, y, maxHP, moveSpeed, jumpHeight)
    local entity = {}
    setmetatable(entity,self)
    self.__index = self

    entity.hpBar = HPBar(100, 100, 1)
    entity.movement = Movement(moveSpeed, jumpHeight)
end


