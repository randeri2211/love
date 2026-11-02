local Inventories = require "items.inventories"

-- Crafting from the recipe list(RECIPE_REGISTRY, filled by the recipes folder)
-- A recipe is {output, count, inputs = {{item = name or group = name, count}...}, station, tier, category},
-- recipes without a station are made by hand, the others need that station within interaction distance
local Crafting = {}


local function matches(name, input)
    -- True when an item counts for a recipe input: the item itself, or any item of the group
    if input.item ~= nil then
        return name == input.item
    end
    local item = ITEM_REGISTRY[name]
    return item ~= nil and item.group == input.group
end


function Crafting.have(inventory, input)
    -- How many items in the inventory count for an input
    local total = 0
    for i, slot in ipairs(inventory.slots) do
        if slot and matches(slot.item, input) then
            total = total + slot.count
        end
    end
    return total
end


local function take(inventory, input, count)
    -- Takes items for an input from the last stacks first, like Inventories.remove
    for i = #inventory.slots, 1, -1 do
        local slot = inventory.slots[i]
        if count <= 0 then
            break
        end
        if slot and matches(slot.item, input) then
            local moved = math.min(count, slot.count)
            slot.count = slot.count - moved
            count = count - moved
            if slot.count <= 0 then
                inventory.slots[i] = false
            end
        end
    end
end


function Crafting.nearbyStations(player)
    -- Names of the stations within interaction distance of the player, as a set
    local stations = {}
    local px, py = player:mapCenter()
    py = py + 1     -- The same center Player:interact measures from
    local reach = math.ceil(INTERACT_DISTANCE)
    for x = px - reach, px + reach do
        for y = py - reach, py + reach do
            local block = map:get(x, y)
            if block ~= nil and block.station and distance(px, py, x, y) < INTERACT_DISTANCE then
                stations[block.name] = true
            end
        end
    end
    return stations
end


function Crafting.available(stations)
    -- Recipes that can be made here: by hand, or at one of the stations(a set of names)
    local list = {}
    for i, recipe in ipairs(RECIPE_REGISTRY) do
        if recipe.station == nil or stations[recipe.station] then
            table.insert(list, recipe)
        end
    end
    return list
end


function Crafting.maxTimes(inventory, recipe)
    -- How many times the recipe can be made from what is in the inventory
    local times = math.huge
    for i, input in ipairs(recipe.inputs) do
        times = math.min(times, math.floor(Crafting.have(inventory, input) / input.count))
    end
    return times == math.huge and 0 or times
end


function Crafting.craft(player, recipe, times)
    -- Makes the recipe up to times times, returns how many were made
    -- What doesnt fit in the inventory drops at the player
    times = math.min(times or 1, Crafting.maxTimes(player.inventory, recipe))
    if times <= 0 then
        return 0
    end
    for i, input in ipairs(recipe.inputs) do
        take(player.inventory, input, input.count * times)
    end
    local left = Inventories.add(player.inventory, recipe.output, recipe.count * times)
    if left > 0 then
        local x, y = player.body:getWorldCenter()
        map.drops:spawn(recipe.output, left, x, y, false)
    end
    return times
end


function Crafting.grouped(recipes)
    -- Recipes sorted for the list: by tier(CRAFT_TIERS order), then by category in the order they first appear
    -- Returns {{tier, name, categories = {{name, recipes}...}}...}, only tiers and categories that have recipes
    local tiers = {}
    for t, tierName in ipairs(CRAFT_TIERS) do
        local entry = {tier = t, name = tierName, categories = {}}
        local byName = {}
        for i, recipe in ipairs(recipes) do
            if (recipe.tier or 1) == t then
                local category = byName[recipe.category]
                if category == nil then
                    category = {name = recipe.category or "Other", recipes = {}}
                    byName[recipe.category] = category
                    table.insert(entry.categories, category)
                end
                table.insert(category.recipes, recipe)
            end
        end
        if #entry.categories > 0 then
            table.insert(tiers, entry)
        end
    end
    return tiers
end

return Crafting
