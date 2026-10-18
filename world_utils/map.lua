local Enemies = require "entities.enemies"
local Generator = require "world_utils.generator"
local Map = {}

function Map:new(height, seed)
    -- Infinite sideways map, a chunk is generated from the seed the first time it is visited,
    -- after that the whole chunk is saved and loaded as it is(generator changes only affect unvisited places)
    map = {}
    setmetatable(map,self)
    self.__index = self
    map.height = height
    map.seed = seed or love.math.random(1, 1000000)
    map.center = {x = math.floor(MAP_X * SPAWN_X + 0.5),
                    y = math.floor(map.height * SPAWN_Y + 0.5)}
    map:emptyMap()
    return map
end


-- Map Functions
function Map:emptyMap()
    -- Forgets every chunk, the map starts over from its seed
    self.enemies = Enemies:new()
    self.chunks = {}    -- Chunks with real blocks, chunks["cx,cy"][cell index] = block
    self.saved = {}     -- Visited chunks from a save, kept as data until they are needed again
end


local function chunkOf(x, y)
    -- Chunk key, chunk position and the cell index inside the chunk for map coordinates
    local cx = math.floor((x - 1) / CHUNK_SIZE)
    local cy = math.floor((y - 1) / CHUNK_SIZE)
    local index = (x - 1 - cx * CHUNK_SIZE) * CHUNK_SIZE + (y - 1 - cy * CHUNK_SIZE) + 1
    return cx .. "," .. cy, cx, cy, index
end


local function cellOf(cx, cy, index)
    -- Map coordinates of a cell index inside a chunk(the inverse of chunkOf)
    local lx = math.floor((index - 1) / CHUNK_SIZE)
    local ly = (index - 1) % CHUNK_SIZE
    return cx * CHUNK_SIZE + lx + 1, cy * CHUNK_SIZE + ly + 1
end


function Map:mapToTile(x, y)
    -- Map coordinates to tile column and row(the inverse of loveToMap for a block at tx, ty times TILE_SIZE)
    return x - self.center.x - 1, self.center.y + 1 - y
end


function Map:surfaceY(tx)
    -- Love y of the top of the ground in a tile column, used for spawning on the surface
    return Generator.surfaceRow(tx, self.seed) * TILE_SIZE
end


function Map.blockFromData(data)
    -- Rebuilds a saved block through the block registry, nil if that block type doesnt exist anymore
    local blockClass = BLOCK_REGISTRY[data.name]
    if blockClass == nil then
        return nil
    end
    local block = blockClass:new(data.x, data.y, data.width, data.height)
    block:load(data)
    return block
end


function Map:newBlock(name, x, y)
    -- Fresh block of a type filling the map cell x, y, nil if the type doesnt exist
    local blockClass = BLOCK_REGISTRY[name]
    if blockClass == nil then
        return nil
    end
    local tx, ty = self:mapToTile(x, y)
    return blockClass:new(tx * TILE_SIZE, ty * TILE_SIZE, TILE_SIZE, TILE_SIZE)
end


function Map:generateChunk(cx, cy)
    -- Fills a chunk the first time it is visited
    local chunk = {}
    for index = 1, CHUNK_SIZE * CHUNK_SIZE do
        local x, y = cellOf(cx, cy, index)
        if y >= 1 and y <= self.height then
            local tx, ty = self:mapToTile(x, y)
            local name = Generator.tile(tx, ty, self.seed, self.center.y)
            if name ~= nil then
                chunk[index] = self:newBlock(name, x, y)
            end
        end
    end
    return chunk
end


function Map:chunkFromData(cx, cy, data)
    -- Rebuilds a saved chunk: blocks from the palette, or from their full data when they had their own state
    local chunk = {}
    for index, id in ipairs(data.cells) do
        if id ~= 0 then
            local full = data.extra and data.extra[index]
            if full ~= nil then
                chunk[index] = Map.blockFromData(full)
            else
                local x, y = cellOf(cx, cy, index)
                chunk[index] = self:newBlock(data.palette[id], x, y)
            end
        end
    end
    return chunk
end


function Map:getChunk(key, cx, cy)
    -- Loaded chunk, a saved one rebuilt now, or a new one from the generator
    local chunk = self.chunks[key]
    if chunk == nil then
        if self.saved[key] ~= nil then
            chunk = self:chunkFromData(cx, cy, self.saved[key])
            self.saved[key] = nil
        else
            chunk = self:generateChunk(cx, cy)
        end
        self.chunks[key] = chunk
    end
    return chunk
end


function Map:get(x, y)
    -- Block at map coordinates or nil, loads its chunk if needed
    if y < 1 or y > self.height then
        return nil
    end
    local key, cx, cy, index = chunkOf(x, y)
    return self:getChunk(key, cx, cy)[index]
end


function Map:set(x, y, block)
    -- Places a block or removes it(nil), the chunk is saved as it is so nothing else needs to remember it
    if y < 1 or y > self.height then
        return
    end
    local key, cx, cy, index = chunkOf(x, y)
    self:getChunk(key, cx, cy)[index] = block
end


function Map:insert(block)
    -- Convert to map coordinates
    local x, y = loveToMap(block.x, block.y)
    self:set(x, y, block)
end


-- Saving
local function encodeChunk(chunk)
    -- Compact chunk data: a palette of block names and one palette number per cell(0 is air),
    -- blocks that differ from a fresh block of their type(like damaged ones) keep their full data
    local palette, lookup, cells, extra = {}, {}, {}, {}
    for index = 1, CHUNK_SIZE * CHUNK_SIZE do
        local block = chunk[index]
        if block == nil then
            cells[index] = 0
        else
            local id = lookup[block.name]
            if id == nil then
                table.insert(palette, block.name)
                id = #palette
                lookup[block.name] = id
            end
            cells[index] = id
            if block:hasOwnState() then
                extra[index] = plainCopy(block)
            end
        end
    end
    return {palette = palette, cells = cells, extra = extra}
end


function Map:toData()
    -- Every visited chunk, the ones not loaded this session are kept as they were saved
    local chunks = {}
    for key, data in pairs(self.saved) do
        chunks[key] = data
    end
    for key, chunk in pairs(self.chunks) do
        chunks[key] = encodeChunk(chunk)
    end
    return {seed = self.seed, chunks = chunks}
end


function Map:loadData(data)
    -- Saved chunks stay data until they are visited
    self:emptyMap()
    self.seed = data.seed
    self.saved = data.chunks or {}
end


function Map:draw()
    -- Only draw blocks around the player to not waste time
    local x_diff = math.floor(loveToWorldSingle(SCREEN_X / 2) + CAMERA_RENDER_OFFSET)
    local y_diff = math.floor(loveToWorldSingle(SCREEN_Y / 2) + CAMERA_RENDER_OFFSET)
    local p_x,p_y = loveToMap(player.body:getWorldCenter())
    for x = p_x - x_diff,p_x + x_diff do
        for y = math.max(1, p_y - y_diff), math.min(self.height, p_y + y_diff) do
            local block = self:get(x, y)
            if block ~= nil then
                block:draw()
            end
        end
    end

    map.enemies:draw()
end

return Map
