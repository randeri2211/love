BLOCK_IMG = {}
BLOCK_IMG["GRASS"] = love.graphics.newImage("assets/grass.png")

BLOCK_IMG["PANELING_SMALL"] = love.graphics.newImage("assets/paneling_small.png")

-- Tilesheet with 16px tiles and a 1px gap after each one, blocks draw their part of it by name
TILESHEET = love.graphics.newImage("assets/tilesheet.png")
TILESHEET:setFilter("nearest", "nearest")    -- Keeps the pixel art sharp when scaled up
local function tile(x, y, w, h)
    return love.graphics.newQuad(x, y, w, h, TILESHEET:getDimensions())
end
BLOCK_TILES = {
    bricks = tile(0, 0, 16, 16),
    grass = tile(17, 0, 16, 16),
    dirt = tile(17, 8, 16, 8),          -- Lower half of the grass tile, only the dirt
    stone = tile(34, 0, 16, 16),
    ice = tile(51, 0, 16, 16),
    slab = tile(68, 8, 16, 8),
}


-- UI
UI_IMG = {}
UI_IMG["button"] = love.graphics.newImage("assets/button.png")
UI_IMG["singlePlayerButton"] = love.graphics.newImage("assets/singlePlayerButton.png")
UI_IMG["exitButton"] = love.graphics.newImage("assets/exitButton.png")
