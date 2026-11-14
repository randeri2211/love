local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- Crafting stations: placed like any block, standing within interaction distance of one
-- adds its recipes to the crafting list(see items/crafting)
-- A processing station(processes) also works on its own over time: an input, a fuel and an output slot, opened with the
-- interact key, fed with fuel or powered by a mana network(see items/processing and ui/processPanel)
local StationBlock = Block:new()
StationBlock.station = true

-- Stations by block name: their tile, how sturdy they are, and whether they process
local STATIONS = {
    {name = "WoodworkingStation", tile = "woodworking", hp = 6},
    {name = "Forge", tile = "forge", hp = 10, light = FORGE_LIGHT, processes = true},
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
    return self.info.name .. "\n" .. self.state .. "\n" .. INTERACT_KEY:upper() .. " to open"
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


-- One block class per station, they only differ in their info table
for i, info in ipairs(STATIONS) do
    local class = StationBlock:new()
    class.info = info
    class.light = info.light    -- A lit forge glows(see world_utils/lighting)
    if info.processes then
        class.processes = true
        for name, method in pairs(Processing) do
            class[name] = method
        end
    end
    registerBlock(info.name, class)
end

return StationBlock
