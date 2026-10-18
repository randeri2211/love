local binser = require "libraries.binser.binser"
local Spellbooks = require "magic.spellbooks"

-- Saves are written with binser, which keeps numbers, booleans, strings and nested tables exactly
local SAVEABLE = {string = true, number = true, boolean = true, table = true}
-- Fields that are rebuilt by code instead of saved(animations, and the spellbook which has its own file)
local SKIP_KEYS = {anim = true, animations = true, spellbook = true, __index = true}


currentWorld = "world"     -- Name of the open world, save and load use it


-- Main Functions
function newWorldName()
    -- First "World N" that doesnt have a save folder yet
    local n = 1
    while love.filesystem.getInfo(SAVE_FOLDER .. "/World " .. n) ~= nil do
        n = n + 1
    end
    return "World " .. n
end

function hasSave(worldName)
    return love.filesystem.getInfo(SAVE_FOLDER .. "/" .. worldName .. "/" .. PLAYER_FILENAME) ~= nil
end

function worldNameProblem(name)
    -- Why a new world cant use this name, nil when the name is fine
    if name:match("^%s*$") then
        return "Enter a name"
    end
    if #name > 32 then
        return "Name is too long"
    end
    if name:find('[\\/:%*%?"<>|]') then
        return 'Names cant use \\ / : * ? " < > |'
    end
    if name:match("^%s") or name:match("%s$") or name:match("%.$") then
        return "Name cant start or end with a space or end with a dot"
    end
    if love.filesystem.getInfo(SAVE_FOLDER .. "/" .. name) ~= nil then
        return "A world with that name already exists"
    end
    return nil
end

local function deleteFolder(path)
    -- love.filesystem.remove only removes empty folders, so files and subfolders go first
    for i, item in ipairs(love.filesystem.getDirectoryItems(path)) do
        local itemPath = path .. "/" .. item
        if love.filesystem.getInfo(itemPath, "directory") ~= nil then
            deleteFolder(itemPath)
        else
            love.filesystem.remove(itemPath)
        end
    end
    love.filesystem.remove(path)
end

function deleteWorld(worldName)
    -- Never with an empty name or a path, that could remove the whole saves folder
    if worldName == nil or worldName:match("^%s*$") or worldName:find("[/\\]") or worldName:find("%.%.") then
        return false
    end
    local path = SAVE_FOLDER .. "/" .. worldName
    if love.filesystem.getInfo(path, "directory") == nil then
        return false
    end
    deleteFolder(path)
    return true
end

function saveScene(worldName)
    -- Creates the world folder too(saves/<world>), not only the saves folder
    local folder = SAVE_FOLDER .. "/" .. worldName
    love.filesystem.createDirectory(folder)

    writeData(folder .. "/" .. PLAYER_FILENAME, savePlayer())
    writeData(folder .. "/" .. ENTITIES_FILENAME, saveEntities())
    writeData(folder .. "/" .. MAP_FILENAME, saveMap())
    writeData(folder .. "/" .. SPELLS_FILENAME, Spellbooks.toData(player.spellbook))
end

function loadScene(worldName)
    initVars()
    local folder = SAVE_FOLDER .. "/" .. worldName

    local playerData = readData(folder .. "/" .. PLAYER_FILENAME)
    if playerData ~= nil then
        loadPlayer(playerData)
    end

    local mapData = readData(folder .. "/" .. MAP_FILENAME)
    if mapData ~= nil then
        loadMap(mapData)
    end

    local entityData = readData(folder .. "/" .. ENTITIES_FILENAME)
    if entityData ~= nil then
        loadEntities(entityData)
    end

    -- Worlds without a spells file keep the default spells the new player starts with
    local spellData = readData(folder .. "/" .. SPELLS_FILENAME)
    if spellData ~= nil then
        player.spellbook = Spellbooks.fromData(spellData)
    end
end


-- File Functions
function writeData(path, data)
    love.filesystem.write(path, binser.serialize(data))
end

function readData(path)
    -- The saved table, or nil when the file is missing or isnt a binser save
    if love.filesystem.getInfo(path) == nil then
        return nil
    end
    local contents = love.filesystem.read(path)
    local ok, results = pcall(binser.deserialize, contents)
    -- Old text saves and broken files are skipped instead of crashing the load
    if not ok or type(results) ~= "table" or type(results[1]) ~= "table" then
        print("Couldnt read save file " .. path)
        return nil
    end
    return results[1]
end

function plainCopy(value, seen)
    -- Copy of a table with only saveable data(no physics bodies, images, functions or classes)
    seen = seen or {}
    if seen[value] then
        return nil      -- Already copied higher up, skips loops like a class pointing at itself
    end
    seen[value] = true

    local copy = {}
    for key, val in pairs(value) do
        local keyType = type(key)
        if (keyType == "string" or keyType == "number") and SAVEABLE[type(val)] and not SKIP_KEYS[key] then
            if type(val) == "table" then
                copy[key] = plainCopy(val, seen)
            else
                copy[key] = val
            end
        end
    end
    seen[value] = nil
    return copy
end


-- Helper Functions
function savePlayer()
    -- Plain data of the player
    player:prepSave()
    return plainCopy(player)
end


function saveEntities()
    -- Plain data of every entity in the world
    local data = {}
    for i, entity in pairs(map.enemies.enemies) do
        entity:prepSave()
        table.insert(data, plainCopy(entity))
    end
    return data
end

function saveMap()
    -- The world seed and only the blocks the player changed, the rest regenerates from the seed
    return map:toData()
end

function loadPlayer(playerData)
    player:load(playerData)
end

function loadMap(mapData)
    -- Maps saved before world generation have no seed, they are skipped
    if mapData.seed == nil then
        print("Map save has no seed, it was made before world generation")
        return
    end
    map:loadData(mapData)
end

function loadEntities(entityData)
    -- Rebuilds every entity through the entity registry
    for i, data in ipairs(entityData) do
        local entityClass = ENTITY_REGISTRY[data.name]
        if entityClass ~= nil then
            local entity = entityClass:new(data.x, data.y)
            entity:load(data)
            map.enemies:addEnemy(entity)
        end
    end
end
