-- Main Functions
function saveScene()
    -- Saving Player
    local playerPath = SAVE_FOLDER .. "/" .. PLAYER_FILENAME
        -- Clear the save file if it exists
    local playerFile = io.open(playerPath,"w")
    if playerFile ~= nil then
        playerFile:write("")
        playerFile:close()
    end

        -- Open file in appending mode and add a player tag and recursively save the player
    playerFile = io.open(playerPath,"a")
    if playerFile ~= nil then
        savePlayer(playerFile, 0)
        playerFile:close()
    end


    -- Saving Entities
    local entityPath = SAVE_FOLDER .. "/" .. ENTITIES_FILENAME
        -- Clear the save file if it exists
    local entityFile = io.open(entityPath,"w")
    if entityFile ~= nil then
        entityFile:write("")
        entityFile:close()
    end

    entityFile = io.open(entityPath,"a")
    if entityFile ~= nil then
        saveEntities(entityFile, 0)
        entityFile:close()
    end

    -- Saving Map
    local mapPath = SAVE_FOLDER .. "/" .. MAP_FILENAME
        -- Clear the save file if it exists
    local mapFile = io.open(mapPath,"w")
    if mapFile ~= nil then
        mapFile:write("")
        mapFile:close()
    end

    mapFile = io.open(mapPath,"a")
    if mapFile ~= nil then
        saveMap(mapFile, 0)
        mapFile:close()
    end
end

function loadScene()
    initVars()

    -- Load Player
    local path = SAVE_FOLDER .. "/" .. PLAYER_FILENAME
    local file = io.open(path, "r")
    if file ~= nil then
        local lines = file:lines()
        loadPlayer(lines, 0)
    end

    -- Load Map
    local path = SAVE_FOLDER .. "/" .. MAP_FILENAME
    local file = io.open(path, "r")
    if file ~= nil then
        local lines = file:lines()
        map:emptyMap()
        loadMap(lines, 0)
    end

    -- Load Entities
    local path = SAVE_FOLDER .. "/" .. ENTITIES_FILENAME
    local file = io.open(path, "r")
    if file ~= nil then
        local lines = file:lines()
    
        loadEntities(lines, 0)
    end

end

-- Helper Functions
function savePlayer(file, spaces)
    -- Saves a player to a given file within the spaces
    player:prepSave()

    space = ""
    --multiply spaces
    for i=1 ,spaces do 
        space = space .. " "
    end

    file:write(space .. "player:\n")
    recursiveSave(file, player, spaces + DATA_SPACING)
end


function saveEntities(file, spaces)
    -- Save all entities in the world
    for i, entity in pairs(map.enemies.enemies) do
        entity:prepSave()
        space = ""
        --multiply spaces
        for j=1 ,spaces do 
            space = space .. " "
        end

        file:write(space .. entity.name .. ":\n")
        recursiveSave(file, entity, spaces + DATA_SPACING)
    end
end

function saveMap(file, spaces)
    for x, col in pairs(map.map) do
        for y, block in pairs(col) do
            space = ""
            --multiply spaces
            for j=1 ,spaces do 
                space = space .. " "
            end
            -- Prepares the block for saving("" on the tooltipText)
            if block.prepSave ~= nil then
                block:prepSave()
            end
            file:write(space .. block.type .. ":\n")
            recursiveSave(file, block, spaces + DATA_SPACING)
            if block.afterSave ~= nil then
                block:afterSave()
            end
        end
    end
end

function loadPlayer(lines, spaces)
    -- Loads a player from the given lines iterator
    lines()
    local res = recursiveLoad(spaces + DATA_SPACING, lines)
    player:load(res)
end

function loadMap(lines, spaces)
    -- Loads all blocks into the map from the given lines iterator
     
    local line = lines()
    repeat
        local res = recursiveLoad(spaces + DATA_SPACING, lines)
        local block = BLOCK_REGISTRY[res.name]:new(res.x, res.y, res.width, res.height)
        block:load(res)
        map:insert(block)

        line = lines()
    until line == nil
end

function loadEntities(lines, spaces)
    -- Loads all blocks into the map from the given lines iterator
    local line = lines()
    repeat
        local res = recursiveLoad(spaces + DATA_SPACING, lines)
        local entity = ENTITY_REGISTRY[res.name]:new(res.x, res.y)
        entity:load(res)
        map.enemies:addEnemy(entity)
        line = lines()
    until line == nil
end


function recursiveSave(file, t, spaces)
    local allowed = {}
    allowed["nil"] = true
    allowed["string"] = true
    allowed["number"] = true
    allowed["boolean"] = true
    -- allowed["userdata"] = true
    allowed["table"] = true
    


    for key, val in pairs(t) do
        if allowed[type(val)] and allowed[type(key)] then
            if type(val) == "table" and key ~= "anim" and key ~= "animations" then

                -- Making sure the table has a valueable information to store
                local okay = false
                for o_key, o_val in pairs(val) do

                    if allowed[type(o_key)] and allowed[type(o_val)] then
                        okay = true
                        break
                    end
                end

                -- As long as we have save worthy data,go inside
                if okay == true then
                    space = ""
                    --multiply spaces
                    for i=1 ,spaces do 
                        space = space .. " "
                    end
                    file:write(space .. tostring(key) .. ":" .. "\n")
                    recursiveSave(file, val, spaces + DATA_SPACING)
                end
            elseif type(val) == "table" then
            else
                space = ""
                -- Multiply spaces
                for i=1 ,spaces do 
                    space = space .. " "
                end
                if val == "" then
                    val = "\"\""
                end
                file:write(space .. tostring(key) .. ":" .. tostring(val) .. "\n")
            end
        end
    end
    file:write("\n")
end


function recursiveLoad(spaces,lines)
    local result = {}
    local line = lines()
    while line ~= nil and #line > spaces and line:sub(spaces,spaces) == " " do
        -- "([^%s]+[[%s]*[%S]+]*)" matches every non whitespace sequence followed by possibly more sequences of whitespaces and not whitespaces
        local matches = string.gmatch(line, "([^%s]+[[%s]*[%S]+]*)")

        for match in matches do
            -- "([^:]+)" Splits the string by the : delimeter
            local content = string.gmatch(match, "([^:]+)")
            local key = tostring(content())
            local temp = content()
            local val

            if temp == nil then
                -- print("inside table "..tostring(key))
                result[key] = recursiveLoad(spaces + DATA_SPACING,lines)
            else
                if tonumber(temp) ~= nil then
                    val = tonumber(temp)
                    -- print("number "..tostring(val))
                elseif temp == "true" then
                    val = true
                    -- print("bool "..tostring(val))
                elseif temp == "false" then
                    val = false
                    -- print("bool "..tostring(val))
                else
                    val = tostring(temp)
                end
                result[key] = val
            end
        end

        if lines ~= nil then
            line = lines()
        else
            line = nil
        end
    end
    return result
end