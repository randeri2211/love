local Enemy = require "entities.enemy"
local Entity = require "entities.entity"
local Movement = require "components.movement"
local ManaBar = require "components.manaBar"
local Spell = require "magic.spell"
local MagicCircle = require "magic.magicCircle"
local Structures = require "world_utils.structures"

-- The Unicorn, the first boss(see docs/game-design: Bosses): a ley beast summoned at the altar of its lair(see
-- structures/unicornLair and blocks/summoningAltar). It holds the Laser rune and fights with three attacks, each with a
-- tell, and the same answer to all of them, jump over it or put a block in the way:
--   charge: it scrapes its front right hoof twice, then runs horn first across the arena until it hits a wall, and
--     stands dazed for a moment after
--   beam: a cast circle builds at its horn, then a plain damage Laser is held low across the arena for a second
--   stomp: it rears with a cast circle at its hooves, and lands sending a ground wave both ways(a Bullet with Size,
--     Repel and Damage running along the floor)
-- Between attacks it keeps a middle distance, always within UNICORN_ARENA tiles of its altar, so it never charges out
-- of the lair's door. It leaves when the player dies or goes far from its altar, and isnt saved
-- Dying it drops a Unicorn Horn Rod or a Large Unicorn Horn Rod, and its lair is cleared(its glyph wall opens)
local Unicorn = Enemy:new()
registerEntity("Unicorn", Unicorn)
Unicorn.entityName = "Unicorn"
Unicorn.displayName = "Unicorn"
Unicorn.loot = {}
Unicorn.xpReward = UNICORN_XP

-- Frames from the unicorn sheet(creatures/unicorn.png), facing right
local SHEET_CELL = {44, 44}         -- Cell size at the 16 pixel layout, the feet at the bottom middle(room above to rear)
local FRAMES = {idle = 1, walkA = 2, walkB = 3, scrape = 4, charge = 5, rear = 6}
local sheet, quad = nil, nil

local BODY_W, BODY_H = TILE_SIZE * 2.4, TILE_SIZE * 1.9
local WALK_FRAME_TIME = 0.18
local SCRAPE_TIME = 0.28            -- One scrape of the hoof, it scrapes twice
local STUN_TIME = 0.8               -- Dazed after a charge hits a wall
local REAR_TIME = 0.75              -- Up on its hind legs before the stomp lands
local BEAM_TIME = 1                 -- Seconds the beam is held
local REST_TIME = {1.1, 1.9}        -- Seconds between attacks
local DEATH_TIME = 1.2


local function beamSpell()
    -- The horn beam, held(see Laser:hold), its damage and hit rate are set when it fires(see fireBeam)
    return Spell:new("Laser", {false, false, false, false, false, false})
end


local function waveSpell()
    -- The stomp's ground wave: big, shoving and hard
    return Spell:new("Bullet", {"Size", "Size", "Repel", "Damage", false, false})
end


function Unicorn:new(x, y)
    local unicorn = Entity:new(x, y, UNICORN_HP)
    setmetatable(unicorn, self)
    self.__index = self
    if x == nil or y == nil then
        return unicorn
    end

    unicorn.name = "Unicorn"
    unicorn.boss = true
    unicorn.width, unicorn.height = BODY_W, BODY_H
    unicorn.movement = Movement(UNICORN_SPEED, BASE_JUMP_HEIGHT)
    unicorn.hpBar.regen, unicorn.hpBar.baseRegen = 0, 0
    unicorn.manaBar = ManaBar(1000, 1000, 1000)     -- Its spells never run dry, the attack pattern paces them
    unicorn.contactDamage = UNICORN_TOUCH
    unicorn.side = 1                -- 1 facing right, -1 left
    unicorn.state, unicorn.clock = "rest", 0.8
    unicorn.walkClock = 0
    unicorn.lastAttack = nil
    unicorn.beam = beamSpell()
    unicorn.wave = waveSpell()

    unicorn.body:setFixedRotation(true)
    unicorn.body:setSleepingAllowed(false)
    local shape = love.physics.newRectangleShape(BODY_W, BODY_H)
    unicorn.fixture = love.physics.newFixture(unicorn.body, shape, 3)
    unicorn.fixture:setCategory(ENEMY_CATEGORY)
    unicorn.fixture:setGroupIndex(-ENEMY_CATEGORY)
    unicorn.fixture:setFriction(0.2)
    unicorn.fixture:setUserData(unicorn)
    return unicorn
