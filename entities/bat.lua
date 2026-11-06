local Enemy = require "entities.enemy"
local Entity = require "entities.entity"
local Movement = require "components.movement"
local Levels = require "components.stats.levels"

-- Cave bats: small fliers that swoop at the player in a wavy line, bite by touch, back off for a moment and come again
-- Gravity doesnt pull them, blocks still stop them, out of sight they drift about
local Bat = Enemy:new()
registerEntity("Bat", Bat)
Bat.loot = {}
Bat.xpReward = BAT_XP
-- Where its level's stat points go: mostly faster, then a harder bite
Bat.build = {swiftness = 5, strength = 3, constitution = 2}

local WOBBLE = 1.4 * TILE_SIZE  -- How far the wavy line swings
local WOBBLE_SPEED = 5          -- Swings a second(radians)
local FLAP_SPEED = 12           -- Wing frames a second

-- Frames from the bat sheet(creatures/bat.png): wings up, level and down
-- center is the row(16 pixel layout) the body is on, so every frame lines up while it flaps
local SHEET_CELL = {18, 9}
local FRAMES = {up = {column = 1, center = 4}, level = {column = 2, center = 2}, down = {column = 3, center = 2}}
local FLAP_ORDER = {"up", "level", "down", "level"}
local sheet, quad = nil, nil


function Bat:new(x, y)
    local bat = Entity:new(x, y, BAT_HP)
    setmetatable(bat, self)
    self.__index = self
    if x == nil or y == nil then
        return bat
    end

    bat.name = "Bat"
    bat.width = TILE_SIZE * 0.7
    bat.height = TILE_SIZE * 0.5
    bat.radius = TILE_SIZE * 0.36
    bat.movement = Movement(BAT_SPEED, 0)
    bat.hpBar.regen, bat.hpBar.baseRegen = 0, 0
    bat.contactDamage = BAT_TOUCH
    bat.time = love.math.random() * 10      -- Drives the wobble and the wings, so bats dont flap in step
    bat.retreat = 0                         -- Seconds left flying away after a bite
    bat.drift = {love.math.random() * 2 - 1, love.math.random() * 2 - 1}
    Levels.setLevel(bat, Levels.forPosition(x, y), self.build)

    bat.body:setFixedRotation(true)
    bat.body:setSleepingAllowed(false)
    bat.body:setGravityScale(0)
    local shape = love.physics.newCircleShape(bat.radius)
    bat.fixture = love.physics.newFixture(bat.body, shape, 1)
    bat.fixture:setCategory(ENEMY_CATEGORY)
    bat.fixture:setGroupIndex(-ENEMY_CATEGORY)
    bat.fixture:setRestitution(0.3)
    bat.fixture:setUserData(bat)
    return bat
end


function Bat:update(dt)
    if self.dying ~= nil then
        self:updateDying(dt)
        return
    end
    if not self:keepLoaded() then
        return
    end
    Entity.update(self, dt)
    self:hitManaBlocks(dt)
    self.body:setGravityScale(0)
    self.time = self.time + dt
    self.retreat = math.max(0, self.retreat - dt)
    self.flashTime = math.max(0, (self.flashTime or 0) - dt)

    local x, y = self.body:getWorldCenter()
    local px, py = player.body:getWorldCenter()
    local dx, dy = px - x, py - y
    local d = math.sqrt(dx * dx + dy * dy)
    local speed = self.movement.maxSpeed
    local vx, vy
    if d <= BAT_SIGHT and d > 1 and not player:isDead() and map:castRay(x, y, px, py) == nil then
        local ux, uy = dx / d, dy / d
        if self.retreat > 0 then
            ux, uy = -ux, -uy * 0.5 - 0.5     -- Away and up
        end
        -- A wavy line: a sideways swing across the way it flies
        local swing = math.cos(self.time * WOBBLE_SPEED) * WOBBLE * WOBBLE_SPEED
        vx = ux * speed - uy * swing * 0.3
        vy = uy * speed + ux * swing * 0.3
    else
        -- Drifts about, turning now and then
        if love.math.random() < dt * 0.5 then
            self.drift = {love.math.random() * 2 - 1, love.math.random() * 2 - 1}
        end
        vx, vy = self.drift[1] * speed * 0.3, self.drift[2] * speed * 0.3 + math.sin(self.time * 3) * TILE_SIZE
    end
    self.body:setLinearVelocity(vx + (self.movement.pushX or 0), vy)
end


function Bat:onMeleeHit(target)
    -- A bite lands, it flies off for a moment
    self.retreat = BAT_RETREAT_TIME
end


function Bat:damage(damage, power, kind)
    if self.dying ~= nil then
        return
    end
    self.flashTime = HIT_FLASH_TIME
    self.lastHitTime = spells.time
    Entity.damage(self, damage, power, kind)
end


function Bat:die()
    self.dying = 0
    self.contactDamage = 0
end


function Bat:updateDying(dt)
    if self.body:isActive() then
        self.body:setActive(false)
    end
    self.dying = self.dying + dt
    if self.dying >= DEATH_TIME then
        self:destroy()
    end
end


function Bat:draw()
    -- Its wings flapping through the frames, falling and fading when it dies
    local x, y = self.body:getWorldCenter()
    if sheet == nil then
        sheet, quad = creatureSheet("bat", SHEET_CELL[1], SHEET_CELL[2])
    end
    local alpha = 1
    if self.dying ~= nil then
        alpha = math.max(0, 1 - self.dying / DEATH_TIME)
        y = y + self.dying * TILE_SIZE * 2
    end
    local frame = FRAMES[FLAP_ORDER[math.floor(self.time * FLAP_SPEED) % #FLAP_ORDER + 1]]
    if self.dying ~= nil then
        frame = FRAMES.down
    end
    local q = quad(frame.column)
    local ox, oy = SHEET_CELL[1] * ART_UNIT / 2, (frame.center + 0.5) * ART_UNIT
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(sheet, q, math.floor(x + 0.5), math.floor(y + 0.5), 0, ART_SCREEN, ART_SCREEN, ox, oy)
    if (self.flashTime or 0) > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.55, 0.12, 0.1, alpha)
        love.graphics.draw(sheet, q, math.floor(x + 0.5), math.floor(y + 0.5), 0, ART_SCREEN, ART_SCREEN, ox, oy)
    end
    love.graphics.pop()
end


function Bat:isAwake()
    -- Flying isnt being awake(it never lands), only a recent hit or a Self spell keeps its area loaded
    if next(self.selfEffects or {}) ~= nil then
        return true
    end
    return self.lastHitTime ~= nil and spells.time - self.lastHitTime < ENEMY_AWAKE_TIME
end


function Bat:load(data)
    self.hpBar = data.hpBar or self.hpBar
    self.statsDirty = true
    self.lastHitTime = nil
end

return Bat
