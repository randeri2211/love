local Slab = require "libraries.Slab"
local Items = require "items.items"
local Crafting = require "items.crafting"

-- Crafting list in the character screen: recipes made by hand and at the stations within interaction distance,
-- by tier and by category within the tier. Click a recipe to make it once, Shift+click to make as many as you can
local CraftingPanel = {}

-- Layout
local ROW_H = 46
local TIER_H = 30
local CATEGORY_H = 24
local ICON = 32
local PAD = 6
local SCROLL_STEP = 40      -- Pixels per mouse wheel step
local TEXT_LINES_H = 104    -- Window height taken by the title, the checkbox, the station line and the hint line

-- Colors
local ROW_COLOR = {0.12, 0.11, 0.22, 1}
local ROW_HOVER = {0.2, 0.17, 0.36, 1}
local ROW_EDGE = {0.32, 0.28, 0.5, 1}
local HOVER_EDGE = {0.45, 0.9, 1, 1}
local TIER_COLOR = {1, 0.83, 0.42, 1}
local CATEGORY_COLOR = {0.6, 0.62, 0.7, 1}
local NAME_COLOR = {0.9, 0.88, 1, 1}
local DIM_COLOR = {0.5, 0.48, 0.62, 1}
local HAVE_COLOR = {0.6, 0.62, 0.7, 1}
local MISSING_COLOR = {1, 0.45, 0.45, 1}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}


function CraftingPanel:new(owner)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.owner = owner
    panel.hovered = nil     -- Recipe under the mouse
    panel.message = nil     -- What the last craft made, shown under the list
    panel.scroll = 0        -- Pixels the list is scrolled down, it scrolls itself so its rows and the mouse always agree
    panel.craftableOnly = false     -- Only list recipes there is enough for
    return panel
end


local function inputName(input)
    -- A group shows as its name("Wood"), an item as its display name
    return input.group or Items.displayName(input.item)
end


function CraftingPanel:layout()
    -- Rows of the list from the top of the canvas: {y, h, kind, text or recipe}, and the full height
    local rows, y = {}, 0
    local stations = Crafting.nearbyStations(self.owner)
    self.stations = stations
    self.sources = Crafting.sources(self.owner)     -- Nearby chests and the inventory, what the recipes count from
    local recipes = Crafting.available(stations)
    if self.craftableOnly then
        local craftable = {}
        for i, recipe in ipairs(recipes) do
            if Crafting.maxTimes(self.sources, recipe) > 0 then
                table.insert(craftable, recipe)
            end
        end
        recipes = craftable
    end
    for i, tier in ipairs(Crafting.grouped(recipes)) do
        table.insert(rows, {y = y, h = TIER_H, kind = "tier", text = tier.name})
        y = y + TIER_H
        for j, category in ipairs(tier.categories) do
            table.insert(rows, {y = y, h = CATEGORY_H, kind = "category", text = category.name})
            y = y + CATEGORY_H
            for k, recipe in ipairs(category.recipes) do
                table.insert(rows, {y = y, h = ROW_H, kind = "recipe", recipe = recipe})
                y = y + ROW_H
            end
        end
    end
    return rows, math.max(y, 1)
end


