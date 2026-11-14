local Spell = require "magic.spell"

-- Spell scrolls(see docs/game-design: Spell scrolls): a Blank Scroll is bound with a spell at the Scribe's Desk and
-- becomes a Bound Scroll, holding a snapshot of that spell in its stack data(data.spell, data.name), like a wand its parts
-- Held in the hotbar, the place button casts it(see main.lua), and a Spell Turret casts the one in its slot
-- Editing the spell in the spellbook later doesnt change scrolls already bound
local Scrolls = {}

local PARCHMENT = {0.93, 0.85, 0.66, 1}

-- Spells rebuilt from scroll data, by the data table, so a scroll's spell keeps its cooldown and isnt rebuilt every frame
local cache = setmetatable({}, {__mode = "k"})


function Scrolls.bind(name, spell)
    -- A Bound Scroll stack holding a copy of a spell
    return {item = "BoundScroll", count = 1, data = {name = name, spell = spell:toData()}}
end


function Scrolls.spellOf(stack)
    -- The spell in a Bound Scroll stack, nil for anything else
    if not stack or stack.item ~= "BoundScroll" or type(stack.data) ~= "table" or type(stack.data.spell) ~= "table" then
        return nil
    end
    if cache[stack.data] == nil then
        cache[stack.data] = Spell.fromData(stack.data.spell)
    end
    return cache[stack.data]
end


function Scrolls.held(owner)
    -- The spell of a Bound Scroll in the selected hotbar slot, nil when it holds something else
    return Scrolls.spellOf(owner.inventory.slots[owner.hotbarSlot])
end


local function runeName(name)
    -- "FireRune" style registry names read as words
    return (name:gsub("(%l)(%u)", "%1 %2"))
end


local function describe(spell, lines, indent, depth)
    -- The runes of a circle, its triggers' circles under them
    local names = {}
    for i = 1, SPELL_SLOTS do
        local name, child = spell:readSlot(spell.slots[i])
        if name then
            table.insert(names, runeName(name))
            if child ~= nil and depth < MAX_SPELL_DEPTH then
                table.insert(lines, {text = string.format("%s%s: %s", indent, runeName(name), runeName(child.core))})
                describe(child, lines, indent .. "  ", depth + 1)
            end
        end
    end
    if #names > 0 and depth == 1 then
        table.insert(lines, 1, {text = "Runes: " .. table.concat(names, ", ")})
    end
end


function Scrolls.lines(stack)
    -- Tooltip lines of a Bound Scroll: the spell in it(see ui/itemTooltip)
    local spell = Scrolls.spellOf(stack)
    if spell == nil then
        return {{text = "Bound at a Scribe's Desk"}}
    end
    local params = spell:getParams()
    local lines = {}
    describe(spell, lines, "  ", 1)
    table.insert(lines, 1, {text = "Form: " .. runeName(spell.core), good = true})
    table.insert(lines, {text = string.format("Mana cost  %.1f", params.manaCost)})
    table.insert(lines, {text = string.format("Complexity  %d", params.complexity)})
    table.insert(lines, {text = "Place button: cast it"})
    return lines
end


registerItem("BlankScroll", {displayName = "Blank Scroll", icon = "scroll", tint = PARCHMENT})

registerItem("BoundScroll", {
    displayName = "Bound Scroll",
    icon = "scroll",
    tint = PARCHMENT,
    maxStack = 1,
    describe = function(stack)
        return "Scroll: " .. tostring(stack.data.name or "Spell")
    end,
    stackTint = function(stack)
        -- The parchment colored a little by its spell
        local spell = Scrolls.spellOf(stack)
        local c = spell and spell:getParams().color or PARCHMENT
        return {0.55 * PARCHMENT[1] + 0.45 * c[1], 0.55 * PARCHMENT[2] + 0.45 * c[2], 0.55 * PARCHMENT[3] + 0.45 * c[3], 1}
    end,
    tooltipLines = Scrolls.lines,
})

return Scrolls
