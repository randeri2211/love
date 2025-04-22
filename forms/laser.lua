local Form = require "forms.form"

local Laser = Form:new()

function Laser:new(player, radius, bounces, reach, imagePath)
    local laser = Form:new(player)
    setmetatable(laser,self)
    self.__index = self

    laser.form = "laser"
    if player == nil then
        return laser
    end
    
    laser.x1, laser.y1 = player.body:getWorldCenter()
    laser.bounces = bounces
    -- Getting the end points for the raycastCallback
    laser.x2, laser.y2 = mouseToLove()
    laser.direction = {x = laser.x2 - laser.x1, y = laser.y2 - laser.y1}
    local velSize = math.sqrt(direction[1]^2 + direction[2]^2)
    direction = {direction[1] / velSize, direction[2] / velSize}
    while laser.bounces > 0 do
        -- Reseting the hits counter for the laser callback
        laser.hits = {}
        
        local endX = laser.x1 + direction * reach
        local endY = laser.y1 + direction * reach
        -- Send raycast
        p_world:rayCast(laser.x1, laser.y1, endX, endY, laser.raycastCallback)
        laser.bounces = laser.bounces - 1
    end
    
    return laser
end

function Laser:raycastCallback(fixture, x, y, xn, yn, fraction)
    -- Calculate distance
    local distance = math.sqrt((self.x1 - x)^2 + (self.y1 - y)^2)

    -- Store the hit point

    table.insert(self.hits, {x = x, y = y, distance = distance})

    -- Calculate reflection
    local dx, dy = self.direction.x, self.direction.y
    local dot = dx * xn + dy * yn
    self.direction.x = dx - 2 * dot * xn
    self.direction.y = dy - 2 * dot * yn

    -- Update the laser's new starting point
    self.startX = x
    self.startY = y

    self.remainingBounces = self.remainingBounces - 1
    self.x1 = x
    self.y1 = y
    return 0 -- Stop raycasting at this point
end


function Laser:draw()

end

return Laser