local Slab = require "libraries.Slab"
local Map = require "world_utils.map"
local Simulation = require "world_utils.simulation"

-- The minimap: the blocks around the player, one pixel a tile, each in the average color of its tile art(ores in their
-- nugget color, so veins stand out). Only loaded chunks are read, the rest is dark, looking never makes a chunk
-- Two options: the chunk grid, and the chunks the anchors keep running(see world_utils/simulation), the second also
-- outlines those chunks in the world
local Minimap = {}

Minimap.TILES = 120             -- Tiles across the map, the player in the middle
Minimap.PIXEL = 2               -- Screen pixels a tile is
Minimap.REDRAW = 0.25           -- Seconds between redraws of the blocks

local AIR = {0.1, 0.12, 0.2, 1}
local UNLOADED = {0.03, 0.03, 0.05, 1}
local MACHINE = {0.55, 0.9, 1, 1}       -- Batteries, conduits and anchors
local FALLBACK = {0.5, 0.5, 0.5, 1}
local GRID = {1, 1, 1, 0.18}

local tileColors = {}   -- Tile name -> its average color, from the tilesheet
local sheetData = nil


local function tileColor(tile)
    -- The average color of a tile's opaque pixels
    if tileColors[tile] == nil then
        sheetData = sheetData or love.image.newImageData(ART_FOLDER .. "blocks.png")
        local qx, qy, qw, qh = BLOCK_TILES[tile]:getViewport()
        local r, g, b, n = 0, 0, 0, 0
        for x = qx, qx + qw - 1 do
            for y = qy, qy + qh - 1 do
                local pr, pg, pb, pa = sheetData:getPixel(x, y)
                if pa > 0.5 then
                    r, g, b, n = r + pr, g + pg, b + pb, n + 1
                end
            end
        end
        tileColors[tile] = n > 0 and {r / n, g / n, b / n, 1} or FALLBACK
    end
    return tileColors[tile]
end


local function blockColor(block)
    if block.ore ~= nil then
        return block.ore.color
    elseif block.manaNode or block.name == "BlockPart" then
        return MACHINE
    elseif block.tile ~= nil and BLOCK_TILES[block.tile] ~= nil then
        local c = tileColor(block.tile)
        if block.tint ~= nil then
            return {c[1] * block.tint[1], c[2] * block.tint[2], c[3] * block.tint[3], 1}
        end
        return c
    end
    return FALLBACK
end


function Minimap:new()
    local minimap = {}
    setmetatable(minimap, self)
    self.__index = self

    minimap.showGrid = false
    minimap.showAnchors = true
    minimap.timer = 0
    return minimap
end


function Minimap:drawBlocks()
    -- The blocks into the image, the player's tile in the middle
    local n = Minimap.TILES
    if self.data == nil then
        self.data = love.image.newImageData(n, n)
        self.image = love.graphics.newImage(self.data)
        self.image:setFilter("nearest", "nearest")
    end
    local pmx, pmy = loveToMap(player.body:getWorldCenter())
    self.x0, self.y0 = pmx - n / 2, pmy + n / 2       -- Map cell of the top left pixel(map y goes up)
    for px = 0, n - 1 do
        for py = 0, n - 1 do
            local block, loaded = map:peek(self.x0 + px, self.y0 - py)
            local c = not loaded and UNLOADED or block == nil and AIR or blockColor(block)
            self.data:setPixel(px, py, c[1], c[2], c[3], 1)
        end
    end
    self.image:replacePixels(self.data)
end


function Minimap:drawCanvas()
    -- The blocks scaled up, then the options over them and the player
    local n, p = Minimap.TILES, Minimap.PIXEL
    if self.canvas == nil then
        self.canvas = love.graphics.newCanvas(n * p, n * p)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.image, 0, 0, 0, p, p)

    -- Chunk cells on the map: where a chunk edge falls in pixels
    local function chunkRect(key)
        local cx, cy = key:match("^(-?%d+),(-?%d+)$")
        local x1, y1, x2, y2 = Map.chunkArea(tonumber(cx), tonumber(cy))
        return (x1 - self.x0) * p, (self.y0 - y2) * p, CHUNK_SIZE * p, CHUNK_SIZE * p
    end
    if self.showAnchors then
        for key, kind in pairs(map.simChunks) do
            local x, y, w, h = chunkRect(key)
            local c = kind == "free" and SIM_FREE_COLOR or SIM_ANCHOR_COLOR
            love.graphics.setColor(c[1], c[2], c[3], 0.25)
            love.graphics.rectangle("fill", x, y, w, h)
            love.graphics.setColor(c)
            love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
        end
    end
    if self.showGrid then
        love.graphics.setColor(GRID)
        local _, cx1, cy1 = Map.chunkKey(self.x0, self.y0 - n)
        local _, cx2, cy2 = Map.chunkKey(self.x0 + n, self.y0)
        for cx = cx1, cx2 + 1 do
            local x = (cx * CHUNK_SIZE + 1 - self.x0) * p
            love.graphics.line(x, 0, x, n * p)
        end
        for cy = cy1, cy2 + 1 do
            local y = (self.y0 - (cy * CHUNK_SIZE)) * p
            love.graphics.line(0, y, n * p, y)
        end
    end
    -- The player
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", n / 2 * p - 2, n / 2 * p - 2, 4, 4)
    love.graphics.pop()
end


function Minimap:update(dt)
    -- Slab window in the top right corner
    self.timer = self.timer - dt
    if self.image == nil or self.timer <= 0 then
        self.timer = Minimap.REDRAW
        self:drawBlocks()
    end
    self:drawCanvas()

    local w = love.graphics.getDimensions()
    local side = Minimap.TILES * Minimap.PIXEL
    Slab.BeginWindow("Minimap", {
        Title = "Minimap", X = w - side - 30, Y = 0, W = side + 20, H = side + 120,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        Slab.Image("MinimapImage", {Image = self.canvas})
        if Slab.CheckBox(self.showGrid, "Chunk grid") then
            self.showGrid = not self.showGrid
        end
        if Slab.CheckBox(self.showAnchors, "Anchor chunks") then
            self.showAnchors = not self.showAnchors
        end
        if self.showAnchors then
            local free, around, cost = 0, 0, 0
            for key, kind in pairs(map.simChunks) do
                if kind == "free" then free = free + 1 else around = around + 1 end
            end
            for node in pairs(map.manaNodes) do
                if node.anchorRadius ~= nil and Simulation.isPowered(node) then
                    cost = cost + Simulation.anchorCost(node)
                end
            end
            Slab.Text(string.format("%d running, %.1f mana/s", free + around, cost))
        end
    Slab.EndWindow()
end

return Minimap
