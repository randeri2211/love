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

-- Pixel art frames, the left half of the bat(mirrored for the right): o outline, d wing, b body, l belly, e eye
-- center is the row the body is on, so every frame lines up while it flaps
local FRAMES = {
    up = {center = 4, half = {
        "o........",
        "do.......",
        "ddo....o.",
        "dddo..obb",
        ".ddddobeb",
        "..dddobbb",
        "....oobbl",
        "......obl",
        ".......oo",
    }},
    level = {center = 2, half = {
        ".......o.",
        "......obb",
        "ooo..obeb",
        "dddoodbbb",
        "ddddddbbl",
        ".ddd.oobl",
        "......oo.",
    }},
    down = {center = 2, half = {
        ".......o.",
        "......obb",
        ".....obeb",
        "....odbbb",
        "...oddbbl",
        "..odddobl",
        ".oddd..oo",
        "oddo.....",
        "do.......",
    }},
}
local FLAP_ORDER = {"up", "level", "down", "level"}
local PALETTE = {
    o = {0.1, 0.07, 0.12, 1},
    d = {0.38, 0.26, 0.42, 1},
    b = {0.55, 0.44, 0.56, 1},
    l = {0.72, 0.62, 0.68, 1},
    e = {1, 0.32, 0.25, 1},
}
local sprites = {}


local function sprite(frame)
    -- The frame as an image, the half mirrored into a whole bat
    if sprites[frame] ~= nil then
        return sprites[frame]
    end
    local rows = {}
    for i, half in ipairs(frame.half) do
        rows[i] = half .. half:reverse()
    end
    local data = love.image.newImageData(#rows[1], #rows)
    for py, row in ipairs(rows) do
        for px = 1, #row do
            local color = PALETTE[row:sub(px, px)]
            if color ~= nil then
                data:setPixel(px - 1, py - 1, color[1], color[2], color[3], color[4])
            end
        end
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    sprites[frame] = image
    return image
end
local DEATH_TIME = 0.5          -- Seconds it falls and fades


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
    -- Pixel art like the blocks, the wings flapping through their frames, falling and fading when it dies
    local x, y = self.body:getWorldCenter()
    local alpha = 1
    if self.dying ~= nil then
        alpha = math.max(0, 1 - self.dying / DEATH_TIME)
        y = y + self.dying * TILE_SIZE * 2
    end
    local frame = FRAMES[FLAP_ORDER[math.floor(self.time * FLAP_SPEED) % #FLAP_ORDER + 1]]
    if self.dying ~= nil then
        frame = FRAMES.down
    end
    local scale = TILE_SIZE / 16
    local image = sprite(frame)
    -- The body row of every frame sits on the bat center
    local left = math.floor(x - image:getWidth() * scale / 2 + 0.5)
    local top = math.floor(y - (frame.center + 0.5) * scale + 0.5)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(image, left, top, 0, scale, scale)
    if (self.flashTime or 0) > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.55, 0.12, 0.1, alpha)
        love.graphics.draw(image, left, top, 0, scale, scale)
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