end


function Unicorn:isAwake()
    return true     -- A boss fight keeps its area loaded
end


function Unicorn:floorY()
    -- Love y of the floor under its feet
    local x, y = self.body:getWorldCenter()
    return y + BODY_H / 2
end


function Unicorn:castOrigin(dx, dy)
    -- The tip of its horn, lowered for the beam
    local x, y = self.body:getWorldCenter()
    return x + self.side * BODY_W * 0.62, y - BODY_H * 0.05
end


function Unicorn:castCirclePosition()
    -- Where its cast circle builds(see EnemyCasting.draw): before the horn for the beam, at its hooves for the stomp
    local x, y = self.body:getWorldCenter()
    if self.casting ~= nil and self.casting.spell == self.wave then
        return x, self:floorY() - TILE_SIZE * 0.4
    end
    return x + self.side * (BODY_W * 0.62 + TILE_SIZE * 0.9), y - BODY_H * 0.05
end


function Unicorn:inArena(x)
    -- True while a love x is inside its arena, around the altar that called it
    return self.altarX == nil or math.abs(x - self.altarX) <= UNICORN_ARENA * TILE_SIZE
end


function Unicorn:leave(text)
    -- Gone back into the ley lines, the altar can call it again
    self:releaseBeam()
    if uihandler ~= nil and text ~= nil then
        uihandler:toast(text, BOSS_COLOR)
    end
    self:destroy()
end


function Unicorn:releaseBeam()
    for i, beam in ipairs(self.beams or {}) do
        beam:release()
    end
    self.beams = nil
end


