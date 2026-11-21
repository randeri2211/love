local Block = require "blocks.block"
local BigBlock = require "blocks.bigBlock"
local HPBar = require "components.hpBar"
local GlyphAura = require "magic.glyphAura"

-- Crafting stations: placed like any block, standing within interaction distance of one
-- adds its recipes to the crafting list(see items/crafting)
-- A processing station(processes) also works on its own over time: an input, a fuel and an output slot, opened with the
-- interact key, fed with fuel or powered by a mana network(see items/processing and ui/processPanel)
local StationBlock = Block:new()
StationBlock.station = true

-- Stations by block name: their tile, how sturdy they are, whether they process, and whether they only work on mana
-- (manaOnly: no fuel slot, see items/processing). An aura is glyphs circling over it, livelier while it works
-- (see magic/glyphAura). A station bigger than a tile has a footprint and its picture in assets/art*/machines/<art>.png
-- instead of a tile(see blocks/bigBlock)
local STATIONS = {
    {name = "WoodworkingStation", tile = "woodworking", hp = 6},
    {name = "Forge", tile = "forge", hp = 10, light = FORGE_LIGHT, processes = true},
    {name = "InfusionTable", displayName = "Infusion Table", footprint = {2, 1}, art = "infusionTable", hp = 8,
        processes = true, manaOnly = true,
        aura = {runes = {"Focus", "Light", "Repeat"}, color = MANA_GLYPH_COLOR, y = 0.1, width = 1.4, size = 5}},
}


function StationBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = self.info.name
    block.tile = self.info.tile
    block.damageThreshold = 1
    block.hpBar = HPBar(self.info.hp, self.info.hp, 0)
    if self.info.processes then
        block.input, block.fuel, block.output = false, false, false
        block.progress = 0      -- Seconds into the item it is working on
        block.burn = 0          -- Seconds of fuel left burning
        block.state = "Idle"
    end

    return block
end


-- What only processing stations do
local Processing = {}

function Processing:update(dt)
    require("items.processing").update(self, dt)
end


function Processing:interact()
    uihandler:openStation(self)
end


function Processing:tooltip()
    return (self.info.displayName or self.info.name) .. "\n" .. self.state .. "\n" .. INTERACT_KEY:upper() .. " to open"
end


function Processing:damage(dmg, power, source)
    -- It holds together while anything is in it, so a stray spell never scatters its items
    if self.input or self.fuel or self.output then
        return
    end
    Block.damage(self, dmg, power, source)
end


function Processing:hasOwnState()
    return Block.hasOwnState(self) or self.input ~= false or self.fuel ~= false or self.output ~= false or self.burn > 0
end


function Processing:saveData()
    return {
        name = self.name, x = self.x, y = self.y, width = self.width, height = self.height,
        hpBar = {currentHP = self.hpBar.currentHP, maxHP = self.hpBar.maxHP, regen = 0},
        input = self.input, fuel = self.fuel, output = self.output, progress = self.progress, burn = self.burn,
    }
end


function Processing:load(data)
    Block.load(self, data)
    local function stack(s) return type(s) == "table" and s or false end
    self.input, self.fuel, self.output = stack(data.input), stack(data.fuel), stack(data.output)
    self.progress, self.burn = data.progress or 0, data.burn or 0
end


local function auraDraw(self)
    -- Its glyphs, after the light so they shine in the dark(see Map:drawGlow): calm while idle, lively while it works
    -- and drawn in as the item fills, flickering out when the mana runs short
    local level, progress = 0.55, nil
    if self.state == "Working" or self.state == "Working (powered)" then
        local process = self.input and require("items.processing").forInput(self.name, self.input.item)
        level, progress = 1, process and math.min(1, self.progress / process.time) or nil
    elseif self.state == "Needs more mana" then
        level = love.math.random() < 0.3 and 0.7 or 0.2
    end
    local x, y, w, h = self.x, self.y, self.width, self.height
    if self.footprint ~= nil then
        x, y, w, h = self:box()
    end
    GlyphAura.draw(x, y, w, h, self.info.aura, level, progress)
end


local function ownDraw(self)
    -- Just the tile, but a draw of its own keeps it out of the sprite batch, so the map hands it to drawGlow
    -- (see Block:addToBatch and Map:draw)
    Block.draw(self)
end


-- One block class per station, they only differ in their info table
for i, info in ipairs(STATIONS) do
    local class = StationBlock:new()
    class.info = info
    class.light = info.light    -- A lit forge glows(see world_utils/lighting)
    if info.footprint then
        -- Everything that makes a big block(its parts, box, breaking and picture), its own draw keeps it loose
        for name, value in pairs(BigBlock) do
            if type(value) == "function" then
                class[name] = value
            end
        end
        class.footprint, class.art = info.footprint, info.art
    elseif info.aura then
        class.draw = ownDraw
    end
    if info.aura then
        class.drawGlow = auraDraw
    end
    if info.processes then
        class.processes = true
        for name, method in pairs(Processing) do
            class[name] = method
        end
    end
    registerBlock(info.name, class)
end

return StationBlock
