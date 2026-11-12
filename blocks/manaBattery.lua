local BigBlock = require "blocks.bigBlock"
local HPBar = require "components.hpBar"
local ManaShader = require "world_utils.manaShader"

-- The mana battery(see docs/game-design: Mana network): a 2x2 block storing up to MANA_BATTERY_CAPACITY mana,
-- its glass window shows the mana in it(the mana effect, drawn after the light so it glows at night)
-- A full player's regen fills it, and with feedPlayer on it pays the player's spells first(see world_utils/manaNetwork)
-- Interacting opens its screen next to the inventory(see ui/batteryPanel)
local ManaBattery = BigBlock:new()
ManaBattery.footprint = {2, 2}
ManaBattery.manaNode = true     -- Part of a mana network(see world_utils/manaNetwork)
ManaBattery.WINDOW = {6, 5, 20, 22}     -- The glass in its 32 x 32 picture at the 16 pixel layout: x, y, width, height

local image = nil   -- The housing(assets/art*/machines/manaBattery.png), loaded with the first battery


function ManaBattery:new(x, y, width, height)
    local block = BigBlock.new(self, x, y, width, height)
    setmetatable(block, self)
    self.__index = self
    if x == nil then
        return block
    end

    block.name = "ManaBattery"
    block.damageThreshold = 1
    block.hpBar = HPBar(MANA_BATTERY_HP, MANA_BATTERY_HP, 0)
    block.mana = 0
    block.feedPlayer = false    -- Pays the player's spells while they are in reach
    if image == nil then
        image = artImage(ART_FOLDER .. "machines/manaBattery.png")
    end

    return block
end


function ManaBattery:fillAmount()
    -- How full it is, 0 to 1
    return self.mana / MANA_BATTERY_CAPACITY
end


function ManaBattery:beamPoint()
    -- Where network beams leave it: the top of its window
    local x, y, w = self:box()
    return x + w / 2, y + TILE_SIZE / 2
end


function ManaBattery:interact()
    uihandler:openStation(self)
end


function ManaBattery:tooltip()
    return string.format("Mana Battery\n%d / %d mana\nFeeding you: %s", math.floor(self.mana), MANA_BATTERY_CAPACITY,
        self.feedPlayer and "on" or "off (" .. INTERACT_KEY:upper() .. " to open)")
end


local function window(x, y, w, h)
    -- The glass of a battery drawn in a box
    local win = ManaBattery.WINDOW
    return x + win[1] / 32 * w, y + win[2] / 32 * h, win[3] / 32 * w, win[4] / 32 * h
end


function ManaBattery:drawArt(x, y, w, h)
    love.graphics.draw(image, x, y, 0, w / image:getWidth(), h / image:getHeight())
end


function ManaBattery:drawGlow()
    -- The mana in the window, after the light(see Map:drawGlow)
    local wx, wy, ww, wh = window(self:box())
    ManaShader.fill(wx, wy, ww, wh, self:fillAmount())
end


function ManaBattery:drawIcon(x, y, size)
    BigBlock.drawIcon(self, x, y, size)
    local wx, wy, ww, wh = window(x, y, size, size)
    ManaShader.fill(wx, wy, ww, wh, 0.6)    -- An item shows a battery with some mana in it
end


function ManaBattery:hasOwnState()
    return BigBlock.hasOwnState(self) or self.mana > 0 or self.feedPlayer
end


function ManaBattery:load(data)
    BigBlock.load(self, data)
    self.mana = data.mana or 0
    self.feedPlayer = data.feedPlayer == true
end


registerBlock("ManaBattery", ManaBattery)

return ManaBattery
