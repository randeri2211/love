local HPBar = require "components.hpBar"
local Flora = require "world_utils.flora"
local Block = {}
registerBlock("Block",Block)
Block.abstract = true   -- The base of every block, not a block of its own(read with rawget so block types dont inherit it)
Block.solid = true      -- Trees and plants are not(see blocks/floraBlock), the map treats them as air for hitboxes and rays

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
    block.imagePath = "FALLBACK"
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


function Block:addToBatch(batch)
    -- A plain tile block goes in its chunk's sprite batch instead of being drawn on its own(see Map:draw), true when it did
    -- Blocks that draw themselves(a mana block, machines) return false and are drawn every frame, block types whose
    -- look is only tiles can add those tiles themselves(see OreBlock)
    if self.draw ~= Block.draw or self.tile == nil then
        return false
    end
    local quad = BLOCK_TILES[self.tile]
    local _, _, qw, qh = quad:getViewport()
    local c = self.tint
    if c ~= nil then
        batch:setColor(c[1], c[2], c[3], c[4] or 1)
    end
    batch:add(quad, self.x, self.y, 0, self.width / qw, self.height / qh)
    batch:setColor(1, 1, 1, 1)
    return true
end


function Block:damage(dmg, power, source)
    -- power is checked against the hardness(a spell passes its dig cap, see Form:digReach), dmg is what the block loses
    -- (spells only deal part of their damage to terrain, Dig runes raise it)
    -- source is what hit it, a spell or a creature clawing at it, nil when unknown(only mana blocks use it)
    power = power or dmg
    -- Development: blocks break on any hit, the bottom of the world still holds
    if DEBUG_ONE_HIT_BLOCKS and self.damageThreshold ~= math.huge then
        self:breakApart()
        return
    end
    if power > self.damageThreshold then
        -- A tree or cactus growing on it makes it slower to break, same hardness but more to dig through
        local above = map:get(self.mx, self.my + 1)
        if above ~= nil and above.rootScale ~= nil then
            dmg = dmg / above.rootScale
        end
        self.hpBar.currentHP = self.hpBar.currentHP - dmg
        if self.hpBar.currentHP <= 0 then
            self:breakApart()
        end
    end
end


function Block:dropItem()
    -- Item the block leaves when broken: drop on the class(like Grass dropping Dirt), itself by default, false for none
    if self.drop == false then
        return nil
    end
    return self.drop or self.name
end


function Block:breakApart()
    -- Broken by damage: the block goes and its item pops out of where it was
    local item = self:dropItem()
    if item ~= nil then
        map.drops:spawn(item, 1, self.x + self.width / 2, self.y + self.height / 2)
    end
    self:destroy()
    Block.fallFrom(self.mx, self.my)
end


function Block.fallFrom(x, y)
    -- Map cell x, y was just emptied: whatever grew on it comes down, so do blocks it was holding up(torches)
    Flora.fell(map, x, y)
    for i, side in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
        local sx, sy = x + side[1], y + side[2]
        local block = map:get(sx, sy)
        if block ~= nil and block.needsSupport and not Block.supported(sx, sy) then
            block:breakApart()
        end
    end
end


function Block.supported(x, y)
    -- True when a solid block is next to map cell x, y(what a torch needs to stay up)
    return map:isSolid(x - 1, y) or map:isSolid(x + 1, y) or map:isSolid(x, y - 1) or map:isSolid(x, y + 1)
end


function Block:hasOwnState()
    -- True when saving only the block type would lose something, then the map saves the whole block
    -- Block types with more state(like a chest) should add their own check here
    return self.hpBar.currentHP < self.hpBar.maxHP or self.width ~= TILE_SIZE or self.height ~= TILE_SIZE
end


function Block:variant(count, salt)
    -- Repeatable pick from 1 to count for this block, from its map position(salt makes separate picks unrelated)
    -- Neighbors look different but a block always looks the same, so nothing about it needs saving
    local v = math.sin(self.mx * 127.1 + self.my * 311.7 + (salt or 0) * 74.7) * 43758.5453
    return math.floor((v - math.floor(v)) * count) + 1
end


function Block:contains(x, y)
    -- True when a love point is inside the block box(blocks shorter than a tile sit at the bottom of it)
    return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end


function Block:destroy()
    -- The map removes the hitbox and gives the newly exposed neighbors theirs
    map:set(self.mx, self.my, nil)
end


function Block:generateHitbox(body)
    -- Hitbox of this block as a fixture on its chunk body(see Map:refreshHitbox), the same box the block is drawn in
    -- The fixture knows its block, so contacts and queries find the block straight from it
    if self.fixture == nil then
        self.shape = love.physics.newRectangleShape(self.x + self.width / 2, self.y + self.height / 2, self.width, self.height)
        self.fixture = love.physics.newFixture(body, self.shape, 1)
        self.fixture:setCategory(BLOCKS_CATEGORY)
        self.fixture:setGroupIndex(-BLOCKS_CATEGORY)
        self.fixture:setUserData(self)
    end
end


function Block:destroyHitbox()
    if self.fixture ~= nil then
        if not self.fixture:isDestroyed() then
            self.fixture:destroy()
        end
        self.fixture = nil
        self.shape = nil
    end
end

function Block:load(blockTable)
    self.hpBar = blockTable.hpBar
    -- self.imagePath = blockTable.imagePath
    -- self.image = BLOCK_IMG[self.imagePath]
end

return Block