local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- Trees and plants(see world_utils/flora): scenery you walk through, spells and dropped items pass through them too
-- They cant be hit, they come down when the ground block they grow on breaks, every part dropping its item
local FloraBlock = Block:new()
FloraBlock.solid = false
FloraBlock.noItem = true    -- Not placeable, they drop materials instead(see items/materials)

-- Parts by block name: the species they belong to(Flora.SPECIES), their tile, what they drop(false for nothing)
-- rootScale makes the ground block under them that many times slower to break, so a tree base isnt plain dirt
-- replaceable parts make way for a placed block(see world_utils/building)
local PARTS = {
    {name = "OakLog", species = "Oak", tile = "oakLog", drop = "OakWood", rootScale = ROOT_HP_SCALE},
    {name = "OakLeaves", species = "Oak", tile = "oakLeaves", drop = false},
    {name = "PineLog", species = "Pine", tile = "pineLog", drop = "PineWood", rootScale = ROOT_HP_SCALE},
    {name = "PineLeaves", species = "Pine", tile = "pineLeaves", drop = false},
    {name = "PineCore", species = "Pine", tile = "pineLeaves", drop = "PineWood"},     -- The trunk inside the needles
    {name = "Cactus", species = "Cactus", tile = "cactus", drop = "Cactus", rootScale = ROOT_HP_SCALE},
    {name = "TallGrass", species = "TallGrass", tile = "tallGrass", drop = "PlantFiber", replaceable = true},
}


function FloraBlock:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = self.part.name
    block.species = self.part.species
    block.tile = self.part.tile
    block.hpBar = HPBar(1, 1, 0)
    block.damageThreshold = math.huge

    return block
end


function FloraBlock:damage()
    -- Spells pass through, the tree comes down with its ground block instead
end


-- One block class per part, they only differ in their part table
for i, part in ipairs(PARTS) do
    local class = FloraBlock:new()
    class.part = part
    class.drop = part.drop
    class.rootScale = part.rootScale
    class.replaceable = part.replaceable
    registerBlock(part.name, class)
end

return FloraBlock
