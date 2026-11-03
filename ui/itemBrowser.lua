local Slab = require "libraries.Slab"
local Items = require "items.items"
local Inventories = require "items.inventories"
local Tools = require "items.tools"
local ItemTooltip = require "ui.itemTooltip"

-- Debug: every item in the game as an icon grid with a text filter, click one to get it(DEBUG_ITEMS_KEY)
-- Click gives one, Shift+click a full stack, wands and staves come as a sample build(a tool needs its parts)
local ItemBrowser = {}

-- Layout
local COLUMNS = 9
local CELL = 46
local ICON = 32
local VIEW_ROWS = 11        -- Rows in view, the rest scroll with the mouse wheel
local TEXT_H = 120          -- Window height over the grid: title, filter, count and hint lines

-- Colors
local SLOT_COLOR = {0.12, 0.11, 0.22, 1}
local SLOT_EDGE = {0.32, 0.28, 0.5, 1}
local HOVER_EDGE = {0.45, 0.9, 1, 1}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}

-- What a tool sample is built from
local SAMPLE_PARTS = {
    Wand = {"OakRod", "WoodenCore", "WoodenCap"},
    Staff = {"LargeOakRod", "WoodenCore", "WoodenCore", "WoodenTip"},
}


function ItemBrowser:new(owner)
    local browser = {}
    setmetatable(browser, self)
    self.__index = self

    browser.owner = owner
    browser.filter = ""
    browser.scroll = 0          -- Rows scrolled down
    browser.hovered = nil       -- Stack under the mouse, for the tooltip
    browser.focusFilter = true  -- The filter box takes the keyboard when the browser opens
    return browser
end


local function stackFor(name)
    -- One of an item, tools built from sample parts
    local item = ITEM_REGISTRY[name]
    if item.tool ~= nil then
        return Tools.build(item.tool, SAMPLE_PARTS[item.tool])
    end
    return {item = name, count = 1}
end


local function itemCount()
    local count = 0
    for name in pairs(ITEM_REGISTRY) do
        count = count + 1
    end
    return count
end


function ItemBrowser:matching()
    -- Item names whose display or registry name has the filter text in it, sorted by display name
    local filter = self.filter:lower()
    local list = {}
    for name in pairs(ITEM_REGISTRY) do
        local shown = Items.displayName(name)
        if filter == "" or shown:lower():find(filter, 1, true) or name:lower():find(filter, 1, true) then
            table.insert(list, name)
        end
    end
    table.sort(list, function(a, b) return Items.displayName(a) < Items.displayName(b) end)
    return list
end


function ItemBrowser:update()
    local w, h = love.graphics.getDimensions()
    local gridW, viewH = COLUMNS * CELL, VIEW_ROWS * CELL
    local ww, wh = gridW + 20, viewH + TEXT_H
    local list = self:matching()
    local rows = math.ceil(#list / COLUMNS)
    self.scroll = math.max(0, math.min(self.scroll, rows - VIEW_ROWS))

    Slab.BeginWindow("ItemBrowser", {
        Title = "All items(debug)", X = w - ww - 20, Y = math.floor(h / 2 - wh / 2), W = ww, H = wh,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        if self.focusFilter then
            Slab.SetInputFocus("ItemFilter")
            self.focusFilter = false
        end
        if Slab.Input("ItemFilter", {Text = self.filter, ReturnOnText = true, W = gridW}) then
            self.filter = Slab.GetInputText()
            self.scroll = 0
        end
        Slab.Text(string.format("%d of %d items", #list, itemCount()), {Color = HINT_COLOR})

        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self.gridX, self.gridY, self.gridW, self.viewH = ox, oy, gridW, viewH
        self:handleMouse(list, ox, oy)
        self:draw(list, gridW, viewH)
        Slab.Image("ItemBrowserGrid", {Image = self.canvas})
        Slab.Text("Click: one   Shift+click: a stack   Wheel: scroll", {Color = HINT_COLOR})
    Slab.EndWindow()
end


function ItemBrowser:handleMouse(list, ox, oy)
    local mx, my = Slab.GetMousePosition()
    self.hovered = nil
    if mx < ox or my < oy or mx >= ox + COLUMNS * CELL or my >= oy + VIEW_ROWS * CELL then
        return
    end
    local index = (math.floor((my - oy) / CELL) + self.scroll) * COLUMNS + math.floor((mx - ox) / CELL) + 1
    local name = list[index]
    if name == nil then
        return
    end
    self.hovered = stackFor(name)
    if Slab.IsMouseClicked(1) and self.hovered ~= nil then
        local stack = Items.copy(self.hovered)
        if love.keyboard.isDown("lshift", "rshift") and stack.data == nil then
            stack.count = Items.maxStack(name)
        end
        -- What doesnt fit drops at the player
        local left = Inventories.addStack(self.owner.inventory, stack)
        if left > 0 then
            local x, y = self.owner.body:getWorldCenter()
            map.drops:spawn(stack.item, left, x, y, false, nil, stack.data)
        end
    end
end


function ItemBrowser:draw(list, gridW, viewH)
    if self.canvas == nil then
        self.canvas = love.graphics.newCanvas(gridW, viewH)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    for row = 0, VIEW_ROWS - 1 do
        for column = 0, COLUMNS - 1 do
            local name = list[(row + self.scroll) * COLUMNS + column + 1]
            if name ~= nil then
                local x, y = column * CELL, row * CELL
                local stack = stackFor(name)
                local hovered = self.hovered ~= nil and self.hovered.item == name
                love.graphics.setColor(SLOT_COLOR)
                love.graphics.rectangle("fill", x + 2, y + 2, CELL - 4, CELL - 4, 4)
                love.graphics.setColor(hovered and HOVER_EDGE or SLOT_EDGE)
                love.graphics.setLineWidth(hovered and 2 or 1)
                love.graphics.rectangle("line", x + 2, y + 2, CELL - 4, CELL - 4, 4)
                love.graphics.setColor(1, 1, 1, 1)
                Items.drawIcon(name, x + (CELL - ICON) / 2, y + (CELL - ICON) / 2, ICON, stack)
            end
        end
    end
    -- A scroll bar when not everything fits
    local rows = math.ceil(#list / COLUMNS)
    if rows > VIEW_ROWS then
        local barH = viewH * VIEW_ROWS / rows
        love.graphics.setColor(SLOT_EDGE)
        love.graphics.rectangle("fill", gridW - 3, (viewH - barH) * self.scroll / (rows - VIEW_ROWS), 3, barH)
    end
    love.graphics.pop()
end


function ItemBrowser:wheel(dy)
    -- Scrolls a row a step while the mouse is over the grid
    local mx, my = Slab.GetMousePosition()
    if self.gridX == nil or mx < self.gridX or mx >= self.gridX + self.gridW or my < self.gridY or my >= self.gridY + self.viewH then
        return false
    end
    self.scroll = self.scroll - dy
    return true
end


function ItemBrowser:drawTooltip()
    if self.hovered ~= nil then
        local mx, my = love.mouse.getPosition()
        ItemTooltip.draw(self.hovered, mx, my)
    end
end

return ItemBrowser
