-- Wands and staves(see docs/game-design): one item each, its parts are in the stack data(data.parts, in slot order)
-- A wand is a rod, a core and an end cap, a staff a large rod, two cores and a tip
-- Tools.effect turns what is in the hands into what every spell gets(read through the combat stats)
local Tools = {}

-- The part kind each slot takes, in order
Tools.LAYOUTS = {
    Wand = {"rod", "core", "cap"},
    Staff = {"largeRod", "core", "core", "tip"},
}


local function partOf(name)
    local item = name and ITEM_REGISTRY[name]
    return item and item.part
end


local function rodOf(stack)
    -- The rod part of a tool stack, it names the tool and colors its icon
    local parts = stack.data and stack.data.parts
    return parts and partOf(parts[1])
end


for kind in pairs(Tools.LAYOUTS) do
    registerItem(kind, {
        maxStack = 1,
        icon = kind:lower(),
        tool = kind,
        describe = function(stack)
            local rod = rodOf(stack)
            return rod and (rod.wood .. " " .. kind) or kind
        end,
        stackTint = function(stack)
            local rod = rodOf(stack)
            return rod and rod.tint
        end,
    })
end


function Tools.fits(kind, index, name)
    -- True when an item can go in slot index of a tool kind
    local part = partOf(name)
    return part ~= nil and part.kind == Tools.LAYOUTS[kind][index]
end


function Tools.build(kind, parts)
    -- The tool made from parts(item names in slot order), nil when a slot is empty or holds the wrong part
    local layout = Tools.LAYOUTS[kind]
    for i = 1, #layout do
        if not parts[i] or not Tools.fits(kind, i, parts[i]) then
            return nil
        end
    end
    local names = {}
    for i = 1, #layout do
        names[i] = parts[i]
    end
    return {item = kind, count = 1, data = {parts = names}}
end


function Tools.isValid(stack)
    -- True for a tool stack whose parts all still exist and fit(checked when a save loads)
    -- Empty slots are false, not nil
    local item = stack and ITEM_REGISTRY[stack.item]
    if not item or item.tool == nil or type(stack.data) ~= "table" or type(stack.data.parts) ~= "table" then
        return false
    end
    return Tools.build(item.tool, stack.data.parts) ~= nil
end


local MULTIPLIED = {damage = true, cooldown = true, manaCost = true}

local function addParts(effect, stack, share)
    -- Adds what every part of a tool does, share is how much of it counts(an off hand wand gives part of it)
    -- The dig cap is the highest core in the hands, it doesnt get weaker in the off hand
    for i, name in ipairs(stack.data.parts) do
        local part = partOf(name)
        if part.digCap ~= nil then
            effect.digCap = math.max(effect.digCap, part.digCap)
        end
        for key, value in pairs(part.bonus or {}) do
            if MULTIPLIED[key] then
                effect[key] = effect[key] * (1 + (value - 1) * share)
            else
                effect[key] = effect[key] + value * share
            end
        end
    end
end


function Tools.effect(equipment)
    -- What the hands do to every spell: {digCap, damage, cooldown, manaCost(multipliers), knockback, complexity(added)}
    -- Only the main hand casts, an off hand wand adds its parts at OFF_HAND_SHARE, empty hands cast with BARE_HANDS_DIG_CAP
    local effect = {digCap = BARE_HANDS_DIG_CAP, damage = 1, cooldown = 1, manaCost = 1, knockback = 0, complexity = 0}
    local main = equipment and equipment.mainHand
    if not Tools.isValid(main) then
        return effect
    end
    local kind = TOOL_KINDS[ITEM_REGISTRY[main.item].tool]
    effect.damage = effect.damage * kind.damage
    effect.cooldown = effect.cooldown * kind.cooldown
    addParts(effect, main, 1)
    local off = equipment.offHand
    if Tools.isValid(off) then
        addParts(effect, off, OFF_HAND_SHARE)
    end
    return effect
end


-- Describing parts and tools for tooltips and the arcane table: lists of {text, good}
-- good is true for a line that helps, false for one that costs, nil for plain information
local PART_KINDS = {rod = "Wand rod", largeRod = "Staff rod", core = "Core, for wands and staves", cap = "Wand end cap", tip = "Staff tip"}
local KIND_LINES = {
    Wand = "Wand: faster, weaker spells, two can be held",
    Staff = "Staff: slower, stronger spells, takes both hands",
}


