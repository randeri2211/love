local Enemy = require "entities.enemy"
local Entity = require "entities.entity"
local Movement = require "components.movement"
local Biomes = require "world_utils.biomes"
local Levels = require "components.stats.levels"

-- Slimes: blobs that sit, then hop at the player, hurting them by touch. Big ones split into two medium ones when
-- they die, medium into two small ones(SLIME_SIZES), so a group of them is what Area spells and Split shots are for
-- Their color comes from the biome they appear in(green, sand in the desert, pale in the snow)
local Slime = Enemy:new()
Slime.loot = {}
Slime.size = "medium"
-- Where its level's stat points go: tougher first, then a harder touch, a little faster
Slime.build = {constitution = 5, strength = 4, swiftness = 1}

local COLORS = {
    default = {0.35, 0.8, 0.35},
    Desert = {0.85, 0.72, 0.42},
    Snow = {0.62, 0.82, 0.95},
}
local SQUASH_TIME = 0.15        -- Seconds it squashes down before a hop
local LAND_TIME = 0.12          -- Seconds it stays squashed after landing
local SPLIT_PUSH = 2 * TILE_SIZE
local DEATH_TIME = 0.35         -- Seconds it shrinks away

-- Pixel art frames, one character a pixel: o outline, l light, h shine, b body, d dark underside, . nothing
-- eyes are the columns of the left eye pixels(the eyes are drawn on top, so they can look at the player)
local FRAMES = {
    idle = {eyeRow = 5, eyes = {4, 10}, rows = {
        "......oooo......",
        "....oolhhloo....",
        "...olhhllbbbo...",
        "..olhllbbbbbbo..",
        ".olllbbbbbbbbbo.",
        ".obbbbbbbbbbbbo.",
        "obbbbbbbbbbbbbbo",
        "obbbbbbbbbbbbbdo",
        "odbbbbbbbbbbbddo",
        ".oddddddddddddo.",
        "..oooooooooooo..",
    }},
    -- Flat and wide, before a hop and on landing
    squash = {eyeRow = 4, eyes = {5, 11}, rows = {
        "......oooooo......",
        "...oollhhhlloo....",
        "..olhhllbbbbbbo...",
        ".olllbbbbbbbbbbbo.",
        "obbbbbbbbbbbbbbbbo",
        "obbbbbbbbbbbbbbbdo",
        "odbbbbbbbbbbbbbddo",
        ".oddddddddddddddo.",
        "..oooooooooooooo..",
    }},
    -- Tall and narrow in the air
    jump = {eyeRow = 6, eyes = {3, 9}, rows = {
        ".....oooo.....",
        "....olhhlo....",
        "...olhhllbo...",
        "..olhllbbbbo..",
        "..olllbbbbbo..",
        ".obbbbbbbbbbo.",
        ".obbbbbbbbbbo.",
        ".obbbbbbbbbbo.",
        "obbbbbbbbbbbbo",
        "obbbbbbbbbbbdo",
        "odbbbbbbbbbddo",
        ".oddddddddddo.",
        "..oooooooooo..",
    }},
}

local sprites = {}      -- Built frames by frame and color, every slime of a color shares them


