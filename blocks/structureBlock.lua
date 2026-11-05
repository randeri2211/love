local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- Blocks structures are built from(see world_utils/structures): stone bricks need an iron level dig cap,
-- so early on a structure is entered through its door, cracked ones(ruins) and planks give way sooner
-- A campfire is walk-through and lights the camp around it like a torch
local StructureBlock = Block:new()

-- Blocks by name: tile, hardness(damageThreshold), hp, and the campfire's own values
local BLOCKS = {
    {name = "StoneBricks", tile = "stoneBricks", threshold = 22, hp = 14},
    {name = "CrackedStoneBricks", tile = "crackedStoneBricks", threshold = 12, hp = 8},
    {name = "Planks", tile = "planks", threshold = 5, hp = 6},
    {name = "Campfire", tile = "campfire", threshold = math.huge, hp = 1, solid = false, light = CAMPFIRE_LIGHT},
}


function StructureBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = self.info.name
    block.tile = self.info.tile
    block.damageThreshold = self.info.threshold
    block.hpBar = HPBar(self.info.hp, self.info.hp, 0)
    return block
end


-- One block class per kind, they only differ in their info table
for i, info in ipairs(BLOCKS) do
    local class = StructureBlock:new()
    class.info = info
    if info.solid == false then
        -- Walk-through and out of the way of spells like a torch, it falls off with the block under it
        class.solid = false
        class.needsSupport = true
        class.light = info.light
        function class:damage() end
    end
    registerBlock(info.name, class)
end

return StructureBlock
