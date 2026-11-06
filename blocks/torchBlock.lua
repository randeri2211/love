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

function TorchBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "Torch"
    block.tile = "torch"
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


registerBlock("Torch", TorchBlock)

return TorchBlock
