BLOCK_IMG = {}
BLOCK_IMG["FALLBACK"] = love.graphics.newImage("assets/blockFallback.png")    -- Blocks without a tile, a "?" so it stands out
BLOCK_IMG["FALLBACK"]:setFilter("nearest", "nearest")

-- Tilesheet with 16px tiles in a row and a 1px gap after each one, blocks draw their part of it by name
TILESHEET = love.graphics.newImage("assets/blocks.png")
TILESHEET:setFilter("nearest", "nearest")    -- Keeps the pixel art sharp when scaled up
-- Numbered tiles are variants(stone1-3, see Block:variant) or ore nugget patterns drawn over stone(ore1-4, see OreBlock)
local TILE_ORDER = {"grass", "dirt", "stone1", "stone2", "stone3", "deepstone1", "deepstone2", "deepstone3",
    "bedrock1", "bedrock2", "bedrock3", "sand", "sandstone", "snow", "ice", "bricks", "slab", "ore1", "ore2", "ore3", "ore4"}
BLOCK_TILES = {}
for i, name in ipairs(TILE_ORDER) do
    if name == "slab" then
        BLOCK_TILES[name] = love.graphics.newQuad((i - 1) * 17, 8, 16, 8, TILESHEET:getDimensions())    -- Only the lower half, a half height block
    else
        BLOCK_TILES[name] = love.graphics.newQuad((i - 1) * 17, 0, 16, 16, TILESHEET:getDimensions())
    end
end


-- UI
UI_IMG = {}
UI_IMG["button"] = love.graphics.newImage("assets/button.png")
UI_IMG["singlePlayerButton"] = love.graphics.newImage("assets/singlePlayerButton.png")
UI_IMG["exitButton"] = love.graphics.newImage("assets/exitButton.png")
