local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- Blocks bigger than one tile(a mana battery is 2x2): footprint = {columns, rows}
-- The block itself sits in the bottom left cell(its anchor) and is the one that draws, takes damage and keeps the state,
-- every other cell holds a BlockPart that points back at it, so the map, the hitboxes and the light still see one block a cell
-- Parts save themselves(their offset to the anchor), a big block over two chunks loads whichever chunk comes first
local BigBlock = Block:new()
BigBlock.footprint = {2, 2}


function BigBlock:cells()
    -- Map cells of the whole block, the anchor first: {x, y} list
    local cells = {}
    for i = 0, self.footprint[1] - 1 do
        for j = 0, self.footprint[2] - 1 do
            table.insert(cells, {self.mx + i, self.my + j})
        end
    end
    return cells
end


function BigBlock:box()
    -- Love box of the whole block: x, y of its top left, width, height(the anchor is the bottom left tile, map y goes up)
    local w, h = self.footprint[1] * TILE_SIZE, self.footprint[2] * TILE_SIZE
    return self.x, self.y + TILE_SIZE - h, w, h
end


function BigBlock:placeParts()
    -- Fills the rest of the footprint with parts, after the anchor is set in the map
    for i, cell in ipairs(self:cells()) do
        if i > 1 then
            local part = map:newBlock("BlockPart", cell[1], cell[2])
            part.dx, part.dy = self.mx - cell[1], self.my - cell[2]
            map:set(cell[1], cell[2], part)
        end
    end
end


function BigBlock:owns(block)
    return block == self or (block ~= nil and block.name == "BlockPart" and block:owner() == self)
end


function BigBlock:destroy()
    -- Every cell of it goes, found before any is removed(a part finds its block through the anchor cell)
    local owned = {}
    for i, cell in ipairs(self:cells()) do
        if self:owns(map:get(cell[1], cell[2])) then
            table.insert(owned, cell)
        end
    end
    for i, cell in ipairs(owned) do
        map:set(cell[1], cell[2], nil)
    end
end


function BigBlock:breakApart()
    -- One item from the middle of it, then every cell lets go of what it held up
    local item = self:dropItem()
    local x, y, w, h = self:box()
    if item ~= nil then
        map.drops:spawn(item, 1, x + w / 2, y + h / 2)
    end
    self:destroy()
    for i, cell in ipairs(self:cells()) do
        Block.fallFrom(cell[1], cell[2])
    end
end


function BigBlock:drawArt(x, y, w, h)
    -- The picture of the block in a box, the same for the world and the item icon(block types draw their own)
end


function BigBlock:draw()
    self:drawArt(self:box())
end


function BigBlock:drawIcon(x, y, size)
    -- The whole block shrunk into an item slot, kept square around its middle
    local scale = size / math.max(self.footprint[1], self.footprint[2])
    local w, h = self.footprint[1] * scale, self.footprint[2] * scale
    self:drawArt(x + (size - w) / 2, y + (size - h) / 2, w, h)
end


-- A cell of a big block that isnt its anchor: solid, but everything that happens to it happens to the block it belongs to
local BlockPart = Block:new()
BlockPart.noItem = true


function BlockPart:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "BlockPart"
    block.dx, block.dy = 0, 0   -- Map cells from here to the anchor
    block.hpBar = HPBar(1, 1, 0)
    block.damageThreshold = 0

    return block
end


function BlockPart:owner()
    -- The big block this part belongs to, nil when it is gone(then the part is a leftover and goes on the next hit)
    local anchor = map:get(self.mx + self.dx, self.my + self.dy)
    if anchor ~= nil and anchor.footprint ~= nil and anchor.name ~= "BlockPart" then
        return anchor
    end
    return nil
end


function BlockPart:draw()
    -- The anchor draws the whole block
end


function BlockPart:damage(dmg, power, source)
    local owner = self:owner()
    if owner == nil then
        Block.destroy(self)
        return
    end
    owner:damage(dmg, power, source)
end


function BlockPart:breakApart()
    local owner = self:owner()
    if owner == nil then
        Block.breakApart(self)
        return
    end
    owner:breakApart()
end


function BlockPart:dropItem()
    return nil
end


function BlockPart:interact()
    -- Interacting with any cell of a big block interacts with the block
    local owner = self:owner()
    if owner ~= nil and type(owner.interact) == "function" then
        owner:interact()
    end
end


function BlockPart:tooltip()
    -- Hovering any cell of a big block shows the block's tooltip
    local owner = self:owner()
    if owner == nil then
        return nil
    end
    return owner.tooltip ~= nil and owner:tooltip() or owner.tooltipText
end


function BlockPart:hasOwnState()
    return true
end


function BlockPart:saveData()
    return {name = self.name, x = self.x, y = self.y, width = self.width, height = self.height, dx = self.dx, dy = self.dy}
end


function BlockPart:load(data)
    self.dx, self.dy = data.dx or 0, data.dy or 0
end


registerBlock("BlockPart", BlockPart)

return BigBlock
