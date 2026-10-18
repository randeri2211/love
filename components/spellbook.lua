local function Spellbook()
    -- Spells an entity knows, each entry is {id, name, spell}(see magic/spellbooks for what you can do with it)
    local spellbook = {}

    spellbook.spells = {}
    spellbook.bindings = {}     -- Key name("1") -> spell id
    spellbook.selected = nil    -- Id of the spell the shoot key casts
    spellbook.nextId = 1        -- Ids are never reused, so bindings cant end up pointing at the wrong spell

    return spellbook
end

return Spellbook
