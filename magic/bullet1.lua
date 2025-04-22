local Bullet = require "forms.bullet"

local Bullet1 = Bullet:new()

function Bullet1:new(player)
    local bullet1 = Bullet:new(player, 10 * TILE_SIZE * TILES_PER_METER, 10, "GRASS")
    setmetatable(bullet1,self)
    self.__index = self
    bullet1:shoot()
    return bullet1
end

return Bullet1