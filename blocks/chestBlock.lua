local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local Inventory = require "components.inventory"
local Inventories = require "items.inventories"

-- Chests: blocks with an inventory of their own, opened with the interact key next to the player inventory(see ui/chestPanel)
-- What is in them stays in them, crafting takes from every chest in reach(see Crafting.sources)
-- A chest only breaks once it is empty, so a stray spell never scatters what it holds
local ChestBlock = Block:new()
ChestBlock.chest = true

-- Chests by block name: rows of CHEST_COLUMNS slots, how sturdy they are, their colors(body, dark, bands, latch)
-- and a light for the ones that glow
local CHESTS = {
    {name = "WoodenChest", rows = 4, hp = 6,
        colors = {{0.58, 0.38, 0.21, 1}, {0.3, 0.19, 0.1, 1}, {0.42, 0.27, 0.15, 1}, {0.85, 0.72, 0.35, 1}}},
    {name = "IronChest", rows = 6, hp = 10,
        colors = {{0.52, 0.53, 0.58, 1}, {0.22, 0.23, 0.27, 1}, {0.72, 0.73, 0.78, 1}, {0.95, 0.85, 0.45, 1}}},
    {name = "ArcaniteChest", rows = 10, hp = 14, light = {0.12, 0.3, 0.4},
        colors = {{0.16, 0.24, 0.42, 1}, {0.07, 0.1, 0.2, 1}, {0.4, 0.85, 1, 1}, {0.75, 0.95, 1, 1}}},
}

-- The chest in 16x16 pixels: {x, y, w, h, color index}, an outline, the lid and the body, two bands and a latch
local PIXELS = {
    {1, 4, 14, 12, 2},
    {2, 5, 12, 3, 1},
    {2, 9, 12, 6, 1},
    {4, 5, 1, 10, 3},
    {11, 5, 1, 10, 3},
    {7, 7, 2, 3, 4},
}


function ChestBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = self.info.name
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


function ChestBlock:draw()
    local scale = self.width / 16
    local colors = self.info.colors
    local r, g, b, a = love.graphics.getColor()
    for i, p in ipairs(PIXELS) do
        local c = colors[p[5]]
        love.graphics.setColor(r * c[1], g * c[2], b * c[3], a * c[4])
        love.graphics.rectangle("fill", self.x + p[1] * scale, self.y + p[2] * scale, p[3] * scale, p[4] * scale)
    end
    love.graphics.setColor(r, g, b, a)
end


-- One block class per chest, they only differ in their info table
for i, info in ipairs(CHESTS) do
    local class = ChestBlock:new()
    class.info = info
    class.light = info.light
    registerBlock(info.name, class)
end

return ChestBlock
