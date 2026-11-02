-- Big pixel font text for titles and buttons(UI_FONT, assets/pixelFont.png, loaded in assets/assetLoader)
-- Drawn in capitals at whole number scales so every pixel stays sharp, the rest of the game text uses GAME_FONT directly
local PixelFont = {}

local supported = nil       -- Character -> true for every glyph in UI_FONT_GLYPHS


local function hasGlyph(c)
    if supported == nil then
        supported = {}
        for glyph in UI_FONT_GLYPHS:gmatch(".") do
            supported[glyph] = true
        end
    end
    return supported[c] == true
end


function PixelFont.get()
    return UI_FONT
end


function PixelFont.clean(text)
    -- Capitals, and characters the font doesnt have become spaces
    text = tostring(text):upper()
    return (text:gsub(".", function(c)
        if not hasGlyph(c) then
            return " "
        end
        return c
    end))
end


function PixelFont.width(text, scale)
    return UI_FONT:getWidth(PixelFont.clean(text)) * scale
end


function PixelFont.height(scale)
    return UI_FONT:getHeight() * scale
end


function PixelFont.capHeight(scale)
    -- Height of capitals, without the room under them for tails, centers capital text
    return UI_FONT_CAP_HEIGHT * scale
end


function PixelFont.print(text, x, y, scale, align)
    -- Draws text at a whole number scale, align is "left"(default), "center" or "right" around x
    text = PixelFont.clean(text)
    scale = math.max(1, math.floor(scale))
    local w = UI_FONT:getWidth(text) * scale
    if align == "center" then
        x = x - w / 2
    elseif align == "right" then
        x = x - w
    end
    local previous = love.graphics.getFont()
    love.graphics.setFont(UI_FONT)
    love.graphics.print(text, math.floor(x), math.floor(y), 0, scale, scale)
    love.graphics.setFont(previous)
end

return PixelFont
