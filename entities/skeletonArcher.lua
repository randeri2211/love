local Zombie = require "entities.zombie"
local Entity = require "entities.entity"
local Movement = require "components.movement"
local Levels = require "components.stats.levels"

-- Skeleton archers: the zombie body and walk with a skeleton skin, but they keep their distance and shoot arrows
-- In range and in sight they raise the bow at the player for SKELETON_AIM_TIME, then shoot an arrow aimed for its arc
-- (see world_utils/projectiles), too close they back off, too far they walk in
local SkeletonArcher = Zombie:new()
registerEntity("SkeletonArcher", SkeletonArcher)
SkeletonArcher.entityName = "SkeletonArcher"
SkeletonArcher.skin = "skeleton"
SkeletonArcher.hp = SKELETON_HP
SkeletonArcher.loot = {}
SkeletonArcher.xpReward = SKELETON_XP
-- Where its level's stat points go: arrows hit harder(Strength), then tougher, a little faster
SkeletonArcher.build = {strength = 5, constitution = 3, swiftness = 2}

-- The bow as pixel art pointing right(the way it shoots), drawn further as it aims: w wood, d grip, s string,
-- a arrow shaft, h arrow head, f fletching. GRIP is the pixel held in the hand, the bow turns around it
local BOW_FRAMES = {
    {
        "......w.....",
        "......sw....",
        "......s.w...",
        "......s.w...",
        "......s..d..",
        "......s..d..",
        "......s..d..",
        "......s.w...",
        "......s.w...",
        "......sw....",
        "......w.....",
    },
    {
        "......w.....",
        "......sw....",
        ".....s..w...",
        ".....s..w...",
        "....s....d..",
        "...fsaaaaaah",
        "....s....d..",
        ".....s..w...",
        ".....s..w...",
        "......sw....",
        "......w.....",
    },
    {
        "......w.....",
        ".....s.w....",
        "....s...w...",
        "...s....w...",
        "..s......d..",
        ".fsaaaaaaaah",
        "..s......d..",
        "...s....w...",
        "....s...w...",
        ".....s.w....",
        "......w.....",
    },
}
local BOW_GRIP = {9, 5}
local BOW_PALETTE = {
    w = {0.58, 0.38, 0.2, 1},
    d = {0.34, 0.21, 0.11, 1},
    s = {0.92, 0.9, 0.84, 1},
    a = {0.62, 0.46, 0.3, 1},
    h = {0.8, 0.82, 0.86, 1},
    f = {0.85, 0.3, 0.25, 1},
}
local bowImages = {}


local function bowImage(index)
    if bowImages[index] ~= nil then
        return bowImages[index]
    end
    local rows = BOW_FRAMES[index]
    local data = love.image.newImageData(#rows[1], #rows)
    for y, row in ipairs(rows) do
        for x = 1, #row do
            local c = BOW_PALETTE[row:sub(x, x)]
            if c ~= nil then
                data:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4])
            end
        end
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    bowImages[index] = image
    return image
end


function SkeletonArcher:new(x, y)
    local archer = Zombie.new(self, x, y)
    if x == nil or y == nil then
        return archer
    end
    archer.movement = Movement(SKELETON_SPEED, BASE_JUMP_HEIGHT)
    archer.contactDamage = SKELETON_TOUCH
    archer.shotRest = love.math.random() * SKELETON_SHOT_REST
    archer.aimTime = nil        -- Seconds drawing the bow, nil while not aiming
    archer.statsDirty = true
    return archer
end


local function aimAt(x, y, tx, ty)
    -- Arrow velocity from x, y that lands at tx, ty with the arrow gravity, the flatter of the two arcs
    -- Out of reach it shoots at 45 degrees, as far as it can
    local g, v = GRAVITY * ARROW_GRAVITY, ARROW_SPEED
    local dx, up = tx - x, y - ty
    local side = dx >= 0 and 1 or -1
    dx = math.abs(dx)
    local under = v ^ 4 - g * (g * dx * dx + 2 * up * v * v)
    local angle = math.pi / 4
    if under >= 0 and dx > 1 then
        angle = math.atan((v * v - math.sqrt(under)) / (g * dx))
    end
    return side * v * math.cos(angle), -v * math.sin(angle)
end


