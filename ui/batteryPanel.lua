local Slab = require "libraries.Slab"
local ManaShader = require "world_utils.manaShader"
local ManaNetwork = require "world_utils.manaNetwork"

-- The mana battery screen, shown where the character stats are while a battery is open(see CharacterScreen)
-- A tank of the mana effect shows how full it is, under it the batteries in reach and the Feed the player setting
local BatteryPanel = {}

-- Layout
local TANK_W, TANK_H = 120, 200

-- Colors
local TANK_BACK = {0.05, 0.06, 0.13, 1}
local TANK_EDGE = {0.32, 0.28, 0.5, 1}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local MANA_TEXT = {0.55, 0.9, 1, 1}


function BatteryPanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.screen = screen
    return panel
end


function BatteryPanel:drawTank(battery)
    -- The tank canvas: the battery's mana filling it
    if self.canvas == nil then
        self.canvas = love.graphics.newCanvas(TANK_W, TANK_H)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(TANK_BACK)
    love.graphics.rectangle("fill", 0, 0, TANK_W, TANK_H, 6)
    love.graphics.setColor(1, 1, 1, 1)
    ManaShader.fill(4, 4, TANK_W - 8, TANK_H - 8, battery:fillAmount())
    love.graphics.setColor(TANK_EDGE)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 1.5, 1.5, TANK_W - 3, TANK_H - 3, 6)
    love.graphics.pop()
end


function BatteryPanel:update(x, y, w, h, battery)
    self:drawTank(battery)
    Slab.BeginWindow("ManaBattery", {
        Title = "Mana Battery", X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        Slab.Text(string.format("%d / %d  (%d%%)", math.floor(battery.mana), MANA_BATTERY_CAPACITY,
            math.floor(battery:fillAmount() * 100)), {Color = MANA_TEXT})
        Slab.Image("BatteryTank", {Image = self.canvas})

        -- Batteries in reach of the player are one buffer
        local count, total = 0, 0
        for i, b in ipairs(ManaNetwork.inReach()) do
            count = count + 1
            total = total + b.mana
        end
        Slab.NewLine()
        Slab.Text(string.format("In reach: %d %s", count, count == 1 and "battery" or "batteries"))
        Slab.Text(string.format("%d / %d", math.floor(total), count * MANA_BATTERY_CAPACITY), {Color = MANA_TEXT})

        Slab.NewLine()
        if Slab.CheckBox(battery.feedPlayer, "Feed the player") then
            battery.feedPlayer = not battery.feedPlayer
        end
        Slab.Text("Your spells use its mana first", {Color = HINT_COLOR})
        Slab.Text("while you are in its reach", {Color = HINT_COLOR})
        Slab.NewLine()
        Slab.Text("With full mana, your regen", {Color = HINT_COLOR})
        Slab.Text(string.format("fills batteries %d tiles away", MANA_NETWORK_REACH), {Color = HINT_COLOR})
    Slab.EndWindow()
end

return BatteryPanel
