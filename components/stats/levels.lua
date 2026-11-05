local Generator = require "world_utils.generator"

-- Experience and levels(see docs/game-design: Early game): the player earns XP, a level up gives stat points to spend,
-- enemies get the points a player of their level would have, spread by their build(fixed weights per enemy type)
-- An entity with levels keeps level, xp and statPoints, the points it spent are in its stats
local Levels = {}

Levels.STATS = {"strength", "intelligence", "wisdom", "concentration", "swiftness", "constitution"}


function Levels.xpToNext(level)
    -- XP from this level to the next one
    return math.floor(XP_BASE * level ^ XP_EXPONENT + 0.5)
end


function Levels.gain(entity, amount)
    -- Adds XP, levelling up as many times as it fills, every level gives STAT_POINTS_PER_LEVEL points to spend
    if entity == nil or entity.xp == nil or amount <= 0 then
        return
    end
    entity.xp = entity.xp + amount
    while entity.xp >= Levels.xpToNext(entity.level) and entity.level < MAX_LEVEL do
        entity.xp = entity.xp - Levels.xpToNext(entity.level)
        entity.level = entity.level + 1
        entity.statPoints = entity.statPoints + STAT_POINTS_PER_LEVEL
        if entity == player and uihandler ~= nil then
            uihandler:toast(string.format("Level %d, %d stat points to spend", entity.level, entity.statPoints), LEVEL_COLOR)
        end
    end
end


function Levels.spend(entity, stat)
    -- One stat point into a stat, true when there was a point to spend
    if (entity.statPoints or 0) <= 0 or entity.stats[stat] == nil then
        return false
    end
    entity.statPoints = entity.statPoints - 1
    entity.stats[stat] = entity.stats[stat] + 1
    entity.statsDirty = true
    return true
end


function Levels.forPosition(x, y)
    -- Enemy level at a love point: one more every LEVEL_DISTANCE tiles from spawn and every LEVEL_DEPTH tiles underground
    local spawnX = player ~= nil and player.spawnX or 0
    local tx, ty = math.floor(x / TILE_SIZE), math.floor(y / TILE_SIZE)
    local away = math.abs(x - spawnX) / TILE_SIZE
    local depth = math.max(0, ty - Generator.surfaceRow(tx, map.seed, map.settings))
    local level = 1 + math.floor(away / LEVEL_DISTANCE) + math.floor(depth / LEVEL_DEPTH)
    return math.max(1, math.min(MAX_LEVEL, level))
end


function Levels.setLevel(entity, level, build)
    -- Gives an enemy its level and the points of that level, spread by build({stat = weight}) like a player would
    -- Whole points go by the weights, the ones left over to the stats with the biggest remainders
    entity.level = level
    local points = (level - 1) * STAT_POINTS_PER_LEVEL
    local total = 0
    for i, stat in ipairs(Levels.STATS) do
        total = total + (build[stat] or 0)
    end
    if total <= 0 or points <= 0 then
        return
    end
    local given, rest = 0, {}
    for i, stat in ipairs(Levels.STATS) do
        local share = points * (build[stat] or 0) / total
        local whole = math.floor(share)
        entity.stats[stat] = whole
        given = given + whole
        table.insert(rest, {stat = stat, part = share - whole})
    end
    table.sort(rest, function(a, b) return a.part > b.part end)
    for i = 1, points - given do
        local stat = rest[i].stat
        entity.stats[stat] = entity.stats[stat] + 1
    end
    entity.statsDirty = true
end

return Levels
