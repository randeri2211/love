local Inventories = require "items.inventories"

-- Crafting from the recipe list(RECIPE_REGISTRY, filled by the recipes folder)
-- A recipe is {output, count, inputs = {{item = name or group = name, count}...}, station, tier, category},
-- recipes without a station are made by hand, the others need that station within interaction distance
-- Inputs come from every chest within interaction distance and the player inventory(see Crafting.sources),
-- the chests first so what the player carries stays with them
local Crafting = {}


local function matches(name, input)
    -- True when an item counts for a recipe input: the item itself, or any item of the group
    if input.item ~= nil then
        return name == input.item
    end
    local item = ITEM_REGISTRY[name]
    return item ~= nil and item.group == input.group
end


function Crafting.have(sources, input)
    -- How many items in the inventories(a list, see Crafting.sources) count for an input
    local total = 0
    for j, inventory in ipairs(sources) do
        for i, slot in ipairs(inventory.slots) do
            if slot and matches(slot.item, input) then
                total = total + slot.count
            end
        end
    end
    return total
end


local function take(sources, input, count)
    -- Takes items for an input, inventory by inventory in order, from the last stacks first like Inventories.remove
    for j, inventory in ipairs(sources) do
        for i = #inventory.slots, 1, -1 do
            local slot = inventory.slots[i]
            if count <= 0 then
                return
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
end


function Crafting.nearbyBlocks(player, test)
    -- Blocks within interaction distance of the player that pass test(block), nearest first
    local found = {}
    local px, py = player:mapCenter()
    py = py + 1     -- The same center Player:interact measures from
    local reach = math.ceil(INTERACT_DISTANCE)
    for x = px - reach, px + reach do
        for y = py - reach, py + reach do
            local block = map:get(x, y)
            local d = distance(px, py, x, y)
            if block ~= nil and d < INTERACT_DISTANCE and test(block) then
                table.insert(found, {block = block, d = d})
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    local blocks = {}
    for i, entry in ipairs(found) do
        blocks[i] = entry.block
    end
    return blocks
end


function Crafting.nearbyStations(player)
    -- Names of the stations within interaction distance of the player, as a set
    local stations = {}
    for i, block in ipairs(Crafting.nearbyBlocks(player, function(block) return block.station end)) do
        stations[block.name] = true
    end
    return stations
end


function Crafting.nearbyChests(player)
    -- Chests within interaction distance, nearest first
    return Crafting.nearbyBlocks(player, function(block) return block.chest end)
end


function Crafting.sources(player)
    -- Where crafting takes its inputs from: the nearby chests, nearest first, then the player inventory
    local sources = {}
    for i, chest in ipairs(Crafting.nearbyChests(player)) do
        table.insert(sources, chest.inventory)
    end
    table.insert(sources, player.inventory)
    return sources
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


function Crafting.maxTimes(sources, recipe)
    -- How many times the recipe can be made from what is in the inventories(a list, see Crafting.sources)
    local times = math.huge
    for i, input in ipairs(recipe.inputs) do
        times = math.min(times, math.floor(Crafting.have(sources, input) / input.count))
    end
    return times == math.huge and 0 or times
end


function Crafting.craft(player, recipe, times)
    -- Makes the recipe up to times times from the nearby chests and the inventory, returns how many were made
    -- What it makes goes in the inventory, what doesnt fit drops at the player
    local sources = Crafting.sources(player)
    times = math.min(times or 1, Crafting.maxTimes(sources, recipe))
    if times <= 0 then
        return 0
    end
    for i, input in ipairs(recipe.inputs) do
        take(sources, input, input.count * times)
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