function CraftingPanel:update(x, y, w, h, holding)
    -- The Slab window, called every frame while the character screen is open
    -- holding is true while a stack is in the hand(clicks place it, they dont craft)
    Slab.BeginWindow("CharacterCrafting", {
        Title = "Crafting", X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        local listW = w - 20
        local viewH = h - TEXT_LINES_H
        local rows, listH = self:layout()
        self.scroll = math.max(0, math.min(self.scroll, listH - viewH))

        if Slab.CheckBox(self.craftableOnly, "Craftable only") then
            self.craftableOnly = not self.craftableOnly
            self.scroll = 0
        end

        -- Which stations are in reach
        local names = {}
        for name in pairs(self.stations) do
            table.insert(names, Items.displayName(name))
        end
        table.sort(names)
        if #names > 0 then
            Slab.Text("Near: " .. table.concat(names, ", "), {Color = HINT_COLOR})
        else
            Slab.Text("No station nearby, by hand only", {Color = HINT_COLOR})
        end

        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self.listX, self.listY, self.rows = ox, oy, rows     -- Where the list is on screen
        self.listW, self.viewH = listW, viewH
        self:handleMouse(rows, ox, oy, listW, viewH, holding)
        self:draw(rows, listW, viewH, listH)
        Slab.Image("CraftingList", {Image = self.canvas})

        if self.message ~= nil then
            Slab.Text(self.message, {Color = HAVE_COLOR})
        else
            Slab.Text("Click to craft, Shift+click for as many as you can", {Color = HINT_COLOR})
        end
    Slab.EndWindow()
end


function CraftingPanel:wheel(dy)
    -- Mouse wheel over the list scrolls it, true when it did
    local mx, my = Slab.GetMousePosition()
    if self.listX == nil or mx < self.listX or mx >= self.listX + self.listW or my < self.listY or my >= self.listY + self.viewH then
        return false
    end
    self.scroll = self.scroll - dy * SCROLL_STEP
    return true
end


function CraftingPanel:handleMouse(rows, ox, oy, listW, viewH, holding)
    -- Recipe row under the mouse(only the part of the list in view), a click crafts it
    local mx, my = Slab.GetMousePosition()
    self.hovered = nil
    if holding or mx < ox or mx >= ox + listW or my < oy or my >= oy + viewH then
        return
    end
    local listY = my - oy + self.scroll
    for i, row in ipairs(rows) do
        if row.kind == "recipe" and listY >= row.y and listY < row.y + row.h then
            self.hovered = row.recipe
        end
    end
    if self.hovered ~= nil and Slab.IsMouseClicked(1) then
        local recipe = self.hovered
        local times = 1
        if love.keyboard.isDown("lshift", "rshift") then
            -- As many as you can, up to a full stack of what it makes
            times = math.max(1, math.floor(Items.maxStack(recipe.output) / recipe.count))
        end
        local made = Crafting.craft(self.owner, recipe, times)
        if made > 0 then
            self.message = string.format("Made %d %s", made * recipe.count, Items.displayName(recipe.output))
        end
    end
end


function CraftingPanel:draw(rows, listW, viewH, listH)
    -- The part of the list in view, with a scroll bar when it doesnt all fit
    if self.canvas == nil or self.canvas:getWidth() ~= listW or self.canvas:getHeight() ~= viewH then
        self.canvas = love.graphics.newCanvas(listW, viewH)
    end
    local inventory = self.sources or {self.owner.inventory}
    local font = love.graphics.getFont()
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    if listH > viewH then
        local barH = viewH * viewH / listH
        love.graphics.setColor(ROW_EDGE)
        love.graphics.rectangle("fill", listW - 3, (viewH - barH) * self.scroll / (listH - viewH), 3, barH)
        listW = listW - 6
    end
    if #rows == 0 then
        love.graphics.setColor(HINT_COLOR)
        love.graphics.printf(self.craftableOnly and "Nothing you can make yet" or "Nothing to make here",
            0, viewH / 2 - font:getHeight() / 2, listW, "center")
    end
    love.graphics.translate(0, -self.scroll)
    for i, row in ipairs(rows) do
        if row.y + row.h < self.scroll or row.y > self.scroll + viewH then
            -- Out of view
        elseif row.kind == "tier" then
            love.graphics.setColor(TIER_COLOR)
            love.graphics.print(row.text, PAD, row.y + (row.h - font:getHeight()) / 2)
            love.graphics.setColor(TIER_COLOR[1], TIER_COLOR[2], TIER_COLOR[3], 0.35)
            love.graphics.rectangle("fill", PAD, row.y + row.h - 3, listW - PAD * 2, 1)
        elseif row.kind == "category" then
            love.graphics.setColor(CATEGORY_COLOR)
            love.graphics.print(row.text, PAD * 2, row.y + (row.h - font:getHeight()) / 2)
        else
            self:drawRecipe(row.recipe, row.y, listW, inventory, font)
        end
    end
    love.graphics.pop()
end


function CraftingPanel:drawRecipe(recipe, y, listW, inventory, font)
    -- Icon, name with how many it makes, then every input with how many you have(red when short)
    local hovered = recipe == self.hovered
    local craftable = Crafting.maxTimes(inventory, recipe) > 0
    love.graphics.setColor(hovered and ROW_HOVER or ROW_COLOR)
    love.graphics.rectangle("fill", 2, y + 2, listW - 4, ROW_H - 4, 4)
    love.graphics.setColor(hovered and craftable and HOVER_EDGE or ROW_EDGE)
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", 2, y + 2, listW - 4, ROW_H - 4, 4)

    love.graphics.setColor(1, 1, 1, craftable and 1 or 0.45)
    Items.drawIcon(recipe.output, PAD + 2, y + (ROW_H - ICON) / 2, ICON)

    local tx = PAD + ICON + 10
    local name = Items.displayName(recipe.output)
    if recipe.count > 1 then
        name = name .. " x" .. recipe.count
    end
    love.graphics.setColor(craftable and NAME_COLOR or DIM_COLOR)
    love.graphics.print(name, tx, y + 4)

    -- Inputs on the second line: "4 Oak Wood (12)", red when there arent enough
    local ix = tx
    for i, input in ipairs(recipe.inputs) do
        local have = Crafting.have(inventory, input)
        local text = string.format("%d %s (%d)", input.count, inputName(input), have)
        if i < #recipe.inputs then
            text = text .. ","
        end
        love.graphics.setColor(have >= input.count and HAVE_COLOR or MISSING_COLOR)
        love.graphics.print(text, ix, y + ROW_H - font:getHeight() - 4)
        ix = ix + font:getWidth(text .. " ")
    end
end

return CraftingPanel
