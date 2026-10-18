local HPBar = require "components.hpBar"
local Block = {}
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
    block.hpBar = HPBar(BASE_BLOCK_HP, BASE_BLOCK_HP, 0)
    block.imagePath = "GRASS"
    block.image = BLOCK_IMG[block.imagePath]
    block.tile = nil        -- Name in BLOCK_TILES, when set the block draws that part of the tilesheet instead of its image
    block.tint = nil        -- Color multiplied into the tile, lets one tile serve several blocks
    block.x = x
    block.y = y
    block.damageThreshold = 1

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
    if self.tile ~= nil then
        -- Part of the tilesheet stretched over the block, tinted if the block has a tint
        local quad = BLOCK_TILES[self.tile]
        local _, _, qw, qh = quad:getViewport()
        if self.tint ~= nil then
            love.graphics.setColor(self.tint)
        end
        love.graphics.draw(TILESHEET, quad, self.x, self.y, 0, self.width / qw, self.height / qh)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.draw(self.image, self.x, self.y, 0, self.width / self.image:getWidth(), self.height / self.image:getHeight())
    end
end


function Block:damage(dmg, power)
    -- power is the hit strength checked against the hardness, dmg is what the block loses
    -- (spells only deal part of their damage to terrain, hardness looks at their dig strength)
    power = power or dmg
    if power > self.damageThreshold then
        self.hpBar.currentHP = self.hpBar.currentHP - dmg
        if self.hpBar.currentHP <= 0 then
            self:destroy()
        end
    end
end


function Block:hasOwnState()
    -- True when saving only the block type would lose something, then the map saves the whole block
    -- Block types with more state(like a chest) should add their own check here
    return self.hpBar.currentHP < self.hpBar.maxHP or self.width ~= TILE_SIZE or self.height ~= TILE_SIZE
end


function Block:destroy()
    self:destroyBody()
    map:set(self.mx, self.my, nil)
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

return Block