function SkeletonArcher:update(dt)
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
    self.body:setGravityScale(self:gravityScale())
    self.shotRest = math.max(0, self.shotRest - dt)

    local x, y = self.body:getWorldCenter()
    local px, py = player.body:getWorldCenter()
    local vx, vy = self.body:getLinearVelocity()
    local dx = px - x
    local side = dx > 0 and 1 or -1
    local far = math.abs(dx)
    local headY = y - self.height * 0.3
    local sees = not player:isDead() and distance(x, y, px, py) <= SKELETON_SIGHT and map:castRay(x, headY, px, py) == nil
    local walking = false
    vx = self.movement.pushX or 0

    if sees then
        self:face(side > 0 and "right" or "left")
        if self.aimTime ~= nil then
            -- Drawing the bow, it stands still and lets go once it is drawn
            self.aimTime = self.aimTime + dt
            if self.aimTime >= SKELETON_AIM_TIME then
                local sx, sy = x + side * self.width * 0.6, headY + self.height * 0.1
                local avx, avy = aimAt(sx, sy, px, py)
                local damage = ARROW_DAMAGE * (self.combatStats and self.combatStats.touchScale or 1)
                map.projectiles:shoot(self, sx, sy, avx, avy, damage)
                self.aimTime = nil
                self.shotRest = SKELETON_SHOT_REST
            end
        elseif self.shotRest <= 0 and far <= SKELETON_RANGE[2] * 1.3 then
            self.aimTime = 0
        elseif far < SKELETON_RANGE[1] then
            vx, walking = vx - side * self.movement.maxSpeed, true    -- Backs off
        elseif far > SKELETON_RANGE[2] then
            vx, walking = vx + side * self.movement.maxSpeed, true    -- Walks in
        end
    else
        self.aimTime = nil
        -- Lost sight: walks at the player like a zombie if they are near
        if far <= SKELETON_SIGHT and math.abs(py - y) <= SKELETON_SIGHT and far > self.width then
            self:face(side > 0 and "right" or "left")
            vx, walking = vx + side * self.movement.maxSpeed, true
        end
    end
    -- A block in front at its feet with room above it gets stepped up with a hop
    if walking and self.grounded then
        local step = vx > 0 and 1 or -1
        local frontX = x + step * (self.width / 2 + 4)
        local feetY = y + self.height / 2 - 4
        if map:solidAt(frontX, feetY) and not map:solidAt(frontX, feetY - TILE_SIZE * 2) then
            vy = -self.movement.jumpHeight
        end
    end
    self.body:setLinearVelocity(vx, vy)
    self:updateAnimation(dt, walking)
end


function SkeletonArcher:updateAnimation(dt, walking)
    -- The zombie walk, with both arms pointed at the player while it draws the bow
    Zombie.updateAnimation(self, dt, walking)
    if self.aimTime ~= nil then
        local x, y = self.body:getWorldCenter()
        local px, py = player.body:getWorldCenter()
        local dx, dy = px - x, py - (y - self.height * 0.2)
        local size = math.sqrt(dx * dx + dy * dy)
        if size > 0 then
            -- Bone angle 0 points down, so the angle that points the arm along dx, dy
            local angle = math.atan2(-dx / size, dy / size)
            self.armPose.right_hand.rotation = angle - 0.08
            self.armPose.left_hand.rotation = angle + 0.08
        end
    end
end


function SkeletonArcher:draw()
    -- The body, and the bow held in front of it while it aims, drawn further back the longer it aims
    Zombie.draw(self)
    if self.aimTime ~= nil and self.dying == nil then
        local x, y = self.body:getWorldCenter()
        local px, py = player.body:getWorldCenter()
        local chest = y - self.height * 0.12       -- Shoulder height, where the arms point from
        local angle = math.atan2(py - chest, px - x)
        local reach = self.width * 1.3              -- Out at the hand tips, clear of the skull
        local bx, by = x + math.cos(angle) * reach, chest + math.sin(angle) * reach
        local drawn = math.min(#BOW_FRAMES, math.floor(self.aimTime / SKELETON_AIM_TIME * #BOW_FRAMES) + 1)
        local scale = TILE_SIZE / 16
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bowImage(drawn), math.floor(bx + 0.5), math.floor(by + 0.5), angle, scale, scale, BOW_GRIP[1] + 0.5, BOW_GRIP[2] + 0.5)
        love.graphics.pop()
    end
end

return SkeletonArcher
