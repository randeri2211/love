local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- A wall of ley light closing a boss lair's way in while its boss is fought(see Structures.sealDoors), so neither the
-- boss nor the player is knocked or walks out. Nothing breaks it. It opens on its own once the lair has no living boss
-- (beaten, gone back after the player died or left), and it isnt saved, a loaded world has the way in open
-- It keeps lairId, the lair whose boss it waits on
local LairSeal = Block:new()
LairSeal.noItem = true
LairSeal.drop = false
LairSeal.light = ALTAR_LIGHT
registerBlock("LairSeal", LairSeal)


function LairSeal:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "LairSeal"
    block.tile = "lairStone"
    block.hpBar = HPBar(1, 1, 0)
    block.damageThreshold = math.huge
    block.lairId = nil
    return block
end


function LairSeal:damage()
    -- Nothing breaks it
end


function LairSeal:isTemporary()
    return true     -- Air in the save
end


function LairSeal:update(dt)
    -- Opens once the fight is over(it runs near the player, see world_utils/simulation)
    if require("world_utils.structures").bossOf(self.lairId) == nil then
        self:destroy()
    end
end


function LairSeal:draw()
    -- The stone, dimmed, under a pulsing violet glow
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 3 + self.y * 0.05)
    love.graphics.push("all")
    love.graphics.setColor(0.45, 0.35, 0.6, 1)
    love.graphics.draw(TILESHEET, BLOCK_TILES[self.tile], self.x, self.y, 0, self.width / (16 * ART_UNIT), self.height / (16 * ART_UNIT))
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.6, 0.35, 1, 0.35 + 0.25 * pulse)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.pop()
end

return LairSeal
