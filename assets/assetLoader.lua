BLOCK_IMG = {}
BLOCK_IMG["FALLBACK"] = love.graphics.newImage("assets/blockFallback.png")    -- Blocks without a tile, a "?" so it stands out
BLOCK_IMG["FALLBACK"]:setFilter("nearest", "nearest")

-- Tilesheet with 16px tiles in a row and a 1px gap after each one, blocks draw their part of it by name
TILESHEET = love.graphics.newImage("assets/blocks.png")
TILESHEET:setFilter("nearest", "nearest")    -- Keeps the pixel art sharp when scaled up
-- Numbered tiles are variants(stone1-3, see Block:variant) or ore nugget patterns drawn over stone(ore1-4, see OreBlock)
local TILE_ORDER = {"grass", "dirt", "stone1", "stone2", "stone3", "deepstone1", "deepstone2", "deepstone3",
    "bedrock1", "bedrock2", "bedrock3", "sand", "sandstone", "snow", "ice", "bricks", "slab", "ore1", "ore2", "ore3", "ore4",
    "oakLog", "oakLeaves", "pineLog", "pineLeaves", "cactus", "tallGrass", "woodworking", "forge"}
BLOCK_TILES = {}
for i, name in ipairs(TILE_ORDER) do
    if name == "slab" then
        BLOCK_TILES[name] = love.graphics.newQuad((i - 1) * 17, 8, 16, 8, TILESHEET:getDimensions())    -- Only the lower half, a half height block
    else
        BLOCK_TILES[name] = love.graphics.newQuad((i - 1) * 17, 0, 16, 16, TILESHEET:getDimensions())
    end
end


-- Item icons that arent blocks, 16px in a row with a 1px gap, drawn tinted by the item(see items/armor)
ITEM_SHEET = love.graphics.newImage("assets/items.png")
ITEM_SHEET:setFilter("nearest", "nearest")
ITEM_TILES = {}
for i, name in ipairs({"helmet", "chestplate", "leggings", "boots", "bar", "rod", "largeRod"}) do
    ITEM_TILES[name] = love.graphics.newQuad((i - 1) * 17, 0, 16, 16, ITEM_SHEET:getDimensions())
end


-- UI
-- The pixel font of the whole game(see ui/pixelFont), one row of glyphs split by magenta columns, 9 pixels tall:
-- capitals use the top 7 rows, the bottom 2 are for the tails of g, j, p, q and y
-- UI_FONT_GLYPHS lists the characters in the same order as the image, a new glyph goes in both at the same spot
UI_FONT_GLYPHS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
UI_FONT_CAP_HEIGHT = 7

local function pixelFont(scale)
    -- The font with every pixel made scale x scale, text drawn with it at scale 1 stays sharp
    local source = love.image.newImageData("assets/pixelFont.png")
    local data = love.image.newImageData(source:getWidth() * scale, source:getHeight() * scale)
    data:mapPixel(function(x, y)
        return source:getPixel(math.floor(x / scale), math.floor(y / scale))
    end)
    local font = love.graphics.newImageFont(data, UI_FONT_GLYPHS, scale)   -- One font pixel between letters
    font:setFilter("nearest", "nearest")
    return font
end
UI_FONT = pixelFont(1)      -- Titles and buttons, drawn at whole number scales by ui/pixelFont
GAME_FONT = pixelFont(2)    -- Every other text, the default font of love and Slab(drawn at 0.5 it is UI_FONT size)
