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
        local burn = statuses.burn or {dps = 0, tick = 0}
        burn.dps = math.max(burn.dps, values.burnDps)
        burn.time = math.max(burn.time or 0, values.burnTime)
        burn.critChance, burn.critMultiplier = critChance, critMultiplier
        statuses.burn = burn
    end
    if values.poisonDps > 0 then
        -- Every poisoned hit adds a stack, up to POISON_MAX_STACKS
        local poison = statuses.poison or {dps = 0, stacks = 0, tick = 0}
        poison.dps = math.max(poison.dps, values.poisonDps)
        poison.stacks = math.min(POISON_MAX_STACKS, poison.stacks + 1)
        poison.time = math.max(poison.time or 0, values.poisonTime)
        poison.critChance, poison.critMultiplier = critChance, critMultiplier
        statuses.poison = poison
    end
    if values.frostSlow > 0 then
        -- Frost resistance takes off part of the slow
        local frost = statuses.frost or {slow = 0}
        local slow = values.frostSlow * (1 - entity:damageReduction("Frost"))
        frost.slow = math.min(FROST_MAX_SLOW, math.max(frost.slow, slow))
        frost.time = math.max(frost.time or 0, values.frostTime)
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
    local statuses = entity.statuses
    if statuses == nil or entity.dying or entity.body:isDestroyed() then
        return
    end
    local x, y = entity.body:getWorldCenter()
    local spread = (entity.width or TILE_SIZE) / 2
    local burn = statuses.burn
    if burn ~= nil then
        ElementFx.trail({"Fire"}, x, y, spread, PARTICLE_RATE, dt)
        hurt(entity, burn, dt, burn.dps, "Fire")
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
            statuses.frost = nil
            entity.statsDirty = true
        end
    end
end


function Statuses.speedFactor(entity)
    -- How much of its speed a creature keeps(frost slows it)
    local frost = entity.statuses and entity.statuses.frost
    return frost and (1 - frost.slow) or 1
end


function Statuses.has(entity, name)
    return entity.statuses ~= nil and entity.statuses[name] ~= nil
end

return Statuses
