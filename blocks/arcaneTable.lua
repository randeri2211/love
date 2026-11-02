local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local ArcaneTables = require "items.arcaneTables"

-- Where wands and staves are put together and taken apart(see items/arcaneTables and ui/arcanePanel)
-- Interacting opens it next to the inventory, parts left in it stay in it, breaking it drops them
local ArcaneTable = Block:new()
registerBlock("ArcaneTable", ArcaneTable)

function ArcaneTable:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ArcaneTable"
    block.tile = "arcaneTable"
    block.damageThreshold = 1
    block.hpBar = HPBar(8, 8, 0)
    block.arcane = ArcaneTables.new()

    return block
end


function ArcaneTable:interact()
    uihandler:openStation(self)
end


function ArcaneTable:hasOwnState()
    -- Saved whole while it holds parts
    return Block.hasOwnState(self) or not ArcaneTables.isEmpty(self.arcane)
end


function ArcaneTable:load(data)
    Block.load(self, data)
    self.arcane = ArcaneTables.fromData(data.arcane)
end


function ArcaneTable:breakApart()
    -- Its parts fall out with it
    ArcaneTables.dropAll(self.arcane, self.x + self.width / 2, self.y + self.height / 2)
    Block.breakApart(self)
end

return ArcaneTable
