BLOCK_REGISTRY = {}
ENTITY_REGISTRY = {}
RUNE_REGISTRY = {}
BIOME_REGISTRY = {}
ITEM_REGISTRY = {}
RECIPE_REGISTRY = {}    -- A list, recipes show in the order they were registered within their tier and category


function registerAll()
    registerFolder("blocks")
    registerFolder("entities")
    registerFolder("runes")
    registerFolder("biomes")
    registerFolder("items")     -- After blocks, every block becomes an item(see items/blockItems)
    registerFolder("recipes")   -- After items, recipes name them
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


function registerItem(itemName, item)
    item.name = itemName
    ITEM_REGISTRY[itemName] = item
end


function registerRecipe(recipe)
    -- recipe = {output, count, inputs = {{item or group, count}...}, station(nil for by hand), tier, category}
    recipe.count = recipe.count or 1
    recipe.id = #RECIPE_REGISTRY + 1
    table.insert(RECIPE_REGISTRY, recipe)
end


function registerBiome(biomeName, biome)
    biome.name = biomeName
    BIOME_REGISTRY[biomeName] = biome
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

