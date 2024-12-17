require "components.hpBar"
require "assets.assetLoader"
Block = {}

function Block:new(x, y, width, height)
    -- Block Variables
    local block = {}
    setmetatable(block, self)
    self.__index = self
    block.width = width
    block.height = height
    block.name = "Default Block"
    block.type = "Block"
    block.hpBar = HPBar(1, 1, 0)
    block.imagePath = "GRASS"
    block.image = BLOCK_IMG[block.imagePath]
    block.x = x
    block.y = y
    
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
        self = self.destroy()
    end
end


function Block:destroy()
    self = nil
    return self
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


