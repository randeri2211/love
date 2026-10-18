BLOCK_REGISTRY = {}
ENTITY_REGISTRY = {}
RUNE_REGISTRY = {}


function registerAll()
    registerFolder("blocks")
    registerFolder("entities")
    registerFolder("runes")
end


function registerBlock(blockName, block)
    if BLOCK_REGISTRY == nil then
        BLOCK_REGISTRY = {}
    end
    BLOCK_REGISTRY[blockName] = block
end


function registerEntity(entityName, entity)
    if ENTITY_REGISTRY == nil then
        ENTITY_REGISTRY = {}
    end
    ENTITY_REGISTRY[entityName] = entity
end


function registerRune(runeName, rune)
    if RUNE_REGISTRY == nil then
        RUNE_REGISTRY = {}
    end
    RUNE_REGISTRY[runeName] = rune
end


function registerFolder(folder)
    -- Get all files in the specified folder
    for _, file in ipairs(love.filesystem.getDirectoryItems(folder)) do
        if file:match("%.lua$") then -- Check for .lua files
            local className = file:sub(1, -5) -- Remove the ".lua" extension
            local classPath = folder .. "." .. className -- Build the module path
            require(classPath) -- Load the module
        end
    end
end

