-- What runes a character knows(see docs/game-design): every rune is unknown, discovered or templated
-- Unknown runes cant be drawn at all, discovered ones are drawn from memory(a glyph wall shows the shape),
-- templated ones get the trace guide in the spell editor and never count as drawn worse than TEMPLATE_QUALITY
-- The knowledge is plain data on the player({runes = {name = state}, found = {name = where}, forgot}), saved with it
local Knowledge = {}

Knowledge.UNKNOWN = "unknown"
Knowledge.DISCOVERED = "discovered"
Knowledge.TEMPLATED = "templated"


function Knowledge.new()
    return {runes = {}, found = {}, forgot = false}
end


function Knowledge.fromData(data)
    -- Saved knowledge, runes that dont exist anymore are left out
    local knowledge = Knowledge.new()
    if type(data) ~= "table" then
        return knowledge
    end
    for name, state in pairs(type(data.runes) == "table" and data.runes or {}) do
        name = RUNE_RENAMES[name] or name
        if RUNE_REGISTRY[name] ~= nil and (state == Knowledge.DISCOVERED or state == Knowledge.TEMPLATED) then
            knowledge.runes[name] = state
        end
    end
    for name, where in pairs(type(data.found) == "table" and data.found or {}) do
        name = RUNE_RENAMES[name] or name
        if RUNE_REGISTRY[name] ~= nil and type(where) == "string" then
            knowledge.found[name] = where
        end
    end
    knowledge.forgot = data.forgot == true
    return knowledge
end


local function starting(name)
    for i, start in ipairs(STARTING_RUNES) do
        if start == name then
            return true
        end
    end
    return false
end


function Knowledge.state(knowledge, name)
    -- unknown, discovered or templated
    -- While ALL_RUNES_TEMPLATED is on every rune is templated, unless this character forgot them(the debug key)
    if ALL_RUNES_TEMPLATED and not (knowledge and knowledge.forgot) then
        return Knowledge.TEMPLATED
    end
    local state = knowledge and knowledge.runes[name]
    if state ~= nil then
        return state
    end
    return starting(name) and Knowledge.TEMPLATED or Knowledge.UNKNOWN
end


function Knowledge.knows(knowledge, name)
    -- True when the rune can be drawn(discovered or templated)
    return Knowledge.state(knowledge, name) ~= Knowledge.UNKNOWN
end


function Knowledge.isTemplated(knowledge, name)
    return Knowledge.state(knowledge, name) == Knowledge.TEMPLATED
end


function Knowledge.where(knowledge, name)
    -- Where the rune was learned, for the grimoire
    if knowledge and knowledge.found[name] then
        return knowledge.found[name]
    end
    if Knowledge.knows(knowledge, name) then
        return "Known from the start"
    end
    return nil
end


function Knowledge.discover(knowledge, name, where)
    -- Learns the shape of a rune(a glyph wall), true when it was new
    if Knowledge.knows(knowledge, name) then
        return false
    end
    knowledge.runes[name] = Knowledge.DISCOVERED
    knowledge.found[name] = where
    return true
end


function Knowledge.unlockTemplate(knowledge, name)
    -- Gives a rune its template(a boss or a quest later), true when it was new
    if Knowledge.isTemplated(knowledge, name) then
        return false
    end
    knowledge.runes[name] = Knowledge.TEMPLATED
    return true
end


function Knowledge.forget(knowledge)
    -- Back to only the starting runes, for testing glyph walls while ALL_RUNES_TEMPLATED is on
    knowledge.runes, knowledge.found, knowledge.forgot = {}, {}, true
end


function Knowledge.counts(knowledge)
    -- How many runes are known and how many there are
    local known, total = 0, 0
    for name in pairs(RUNE_REGISTRY) do
        total = total + 1
        if Knowledge.knows(knowledge, name) then
            known = known + 1
        end
    end
    return known, total
end

return Knowledge
