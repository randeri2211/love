local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local ManaBar = require "components.manaBar"
local CombatStats = require "components.stats.combatStats"
local Levels = require "components.stats.levels"
local MagicCircle = require "magic.magicCircle"
local ManaNetwork = require "world_utils.manaNetwork"
local Scrolls = require "items.scrolls"

-- Spell Turrets(see docs/game-design: Spell Turrets): a 1 tile block that casts the spell of the Bound Scroll in its slot
-- at enemies it can see, paid by the mana network in reach(see world_utils/manaNetwork)
-- A turret is a caster with stats: its tier gives the points of a player of TIERS level, its kind spreads them(the way
-- enemies get theirs, see Levels.setLevel), so its spells get stronger through the same stats as the player's
-- It builds a cast circle like a caster(MagicCircle.timeline), its spells never hit the player and cant break blocks
-- A Laser scroll is held on its target(the laser asks the caster where to aim, see aimPoint and Laser:updateHeld)
-- while the target stays in sight, its casts and the held beam are paid through ManaNetwork.pay like any caster's
-- It works near the player or in a running chunk(see world_utils/simulation), its block update does the casting
local SpellTurret = Block:new()
SpellTurret.turret = true

-- Tiers: the level its stat points are from, its material and how sturdy it is(columns of the sheet)
SpellTurret.TIERS = {
    {name = "Wood", level = 1, hp = 6},
    {name = "Copper", level = 5, hp = 10},
    {name = "Iron", level = 10, hp = 14},
    {name = "Gold", level = 15, hp = 16},
    {name = "Arcanite", level = 20, hp = 20},
}
-- Kinds: how the points are spread(rows of the sheet)
SpellTurret.KINDS = {
    {name = "Arcane", build = {intelligence = 3, concentration = 1}, text = "Stronger spells, runs more complex scrolls"},
    {name = "Rapid", build = {concentration = 3, wisdom = 1}, text = "Casts faster, shorter cooldowns"},
    {name = "Attuned", build = {wisdom = 3, intelligence = 1}, text = "Its spells cost the network less mana"},
}

local sheet, quads = nil, {}    -- assets/art*/machines/spellTurret.png, cells of 16 at the 16 pixel layout, 1 apart


local function quad(tier, kind)
    local key = tier .. "," .. kind
    if quads[key] == nil then
        local step, size = 17 * ART_UNIT, 16 * ART_UNIT
        quads[key] = love.graphics.newQuad((tier - 1) * step, (kind - 1) * step, size, size, sheet:getDimensions())
    end
    return quads[key]
end


function SpellTurret:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = self.info.name
    block.damageThreshold = 1
    block.hpBar = HPBar(self.info.tier.hp, self.info.tier.hp, 0)
    block.scroll = false        -- The Bound Scroll in its slot
    block.aim = "nearest"       -- What it aims at: "nearest" or "weakest"(lowest hp)
    block.casting = nil         -- The circle it is building: {spell, timeline, clock}
    if sheet == nil then
        sheet = artImage(ART_FOLDER .. "machines/spellTurret.png")
    end

    return block
end


function SpellTurret:center()
    return self.x + self.width / 2, self.y + self.height / 2
end


function SpellTurret:caster()
    -- The caster its spells come from: stats from its tier and kind, a body standing in for its block(spells only ask
    -- where it is), allied with the player so its spells pass through them
    if self.casterData == nil then
        local cx, cy = self:center()
        local caster = {
            name = self.name, stats = {}, hpBar = HPBar(1, 1, 0), manaBar = ManaBar(0, 1, 0), movement = {},
            alliedWithPlayer = true, turret = self,
            body = {
                getWorldCenter = function() return cx, cy end,
                getPosition = function() return cx, cy end,
                getX = function() return cx end,
                getY = function() return cy end,
                getLinearVelocity = function() return 0, 0 end,
                isDestroyed = function() return false end,
            },
            selfBuff = function() return 1 end,
            -- Where a held laser aims: its target, nothing once it lost it or stopped being updated(its chunk stopped)
            aimPoint = function()
                local target = self.aimTarget
                if target == nil or target.body:isDestroyed() or target.dying or spells.time - (self.tickTime or -1) > 0.25 then
                    return nil
                end
                return target.body:getWorldCenter()
            end,
        }
        for i, stat in ipairs(Levels.STATS) do
            caster.stats[stat] = 0
        end
        Levels.setLevel(caster, self.info.tier.level, self.info.kind.build)
        caster.combatStats = CombatStats(caster)
        caster.combatStats.digCap = 0       -- Its spells never break blocks, a turret doesnt dig into the base it guards
        -- Wisdom makes a turret's spells cheaper(the network pays, so max mana means nothing to it)
        local saved = math.min(TURRET_WISDOM_MANA * caster.stats.wisdom, TURRET_WISDOM_CAP)
        caster.combatStats.spellManaCost = caster.combatStats.spellManaCost * (1 - saved)
        self.casterData = caster
    end
    return self.casterData
end


function SpellTurret:canTake(stack)
    -- Whether a stack can go in its slot: a Bound Scroll it can cast
    local spell = Scrolls.spellOf(stack)
    if spell == nil then
        return false, "Only Bound Scrolls go here"
    end
    if spell.core == "Self" then
        return false, "A turret cant cast a Self spell"
    end
    local params = spell:getParams()
    local max = spell:getMaxComplexity(self:caster())
    if params.complexity > max then
        return false, string.format("Too complex: %d, it takes up to %d", params.complexity, max)
    end
    return true
end


