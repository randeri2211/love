local Block = require "blocks.block"
local HPBar = require "components.hpBar"

-- The Scribe's Desk(see docs/game-design: Spell scrolls): binds the player's spells into Blank Scrolls
-- Its slot holds Blank Scrolls, its screen lists the player's spells to bind one(see ui/scribePanel)
-- What is in the slot stays in it and is saved, the desk breaks only when the slot is empty
local ScribesDesk = Block:new()
ScribesDesk.scribe = true

local image = nil   -- assets/art*/machines/scribesDesk.png, loaded with the first desk


function ScribesDesk:new(x, y, width, height)
    local block = Block:new(x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ScribesDesk"
    block.damageThreshold = 1
    block.hpBar = HPBar(6, 6, 0)
    block.slot = false      -- The Blank Scrolls in it
    if image == nil then
        image = artImage(ART_FOLDER .. "machines/scribesDesk.png")
    end

    return block
end


function ScribesDesk:draw()
    love.graphics.draw(image, self.x, self.y, 0, self.width / image:getWidth(), self.height / image:getHeight())
end


function ScribesDesk:drawIcon(x, y, size)
    love.graphics.draw(image, x, y, 0, size / image:getWidth(), size / image:getHeight())
end


function ScribesDesk:interact()
    uihandler:openStation(self)
end


function ScribesDesk:damage(dmg, power, source)
    -- It holds together while scrolls are in it
    if self.slot then
        return
    end
    Block.damage(self, dmg, power, source)
end


function ScribesDesk:hasOwnState()
    return Block.hasOwnState(self) or self.slot ~= false
end


function ScribesDesk:load(data)
    Block.load(self, data)
    self.slot = type(data.slot) == "table" and data.slot or false
end


registerBlock("ScribesDesk", ScribesDesk)

return ScribesDesk
