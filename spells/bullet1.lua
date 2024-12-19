require "spells.bullet"

Bullet1 = Bullet:new()

function Bullet1:new(player)
    local bullet1 = Bullet:new(player, 1, 10, "GRASS")
    setmetatable(bullet1,self)
    self.__index = self


    return bullet1
end