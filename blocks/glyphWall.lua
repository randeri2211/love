local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local MagicCircle = require "magic.magicCircle"
local Knowledge = require "magic.knowledge"
local Biomes = require "world_utils.biomes"

-- A wall with a rune carved into it: reading it(the interact key) adds the rune to the grimoire(see magic/knowledge)
-- A placeholder for the shrines and boss arenas the walls will stand in, for now placed with DEBUG_GLYPH_WALL_KEY
-- Its glyph glows until the reader knows the rune
local GlyphWall = Block:new()
registerBlock("GlyphWall", GlyphWall)
GlyphWall.noItem = true     -- Part of a shrine, not something to carry

function GlyphWall:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "GlyphWall"
    block.tile = "bricks"
    block.tint = {0.5, 0.48, 0.6, 1}    -- Old grey shrine stone, so any rune color stands out on it
    block.damageThreshold = math.huge   -- Shrines cant be dug out
    block.hpBar = HPBar(1, 1, 0)
    block.rune = "Fire"                 -- The rune it teaches, set when it is placed

    return block
end


function GlyphWall:draw()
    Block.draw(self)
    local rune = RUNE_REGISTRY[self.rune]
    if rune == nil or rune.glyph == nil then
        return
    end
    -- Bright and pulsing while it still has something to teach, faint once the rune is known
    local known = Knowledge.knows(player and player.knowledge, self.rune)
    local alpha = known and 0.35 or 0.75 + 0.25 * math.sin(love.timer.getTime() * 3)
    local cx, cy = self.x + self.width / 2, self.y + self.height / 2
    love.graphics.push("all")
    -- A dark seal carved into the stone, a soft glow, then the glyph
    love.graphics.setColor(0.06, 0.05, 0.1, 0.85)
    love.graphics.circle("fill", cx, cy, self.width * 0.46, 20)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(rune.color[1], rune.color[2], rune.color[3], alpha * 0.25)
    love.graphics.circle("fill", cx, cy, self.width * 0.42, 20)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(rune.color[1], rune.color[2], rune.color[3], alpha)
    MagicCircle.drawGlyph(rune.glyph, cx, cy, self.width * 0.32, 1.5)
    love.graphics.pop()
end


function GlyphWall:interact()
    -- Reading the wall, the grimoire remembers where the rune was found
    local rune = self.rune
    local biome = Biomes.surface(math.floor(self.x / TILE_SIZE), map.seed, map.settings)
    local where = "A glyph wall in the " .. biome.name
    if Knowledge.discover(player.knowledge, rune, where) then
        uihandler:toast("You learned the " .. rune .. " rune", RUNE_REGISTRY[rune].color)
    else
        uihandler:toast("You already know " .. rune)
    end
end


function GlyphWall:hasOwnState()
    -- Its rune has to be saved
    return true
end


function GlyphWall:load(data)
    Block.load(self, data)
    if RUNE_REGISTRY[data.rune] ~= nil then
        self.rune = data.rune
    end
end

return GlyphWall
