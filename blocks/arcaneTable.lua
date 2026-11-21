local Block = require "blocks.block"
local BigBlock = require "blocks.bigBlock"
local HPBar = require "components.hpBar"
local ArcaneTables = require "items.arcaneTables"

-- Where wands and staves are put together and taken apart(see items/arcaneTables and ui/arcanePanel)
-- Interacting opens it next to the inventory, parts left in it stay in it, breaking it drops them
-- Two tiles wide(see blocks/bigBlock), its picture is assets/art*/machines/arcaneTable.png
local ArcaneTable = BigBlock:new()
ArcaneTable.footprint = {2, 1}
ArcaneTable.art = "arcaneTable"
registerBlock("ArcaneTable", ArcaneTable)

function ArcaneTable:new(x, y, width, height)
    local block = BigBlock.new(self, x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ArcaneTable"
    block.damageThreshold = 1
    block.hpBar = HPBar(8, 8, 0)
    block.arcane = ArcaneTables.new()

    return block
end


function ArcaneTable:interact()
    uihandler:openStation(self)
end


function ArcaneTable:tooltip()
    -- Like a processing station's(see blocks/stationBlock), with what is left on it
    local text = "Arcane Table\n"
    if not ArcaneTables.isEmpty(self.arcane) then
        text = text .. "Has parts on it\n"
    end
    return text .. INTERACT_KEY:upper() .. " to open"
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
    local x, y, w, h = self:box()
    ArcaneTables.dropAll(self.arcane, x + w / 2, y + h / 2)
    BigBlock.breakApart(self)
end

return ArcaneTable
