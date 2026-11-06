-- Item sets: armor pieces name their set(armor.set), wearing 2 or 4 pieces of one set turns on its bonuses
-- A bonus is an effect, the same kind of table trinkets and focuses carry(see Effects in items/equipments):
--   stats = {intelligence = 2}, defense, resist = {Fire = 10}, castSpeed, critChance, critDamage,
--   manaCost and cooldown(multipliers), complexity and manaRegen(added),
--   spells = {{form, param, mult, add, when, above}} changes the spells cast(see Spell:shoot),
--   text = {"..."} what the tooltip says about it
local Sets = {}

-- Every element, for bonuses that resist them all
local function allResist(amount)
    return {Fire = amount, Frost = amount, Poison = amount, Lightning = amount}
end

Sets.LIST = {
    -- Forge sets: resistances and Area spells(see docs/game-design: Armor sets by crafting station)
    Copper = {
        title = "Copper",
        tiers = {
            [2] = {resist = allResist(8), text = {"+8 every resistance"}},
            [4] = {spells = {{form = "Area", param = "areaRadius", mult = 1.2}}, text = {"Area spells 20% bigger"}},
        },
    },
    Iron = {
        title = "Iron",
        tiers = {
            [2] = {defense = 4, text = {"+4 defense"}},
            [4] = {resist = allResist(12), spells = {{form = "Area", param = "areaRadius", mult = 1.3}},
                text = {"+12 every resistance", "Area spells 30% bigger"}},
        },
    },
}


function Sets.worn(equipment)
    -- How many pieces of every set are worn, by set name
    local counts = {}
    for i, slot in ipairs(ARMOR_SLOTS) do
        local stack = equipment[slot.name]
        local set = stack and ITEM_REGISTRY[stack.item].armor.set
        if set ~= nil then
            counts[set] = (counts[set] or 0) + 1
        end
    end
    return counts
end


function Sets.active(equipment)
    -- The set bonuses turned on: {set, pieces, effect} for every tier reached
    local list = {}
    for name, pieces in pairs(Sets.worn(equipment)) do
        local set = Sets.LIST[name]
        if set ~= nil then
            for need, effect in pairs(set.tiers) do
                if pieces >= need then
                    table.insert(list, {set = set, pieces = need, effect = effect})
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.set.title < b.set.title or (a.set.title == b.set.title and a.pieces < b.pieces) end)
    return list
end

return Sets
