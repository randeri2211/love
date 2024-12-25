require "forms.form"

Laser = Form:new()

function Laser:new(playe, radius, bounces, reach, imagePath)
    local laser = Form:new(player)
    setmetatable(laser,self)
    self.__index = self

    if player == nil then
        return laser
    end

    laser.bounces = bounces
    while laser.bounces > 0 do
        -- Reseting the hits counter for the laser callback
        laser.hits = {}
        -- Getting the end points for the raycastCallback
        local px, py = player.body:getWorldCenter()
        local mx, my = mouseToLove()
        local direction = {mx - px, my - py}
        local velSize = math.sqrt(direction[1]^2 + direction[2]^2)
        direction = {direction[1] / velSize, direction[2] / velSize}
        local endX = px + direction * reach
        local endY = py + direction * reach

        p_world:rayCast(px, py, endX, endY, laser.raycastCallback)
    end
    
    return laser
end

function Laser:raycastCallback(fixture, x, y, xn, yn, fraction)
    -- Store the hit point
    table.insert(self.hits, {x = x, y = y, distance = })

    -- Calculate reflection
    local dx, dy = self.direction.x, self.direction.y
    local dot = dx * xn + dy * yn
    self.direction.x = dx - 2 * dot * xn
    self.direction.y = dy - 2 * dot * yn

    -- Update the laser's new starting point
    self.startX = x
    self.startY = y

    self.remainingBounces = self.remainingBounces - 1
    return 0 -- Stop raycasting at this point
end


function Laser:draw()

end