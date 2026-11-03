local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local Inventories = require "items.inventories"

-- A torch: a walk-through block that lights the tiles around it(see world_utils/lighting)
-- Placed against a solid block like any block, it falls off when nothing holds it any more(see Block:breakApart)
-- Spells pass through it, interacting picks it back up
local TorchBlock = Block:new()
TorchBlock.solid = false
TorchBlock.needsSupport = true
TorchBlock.light = TORCH_LIGHT

-- The torch in 16x16 pixels: {x, y, w, h, color}, a stick with a flame on top
local PIXELS = {
    {7, 8, 2, 8, {0.45, 0.3, 0.18, 1}},     -- Stick
    {7, 8, 1, 8, {0.55, 0.38, 0.22, 1}},    -- Its lit side
    {6, 4, 4, 4, {0.95, 0.45, 0.15, 1}},    -- Flame
    {7, 2, 2, 2, {0.95, 0.45, 0.15, 1}},
    {7, 5, 2, 3, {1, 0.85, 0.35, 1}},       -- Its bright core
}


function TorchBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "Torch"
    block.hpBar = HPBar(1, 1, 0)
    block.damageThreshold = math.huge

    return block
end


function TorchBlock:damage()
    -- Spells pass through, it comes off with the block holding it
end


function TorchBlock:interact()
    -- Back into the inventory, or onto the ground when there is no room
    if Inventories.add(player.inventory, self.name, 1) > 0 then
        map.drops:spawn(self.name, 1, self.x + self.width / 2, self.y + self.height / 2)
    end
    self:destroy()
end


function TorchBlock:draw()
    local scale = self.width / 16
    local r, g, b, a = love.graphics.getColor()
    for i, p in ipairs(PIXELS) do
        local c = p[5]
        love.graphics.setColor(r * c[1], g * c[2], b * c[3], a * c[4])
        love.graphics.rectangle("fill", self.x + p[1] * scale, self.y + p[2] * scale, p[3] * scale, p[4] * scale)
    end
    love.graphics.setColor(r, g, b, a)
end


registerBlock("Torch", TorchBlock)

return TorchBlock
