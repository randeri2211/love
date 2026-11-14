local Slab = require "libraries.Slab"
local Items = require "items.items"
local SlotWidget = require "ui.slotWidget"
local Processing = require "items.processing"

-- A processing station's screen(the Forge), shown where the character stats are while it is open(see CharacterScreen)
-- Its input, fuel and output slots, how far along the current item is, what powers it, and what it can process
local ProcessPanel = {}

local BAR_W, BAR_H = 200, 12
local BAR_BACK = {0.12, 0.11, 0.22, 1}
local BAR_FILL = {1, 0.65, 0.3, 1}
local BAR_POWERED = {0.45, 0.85, 1, 1}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local BAD_COLOR = {1, 0.5, 0.5, 1}


function ProcessPanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.screen = screen
    panel.hint = nil
    return panel
end


function ProcessPanel:drawBar(station)
    -- The progress of the item it works on
    if self.bar == nil then
        self.bar = love.graphics.newCanvas(BAR_W, BAR_H)
    end
    local process = station.input and Processing.forInput(station.name, station.input.item)
    local part = process and math.min(1, station.progress / process.time) or 0
    love.graphics.push("all")
    love.graphics.setCanvas(self.bar)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(BAR_BACK)
    love.graphics.rectangle("fill", 0, 0, BAR_W, BAR_H, 3)
    love.graphics.setColor(station.powered and BAR_POWERED or BAR_FILL)
    love.graphics.rectangle("fill", 0, 0, BAR_W * part, BAR_H, 3)
    love.graphics.pop()
end


function ProcessPanel:update(x, y, w, h, station)
    self:drawBar(station)
    Slab.BeginWindow("ProcessStation", {
        Title = station.info.name, X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        local reason
        Slab.Text("Input")
        station.input, reason = SlotWidget.update("ProcessInput", station.input, self.screen, function(stack)
            if Processing.forInput(station.name, stack.item) == nil then
                return false, "It does nothing with " .. Items.displayName(stack.item)
            end
            return true
        end, "In")
        self.hint = reason or self.hint
        Slab.Text("Fuel")
        station.fuel, reason = SlotWidget.update("ProcessFuel", station.fuel, self.screen, function(stack)
            if Processing.fuel(stack.item) == nil then
                return false, "Only wood burns"
            end
            return true
        end, "Wood")
        self.hint = reason or self.hint
        Slab.Text("Output")
        station.output, reason = SlotWidget.update("ProcessOutput", station.output, self.screen, function()
            return false, "Take from here, nothing goes in"
        end, "Out")
        self.hint = reason or self.hint

        Slab.NewLine()
        Slab.Image("ProcessBar", {Image = self.bar})
        Slab.Text(station.state, {Color = station.state:match("^Working") and GOOD_COLOR or HINT_COLOR})
        if station.powered then
            Slab.Text(string.format("Powered: %.1f mana/s, %dx faster", STATION_MANA, STATION_POWERED_SPEED), {Color = BAR_POWERED})
            Slab.Text("Takes from and fills chests next to it", {Color = HINT_COLOR})
        elseif station.burn > 0 then
            Slab.Text(string.format("Fuel burning: %d s", math.ceil(station.burn)), {Color = BAR_FILL})
        end
        if self.hint ~= nil then
            Slab.Text(self.hint, {Color = BAD_COLOR})
        end

        Slab.NewLine()
        Slab.Text("It makes:")
        local processes = Processing.ofStation(station.name)
        local makers = {}       -- How many processes make each item
        for i, process in ipairs(processes) do
            makers[process.output.item] = (makers[process.output.item] or 0) + 1
        end
        for i, process in ipairs(processes) do
            -- Short enough for the panel: what it makes, then from how many of what("ore" for Copper Ore, the whole
            -- name when two processes make the same thing, like gold from deep gold ore) and how long
            local from = Items.displayName(process.input.item):lower()
            if makers[process.output.item] == 1 then
                from = from:match("(%S+)$")
            end
            Slab.Text(string.format("%s  (%d %s, %d s%s)", Items.displayName(process.output.item), process.input.count, from,
                process.time, process.needsMana and ", mana" or ""), {Color = HINT_COLOR})
        end
    Slab.EndWindow()
end

return ProcessPanel
