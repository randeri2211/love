require "blocks.block"
InteractiveBlock = Block:new()

function InteractiveBlock:new(x, y, width, height)
    -- Block Variables
    local iblock = Block:new(x, y, width, height)
    setmetatable(iblock, self)
    self.__index = self

    iblock.imagePath = "PANELING_SMALL"
    iblock.name = "Interactive Block"
    iblock.image = BLOCK_IMG[iblock.imagePath]

    return iblock
end

function InteractiveBlock:interact()
    print("interacted "..self.x..","..self.y)
end