Block = {}
registerBlock("Block",Block)

function Block:new(x, y, width, height)
    -- Block Variables
    local block = {}
    setmetatable(block, self)
    self.__index = self

    if x == nil then
        return block
    end

    block.width = width
    block.height = height
    block.name = "Block"
    block.type = "Block"
    block.hpBar = HPBar(1, 1, 0)
    block.imagePath = "GRASS"
    block.image = BLOCK_IMG[block.imagePath]
    block.x = x
    block.y = y

    block.mx, block.my = loveToMap(x, y)
    
    if x == nil then
        return block
    end
    -- Adjust y to block size
    if height ~= TILE_SIZE then
        if block.y % TILE_SIZE == 0 then
            block.y = block.y + TILE_SIZE - height
        end
    end
    -- Round x to tiles
    if block.x % TILE_SIZE ~= 0 then
        block.x = block.x - (block.x % TILE_SIZE)
    end
    
    return block
end


-- Block Functions
function Block:draw()
    love.graphics.draw(self.image, self.x, self.y, 0, self.width / self.image:getWidth(), self.height / self.image:getHeight())
end


function Block:damage(dmg)
    self.hpBar.currentHP = self.hpBar.currentHP - dmg
    if self.hpBar.currentHP <= 0 then
        self:destroy()
    end
end


function Block:destroy()
    self:destroyBody()
    map.map[self.mx][self.my] = nil
end


function Block:generateBody()
    -- Setting up all the userdata
    if self.body == nil then
        self.body = love.physics.newBody(p_world, self.x, self.y, "static")
        self.shape = love.physics.newRectangleShape(self.width / 2, self.height / 2, self.width, self.height)
        self.fixture = love.physics.newFixture(self.body, self.shape, 1)
        self.body:setSleepingAllowed(true)
        self.body:isAwake(false)
        self.fixture:setCategory(BLOCKS_CATEGORY)
        self.fixture:setGroupIndex(-BLOCKS_CATEGORY)
    end
end


function Block:destroyBody()
    if self.body ~= nil then
        self.body:destroy()
        self.body = nil
    end
end

function Block:load(blockTable)
    self.hpBar = blockTable.hpBar
    -- self.imagePath = blockTable.imagePath
    -- self.image = BLOCK_IMG[self.imagePath]
end

function Block:prepSave()
    -- Prevents crash
    if self.tooltipText ~= nil then
        self.tooltipText = "\"" .. self.tooltipText .. "\""
    end
end

function Block:afterSave()
    if self.tooltipText ~= nil then
        if #self.tooltipText > 2 then
            self.tooltipText = string.sub(self.tooltipText, 2, -2)
        end
    end
end