local ElementFx = require "magic.elementFx"
local Statuses = require "magic.statuses"
local Crit = require "magic.crit"

-- Elements(see docs/game-design): Fire burns, Frost slows, Poison stacks damage over time, Lightning jumps to enemies nearby
-- Each element rune switches its params on(BASE_SPELL_PARAMS has them at 0), scaled by its settings:
-- power makes it stronger, duration makes it last longer(or jump further), runes before it in the flow change both
local Elements = {}

-- In the order they show, every element sets a strength param from power and a time param from duration
Elements.LIST = {
    {name = "Fire", power = {"burnDps", 4}, duration = {"burnTime", 3}},
    {name = "Frost", power = {"frostSlow", 0.4}, duration = {"frostTime", 3}},
    {name = "Poison", power = {"poisonDps", 2}, duration = {"poisonTime", 8}},
    {name = "Lightning", power = {"chainDamage", 0.5}, duration = {"chainRange", 6 * TILE_SIZE}},
}
Elements.BY_NAME = {}
for i, element in ipairs(Elements.LIST) do
    Elements.BY_NAME[element.name] = element
end


function Elements.apply(name, params, settings)
    -- An element rune effect: sets its params from its settings(power and duration multipliers)
    local element = Elements.BY_NAME[name]
    params[element.power[1]] = element.power[2] * settings.power
    params[element.duration[1]] = element.duration[2] * settings.duration
end


function Elements.of(params)
    -- Names of the elements a spell has, nil when it has none
    local list = nil
    for i, element in ipairs(Elements.LIST) do
        if (params[element.power[1]] or 0) > 0 then
            list = list or {}
            table.insert(list, element.name)
        end
    end
    return list
end


function Elements.valuesFor(powers)
    -- Element values for something that isnt a spell(a creature with a burning touch): {Fire = 1, Poison = 0.5}
    -- gives each listed element its base strength times the number, with its base duration
    local values = {}
    for i, element in ipairs(Elements.LIST) do
        local power = powers[element.name]
        values[element.power[1]] = power and element.power[2] * power or 0
        values[element.duration[1]] = power and element.duration[2] or 0
    end
    return values
end


function Elements.pick(params)
    -- The element params a spell instance carries to its hits
    local picked = {}
    for i, element in ipairs(Elements.LIST) do
        picked[element.power[1]] = params[element.power[1]]
        picked[element.duration[1]] = params[element.duration[1]]
    end
    return picked
end


local function chain(form, hit, x, y)
    -- Lightning: part of the hit jumps to the nearest enemies around the one that was hit
    local values = form.elementParams
    local found = {}
    for i, enemy in pairs(map.enemies.enemies) do
        if enemy ~= hit and not enemy.dying and enemy.body ~= nil and not enemy.body:isDestroyed() then
            local ex, ey = enemy.body:getWorldCenter()
            local d = distance(x, y, ex, ey)
            if d <= values.chainRange then
                table.insert(found, {enemy = enemy, d = d, x = ex, y = ey})
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    for i = 1, math.min(CHAIN_TARGETS, #found) do
        local target = found[i]
        ElementFx.bolt(x, y, target.x, target.y)
        local amount = Crit.roll(form, form.damage * values.chainDamage, target.x, target.y)
        target.enemy:damage(amount, nil, "Lightning")
    end
end


function Elements.onHit(form, entity, x, y)
    -- A hit of a spell with elements: statuses go on creatures, Lightning jumps on from them, blocks only get sparks
    local values = form.elementParams
    if values == nil then
        return
    end
    if form.elements ~= nil then
        for i, name in ipairs(form.elements) do
            ElementFx.emit(name, x, y, 6, 10)
        end
    end
    if entity == nil or entity.type == "Block" or entity.hpBar == nil then
        return
    end
    Statuses.apply(entity, values, form)
    if values.chainDamage > 0 then
        local ex, ey = entity.body:getWorldCenter()
        chain(form, entity, ex, ey)
    end
end

return Elements
