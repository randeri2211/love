local Form = require "forms.form"

local Area = Form:new()

function Area:new(caster, params, x, y, dirX, dirY)
    local area = Form:new(caster)
    setmetatable(area,self)
    self.__index = self

    area.form = "area"
    if caster == nil then
        return area
    end

    -- Values from the compiled spell params
    area.damage = params.damage
    area.terrainDamage = params.terrainDamage
    area.areaRadius = params.areaRadius
    area.expandTime = params.expandTime     -- Seconds to grow to full size
    area.lifetime = params.lifetime
    area.pull = params.pull                 -- Gravity, pulls enemies toward the center
    area.color = params.color

    -- Cast directly it appears in front of the cast point, from a trigger it centers on the hit point
    -- Split copies spread further out either way
    local dist = params.areaRadius * 0.6 * (params.count - 1)
    if not params.triggered then
        dist = dist + params.areaRadius
    end
    area.x, area.y = x + dirX * dist, y + dirY * dist
    area.direction = {dirX, dirY}
    area.time = 0
    area.hits = {}      -- Everything already hit, the burst hits each thing once

    return area
end


function Area:currentRadius()
    return self.areaRadius * math.min(1, self.time / self.expandTime)
end


function Area:query(radius)
    -- Blocks and enemies overlapping the circle(collected first, so nothing is destroyed mid query)
    local found = {}
    p_world:queryBoundingBox(self.x - radius, self.y - radius, self.x + radius, self.y + radius, function(fixture)
        local category = fixture:getCategory()
        if category == ENEMY_CATEGORY or category == BLOCKS_CATEGORY then
            local x1, y1, x2, y2 = fixture:getBoundingBox()
            local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            local size = math.min(x2 - x1, y2 - y1) / 2
            if distance(cx, cy, self.x, self.y) <= radius + size then
                table.insert(found, {fixture = fixture, x = cx, y = cy})
            end
        end
        return true     -- Keep looking
    end)
    return found
end


function Area:update(dt)
    self.time = self.time + dt
    local radius = self:currentRadius()

    for i, found in ipairs(self:query(radius)) do
        local fixture = found.fixture
        if not fixture:isDestroyed() then
            local entity = getEntityFromFixture(fixture)
            local key = entity or fixture
            -- Direction from the center outward, for child spells
            local dx, dy = found.x - self.x, found.y - self.y
            local size = math.sqrt(dx * dx + dy * dy)
            if size > 0.001 then
                dx, dy = dx / size, dy / size
            else
                dx, dy = self.direction[1], self.direction[2]
            end

            if not self.hits[key] then
                self.hits[key] = true
                self:hit(entity, found.x, found.y, dx, dy)
            end

            -- Gravity pulls enemies that survived toward the center
            if self.pull > 0 and not fixture:isDestroyed() and fixture:getCategory() == ENEMY_CATEGORY then
                local body = fixture:getBody()
                local bx, by = body:getPosition()
                local step = math.min(size, AREA_PULL_SPEED * self.pull * dt)
                body:setPosition(bx - dx * step, by - dy * step)
            end
        end
    end

    if self.time >= self.lifetime then
        self:expire()
    end
end


function Area:draw()
    local radius = self:currentRadius()
    if radius <= 0 then
        return
    end
    -- Fades out after it finished growing
    local fadeTime = math.max(0.001, self.lifetime - self.expandTime)
    local fade = 1 - math.max(0, (self.time - self.expandTime) / fadeTime)
    local c = self.color

    love.graphics.push("all")
    love.graphics.setColor(c[1], c[2], c[3], 0.18 * fade)
    love.graphics.circle("fill", self.x, self.y, radius, 48)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(c[1], c[2], c[3], 0.9 * fade)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, radius, 48)
    love.graphics.setColor(c[1], c[2], c[3], 0.4 * fade)
    love.graphics.circle("line", self.x, self.y, radius * 0.6, 48)

    -- Rings shrinking toward the center show the pull
    if self.pull > 0 then
        for k = 0, 2 do
            local f = 1 - (self.time * 0.8 + k / 3) % 1
            love.graphics.setColor(c[1], c[2], c[3], 0.6 * fade * f)
            love.graphics.circle("line", self.x, self.y, radius * f, 48)
        end
    end
    love.graphics.pop()
end

return Area
