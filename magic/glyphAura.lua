-- A glyph aura: a few rune glyphs circling over a block, glowing softly, for anything magical that should look alive
-- (the infusion table, later altars and arcane tables). The block's tile stays still, the aura moves on top of it
-- It is drawn in the art's own pixels: the glyphs go on a small canvas at ART_PIXELS a block, then it is scaled up
-- without smoothing, so they look like part of the pixel art and not like lines laid over it
-- An aura is a table: {runes = {rune names}, color, y(the orbit's height from the block's top, in tiles),
-- width(how wide it circles, in tiles), size(a glyph's radius, in art pixels)}
local MagicCircle = require "magic.magicCircle"

local GlyphAura = {}

local canvases = {}          -- By block size("columns x rows"), shared by every aura that size, drawn one at a time


local function areaCanvas(columns, rows)
    -- The block with a tile free on either side and above it, room for the glyphs to circle out
    local key = columns .. "x" .. rows
    if canvases[key] == nil then
        canvases[key] = love.graphics.newCanvas(ART_PIXELS * (columns + 2), ART_PIXELS * (rows + 1))
        canvases[key]:setFilter("nearest", "nearest")
    end
    return canvases[key]
end


function GlyphAura.draw(x, y, w, h, aura, level, progress)
    -- Over the block in the box x, y, w, h(in the world, TILE_SIZE a tile). level: how lively it is, 0 to 1(idle about
    -- 0.55, working 1). progress: 0 to 1 of the work done, the glyphs are drawn in toward the middle as it fills(nil
    -- when nothing is worked on)
    if level <= 0 then
        return
    end
    local columns = math.max(1, math.floor(w / TILE_SIZE + 0.5))
    local rows = math.max(1, math.floor(h / TILE_SIZE + 0.5))
    local c = areaCanvas(columns, rows)
    local px = ART_PIXELS                           -- Canvas pixels a tile
    local t = love.timer.getTime()
    local cx = c:getWidth() / 2                     -- The orbit's middle on the canvas
    local cy = px + aura.y * px
    local spin = 0.5 + 1.5 * level                  -- Faster the harder it works
    local reach = aura.width * px / 2 * (1 - 0.55 * (progress or 0))
    local color = aura.color

    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setLineStyle("rough")             -- No smoothing, every line stays on whole pixels
    -- A stepped glow over the middle, breathing with the glyphs
    local breath = 0.75 + 0.25 * math.sin(t * 2.2)
    for ring = 3, 1, -1 do
        love.graphics.setColor(color[1], color[2], color[3], 0.05 * level * breath)
        love.graphics.circle("fill", cx, cy, reach * ring / 3 + 1, 16)
    end
    -- The glyphs on a flat oval, so they seem to go round behind and in front, dimmer when behind
    local n = #aura.runes
    for i, name in ipairs(aura.runes) do
        local rune = RUNE_REGISTRY[name]
        if rune ~= nil and rune.glyph ~= nil then
            local angle = t * spin + (i - 1) * 2 * math.pi / n
            local depth = math.sin(angle)           -- -1 at the back, 1 at the front
            local gx = cx + math.cos(angle) * reach
            local gy = cy + depth * reach * 0.25 + math.sin(t * 1.7 + i) * 1.5
            local alpha = math.min(1, level * (0.85 + 0.25 * depth) * (0.85 + 0.15 * math.sin(t * 3 + i * 2)))
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            MagicCircle.drawGlyph(rune.glyph, math.floor(gx) + 0.5, math.floor(gy) + 0.5, aura.size * (0.85 + 0.15 * depth), 1)
        end
    end
    love.graphics.pop()

    -- The canvas over the block, its pixels as big as the tile's, added on so it glows
    local scale = TILE_SIZE / px
    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c, x - TILE_SIZE, y - TILE_SIZE, 0, scale, scale)
    love.graphics.pop()
end

return GlyphAura
