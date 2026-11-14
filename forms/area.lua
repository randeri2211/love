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


local function overlapsBox(cx, cy, radius, x1, y1, x2, y2)
    -- True when a circle touches a box, using the point of the box closest to the circle center
    local px = math.max(x1, math.min(cx, x2))
    local py = math.max(y1, math.min(cy, y2))
    return distance(cx, cy, px, py) <= radius
end


function Area:query(radius)
    -- Blocks and enemies overlapping the circle not hit yet(collected first, so nothing is destroyed mid query)
    -- Returns {entity, fixture(enemies only), x, y}
    local found = {}

    -- Creatures: every enemy and the player, not the caster. Their fixtures are checked straight from the enemy list,
    -- a physics query would call back for every block hitbox in the box too, many times the cost with hundreds of areas
    local reach = radius + CREATURE_REACH
    local function creature(entity, fixture)
        -- Far ones are left out by where they were this frame(plain numbers) before asking physics anything
        if entity.x ~= nil and (math.abs(entity.x - self.x) > reach or math.abs(entity.y - self.y) > reach) then
            return
        end
        if fixture ~= nil and not fixture:isDestroyed() and fixture:getBody():isActive() and not self:isCaster(entity) then
            local category = fixture:getCategory()
            if category == ENEMY_CATEGORY or category == PLAYER_CATEGORY then
                local x1, y1, x2, y2 = fixture:getBoundingBox()
                if overlapsBox(self.x, self.y, radius, x1, y1, x2, y2) then
                    table.insert(found, {entity = entity, fixture = fixture, x = (x1 + x2) / 2, y = (y1 + y2) / 2})
                end
            end
        end
    end
    for i, enemy in pairs(map.enemies.enemies) do
        if enemy.body ~= nil and not enemy.body:isDestroyed() then
            creature(enemy, enemy.fixture)
        end
    end
    for i, fixture in ipairs(player.fixtures or {}) do
        creature(player, fixture)
    end

    -- Blocks come from the map tiles under the circle, blocks inside the ground have no hitbox for physics to find
    -- Only while it grows: blocks dont move and each is hit once, a full grown area has found every block it will
    if radius <= (self.blocksScanned or -1) then
        return found
    end
    self.blocksScanned = radius
    for tx = math.floor((self.x - radius) / TILE_SIZE), math.floor((self.x + radius) / TILE_SIZE) do
        for ty = math.floor((self.y - radius) / TILE_SIZE), math.floor((self.y + radius) / TILE_SIZE) do
            local block = map:blockAt(tx * TILE_SIZE, ty * TILE_SIZE)
            if block ~= nil and block.solid and not self.hits[block] and not self:isCaster(block)
                and overlapsBox(self.x, self.y, radius, block.x, block.y, block.x + block.width, block.y + block.height) then
                table.insert(found, {entity = block, x = block.x + block.width / 2, y = block.y + block.height / 2})
            end
        end
    end
    return found
end


function Area:update(dt)
    self.time = self.time + dt
    local radius = self:currentRadius()

    for i, found in ipairs(self:query(radius)) do
        local fixture = found.fixture
        -- Enemies hit earlier in this loop may already be gone
        if fixture == nil or not fixture:isDestroyed() then
            local entity = found.entity or getEntityFromFixture(fixture)
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
            if self.pull > 0 and fixture ~= nil and not fixture:isDestroyed() then
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


function Area:light(add)
    -- A burst lights more while it grows, then fades with it
    if self:currentRadius() <= 0 then
        return
    end
    local fadeTime = math.max(0.001, self.lifetime - self.expandTime)
    local fade = 1 - math.max(0, (self.time - self.expandTime) / fadeTime)
    add(self.x, self.y, self.color or {1, 1, 1}, self:lightStrength(AREA_LIGHT) * fade)
end


function Area:fxSpot()
    -- A random spot on the edge of the burst as it grows
    local radius = self:currentRadius()
    local angle = love.math.random() * math.pi * 2
    return self.x + math.cos(angle) * radius, self.y + math.sin(angle) * radius, 4, 80
end


-- An area is drawn as one square by a shader: a faint fill, a bright 2 pixel ring at its edge and a fainter one at 60%,
-- and with gravity three rings shrinking toward the center. It gives back colors already multiplied by their alpha, so
-- with the premultiplied blend the fill blends like paint and the rings add light, in one draw
local SHADER = [[
extern number radius;       // Pixels
extern number fade;         // 1 while it grows, down to 0 as it fades
extern number pull;         // 1 with gravity
extern number time;
extern number size;         // Pixels across the square

float ring(float d, float r) {
    // How much of a 2 pixel line around radius r covers this pixel
    return clamp(1.5 - abs(d - r), 0.0, 1.0);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float d = length(uv - 0.5) * size;
    float fill = 0.18 * fade * clamp(radius - d + 0.5, 0.0, 1.0);
    float light = 0.9 * fade * ring(d, radius) + 0.4 * fade * ring(d, radius * 0.6);
    if (pull > 0.0) {
        for (int k = 0; k < 3; k++) {
            float f = 1.0 - fract(time * 0.8 + float(k) / 3.0);
            light += 0.6 * fade * f * ring(d, radius * f);
        }
    }
    return vec4(color.rgb * (fill + light), fill);
}
]]

local shader = nil
local pixel = nil   -- A white pixel stretched over the square, so the shader gets 0 to 1 across it


function Area:draw()
    local radius = self:currentRadius()
    if radius <= 0 then
        return
    end
    if shader == nil then
        shader = love.graphics.newShader(SHADER)
        pixel = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))
    end
    -- Fades out after it finished growing
    local fadeTime = math.max(0.001, self.lifetime - self.expandTime)
    local fade = 1 - math.max(0, (self.time - self.expandTime) / fadeTime)
    local c = self.color
    local size = radius * 2 + 4

    local oldShader = love.graphics.getShader()
    local blend, alphaMode = love.graphics.getBlendMode()
    love.graphics.setShader(shader)
    shader:send("radius", radius)
    shader:send("fade", fade)
    shader:send("pull", self.pull > 0 and 1 or 0)
    shader:send("time", self.time)
    shader:send("size", size)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.draw(pixel, self.x - size / 2, self.y - size / 2, 0, size, size)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode(blend, alphaMode)
    love.graphics.setShader(oldShader)
end

return Area
