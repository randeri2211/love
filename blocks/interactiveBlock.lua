local Block = require "blocks.block"

InteractiveBlock = Block:new()
registerBlock("Interactive",InteractiveBlock)

function InteractiveBlock:new(x, y, width, height)
    -- Block Variables
    local iblock = Block:new(x, y, width, height)
    setmetatable(iblock, self)
    self.__index = self

    iblock.imagePath = "PANELING_SMALL"
    iblock.name = "Interactive"
    iblock.image = BLOCK_IMG[iblock.imagePath]
    iblock.tooltipText = "Interactive block"  -- Default tooltip

    return iblock
end

function InteractiveBlock:interact()
    print("interacted with interactiveBlock at "..self.x..","..self.y.." in love coordinates")
end

function InteractiveBlock:draw()
    Block.draw(self)
end

return InteractiveBlock