function Unicorn:nextAttack()
    -- Any attack but the last one, the stomp only when the player is close enough for the wave to matter, and the charge
    -- only with room to run toward the player(not into the edge of its arena when the player stands in the door)
    local x = self.body:getWorldCenter()
    local px = player.body:getWorldCenter()
    local side = px > x and 1 or -1
    local room = self.altarX == nil and math.huge or math.abs(self.altarX + side * UNICORN_ARENA * TILE_SIZE - x)
    local options = {}
    for i, attack in ipairs({"charge", "beam", "stomp"}) do
        local fits = (attack ~= "stomp" or math.abs(px - x) < UNICORN_STOMP_RANGE)
            and (attack ~= "charge" or room > BODY_W / 2 + UNICORN_CHARGE_ROOM * TILE_SIZE)
        if attack ~= self.lastAttack and fits then
            table.insert(options, attack)
        end
    end
    if #options == 0 then
        options = {"beam"}
    end
    local attack = options[love.math.random(1, #options)]
    self.lastAttack = attack
    if attack == "charge" then
        self.state, self.clock = "scrape", SCRAPE_TIME * 2
    elseif attack == "beam" then
        self:startCast(self.beam, "beam")
    else
        self:startCast(self.wave, "rear")
    end
end


function Unicorn:startCast(spell, state)
    -- Its circle builds while it holds still(the tell), the attack goes off when the circle is done
    self.casting = {spell = spell, timeline = MagicCircle.timeline(spell, UNICORN_RING_TIME, UNICORN_RUNE_TIME), clock = 0}
    self.state = state
    self.clock = math.max(self.casting.timeline.total, state == "rear" and REAR_TIME or 0)
end


function Unicorn:fireBeam()
    -- The beam held low across the arena the way it faces, a plain hit every UNICORN_BEAM_INTERVAL
    local side = self.side
    self.channel, self.channelCast, self.castBuilt = nil, true, true
    self.beam:shoot(self, nil, nil, side, 0)
    self.channelCast, self.castBuilt = nil, nil
    self.beams = self.channel or {}
    self.channel = nil
    for i, beam in ipairs(self.beams) do
        beam.aim = function() return side, 0 end
        beam.damage = UNICORN_BEAM_DAMAGE
        beam.interval = UNICORN_BEAM_INTERVAL
        beam.manaCost = 0
        beam.width = TILE_SIZE * 0.35
    end
end


function Unicorn:fireWave()
    -- Lands: a ground wave runs out each way along the floor
    local x = self.body:getWorldCenter()
    local radius = self.wave:getParams().radius
    local y = self:floorY() - radius - 3
    self.castBuilt = true
    for i, side in ipairs({-1, 1}) do
        self.wave.cooldownEnd = nil     -- Both waves are one stomp
        self.wave:shoot(self, x + side * BODY_W * 0.6, y, side, 0)
    end
    self.castBuilt = nil
end


function Unicorn:update(dt)
    if self.dying ~= nil then
        self:updateDying(dt)
        return
    end
    -- It leaves when there is no fight: the player died or went far from its altar
    if player:isDead() then
        self:leave("The Unicorn fades back into the ley lines")
        return
    end
    local x, y = self.body:getWorldCenter()
    local px, py = player.body:getWorldCenter()
    if self.altarX ~= nil and distance(px, py, self.altarX, self.altarY) > UNICORN_LEASH * TILE_SIZE then
        self:leave("The Unicorn fades back into the ley lines")
        return
    end
    self:keepLoaded()
    Entity.update(self, dt)
    groundRay(self)
    self.flashTime = math.max(0, (self.flashTime or 0) - dt)
    self.clock = self.clock - dt
    local vx, vy = self.body:getLinearVelocity()
    local push = self.movement.pushX or 0
    local toPlayer = px > x and 1 or -1
    local state = self.state
    self.contactDamage = state == "charge" and UNICORN_CHARGE_DAMAGE or UNICORN_TOUCH

    if self.casting ~= nil then
        self.casting.clock = self.casting.clock + dt
    end

    if state == "rest" then
        -- Keeps a middle distance, facing the player, then picks an attack
        self.side = toPlayer
        local far = math.abs(px - x)
        vx = 0
        if far > UNICORN_RANGE[2] then
            vx = toPlayer * self.movement.maxSpeed
        elseif far < UNICORN_RANGE[1] then
            vx = -toPlayer * self.movement.maxSpeed
            -- Not into a wall behind it
            if map:solidAt(x - toPlayer * (BODY_W / 2 + 6), y) then
                vx = 0
            end
        end
        if vx ~= 0 and not self:inArena(x + (vx > 0 and 1 or -1) * (BODY_W / 2 + 6)) then
            vx = 0      -- Never out of its arena
        end
        self.walking = vx ~= 0
        if self.clock <= 0 and self.grounded then
            self.walking = false
            self:nextAttack()
        end
        self.body:setLinearVelocity(vx + push, vy)
    elseif state == "scrape" then
        -- The tell: still, facing the player, scraping its hoof twice
        self.side = toPlayer
        self.body:setLinearVelocity(push, vy)
        if self.clock <= 0 then
            self.state, self.clock = "charge", UNICORN_CHARGE_TIME
            self.chargeSide = self.side
            self.chargeStall = 0
        end
    elseif state == "charge" then
        -- Horn first until a wall stops it(or it ran its whole time)
        local speed = UNICORN_CHARGE_SPEED * self.chargeSide
        self.body:setLinearVelocity(speed, vy)
        local frontX = x + self.chargeSide * (BODY_W / 2 + 4)
        local blocked = map:solidAt(frontX, y) or map:solidAt(frontX, y + BODY_H * 0.35) or not self:inArena(frontX)
        self.chargeStall = math.abs(vx) < UNICORN_CHARGE_SPEED * 0.3 and self.chargeStall + dt or 0
        if blocked or self.chargeStall > 0.15 then
            self.state, self.clock = "stunned", STUN_TIME
            self.body:setLinearVelocity(-self.chargeSide * TILE_SIZE * 3, -TILE_SIZE * 4)    -- Bounces off the wall
        elseif self.clock <= 0 then
            self.state, self.clock = "rest", REST_TIME[1]
        end
    elseif state == "stunned" then
        self.body:setLinearVelocity(push + vx * math.exp(-6 * dt), vy)
        if self.clock <= 0 then
            self.state, self.clock = "rest", REST_TIME[1]
        end
    elseif state == "beam" then
        self.body:setLinearVelocity(push, vy)
        if self.casting ~= nil and self.clock <= 0 then
            self.casting = nil
            self:fireBeam()
            self.state, self.clock = "beaming", BEAM_TIME
        end
    elseif state == "beaming" then
        self.body:setLinearVelocity(push, vy)
        if self.clock <= 0 then
            self:releaseBeam()
            self.state, self.clock = "rest", REST_TIME[1] + love.math.random() * (REST_TIME[2] - REST_TIME[1])
        end
    elseif state == "rear" then
        self.body:setLinearVelocity(push, vy)
        if self.clock <= 0 then
            self.casting = nil
            self:fireWave()
            self.state, self.clock = "rest", REST_TIME[1] + love.math.random() * (REST_TIME[2] - REST_TIME[1])
        end
    end
    if self.walking then
        self.walkClock = self.walkClock + dt
    end
end


function Unicorn:damage(damage, power, kind)
    if self.dying ~= nil then
        return
    end
    self.flashTime = HIT_FLASH_TIME
    self.lastHitTime = spells.time
    Entity.damage(self, damage, power, kind)
end


function Unicorn:dropLoot()
    -- One of its horns, a wand rod or a staff rod
    local x, y = self.body:getWorldCenter()
    local rod = love.math.random() < 0.5 and "UnicornHornRod" or "LargeUnicornHornRod"
    map.drops:spawn(rod, 1, x, y)
end


function Unicorn:die()
    self.dying = 0
    self.contactDamage = 0
    self.casting = nil
    self:releaseBeam()
    if self.lairId ~= nil then
        Structures.bossDefeated(self.lairId)
    end
    if uihandler ~= nil then
        uihandler:toast("The Unicorn is beaten", BOSS_COLOR)
    end
end


function Unicorn:updateDying(dt)
    if self.body:isActive() then
        self.body:setActive(false)
    end
    self.dying = self.dying + dt
    if self.dying >= DEATH_TIME then
        self:destroy()
    end
end


function Unicorn:destroy()
    self:releaseBeam()
    Enemy.destroy(self)
end


function Unicorn:frame()
    -- Its frame for what it is doing
    local state = self.state
    if self.dying ~= nil or state == "stunned" then
        return FRAMES.idle
    elseif state == "scrape" then
        -- Hoof up, down, up, down
        local t = SCRAPE_TIME * 2 - self.clock
        return (math.floor(t / (SCRAPE_TIME / 2)) % 2 == 0) and FRAMES.scrape or FRAMES.idle
    elseif state == "charge" or state == "beam" or state == "beaming" then
        return FRAMES.charge        -- Head down, horn forward
    elseif state == "rear" then
        return FRAMES.rear
    elseif self.walking then
        return (math.floor(self.walkClock / WALK_FRAME_TIME) % 2 == 0) and FRAMES.walkA or FRAMES.walkB
    end
    return FRAMES.idle
end


function Unicorn:draw()
    local x, y = self.body:getWorldCenter()
    if sheet == nil then
        sheet, quad = creatureSheet("unicorn", SHEET_CELL[1], SHEET_CELL[2])
    end
    local w, h = SHEET_CELL[1] * ART_UNIT, SHEET_CELL[2] * ART_UNIT
    local bottom = math.floor(self:floorY() + 0.5)
    local alpha = self.dying ~= nil and math.max(0, 1 - self.dying / DEATH_TIME) or 1
    local q = quad(self:frame(), 1)
    love.graphics.push("all")
    -- Dazed, it wobbles
    local tilt = self.state == "stunned" and math.sin(love.timer.getTime() * 18) * 0.04 or 0
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(sheet, q, math.floor(x + 0.5), bottom, tilt, ART_SCREEN * self.side, ART_SCREEN, w / 2, h)
    if (self.flashTime or 0) > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.55, 0.12, 0.1, alpha)
        love.graphics.draw(sheet, q, math.floor(x + 0.5), bottom, tilt, ART_SCREEN * self.side, ART_SCREEN, w / 2, h)
    end
    love.graphics.pop()
end


function Unicorn:light(add)
    -- Its horn glows, so the fight is never in the dark
    local hx, hy = self:castOrigin(self.side, 0)
    add(hx, hy, UNICORN_LIGHT, 1)
end

return Unicorn
