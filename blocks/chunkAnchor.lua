local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local ManaShader = require "world_utils.manaShader"

-- The Chunk Anchor(see docs/game-design: Mana network): a network node that keeps the chunks around it simulated while
-- the player is away, anchorRadius chunks out from its own(0 to CHUNK_ANCHOR_MAX_RADIUS, set in its screen, see ui/anchorPanel)
-- Every chunk it adds costs its network CHUNK_ANCHOR_MANA a second(see world_utils/simulation), without the mana it keeps
-- only its own chunk, like any node. Its core glows while it is paid for
local ChunkAnchor = Block:new()
ChunkAnchor.manaNode = true
ChunkAnchor.simulatesChunk = true   -- Its own chunk runs for free(see world_utils/simulation)
ChunkAnchor.CORE = {6, 4, 4, 6}     -- The core in its 16 x 16 picture at the 16 pixel layout: x, y, width, height

local image = nil   -- assets/art*/machines/chunkAnchor.png, loaded with the first anchor


function ChunkAnchor:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ChunkAnchor"
    block.damageThreshold = 1
    block.hpBar = HPBar(CHUNK_ANCHOR_HP, CHUNK_ANCHOR_HP, 0)
    block.anchorRadius = 1
    if image == nil then
        image = artImage(ART_FOLDER .. "machines/chunkAnchor.png")
    end

    return block
end


function ChunkAnchor:box()
    return self.x, self.y, self.width, self.height
end


function ChunkAnchor:beamPoint()
    local c = ChunkAnchor.CORE
    return self.x + (c[1] + c[3] / 2) / 16 * self.width, self.y + (c[2] + c[4] / 2) / 16 * self.height
end


local function core(x, y, w, h)
    local c = ChunkAnchor.CORE
    return x + c[1] / 16 * w, y + c[2] / 16 * h, c[3] / 16 * w, c[4] / 16 * h
end


function ChunkAnchor:draw()
    love.graphics.draw(image, self.x, self.y, 0, self.width / image:getWidth(), self.height / image:getHeight())
end


function ChunkAnchor:drawGlow()
    -- Full while its chunks are paid for, a little mana at the bottom when it only holds its own
    local cx, cy, cw, ch = core(self.x, self.y, self.width, self.height)
    local Simulation = require "world_utils.simulation"
    ManaShader.fill(cx, cy, cw, ch, Simulation.isPowered(self) and 1 or 0.2)
end


function ChunkAnchor:drawIcon(x, y, size)
    love.graphics.draw(image, x, y, 0, size / image:getWidth(), size / image:getHeight())
    local cx, cy, cw, ch = core(x, y, size, size)
    ManaShader.fill(cx, cy, cw, ch, 1)
end


function ChunkAnchor:interact()
    uihandler:openStation(self)
end


function ChunkAnchor:tooltip()
    local Simulation = require "world_utils.simulation"
    return string.format("Chunk Anchor\n%d x %d chunks, %.1f mana/s\n%s", 2 * self.anchorRadius + 1, 2 * self.anchorRadius + 1,
        Simulation.anchorCost(self), Simulation.isPowered(self) and "Running" or "No mana: only its own chunk")
end


function ChunkAnchor:hasOwnState()
    return Block.hasOwnState(self) or self.anchorRadius ~= 1
end


function ChunkAnchor:load(data)
    Block.load(self, data)
    self.anchorRadius = data.anchorRadius or 1
end


registerBlock("ChunkAnchor", ChunkAnchor)

return ChunkAnchor
