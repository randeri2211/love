require "constants"


-- Main Functions
function saveScene()
    -- Saving Player
    local playerPath = SAVE_FOLDER .. "/" .. PLAYER_FILENAME
        -- Clear the save file if it exists
    local playerFile = io.open(playerPath,"w")
    playerFile:write("")
    playerFile:close()

        -- Open file in appending mode and add a player tag and recursively save the player
    playerFile = io.open(playerPath,"a")
    -- savePlayer(file, 0)
    playerFile:close()


    -- Saving Entities
    local entityPath = SAVE_FOLDER .. "/" .. ENTITIES_FILENAME
        -- Clear the save file if it exists
    local entityFile = io.open(entityPath,"w")
    entityFile:write("")
    entityFile:close()

    entityFile = io.open(entityPath,"a")
    -- saveEntities(entityFile, 0)
    entityFile:close()

    -- Saving Map
    local mapPath = SAVE_FOLDER .. "/" .. MAP_FILENAME
        -- Clear the save file if it exists
    local mapFile = io.open(mapPath,"w")
    mapFile:write("")
    mapFile:close()

    mapFile = io.open(mapPath,"a")
    saveMap(mapFile, 0)
    mapFile:close()
end

function loadScene()
    initVars()

    -- Load Player
    local path = SAVE_FOLDER .. "/" .. PLAYER_FILENAME
    local file = io.open(path, "r")
    local lines = file:lines()
    loadPlayer(lines, 0)

    -- Load Map
    local path = SAVE_FOLDER .. "/" .. MAP_FILENAME
    local file = io.open(path, "r")
    local lines = file:lines()

    loadMap(lines, 0)

    -- Load Entities
    local path = SAVE_FOLDER .. "/" .. ENTITIES_FILENAME
    local file = io.open(path, "r")
    local lines = file:lines()

    loadEntities(lines, 0)

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
        entity.prepSave()
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

            file:write(space .. block.type .. ":\n")
            recursiveSave(file, block, spaces + DATA_SPACING)
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
        -- print(tostring(line))
        local res = recursiveLoad(spaces + DATA_SPACING, lines)
        -- for k, v in pairs(res) do
        --     print(k..","..tostring(v))
        -- end
        if res.type == "Block" then
            local block = Block:new(res.x, res.y, res.width, res.height)
            block:load(res)
            map:insert(block)
        end
        line = lines()
    until line == nil
end

function loadEntities(lines, spaces)
    -- Loads all blocks into the map from the given lines iterator
    local line = lines()
    repeat
        local res = recursiveLoad(spaces + DATA_SPACING, lines)

        if res.name == "enemy" then
            local enemy = Enemy(res.x, res.y)
            enemy.load(res)
            addEnemy(enemy)
        elseif res.name == "enemy1" then 
            
            local enemy = Enemy1(res.x, res.y)

            enemy.load(res)
            addEnemy(enemy)
        end
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
            if type(val) == "table" then

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
            else
                space = ""
                -- Multiply spaces
                for i=1 ,spaces do 
                    space = space .. " "
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
        local matches = string.gmatch(line, "([^%s]+)")

        for match in matches do
            local content = string.gmatch(match, "([^:]+)")
            local key = tostring(content())
            local val = content()

            if val == nil then
                result[key] = recursiveLoad(spaces + DATA_SPACING,lines)
            else
                if type(val) == "number" then
                    val = tonumber(val)
                elseif type(val) == "boolean" then
                    val = toboolean(val)
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