require "forms.bullet"

Bullet1 = Bullet:new()

function Bullet1:new(player)
    local bullet1 = Bullet:new(player, 100 * TILE_SIZE * TILES_PER_METER, 10, "GRASS")
    setmetatable(bullet1,self)
    self.__index = self

    return bullet1
end
