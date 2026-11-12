local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local Inventories = require "items.inventories"
local ManaShader = require "world_utils.manaShader"

-- A mana conduit(see docs/game-design: Mana network): a node that carries the network MANA_NETWORK_REACH tiles further,
-- beams join it to the nodes in its reach(see world_utils/manaNetwork)
-- Like a torch it is walk-through and needs a block next to it, spells pass through it and interacting picks it back up
local ManaConduit = Block:new()
ManaConduit.solid = false
ManaConduit.needsSupport = true
ManaConduit.manaNode = true
ManaConduit.light = MANA_CONDUIT_LIGHT
ManaConduit.CRYSTAL = {6, 2, 4, 6}     -- The crystal in its 16 x 16 picture at the 16 pixel layout: x, y, width, height

local image = nil   -- assets/art*/machines/manaConduit.png, loaded with the first conduit


function ManaConduit:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ManaConduit"
    block.hpBar = HPBar(1, 1, 0)
    block.damageThreshold = math.huge
    if image == nil then
        image = artImage(ART_FOLDER .. "machines/manaConduit.png")
    end

    return block
end


function ManaConduit:box()
    return self.x, self.y, self.width, self.height
end


function ManaConduit:beamPoint()
    -- Where network beams leave it: the crystal
    local c = ManaConduit.CRYSTAL
    return self.x + (c[1] + c[3] / 2) / 16 * self.width, self.y + (c[2] + c[4] / 2) / 16 * self.height
end


local function crystal(x, y, w, h)
    local c = ManaConduit.CRYSTAL
    return x + c[1] / 16 * w, y + c[2] / 16 * h, c[3] / 16 * w, c[4] / 16 * h
end


function ManaConduit:draw()
    love.graphics.draw(image, self.x, self.y, 0, self.width / image:getWidth(), self.height / image:getHeight())
end


function ManaConduit:drawGlow()
    -- The crystal is full of mana, after the light(see Map:drawGlow)
    local cx, cy, cw, ch = crystal(self.x, self.y, self.width, self.height)
    ManaShader.fill(cx, cy, cw, ch, 1)
end


function ManaConduit:drawIcon(x, y, size)
    love.graphics.draw(image, x, y, 0, size / image:getWidth(), size / image:getHeight())
    local cx, cy, cw, ch = crystal(x, y, size, size)
    ManaShader.fill(cx, cy, cw, ch, 1)
end


function ManaConduit:damage()
    -- Spells pass through, it comes off with the block holding it
end


function ManaConduit:interact()
    -- Back into the inventory, or onto the ground when there is no room
    if Inventories.add(player.inventory, self.name, 1) > 0 then
        map.drops:spawn(self.name, 1, self.x + self.width / 2, self.y + self.height / 2)
    end
    self:destroy()
end


function ManaConduit:tooltip()
    return "Mana Conduit\n" .. INTERACT_KEY:upper() .. " to pick up"
end


registerBlock("ManaConduit", ManaConduit)

return ManaConduit
