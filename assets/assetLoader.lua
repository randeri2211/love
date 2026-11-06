BLOCK_IMG = {}
BLOCK_IMG["FALLBACK"] = love.graphics.newImage("assets/blockFallback.png")    -- Blocks without a tile, a "?" so it stands out
BLOCK_IMG["FALLBACK"]:setFilter("nearest", "nearest")

-- Tilesheet with tiles in a row and a gap after each one(16 pixels and 1 at the 16 pixel layout, ART_UNIT times that),
-- blocks draw their part of it by name, from the art folder in use(ART_FOLDER)
TILESHEET = love.graphics.newImage(ART_FOLDER .. "blocks.png")
TILESHEET:setFilter("nearest", "nearest")    -- Keeps the pixel art sharp when scaled up
-- Numbered tiles are variants(stone1-3, see Block:variant) or ore nugget patterns drawn over stone(ore1-4, see OreBlock)
local TILE_ORDER = {"grass", "dirt", "stone1", "stone2", "stone3", "deepstone1", "deepstone2", "deepstone3",
    "bedrock1", "bedrock2", "bedrock3", "sand", "sandstone", "snow", "ice", "bricks", "slab", "ore1", "ore2", "ore3", "ore4",
    "oakLog", "oakLeaves", "pineLog", "pineLeaves", "cactus", "tallGrass", "woodworking", "forge", "arcaneTable",
    "stoneBricks", "crackedStoneBricks", "planks", "campfire", "torch", "woodenChest", "ironChest", "arcaniteChest"}
local TILE, STEP = 16 * ART_UNIT, 17 * ART_UNIT     -- A tile and the distance to the next one, in art pixels
BLOCK_TILES = {}
for i, name in ipairs(TILE_ORDER) do
    if name == "slab" then
        BLOCK_TILES[name] = love.graphics.newQuad((i - 1) * STEP, TILE / 2, TILE, TILE / 2, TILESHEET:getDimensions())    -- Only the lower half, a half height block
    else
        BLOCK_TILES[name] = love.graphics.newQuad((i - 1) * STEP, 0, TILE, TILE, TILESHEET:getDimensions())
    end
end


-- Item icons that arent blocks, laid out like the tilesheet, drawn tinted by the item(see items/armor)
ITEM_SHEET = love.graphics.newImage(ART_FOLDER .. "items.png")
ITEM_SHEET:setFilter("nearest", "nearest")
ITEM_TILES = {}
for i, name in ipairs({"helmet", "chestplate", "leggings", "boots", "bar", "rod", "largeRod", "wand", "staff", "core", "cap", "tip",
        "trinket", "focus"}) do
    ITEM_TILES[name] = love.graphics.newQuad((i - 1) * STEP, 0, TILE, TILE, ITEM_SHEET:getDimensions())
end


-- UI
-- The pixel font of the whole game(see ui/pixelFont), one row of glyphs split by magenta columns, 9 pixels tall:
-- capitals use the top 7 rows, the bottom 2 are for the tails of g, j, p, q and y
-- UI_FONT_GLYPHS lists the characters in the same order as the image, a new glyph goes in both at the same spot
-- A sheet of creature frames(assets/art*/creatures): cells of w x h at the 16 pixel layout with a 1 pixel gap,
-- frames in columns and variants(colors) in rows. Returns the image and quad(column, row), both from 1
function creatureSheet(name, w, h)
    local image = love.graphics.newImage(ART_FOLDER .. "creatures/" .. name .. ".png")
    image:setFilter("nearest", "nearest")
    local quads = {}
    local function quad(column, row)
        local key = column .. "," .. (row or 1)
        if quads[key] == nil then
            quads[key] = love.graphics.newQuad((column - 1) * (w + 1) * ART_UNIT, ((row or 1) - 1) * (h + 1) * ART_UNIT,
                w * ART_UNIT, h * ART_UNIT, image:getDimensions())
        end
        return quads[key]
    end
    return image, quad
end


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
