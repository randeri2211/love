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

-- Frames from the slime sheet(creatures/slime.png): idle, squash and jump in columns, a color per row(COLORS order)
-- They face right with the eyes painted on, a slime left of the player is drawn turned the other way
local SHEET_CELL = {18, 13}         -- Cell size at the 16 pixel layout, the frame sits at the bottom middle
local FRAMES = {idle = 1, squash = 2, jump = 3}
local ROWS = {default = 1, Desert = 2, Snow = 3}
local sheet, quad = nil, nil


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
    -- How big it is drawn: the sheet frames are a small slime(one tile), medium ones 1.5 and big ones 2 times that
    slime.pixel = ART_SCREEN * slime.width / TILE_SIZE
    local biome = Biomes.surface(math.floor(x / TILE_SIZE), map.seed, map.settings)
    slime.color = COLORS[biome.name] or COLORS.default
    slime.row = ROWS[biome.name] or ROWS.default     -- Its row on the slime sheet
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
                child.row = self.row
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
    -- Its frame for what it is doing, its bottom on the ground, turned to face the player
    local x, y = self.body:getWorldCenter()
    if sheet == nil then
        sheet, quad = creatureSheet("slime", SHEET_CELL[1], SHEET_CELL[2])
    end
    local frame = FRAMES.idle
    if self.dying ~= nil or self.squash > 0.3 or (self.landTime or 0) > 0 then
        frame = FRAMES.squash
    elseif not self.grounded then
        frame = FRAMES.jump
    end
    local scale = self.pixel
    local w, h = SHEET_CELL[1] * ART_UNIT, SHEET_CELL[2] * ART_UNIT
    local side = player.body:getX() >= x and 1 or -1
    local bottom = math.floor(y + self.radius * 0.9 + 0.5)
    local alpha = self.dying ~= nil and math.max(0, 1 - self.dying / DEATH_TIME) or 1
    local q = quad(frame, self.row or 1)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(sheet, q, math.floor(x + 0.5), bottom, 0, scale * side, scale, w / 2, h)
    if (self.flashTime or 0) > 0 then
        -- A hit lights it up red instead of darkening it
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.55, 0.12, 0.1, alpha)
        love.graphics.draw(sheet, q, math.floor(x + 0.5), bottom, 0, scale * side, scale, w / 2, h)
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
    self.row = data.row or self.row
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
