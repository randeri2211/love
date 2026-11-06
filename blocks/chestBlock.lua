local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local Inventory = require "components.inventory"
local Inventories = require "items.inventories"

-- Chests: blocks with an inventory of their own, opened with the interact key next to the player inventory(see ui/chestPanel)
-- What is in them stays in them, crafting takes from every chest in reach(see Crafting.sources)
-- A chest only breaks once it is empty, so a stray spell never scatters what it holds
local ChestBlock = Block:new()
ChestBlock.chest = true

-- Chests by block name: rows of CHEST_COLUMNS slots, their tile, how sturdy they are, and a light for the ones that glow
local CHESTS = {
    {name = "WoodenChest", tile = "woodenChest", rows = 4, hp = 6},
    {name = "IronChest", tile = "ironChest", rows = 6, hp = 10},
    {name = "ArcaniteChest", tile = "arcaniteChest", rows = 10, hp = 14, light = {0.12, 0.3, 0.4}},
}


function ChestBlock:new(x, y, width, height)
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
    block.inventory = Inventory(self.info.rows * CHEST_COLUMNS)

    return block
end


function ChestBlock:interact()
    uihandler:openStation(self)
end


function ChestBlock:damage(dmg, power, source)
    -- It holds together while anything is inside
    if not Inventories.isEmpty(self.inventory) then
        return
    end
    Block.damage(self, dmg, power, source)
end


function ChestBlock:hasOwnState()
    -- Saved whole while it holds items
    return Block.hasOwnState(self) or not Inventories.isEmpty(self.inventory)
end


function ChestBlock:saveData()
    -- Its items saved like the player inventory(the plain save skips every field named inventory, see SKIP_KEYS)
    return {
        name = self.name, x = self.x, y = self.y, width = self.width, height = self.height,
        hpBar = {currentHP = self.hpBar.currentHP, maxHP = self.hpBar.maxHP, regen = 0},
        inventory = Inventories.toData(self.inventory),
    }
end


function ChestBlock:load(data)
    Block.load(self, data)
    self.inventory = Inventories.fromData(data.inventory, self.info.rows * CHEST_COLUMNS)
end


-- One block class per chest, they only differ in their info table
for i, info in ipairs(CHESTS) do
    local class = ChestBlock:new()
    class.info = info
    class.light = info.light
    registerBlock(info.name, class)
end

return ChestBlock