local function sprite(frame, color)
    -- The frame as an image in a slime color: the body a little see-through, a dark outline, a light top and a shine
    local key = tostring(frame) .. table.concat(color, ",")
    if sprites[key] ~= nil then
        return sprites[key]
    end
    local c = color
    local palette = {
        o = {c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 1},
        b = {c[1], c[2], c[3], 0.88},
        l = {c[1] + (1 - c[1]) * 0.35, c[2] + (1 - c[2]) * 0.35, c[3] + (1 - c[3]) * 0.35, 0.92},
        h = {0.95, 0.98, 0.95, 1},
        d = {c[1] * 0.68, c[2] * 0.68, c[3] * 0.68, 0.92},
    }
    local rows = frame.rows
    local data = love.image.newImageData(#rows[1], #rows)
    for py, row in ipairs(rows) do
        for px = 1, #row do
            local color = palette[row:sub(px, px)]
            if color ~= nil then
                data:setPixel(px - 1, py - 1, color[1], color[2], color[3], color[4])
            end
        end
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    sprites[key] = image
    return image
end


function Slime:new(x, y)
    local info = SLIME_SIZES[self.size]
    local slime = Entity:new(x, y, info.hp)
    setmetatable(slime, self)
    self.__index = self
    if x == nil or y == nil then
        return slime
    end

    slime.name = self.entityName
    slime.width = TILE_SIZE * info.size
    slime.radius = slime.width / 2
    slime.height = slime.radius * 1.8       -- Its round body, the ground check reads its feet from it
    slime.movement = Movement(SLIME_HOP_SPEED, BASE_JUMP_HEIGHT * SLIME_HOP_HEIGHT)
    slime.hpBar.regen, slime.hpBar.baseRegen = 0, 0
    slime.contactDamage = info.touch
    slime.xpReward = info.xp
    slime.hopWait = love.math.random() * SLIME_HOP_WAIT[2]
    slime.squash = 0                -- 0 to 1 while it squashes down for a hop
    slime.pixel = math.max(1, math.floor(slime.width / 16 + 0.5))   -- Screen pixels per art pixel, small 1, medium 2, big 3
    local biome = Biomes.surface(math.floor(x / TILE_SIZE), map.seed, map.settings)
    slime.color = COLORS[biome.name] or COLORS.default
    Levels.setLevel(slime, Levels.forPosition(x, y), self.build)

    slime.body:setFixedRotation(true)
    slime.body:setSleepingAllowed(false)
    slime.body:setLinearDamping(LINEAR_DAMPING)
    local shape = love.physics.newCircleShape(slime.radius * 0.9)
    slime.fixture = love.physics.newFixture(slime.body, shape, 1)
    slime.fixture:setCategory(ENEMY_CATEGORY)
    slime.fixture:setGroupIndex(-ENEMY_CATEGORY)
    slime.fixture:setFriction(0.8)
    slime.fixture:setUserData(slime)
    return slime
end


function Slime:update(dt)
    if self.dying ~= nil then
        self:updateDying(dt)
        return
    end
    if not self:keepLoaded() then
        return
    end
    Entity.update(self, dt)
    self:hitManaBlocks(dt)
    groundRay(self)
    -- A moment squashed flat when it lands
    if self.grounded and self.wasGrounded == false then
        self.landTime = LAND_TIME
    end
    self.wasGrounded = self.grounded
    self.landTime = math.max(0, (self.landTime or 0) - dt)
    self.body:setGravityScale(self:gravityScale())
    self.flashTime = math.max(0, (self.flashTime or 0) - dt)

    local x, y = self.body:getWorldCenter()
    local px, py = player.body:getWorldCenter()
    local vx, vy = self.body:getLinearVelocity()
    if self.grounded then
        -- Sits still between hops, then squashes and jumps at the player when it can see them
        vx = self.movement.pushX or 0
        self.hopWait = self.hopWait - dt
        local near = math.abs(px - x) <= SLIME_SIGHT and math.abs(py - y) <= SLIME_SIGHT
        if self.hopWait <= SQUASH_TIME and near then
            self.squash = math.min(1, 1 - self.hopWait / SQUASH_TIME)
        end
        if self.hopWait <= 0 then
            self.squash = 0
            self.hopWait = SLIME_HOP_WAIT[1] + love.math.random() * (SLIME_HOP_WAIT[2] - SLIME_HOP_WAIT[1])
            if near then
                local side = px > x and 1 or -1
                vx = side * self.movement.maxSpeed
                vy = -self.movement.jumpHeight
            end
        end
        self.body:setLinearVelocity(vx, vy)
    end
end


function Slime:damage(damage, power, kind)
    if self.dying ~= nil then
        return
    end
    self.flashTime = HIT_FLASH_TIME
    self.lastHitTime = spells.time
    Entity.damage(self, damage, power, kind)
end


function Slime:die()
    -- Shrinks away, and a slime that splits leaves its two halves(made on the next update, not inside a physics callback)
    self.dying = 0
    self.contactDamage = 0
    self.splitDone = false
end


function Slime:updateDying(dt)
    if self.body:isActive() then
        self.body:setActive(false)
    end
    if not self.splitDone then
        self.splitDone = true
        local splits = SLIME_SIZES[self.size].splits
        if splits ~= nil then
            local x, y = self.body:getWorldCenter()
            for i, side in ipairs({-1, 1}) do
                local child = ENTITY_REGISTRY[Slime.NAMES[splits]]:new(x + side * self.radius * 0.5, y - self.radius * 0.3)
                -- The halves keep its level and color, and go when it would have(spawned ones are temporary)
                Levels.setLevel(child, self.level, child.build)
                child.color = self.color
                child.spawned = self.spawned
                child.body:setLinearVelocity(side * SPLIT_PUSH, -SPLIT_PUSH)
                child.lastHitTime = spells.time     -- Awake right away
                map.enemies:addEnemy(child)
            end
        end
    end
    self.dying = self.dying + dt
    if self.dying >= DEATH_TIME then
        self:destroy()
    end
end


function Slime:draw()
    -- Pixel art in the block style: the frame for what it is doing, scaled by a whole number so the pixels stay square,
    -- its bottom on the ground, and two eyes that look at the player
    local x, y = self.body:getWorldCenter()
    local frame = FRAMES.idle
    if self.dying ~= nil or self.squash > 0.3 or (self.landTime or 0) > 0 then
        frame = FRAMES.squash
    elseif not self.grounded then
        frame = FRAMES.jump
    end
    local scale = self.pixel
    local w, h = #frame.rows[1], #frame.rows
    local left = math.floor(x - w * scale / 2 + 0.5)
    local top = math.floor(y + self.radius * 0.9 - h * scale + 0.5)
    local alpha = self.dying ~= nil and math.max(0, 1 - self.dying / DEATH_TIME) or 1
    local image = sprite(frame, self.color)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(image, left, top, 0, scale, scale)
    if (self.flashTime or 0) > 0 then
        -- A hit lights it up red instead of darkening it
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.55, 0.12, 0.1, alpha)
        love.graphics.draw(image, left, top, 0, scale, scale)
        love.graphics.setBlendMode("alpha")
    end
    if self.dying == nil then
        local px = player.body:getWorldCenter()
        local look = px > x and 1 or 0     -- The eyes sit a pixel toward the player
        love.graphics.setColor(0.06, 0.08, 0.06, alpha)
        for i, ex in ipairs(frame.eyes) do
            love.graphics.rectangle("fill", left + (ex + look) * scale, top + frame.eyeRow * scale, scale, scale * 2)
        end
    end
    love.graphics.pop()
end


function Slime:isAwake()
    -- Hopping isnt being awake, only a recent hit or a Self spell keeps its area loaded
    if next(self.selfEffects or {}) ~= nil then
        return true
    end
    return self.lastHitTime ~= nil and spells.time - self.lastHitTime < ENEMY_AWAKE_TIME
end


function Slime:load(data)
    self.hpBar = data.hpBar or self.hpBar
    self.color = data.color or self.color
    self.statsDirty = true
    self.lastHitTime = nil
end


-- One entity per size, they only differ in their size
Slime.NAMES = {big = "BigSlime", medium = "Slime", small = "SmallSlime"}
for size, name in pairs(Slime.NAMES) do
    local class = Slime:new()
    class.size = size
    class.entityName = name
    registerEntity(name, class)
end

return Slime
