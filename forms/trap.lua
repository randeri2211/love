local Form = require "forms.form"
local MagicCircle = require "magic.magicCircle"

local Trap = Form:new()

local TRAP_BODY_RADIUS = 6      -- Size of the trap itself, the trigger zone is params.triggerRadius
local TRAP_GLYPH_RADIUS = 9

function Trap:new(caster, params, x, y, dirX, dirY)
    local trap = Form:new(caster)
    setmetatable(trap,self)
    self.__index = self

    trap.form = "trap"
    if caster == nil then
        return trap
    end

    -- Values from the compiled spell params
    trap.damage = params.damage
    trap.terrainDamage = params.terrainDamage
    trap.triggerRadius = params.triggerRadius
    trap.armTime = params.armTime           -- Seconds before it can go off
    trap.lifetime = params.lifetime         -- Gone(onExpire) if nothing walks into it
    trap.color = params.color
    trap.direction = {dirX, dirY}
    trap.time = 0

    -- Tossed forward and falls to the ground, Split throws several across the fan
    trap.body = love.physics.newBody(p_world, x + dirX * TILE_SIZE * 0.5, y + dirY * TILE_SIZE * 0.5, "dynamic")
    trap.body:setFixedRotation(true)
    trap.shape = love.physics.newCircleShape(TRAP_BODY_RADIUS)
    trap.fixture = love.physics.newFixture(trap.body, trap.shape, 1)
    trap.fixture:setCategory(SPELLS_CATEGORY)
    trap.fixture:setGroupIndex(-SPELLS_CATEGORY)
    trap.fixture:setFriction(1)
    trap.fixture:setRestitution(0.1)
    trap.body:setLinearVelocity(dirX * params.throwSpeed, dirY * params.throwSpeed)

    return trap
end


function Trap:isArmed()
    return self.time >= self.armTime
end


function Trap:enemiesInRange()
    -- Enemies overlapping the trigger zone
    local x, y = self.body:getWorldCenter()
    local r = self.triggerRadius
    local found = {}
    p_world:queryBoundingBox(x - r, y - r, x + r, y + r, function(fixture)
        if fixture:getCategory() == ENEMY_CATEGORY then
            local x1, y1, x2, y2 = fixture:getBoundingBox()
            local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            if distance(cx, cy, x, y) <= r + math.min(x2 - x1, y2 - y1) / 2 then
                table.insert(found, {fixture = fixture, x = cx, y = cy})
            end
        end
        return true
    end)
    return found
end


function Trap:update(dt)
    self.time = self.time + dt

    if self:isArmed() then
        local enemies = self:enemiesInRange()
        if #enemies > 0 then
            -- Goes off once, hitting every enemy in the zone
            local x, y = self.body:getWorldCenter()
            for i, found in ipairs(enemies) do
                if not found.fixture:isDestroyed() then
                    local dx, dy = found.x - x, found.y - y
                    local size = math.max(0.001, math.sqrt(dx * dx + dy * dy))
                    self:hit(getEntityFromFixture(found.fixture), found.x, found.y, dx / size, dy / size)
                end
            end
            spells:destroy(self)
            return
        end
    end

    if self.time >= self.lifetime then
        self:expire()
    end
end


function Trap:draw()
    local x, y = self.body:getWorldCenter()
    local c = self.color

    love.graphics.push("all")
    -- Trigger zone pulses once armed
    if self:isArmed() then
        local pulse = 0.15 + 0.1 * math.sin(self.time * 4)
        love.graphics.setColor(c[1], c[2], c[3], pulse)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", x, y, self.triggerRadius, 32)
    end

    -- Dimmer while arming
    local alpha = self:isArmed() and 1 or 0.45
    love.graphics.setColor(0.06, 0.07, 0.11, alpha)
    love.graphics.circle("fill", x, y, TRAP_GLYPH_RADIUS, 24)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x, y, TRAP_GLYPH_RADIUS, 24)
    local rune = RUNE_REGISTRY["Trap"]
    if rune ~= nil and rune.glyph ~= nil then
        MagicCircle.drawGlyph(rune.glyph, x, y, TRAP_GLYPH_RADIUS * 0.6, 1.2)
    end
    love.graphics.pop()
end


function Trap:isFixture(fixture)
    return self.fixture == fixture
end


function Trap:onContact(fixture, entity, contact)
    -- Landing on blocks or bumping enemies isnt a hit, the trigger zone handles enemies
end


function Trap:destroy()
    self.body:destroy()
end

return Trap
