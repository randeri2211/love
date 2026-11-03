local ElementFx = require "magic.elementFx"
local Crit = require "magic.crit"

-- What element hits leave on a creature: burning, frozen(slowed) and poisoned
-- entity.statuses is plain data({burn, frost, poison}), these functions change it, Entity.update runs it every frame
local Statuses = {}

local PARTICLE_RATE = 14    -- Particles a second from a creature with a status


function Statuses.apply(entity, values, source)
    -- A hit with element values(see Elements.pick), source is what hit(its crit chance goes to the ticks, nil for none)
    local statuses = entity.statuses or {}
    entity.statuses = statuses
    local critChance = source and source.critChance or 0
    local critMultiplier = source and source.critMultiplier or CRIT_MULTIPLIER
    if values.burnDps > 0 then
        -- A new burn refreshes the time and keeps the stronger flame, it doesnt stack
        -- A kindling burn keeps how long it has been burning, so hitting it again keeps it hot(see burnFactor)
        local burn = statuses.burn or {dps = 0, tick = 0, burning = 0}
        burn.dps = math.max(burn.dps, values.burnDps)
        burn.time = math.max(burn.time or 0, values.burnTime)
        burn.duration = math.max(burn.duration or 0, values.burnTime)   -- A full burn, what wildfire passes on
        burn.kindle = math.max(burn.kindle or 0, values.burnKindle or 0)
        burn.spread = math.max(burn.spread or 0, values.burnSpread or 0)
        burn.fromPlayer = source ~= nil and source.player == player     -- Wildfire from the player never comes back to them
        burn.critChance, burn.critMultiplier = critChance, critMultiplier
        statuses.burn = burn
    end
    if values.poisonDps > 0 then
        -- Every poisoned hit adds a stack, up to POISON_MAX_STACKS or more for a Poison rune with dots(poisonMax)
        local poison = statuses.poison or {dps = 0, stacks = 0, tick = 0}
        poison.dps = math.max(poison.dps, values.poisonDps)
        local most = (values.poisonMax or 0) > 0 and values.poisonMax or POISON_MAX_STACKS
        poison.max = math.max(poison.max or 0, most)
        poison.stacks = math.min(poison.max, poison.stacks + 1)
        poison.time = math.max(poison.time or 0, values.poisonTime)
        poison.critChance, poison.critMultiplier = critChance, critMultiplier
        statuses.poison = poison
    end
    if values.frostSlow > 0 then
        -- Frost resistance takes off part of the slow
        local frost = statuses.frost or {slow = 0}
        local resisted = 1 - entity:damageReduction("Frost")
        local slow = values.frostSlow * resisted
        -- Right after a full freeze it cant be frozen solid again for a while(see FREEZE_IMMUNITY)
        local most = FROST_MAX_SLOW
        if (entity.freezeImmuneTime or 0) > 0 then
            most = math.min(most, FREEZE_IMMUNE_SLOW)
        end
        local wasFrozen = frost.slow >= 1
        frost.slow = math.min(most, math.max(frost.slow, slow))
        frost.shatter = math.max(frost.shatter or 0, (values.frostShatter or 0) * resisted)
        -- A full freeze isnt made longer by hitting it again, so it always ends
        if not wasFrozen then
            frost.time = math.max(frost.time or 0, values.frostTime)
        end
        statuses.frost = frost
        entity.statsDirty = true    -- Its speed comes from the combat stats
    end
end


local function hurt(entity, status, dt, amount, kind)
    -- Damage over time lands every STATUS_TICK so a creature isnt hit every frame, every tick can crit
    -- kind is the element, its resistance blocks part of it
    status.tick = status.tick + dt
    if status.tick >= STATUS_TICK then
        status.tick = status.tick - STATUS_TICK
        local x, y = entity.body:getWorldCenter()
        entity:damage(Crit.roll(status, amount * STATUS_TICK, x, y), nil, kind)
    end
end