function SpellTurret:sees(enemy)
    -- A clear line from it to the enemy(only blocks stand in the way, it can see past itself)
    local x1, y1 = self:center()
    local x2, y2 = enemy.body:getWorldCenter()
    local hit = map:castRay(x1, y1, x2, y2, function(block) return block == self or not block.solid end)
    return hit == nil
end


function SpellTurret:target()
    -- The enemy it aims at among the ones it sees: the nearest, or the weakest
    local x, y = self:center()
    local best, bestScore = nil, math.huge
    for i, enemy in pairs(map.enemies.enemies) do
        if enemy.body ~= nil and not enemy.body:isDestroyed() and not enemy.dying then
            local ex, ey = enemy.body:getWorldCenter()
            local d = math.sqrt((ex - x) ^ 2 + (ey - y) ^ 2) / TILE_SIZE
            if d <= TURRET_RANGE then
                local score = self.aim == "weakest" and enemy.hpBar.currentHP or d
                if score < bestScore and self:sees(enemy) then
                    best, bestScore = enemy, score
                end
            end
        end
    end
    return best
end


local function holding(caster)
    -- True while one of its held beams is still going(running out of mana ends one on its own)
    for i, beam in ipairs(caster.channel or {}) do
        if beam.held then
            return true
        end
    end
    return false
end


function SpellTurret:update(dt)
    -- Builds a circle while an enemy is in sight and its network can pay, casts at the enemy when it is done
    -- A held laser stays on while its target is in sight and it is the same scroll
    local spell = self.scroll and Scrolls.spellOf(self.scroll)
    local x, y = self:center()
    local node = spell ~= nil and ManaNetwork.nodeNear(x, y)
    local enemy = node and self:target()
    local caster = self:caster()
    self.aimTarget, self.tickTime = enemy or nil, spells.time
    if caster.channel ~= nil then
        if enemy and caster.channelSpell == spell and holding(caster) then
            return
        end
        for i, beam in ipairs(caster.channel) do
            beam:release()
        end
        caster.channel, caster.channelSpell = nil, nil
    end
    if not enemy then
        self.casting = nil
        return
    end
    local casting = self.casting
    if casting == nil or casting.spell ~= spell then
        self.casting = nil
        if spell:canCast(caster) then
            local speed = caster.combatStats.castSpeed
            self.casting = {spell = spell, clock = 0,
                timeline = MagicCircle.timeline(spell, PLAYER_CAST_RING_TIME / speed, PLAYER_CAST_RUNE_TIME / speed)}
        end
        return
    end
    casting.clock = casting.clock + dt
    if casting.clock >= casting.timeline.total then
        self.casting = nil
        local ex, ey = enemy.body:getWorldCenter()
        local dx, dy = ex - x, ey - y
        caster.castBuilt = true
        caster.channelCast = spell.core == "Laser"      -- A laser is held on the target(see aimPoint)
        spell:shoot(caster, x, y, dx, dy)
        caster.castBuilt, caster.channelCast = nil, nil
        if caster.channel ~= nil then
            caster.channelSpell = spell
        end
    end
end


function SpellTurret:draw()
    love.graphics.draw(sheet, quad(self.info.tierIndex, self.info.kindIndex), self.x, self.y, 0,
        self.width / (16 * ART_UNIT), self.height / (16 * ART_UNIT))
end


function SpellTurret:drawGlow()
    -- The circle it is building, over its gem
    local casting = self.casting
    if casting ~= nil then
        local x, y = self:center()
        MagicCircle.draw(casting.spell, x, y - self.height * 0.9, CAST_CIRCLE_SCALE * 0.6,
            {timeline = casting.timeline, clock = casting.clock, spiral = true})
    end
end


function SpellTurret:drawIcon(x, y, size)
    love.graphics.draw(sheet, quad(self.info.tierIndex, self.info.kindIndex), x, y, 0, size / (16 * ART_UNIT), size / (16 * ART_UNIT))
end


function SpellTurret:interact()
    uihandler:openStation(self)
end


function SpellTurret:tooltip()
    local spell = self.scroll and Scrolls.spellOf(self.scroll)
    return string.format("%s\n%s\nTakes up to complexity %d", self.info.title,
        spell and ("Casting " .. tostring(self.scroll.data.name)) or "No scroll (" .. INTERACT_KEY:upper() .. " to open)",
        self:caster().combatStats.maxComplexity)
end


function SpellTurret:damage(dmg, power, source)
    -- It holds together while a scroll is in it, the scroll is never lost
    if self.scroll then
        return
    end
    Block.damage(self, dmg, power, source)
end


function SpellTurret:hasOwnState()
    return Block.hasOwnState(self) or self.scroll ~= false or self.aim ~= "nearest"
end


function SpellTurret:saveData()
    -- Its scroll and setting, not its caster or circle
    return {
        name = self.name, x = self.x, y = self.y, width = self.width, height = self.height,
        hpBar = {currentHP = self.hpBar.currentHP, maxHP = self.hpBar.maxHP, regen = 0},
        scroll = self.scroll, aim = self.aim,
    }
end


function SpellTurret:load(data)
    Block.load(self, data)
    self.scroll = type(data.scroll) == "table" and data.scroll or false
    self.aim = data.aim == "weakest" and "weakest" or "nearest"
end


-- One block class per tier and kind, "WoodArcaneTurret" to "ArcaniteAttunedTurret"
for t, tier in ipairs(SpellTurret.TIERS) do
    for k, kind in ipairs(SpellTurret.KINDS) do
        local class = SpellTurret:new()
        class.info = {name = tier.name .. kind.name .. "Turret", title = tier.name .. " " .. kind.name .. " Turret",
            tier = tier, kind = kind, tierIndex = t, kindIndex = k}
        registerBlock(class.info.name, class)
    end
end

return SpellTurret
