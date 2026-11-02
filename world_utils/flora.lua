-- Trees and plants: where the generator grows them and how they come down
-- They are walk-through blocks(solid = false, see blocks/floraBlock) that grow on a ground block,
-- breaking that ground block fells everything growing on it(see Block:breakApart)
-- A biome says what grows in it: flora = {tree, treeChance, plant, plantChance}
local Flora = {}

local TREE_EDGE = 2     -- Columns kept free at each side of a tree spot(TREE_CELL), the widest canopy reaches this far

-- What grows, by species: the blocks it is made of, how tall it gets, how far its blocks reach from the trunk
-- shape(dx, up, height, rand) says which part a cell is: dx is the columns from the trunk, up the rows above the ground,
-- it returns the part("trunk", "leaves", "core") or nil, rand(0-1) is the same for the whole tree so trees of a species differ
Flora.SPECIES = {
    Oak = {
        trunk = "OakLog", leaves = "OakLeaves", height = {4, 6}, radius = 2,
        shape = function(dx, up, height, rand)
            if dx == 0 and up < height - 1 then
                return "trunk"
            end
            -- A round crown around the top of the trunk, its corners cut by rand
            local cy = height - 0.5
            local d = (dx / 2.4) ^ 2 + ((up - cy) / 1.8) ^ 2
            if d <= 1 and not (math.abs(dx) == 2 and up >= height + 1 and rand < 0.5) then
                return "leaves"
            end
            return nil
        end,
    },
    Pine = {
        trunk = "PineLog", leaves = "PineLeaves", core = "PineCore", height = {6, 9}, radius = 2,
        shape = function(dx, up, height, rand)
            -- A cone of needles from the third row up, the bare trunk shows under it
            -- Inside the cone the trunk is a core: needles to look at, wood when felled
            if dx == 0 and up < 2 then
                return "trunk"
            end
            if dx == 0 and up < height then
                return "core"
            end
            if up >= 2 and up <= height then
                local half = math.min(2, math.floor((height - up) / 2.2 + 0.5))
                if math.abs(dx) <= half then
                    return "leaves"
                end
            end
            return nil
        end,
    },
    Cactus = {
        -- A single column for now, arms need a tile that joins them to the trunk
        trunk = "Cactus", height = {2, 4}, radius = 0,
        shape = function(dx, up, height)
            return dx == 0 and up < height and "trunk" or nil
        end,
    },
    TallGrass = {
        trunk = "TallGrass", height = {1, 1}, radius = 0,
        shape = function(dx, up)
            return dx == 0 and up == 0 and "trunk" or nil
        end,
    },
}
local MAX_REACH = 10    -- Most rows any species reaches above the ground

local cache = {}        -- Tree spots worked out so far(the generator asks for the same spot for every tile near it)
local cacheSeed, cacheSettings, cacheSize = nil, nil, 0


local function hash(seed, i, salt)
    -- Repeatable number from 0 to 1 for a spot
    local v = math.sin(i * 12.9898 + (seed % 10007) * 0.731 + salt * 78.233) * 43758.5453
    return v - math.floor(v)
end


local function treeSpot(cell, seed, settings, biomeAt, surfaceRow)
    -- The tree of a spot: {column, ground row, species, height, rand}, or false when nothing grows there
    if cacheSeed ~= seed or cacheSettings ~= settings or cacheSize > 4096 then
        cache, cacheSeed, cacheSettings, cacheSize = {}, seed, settings, 0
    end
    local spot = cache[cell]
    if spot ~= nil then
        return spot
    end
    spot = false
    local column = cell * TREE_CELL + TREE_EDGE + math.floor(hash(seed, cell, 1) * (TREE_CELL - TREE_EDGE * 2))
    local flora = biomeAt(column).flora
    if flora ~= nil and flora.tree ~= nil and hash(seed, cell, 2) < flora.treeChance then
        local species = Flora.SPECIES[flora.tree]
        local low, high = species.height[1], species.height[2]
        spot = {
            column = column,
            ground = surfaceRow(column),
            species = species,
            height = low + math.floor(hash(seed, cell, 3) * (high - low + 1)),
            rand = hash(seed, cell, 4),
        }
    end
    cache[cell] = spot
    cacheSize = cacheSize + 1
    return spot
end


function Flora.tile(tx, ty, surface, seed, settings, biomeAt, surfaceRow)
    -- Block name of a tree or plant in an air tile above the ground, nil for none
    -- surface is the ground row of this column, biomeAt and surfaceRow come from the generator
    if surface - ty > MAX_REACH then
        return nil
    end
    for cell = math.floor((tx - TREE_EDGE) / TREE_CELL), math.floor((tx + TREE_EDGE) / TREE_CELL) do
        local tree = treeSpot(cell, seed, settings, biomeAt, surfaceRow)
        if tree then
            local dx = tx - tree.column
            local up = tree.ground - 1 - ty
            if math.abs(dx) <= tree.species.radius and up >= 0 then
                local part = tree.species.shape(dx, up, tree.height, tree.rand)
                if part ~= nil then
                    return tree.species[part]
                end
            end
        end
    end

    -- Small plants sit right on the ground
    if ty == surface - 1 then
        local flora = biomeAt(tx).flora
        if flora ~= nil and flora.plant ~= nil and hash(seed, tx, 5) < flora.plantChance then
            return Flora.SPECIES[flora.plant].trunk
        end
    end
    return nil
end


function Flora.fell(map, x, y)
    -- Map cell x, y lost its block: whatever grew on it comes down, every part dropping its item
    -- Only when its trunk stood there, leaves of a tree on a slope can rest on the hill beside it without growing from it
    local base = map:get(x, y + 1)
    if base == nil or base.species == nil or base.name ~= Flora.SPECIES[base.species].trunk then
        return
    end
    local species = Flora.SPECIES[base.species]
    -- Tree spots are TREE_CELL apart and their parts stay within radius, so this box only holds this tree
    for dx = -species.radius, species.radius do
        for up = 1, MAX_REACH + 1 do
            local block = map:get(x + dx, y + up)
            if block ~= nil and block.species == base.species then
                local item = block:dropItem()
                if item ~= nil then
                    map.drops:spawn(item, 1, block.x + block.width / 2, block.y + block.height / 2)
                end
                map:set(x + dx, y + up, nil)
            end
        end
    end
end

return Flora
