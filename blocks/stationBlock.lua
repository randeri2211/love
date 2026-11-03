local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- Crafting stations: placed like any block, standing within interaction distance of one
-- adds its recipes to the crafting list(see items/crafting)
local StationBlock = Block:new()
StationBlock.station = true

-- Stations by block name: their tile and how sturdy they are
local STATIONS = {
    {name = "WoodworkingStation", tile = "woodworking", hp = 6},
    {name = "Forge", tile = "forge", hp = 10, light = FORGE_LIGHT},
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

    return block
end


-- One block class per station, they only differ in their info table
for i, info in ipairs(STATIONS) do
    local class = StationBlock:new()
    class.info = info
    class.light = info.light    -- A lit forge glows(see world_utils/lighting)
    registerBlock(info.name, class)
end

return StationBlock