function Statuses.update(entity, dt)
    if (entity.freezeImmuneTime or 0) > 0 then
        entity.freezeImmuneTime = entity.freezeImmuneTime - dt
    end
    local statuses = entity.statuses
    if statuses == nil or entity.dying or entity.body:isDestroyed() then
        return
    end
    local x, y = entity.body:getWorldCenter()
    local spread = (entity.width or TILE_SIZE) / 2
    local burn = statuses.burn
    if burn ~= nil then
        ElementFx.trail({"Fire"}, x, y, spread, PARTICLE_RATE, dt)
        burn.burning = (burn.burning or 0) + dt
        hurt(entity, burn, dt, burn.dps * Statuses.burnFactor(burn), "Fire")
        burn.time = burn.time - dt
        if burn.time <= 0 then
            statuses.burn = nil
        end
    end
    local poison = statuses.poison
    if poison ~= nil and not entity.dying then
        ElementFx.trail({"Poison"}, x, y, spread, PARTICLE_RATE * poison.stacks / 2, dt)
        hurt(entity, poison, dt, poison.dps * poison.stacks, "Poison")
        poison.time = poison.time - dt
        if poison.time <= 0 then
            statuses.poison = nil
        end
    end
    local frost = statuses.frost
    if frost ~= nil then
        ElementFx.trail({"Frost"}, x, y, spread, PARTICLE_RATE, dt)
        frost.time = frost.time - dt
        if frost.time <= 0 then
            if frost.slow >= 1 then
                entity.freezeImmuneTime = FREEZE_IMMUNITY
            end
            statuses.frost = nil
            entity.statsDirty = true
        end
    end
end


function Statuses.burnFactor(burn)
    -- Kindling(spiral marks): the burn starts weaker and grows stronger the longer it has been burning, the same total
    -- over one full burn, more for keeping it lit
    local kindle = burn.kindle or 0
    if kindle <= 0 then
        return 1
    end
    local grown = math.min(1, (burn.burning or 0) / KINDLE_TIME)
    return 1 - KINDLE_STEP * kindle + 2 * KINDLE_STEP * kindle * grown
end


function Statuses.died(entity)
    -- Wildfire(spark marks): a burning creature that dies passes its burn, one spark fewer, to the nearest creature near it
    -- A burn the player cast never jumps to the player
    local burn = entity.statuses and entity.statuses.burn
    if burn == nil or (burn.spread or 0) <= 0 or entity.body == nil or entity.body:isDestroyed() then
        return
    end
    local x, y = entity.body:getWorldCenter()
    local creatures = {}
    if not burn.fromPlayer and player ~= nil and not player:isDead() then
        table.insert(creatures, player)
    end
    for i, enemy in ipairs(map.enemies.enemies) do
        table.insert(creatures, enemy)
    end
    local nearest, best = nil, WILDFIRE_RANGE
    for i, creature in ipairs(creatures) do
        if creature ~= entity and not creature.dying and creature.body ~= nil and not creature.body:isDestroyed() then
            local cx, cy = creature.body:getWorldCenter()
            local d = distance(x, y, cx, cy)
            if d <= best then
                nearest, best = creature, d
            end
        end
    end
    if nearest == nil then
        return
    end
    local nx, ny = nearest.body:getWorldCenter()
    ElementFx.bolt(x, y, nx, ny)
    local statuses = nearest.statuses or {}
    nearest.statuses = statuses
    local passed = statuses.burn or {dps = 0, tick = 0, burning = 0}
    passed.dps = math.max(passed.dps, burn.dps)
    passed.time = math.max(passed.time or 0, burn.duration or burn.time)
    passed.duration = math.max(passed.duration or 0, burn.duration or burn.time)
    passed.kindle = math.max(passed.kindle or 0, burn.kindle or 0)
    passed.spread = math.max(passed.spread or 0, burn.spread - 1)
    passed.fromPlayer = burn.fromPlayer
    passed.critChance, passed.critMultiplier = burn.critChance, burn.critMultiplier
    statuses.burn = passed
    ElementFx.emit("Fire", nx, ny, TILE_SIZE / 2, 16)
end


function Statuses.speedFactor(entity)
    -- How much of its speed a creature keeps(frost slows it)
    local frost = entity.statuses and entity.statuses.frost
    return frost and (1 - frost.slow) or 1
end


function Statuses.shatterFactor(entity)
    -- How much harder hits land on a creature Frost slowed(1 when it isnt frozen)
    local frost = entity.statuses and entity.statuses.frost
    return frost and 1 + (frost.shatter or 0) or 1
end


function Statuses.isFrozen(entity)
    -- Frozen solid(a full Frost freeze), the one thing that breaks an enemy cast later
    local frost = entity.statuses and entity.statuses.frost
    return frost ~= nil and frost.slow >= 1
end


function Statuses.has(entity, name)
    return entity.statuses ~= nil and entity.statuses[name] ~= nil
end

return Statuses
