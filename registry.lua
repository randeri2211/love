BLOCK_REGISTRY = {}
ENTITY_REGISTRY = {}
RUNE_REGISTRY = {}
BIOME_REGISTRY = {}
ITEM_REGISTRY = {}
RECIPE_REGISTRY = {}    -- A list, recipes show in the order they were registered within their tier and category
STRUCTURE_REGISTRY = {} -- A list, structures placed by world generation(see world_utils/structures)


function registerAll()
    registerFolder("blocks")
    registerFolder("entities")
    registerFolder("runes")
    registerFolder("biomes")
    registerFolder("structures")
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


function registerStructure(name, def)
    -- def is a structure type(see world_utils/structures), its guard count comes from its blueprint
    def.name = name
    def.title = def.title or name
    def.priority = def.priority or 0
    def.guardCount = 0
    for i, row in ipairs(def.blueprint) do
        for c = 1, #row do
            local entry = def.legend[row:sub(c, c)]
            if type(entry) == "table" and entry.guard then
                def.guardCount = def.guardCount + 1
            end
        end
    end
    table.insert(STRUCTURE_REGISTRY, def)
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

