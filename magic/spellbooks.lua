local Spell = require "magic.spell"
local Spellbook = require "components.spellbook"

-- Functions working on a spellbook component
local Spellbooks = {}

function Spellbooks.find(book, id)
    -- The entry with this id and its position in the list
    for i, entry in ipairs(book.spells) do
        if entry.id == id then
            return entry, i
        end
    end
    return nil
end


function Spellbooks.add(book, name, spell)
    -- Adds a spell and returns its entry, the first spell added becomes the selected one
    local entry = {id = book.nextId, name = name, spell = spell}
    book.nextId = book.nextId + 1
    table.insert(book.spells, entry)
    if book.selected == nil then
        book.selected = entry.id
    end
    return entry
end


function Spellbooks.remove(book, id)
    -- Removes a spell and its key binding, the last spell cant be removed
    local entry, index = Spellbooks.find(book, id)
    if entry == nil or #book.spells <= 1 then
        return false
    end
    table.remove(book.spells, index)
    for key, boundId in pairs(book.bindings) do
        if boundId == id then
            book.bindings[key] = nil
        end
    end
    if book.selected == id then
        book.selected = book.spells[math.min(index, #book.spells)].id
    end
    return true
end


function Spellbooks.duplicate(book, id)
    -- Copy of a spell(through its saved data so nothing is shared), without a key binding
    local entry = Spellbooks.find(book, id)
    if entry == nil then
        return nil
    end
    return Spellbooks.add(book, entry.name .. " copy", Spell.fromData(entry.spell:toData()))
end


-- Selecting and key bindings

function Spellbooks.selectedEntry(book)
    return Spellbooks.find(book, book.selected) or book.spells[1]
end


function Spellbooks.selectedSpell(book)
    local entry = Spellbooks.selectedEntry(book)
    if entry ~= nil then
        return entry.spell
    end
    return nil
end


function Spellbooks.select(book, id)
    if Spellbooks.find(book, id) ~= nil then
        book.selected = id
    end
end


function Spellbooks.bind(book, key, id)
    -- One key per spell and one spell per key, binding takes the key from any other spell
    for boundKey, boundId in pairs(book.bindings) do
        if boundId == id then
            book.bindings[boundKey] = nil
        end
    end
    book.bindings[key] = id
end


function Spellbooks.keyFor(book, id)
    for key, boundId in pairs(book.bindings) do
        if boundId == id then
            return key
        end
    end
    return nil
end


function Spellbooks.selectByKey(book, key)
    -- Selects the spell bound to this key, false when the key isnt bound
    local id = book.bindings[key]
    if id ~= nil and Spellbooks.find(book, id) ~= nil then
        book.selected = id
        return true
    end
    return false
end


-- Saving

function Spellbooks.toData(book)
    -- Plain data for saving, spells become rune names(see Spell:toData)
    local data = {spells = {}, bindings = {}, selected = book.selected, nextId = book.nextId}
    for i, entry in ipairs(book.spells) do
        table.insert(data.spells, {id = entry.id, name = entry.name, spell = entry.spell:toData()})
    end
    for key, id in pairs(book.bindings) do
        data.bindings[key] = id
    end
    return data
end


function Spellbooks.fromData(data)
    -- Rebuilds a spellbook from saved data, bindings to spells that arent there are dropped
    local book = Spellbook()
    for i, entryData in ipairs(data.spells or {}) do
        if type(entryData.spell) == "table" and type(entryData.id) == "number" then
            table.insert(book.spells, {id = entryData.id, name = tostring(entryData.name or "Spell"), spell = Spell.fromData(entryData.spell)})
            book.nextId = math.max(book.nextId, entryData.id + 1)
        end
    end
    if #book.spells == 0 then
        return Spellbooks.default()
    end

    for key, id in pairs(data.bindings or {}) do
        if Spellbooks.find(book, id) ~= nil then
            book.bindings[key] = id
        end
    end
    book.selected = data.selected
    if Spellbooks.find(book, book.selected) == nil then
        book.selected = book.spells[1].id
    end
    book.nextId = math.max(book.nextId, data.nextId or 1)
    return book
end


function Spellbooks.default()
    -- What a new player starts with, bound to keys 1-6
    local book = Spellbook()
    local defaults = {
        {"Shotgun burst", Spell:new("Bullet", {"Speed", {"OnHit", Spell:new("Bullet", {"Split", "Split"})}})},
        {"Exploding bullet", Spell:new("Bullet", {"Speed", {"OnHit", Spell:new("Area", {"Size"})}})},
        {"Bouncing laser", Spell:new("Laser", {"Rebound", "Damage"})},
        {"Gravity well", Spell:new("Area", {"Gravity", "Size"})},
        {"Minefield", Spell:new("Trap", {"Split", "Split"})},
        {"Bouncing arcs", Spell:new("Bullet", {"Split", "Gravity", "Rebound"})},
    }
    for i, default in ipairs(defaults) do
        local entry = Spellbooks.add(book, default[1], default[2])
        book.bindings[tostring(i)] = entry.id
    end
    return book
end

return Spellbooks
