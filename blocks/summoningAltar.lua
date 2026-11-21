local Block = require "blocks.block"
local HPBar = require "components.hpBar"
local Inventories = require "items.inventories"
local Items = require "items.items"
local Structures = require "world_utils.structures"

-- The altar in a boss lair(see world_utils/structures and structures/unicornLair): offering its summoning item(the
-- interact key, from anywhere in the inventory) calls the lair's boss down onto it and seals the lair's way in until
-- the fight ends(see blocks/lairSeal). The boss can be called again after it was beaten, one at a time. Walk-through, so a charge across the arena doesnt stop at it, and nothing breaks it
-- It keeps lairId(its structure), boss(the entity it summons) and summon(the item it takes)
local SummoningAltar = Block:new()
SummoningAltar.solid = false
SummoningAltar.noItem = true        -- Part of a lair, not something to carry
SummoningAltar.drop = false
SummoningAltar.light = ALTAR_LIGHT
registerBlock("SummoningAltar", SummoningAltar)


function SummoningAltar:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "SummoningAltar"
    block.tile = "altar"
    block.hpBar = HPBar(1, 1, 0)
    block.damageThreshold = math.huge
    block.lairId, block.boss, block.summon = nil, nil, nil     -- Set when its lair is made(see Map:stampStructures)
    return block
end


function SummoningAltar:damage()
    -- Nothing breaks it, spells pass through
end


function SummoningAltar:bossHere()
    -- The boss of this altar while it is alive, nil when it isnt summoned
    return Structures.bossOf(self.lairId)
end


function SummoningAltar:interact()
    local class = ENTITY_REGISTRY[self.boss]
    if class == nil or self.summon == nil then
        return
    end
    local name = class.displayName or self.boss
    if self:bossHere() ~= nil then
        uihandler:toast("The " .. name .. " is already here")
        return
    end
    if Inventories.count(player.inventory, self.summon) < 1 then
        uihandler:toast("The altar asks for a " .. Items.displayName(self.summon))
        return
    end
    Inventories.remove(player.inventory, self.summon, 1)
    -- It comes down a little above the altar, facing the player
    local x, y = self.x + self.width / 2, self.y - TILE_SIZE * 2
    local boss = class:new(x, y)
    boss.lairId = self.lairId
    boss.altarX, boss.altarY = x, self.y + self.height     -- Where its fight is, it leaves when the player goes far
    map.enemies:addEnemy(boss)
    boss:update(0)
    Structures.sealDoors(self.lairId)
    uihandler:toast("The " .. name .. " answers the call", BOSS_COLOR)
end


function SummoningAltar:tooltip()
    local class = ENTITY_REGISTRY[self.boss]
    local name = class and class.displayName or self.boss or "boss"
    return string.format("Summoning Altar\nOffer a %s to call the %s\n%s to offer", Items.displayName(self.summon or ""), name,
        INTERACT_KEY:upper())
end


function SummoningAltar:draw()
    Block.draw(self)
    -- A soft violet glow over the bowl, brighter while the player carries what it asks for
    local ready = self.summon ~= nil and player ~= nil and Inventories.count(player.inventory, self.summon) > 0
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 2.5)
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.7, 0.45, 1, (ready and 0.35 or 0.12) + 0.1 * pulse)
    love.graphics.circle("fill", self.x + self.width / 2, self.y + self.height * 0.3, self.width * 0.45, 16)
    love.graphics.pop()
end


function SummoningAltar:hasOwnState()
    return true     -- Its lair and boss have to be saved
end


function SummoningAltar:load(data)
    Block.load(self, data)
    self.lairId = type(data.lairId) == "string" and data.lairId or nil
    self.boss = type(data.boss) == "string" and data.boss or nil
    self.summon = type(data.summon) == "string" and data.summon or nil
end

return SummoningAltar