local function percentChange(value)
    -- 0.85 is -15, 1.3 is +30(rounded to the nearest, 0.85 - 1 is a hair under -0.15 in floating point)
    return math.floor((value - 1) * 100 + 0.5)
end


function Tools.bonusLines(bonus)
    -- What a part bonus changes, as changes("-10% spell cooldown")
    local lines = {}
    if bonus.damage ~= nil and bonus.damage ~= 1 then
        table.insert(lines, {text = string.format("%+d%% spell damage", percentChange(bonus.damage)), good = bonus.damage > 1})
    end
    if bonus.cooldown ~= nil and bonus.cooldown ~= 1 then
        table.insert(lines, {text = string.format("%+d%% spell cooldown", percentChange(bonus.cooldown)), good = bonus.cooldown < 1})
    end
    if bonus.manaCost ~= nil and bonus.manaCost ~= 1 then
        table.insert(lines, {text = string.format("%+d%% mana cost", percentChange(bonus.manaCost)), good = bonus.manaCost < 1})
    end
    if bonus.knockback ~= nil and bonus.knockback ~= 0 then
        table.insert(lines, {text = string.format("%+.1f knockback", bonus.knockback), good = bonus.knockback > 0})
    end
    if bonus.complexity ~= nil and bonus.complexity ~= 0 then
        table.insert(lines, {text = string.format("%+d max complexity", bonus.complexity), good = bonus.complexity > 0})
    end
    return lines
end


local function better(value, plain, higherIsBetter)
    -- good for a total: true when it is better than plain, false when worse, nil when the same
    if value == plain then
        return nil
    end
    return (value > plain) == higherIsBetter
end


function Tools.effectLines(effect)
    -- What a whole tool does to every spell(Tools.effect), as totals("Spell cooldown 72%")
    local lines = {
        {text = string.format("Dig strength cap  %d", effect.digCap), good = better(effect.digCap, BARE_HANDS_DIG_CAP, true)},
        {text = string.format("Spell damage  %d%%", math.floor(effect.damage * 100 + 0.5)), good = better(effect.damage, 1, true)},
        {text = string.format("Spell cooldown  %d%%", math.floor(effect.cooldown * 100 + 0.5)), good = better(effect.cooldown, 1, false)},
        {text = string.format("Mana cost  %d%%", math.floor(effect.manaCost * 100 + 0.5)), good = better(effect.manaCost, 1, false)},
    }
    if effect.knockback ~= 0 then
        table.insert(lines, {text = string.format("Knockback  %+.1f", effect.knockback), good = effect.knockback > 0})
    end
    if effect.complexity ~= 0 then
        table.insert(lines, {text = string.format("Max complexity  %+d", effect.complexity), good = effect.complexity > 0})
    end
    return lines
end


function Tools.describe(stack)
    -- Tooltip lines of a part or a tool, nil for other items
    local item = ITEM_REGISTRY[stack.item]
    if item == nil then
        return nil
    end
    if item.part ~= nil then
        local part = item.part
        local lines = {{text = PART_KINDS[part.kind]}}
        if part.digCap ~= nil then
            table.insert(lines, {text = string.format("Dig strength cap  %d", part.digCap), good = true})
        end
        for i, line in ipairs(Tools.bonusLines(part.bonus or {})) do
            table.insert(lines, line)
        end
        if #lines == 1 then
            table.insert(lines, {text = "No special effect"})
        end
        return lines
    end
    if item.tool ~= nil and Tools.isValid(stack) then
        local lines = {{text = KIND_LINES[item.tool]}}
        for i, line in ipairs(Tools.effectLines(Tools.effect({mainHand = stack}))) do
            table.insert(lines, line)
        end
        local names = {}
        for i, name in ipairs(stack.data.parts) do
            local partItem = ITEM_REGISTRY[name]
            table.insert(names, partItem.displayName or name)
        end
        table.insert(lines, {text = "Parts: " .. table.concat(names, ", ")})
        if item.tool == "Wand" then
            table.insert(lines, {text = string.format("In the off hand it adds %d%% of its parts", OFF_HAND_SHARE * 100)})
        end
        return lines
    end
    return nil
end

return Tools
