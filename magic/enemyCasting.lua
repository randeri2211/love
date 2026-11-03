local MagicCircle = require "magic.magicCircle"
local Statuses = require "magic.statuses"
local ElementFx = require "magic.elementFx"

-- Enemies casting real spells(see docs: enemy spellcasting): an enemy with a spell list and a mana bar
-- builds a circle in front of itself part by part(MagicCircle.timeline: the ring spirals in, then every rune in flow order,
-- trigger children in between), and when it is done the spell goes off toward the player
-- Only a full freeze breaks a cast(Statuses.isFrozen), the mana is paid when the spell goes off
-- An enemy keeps enemy.spells(a list, the first one it can cast is used) and enemy.casting({spell, timeline, clock}) while it builds
local EnemyCasting = {}


local function target()
    -- What enemies cast at, nil while there is nothing to cast at
    if player == nil or player:isDead() then
        return nil
    end
    return player
end


function EnemyCasting.canSee(enemy, who)
    -- In range with nothing solid in between
    local x, y = enemy.body:getWorldCenter()
    local tx, ty = who.body:getWorldCenter()
    if distance(x, y, tx, ty) > ENEMY_CAST_RANGE * TILE_SIZE then
        return false
    end
    return map:castRay(x, y, tx, ty) == nil
end


function EnemyCasting.circlePosition(enemy)
    -- Where the circle builds: a little in front of the enemy toward its target, at chest height
    local x, y = enemy.body:getWorldCenter()
    local who = target()
    local side = enemy.facing == "left" and -1 or 1
    if who ~= nil then
        side = who.body:getX() < x and -1 or 1
    end
    return x + side * ENEMY_CAST_OFFSET * TILE_SIZE, y - TILE_SIZE * 0.3
end


function EnemyCasting.update(enemy, dt)
    if enemy.spells == nil or enemy.dying then
        return
    end
    local casting = enemy.casting
    if casting ~= nil then
        -- Frozen solid breaks the cast, the circle shatters
        if Statuses.isFrozen(enemy) then
            local cx, cy = EnemyCasting.circlePosition(enemy)
            ElementFx.emit("Frost", cx, cy, TILE_SIZE, 24)
            enemy.casting = nil
            enemy.castRest = ENEMY_CAST_REST
            return
        end
        casting.clock = casting.clock + dt
        if casting.clock >= casting.timeline.total then
            enemy.casting = nil
            enemy.castRest = ENEMY_CAST_REST
            local who = target()
            if who ~= nil then
                -- From the circle toward where the target is now
                local cx, cy = EnemyCasting.circlePosition(enemy)
                local tx, ty = who.body:getWorldCenter()
                enemy.castBuilt = true      -- The circle is already built, the cast circle doesnt draw in again
                casting.spell:shoot(enemy, cx, cy, tx - cx, ty - cy)
                enemy.castBuilt = nil
            end
        end
        return
    end

    enemy.castRest = math.max(0, (enemy.castRest or 0) - dt)
    local who = target()
    if enemy.castRest > 0 or who == nil or Statuses.isFrozen(enemy) or not EnemyCasting.canSee(enemy, who) then
        return
    end
    -- The first spell it has the mana and the cooldown for
    for i, spell in ipairs(enemy.spells) do
        if spell:canCast(enemy) then
            local speed = enemy.combatStats and enemy.combatStats.castSpeed or 1
            enemy.casting = {spell = spell, timeline = MagicCircle.timeline(spell, CAST_RING_TIME / speed, CAST_RUNE_TIME / speed), clock = 0}
            return
        end
    end
end


function EnemyCasting.draw(enemy)
    -- World space, the circle building in front of the enemy
    local casting = enemy.casting
    if casting == nil then
        return
    end
    local cx, cy = EnemyCasting.circlePosition(enemy)
    MagicCircle.draw(casting.spell, cx, cy, ENEMY_CAST_SCALE, {
        timeline = casting.timeline,
        clock = casting.clock,
        spiral = true,
    })
end

return EnemyCasting
