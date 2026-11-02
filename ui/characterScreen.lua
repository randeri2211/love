local Slab = require "libraries.Slab"
local Humanoid = require "animations.humanoid"
local Items = require "items.items"
local Inventories = require "items.inventories"
local Equipments = require "items.equipments"

-- Character screen: the character with its stats on the left, the inventory grid on the right
-- Items move with a stack held in the hand: left click picks up, places, merges or swaps a whole stack,
-- right click picks up half a stack or places one item, clicking outside the window throws the held stack
local CharacterScreen = {}

-- Layout
local COLUMNS = 10
local CELL = 46             -- Pixels per inventory slot
local ICON = 32
local STATS_W = 300
local PREVIEW_H = 170
local PREVIEW_SCALE = 2.2   -- The character preview drawn bigger than in the world
local MARGIN = 16
local STATS_H = 760         -- Tall enough for the preview, the armor slots and every stat line

-- Colors
local SLOT_COLOR = {0.12, 0.13, 0.18, 1}
local SLOT_EDGE = {0.32, 0.33, 0.42, 1}
local HOVER_EDGE = {0.85, 0.85, 1, 1}
local STAGE_COLOR = {0.07, 0.08, 0.12, 1}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local HEADER_COLOR = {0.85, 0.75, 1, 1}
local HOTBAR_SLOT_COLOR = {0.16, 0.17, 0.25, 1}    -- The first row is the hotbar
local SELECTED_EDGE = {1, 0.85, 0.4, 1}            -- The selected hotbar slot
local BONUS_COLOR = {0.6, 1, 0.6, 1}               -- Stats added by armor
local EMPTY_LABEL_COLOR = {1, 1, 1, 0.25}


function CharacterScreen:new(owner)
    local screen = {}
    setmetatable(screen, self)
    self.__index = self

    screen.owner = owner            -- The player whose stats and inventory it shows
    screen.held = nil               -- Stack in the hand, {item, count}
    screen.hovered = nil            -- Slot index under the mouse
    -- Its own copy of the body for the preview, standing still and facing right
    screen.preview = Humanoid.build(owner.width, owner.height, PLAYER_SKIN)
    Humanoid.face(screen.preview, "right")
    return screen
end


local drawStack     -- Defined with the grid drawing below


local function windowOptions(title, x, y, w, h)
    return {
        Title = title,
        X = x, Y = y, W = w, H = h,
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        ShowMinimize = false,
        NoSavedSettings = true,
    }
end


function CharacterScreen:update()
    -- Slab windows, called every frame while the screen is open
    local w, h = love.graphics.getDimensions()
    local rows = math.ceil(self.owner.inventory.size / COLUMNS)
    local gridW, gridH = COLUMNS * CELL, rows * CELL
    local totalW = STATS_W + gridW + 40 + MARGIN
    local x = math.floor(w / 2 - totalW / 2)
    local y = math.floor(h / 2 - STATS_H / 2)

    self:characterWindow(x, y)
    self:inventoryWindow(x + STATS_W + MARGIN, y, gridW, gridH)

    -- A click on no window throws the held stack into the world
    if self.held ~= nil and Slab.IsVoidClicked(1) then
        self:throwHeld()
    end
end


-- Character
function CharacterScreen:characterWindow(x, y)
    local owner = self.owner
    Slab.BeginWindow("CharacterStats", windowOptions("Character", x, y, STATS_W, STATS_H))
        -- The character, drawn into its own canvas
        local cw = STATS_W - 20
        if self.previewCanvas == nil then
            self.previewCanvas = love.graphics.newCanvas(cw, PREVIEW_H)
        end
        love.graphics.push("all")
        love.graphics.setCanvas(self.previewCanvas)
        love.graphics.origin()
        love.graphics.clear(STAGE_COLOR)
        love.graphics.translate(cw / 2, PREVIEW_H / 2)
        love.graphics.scale(PREVIEW_SCALE)
        Humanoid.place(self.preview, 0, 0, owner.height)
        self.preview.actor:Update(0)
        self.preview.actor:Draw()
        love.graphics.pop()
        Slab.Image("CharacterPreview", {Image = self.previewCanvas})

        -- Armor slots under the character
        local ex, ey = Slab.GetCursorPos({Absolute = true})
        self.equipX, self.equipY = ex, ey     -- Where the armor slots are on screen
        self:handleEquipmentMouse(ex, ey)
        self:drawEquipment()
        Slab.Image("CharacterEquipment", {Image = self.equipCanvas})
        if self.equipHint ~= nil then
            Slab.Text(self.equipHint, {Color = HINT_COLOR})
        elseif self.hoveredArmor ~= nil and owner.equipment[self.hoveredArmor] then
            local stack = owner.equipment[self.hoveredArmor]
            local armor = ITEM_REGISTRY[stack.item].armor
            Slab.Text(string.format("%s  defense %d", Items.displayName(stack.item), armor.defense))
        else
            Slab.Text("Armor", {Color = HINT_COLOR})
        end

        Slab.Text(owner.name or "Player", {Color = HEADER_COLOR})
        Slab.Text(string.format("HP  %d / %d", math.floor(owner.hpBar.currentHP + 0.5), math.floor(owner.hpBar.maxHP + 0.5)))
        Slab.Text(string.format("Mana  %d / %d", math.floor(owner.manaBar.currentMana + 0.5), math.floor(owner.manaBar.maxMana + 0.5)))
        Slab.NewLine()

        -- Stats with what the armor adds
        Slab.Text("Stats", {Color = HEADER_COLOR})
        local stats = owner.stats
        local bonus = owner.combatStats and owner.combatStats.statBonus or {}
        for i, stat in ipairs({"strength", "intelligence", "wisdom", "concentration", "swiftness", "constitution"}) do
            local name = stat:sub(1, 1):upper() .. stat:sub(2)
            local extra = bonus[stat] or 0
            if extra ~= 0 then
                Slab.Text(string.format("%s  %d", name, stats[stat] + extra))
                Slab.SameLine()
                Slab.Text(string.format("(%+d)", extra), {Color = BONUS_COLOR})
            else
                Slab.Text(string.format("%s  %d", name, stats[stat]))
            end
        end
        Slab.NewLine()

        -- What they add up to
        Slab.Text("Combat", {Color = HEADER_COLOR})
        local combat = owner.combatStats
        if combat ~= nil then
            Slab.Text(string.format("Magic damage  %d%%", math.floor(combat.magicDamage * 100 + 0.5)))
            Slab.Text(string.format("Cooldown reduction  %d%%", math.floor(combat.cooldownReduction * 100 + 0.5)))
            Slab.Text(string.format("Max complexity  %d", combat.maxComplexity))
            Slab.Text(string.format("Defense  %d", combat.defense))
            Slab.Text(string.format("Blocks  %d%% of damage", math.floor(combat.damageReduction * 100 + 0.5)))
        end
        Slab.Text(string.format("HP regen  %.1f/s", owner.hpBar.regen))
        Slab.Text(string.format("Mana regen  %.1f/s", owner.manaBar.manaRegen))
        local jumpTiles = owner.movement.jumpHeight ^ 2 / (2 * GRAVITY * JUMP_GRAVITY_SCALE * owner:gravityScale()) / TILE_SIZE
        Slab.Text(string.format("Speed  %.1f tiles/s", owner.movement.maxSpeed / TILE_SIZE))
        Slab.Text(string.format("Jump  %.1f tiles", jumpTiles))
    Slab.EndWindow()
end


-- Equipment
function CharacterScreen:handleEquipmentMouse(ox, oy)
    -- Armor slot under the mouse, a click swaps it with the held stack when the held item is armor for that slot
    local mx, my = Slab.GetMousePosition()
    self.hoveredArmor = nil
    if my < oy or my >= oy + CELL or mx < ox or mx >= ox + #ARMOR_SLOTS * CELL then
        return
    end
    local slot = ARMOR_SLOTS[math.floor((mx - ox) / CELL) + 1]
    self.hoveredArmor = slot.name
    if Slab.IsMouseClicked(1) or Slab.IsMouseClicked(2) then
        self:equipClick(slot)
    end
end


function CharacterScreen:equipClick(slot)
    local equipment = self.owner.equipment
    local worn, held = equipment[slot.name], self.held
    self.equipHint = nil
    if held == nil then
        if worn then
            self.held, equipment[slot.name] = worn, false
            self.owner.statsDirty = true
        end
    elseif Equipments.fits(slot.name, held) then
        -- Armor is one piece, a held stack of it can only be one
        equipment[slot.name], self.held = held, worn or nil
        self.owner.statsDirty = true
    else
        self.equipHint = "Only " .. slot.label:lower() .. " armor goes there"
    end
end


function CharacterScreen:drawEquipment()
    local w = #ARMOR_SLOTS * CELL
    if self.equipCanvas == nil then
        self.equipCanvas = love.graphics.newCanvas(w, CELL)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.equipCanvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    local font = love.graphics.getFont()
    for i, slot in ipairs(ARMOR_SLOTS) do
        local x = (i - 1) * CELL
        local hovered = slot.name == self.hoveredArmor
        love.graphics.setColor(SLOT_COLOR)
        love.graphics.rectangle("fill", x + 2, 2, CELL - 4, CELL - 4, 4)
        love.graphics.setColor(hovered and HOVER_EDGE or SLOT_EDGE)
        love.graphics.setLineWidth(hovered and 2 or 1)
        love.graphics.rectangle("line", x + 2, 2, CELL - 4, CELL - 4, 4)
        local worn = self.owner.equipment[slot.name]
        if worn then
            drawStack(worn, x, 0)
        else
            -- Empty slots say what goes in them
            love.graphics.setColor(EMPTY_LABEL_COLOR)
            local label = slot.label
            -- Half size when it doesnt fit, the pixel font stays sharp at whole and half sizes
            local scale = font:getWidth(label) <= CELL - 8 and 1 or 0.5
            love.graphics.print(label, x + CELL / 2 - font:getWidth(label) * scale / 2, CELL / 2 - font:getHeight() * scale / 2, 0, scale, scale)
        end
    end
    love.graphics.pop()
end


-- Inventory
function CharacterScreen:inventoryWindow(x, y, gridW, gridH)
    Slab.BeginWindow("CharacterInventory", windowOptions("Inventory", x, y, gridW + 20, gridH + 78))
        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self.gridX, self.gridY = ox, oy     -- Where the grid is on screen
        self:handleGridMouse(ox, oy, gridW, gridH)
        self:drawGrid(gridW, gridH)
        Slab.Image("InventoryGrid", {Image = self.gridCanvas})

        -- Name of what is under the mouse, or how to use the grid
        local slot = self.hovered and self.owner.inventory.slots[self.hovered]
        if slot then
            Slab.Text(string.format("%s  x%d", Items.displayName(slot.item), slot.count))
        elseif self.held ~= nil then
            Slab.Text("Click outside to throw it", {Color = HINT_COLOR})
        else
            Slab.Text("Left click: take or place a stack", {Color = HINT_COLOR})
            Slab.Text("Right click: take half or place one", {Color = HINT_COLOR})
        end
    Slab.EndWindow()
end


function CharacterScreen:handleGridMouse(ox, oy, gridW, gridH)
    -- Slot under the mouse, and what a click on it does
    local mx, my = Slab.GetMousePosition()
    self.hovered = nil
    if mx < ox or my < oy or mx >= ox + gridW or my >= oy + gridH then
        return
    end
    local index = math.floor((my - oy) / CELL) * COLUMNS + math.floor((mx - ox) / CELL) + 1
    if index > self.owner.inventory.size then
        return
    end
    self.hovered = index
    if Slab.IsMouseClicked(1) then
        self:leftClick(index)
    elseif Slab.IsMouseClicked(2) then
        self:rightClick(index)
    end
end


function CharacterScreen:leftClick(index)
    -- Pick up, place, merge or swap a whole stack
    self.equipHint = nil
    local slots = self.owner.inventory.slots
    local slot, held = slots[index], self.held
    if held == nil then
        if slot then
            self.held, slots[index] = slot, false
        end
    elseif not slot then
        slots[index], self.held = held, nil
    elseif slot.item == held.item then
        local moved = math.min(held.count, Items.maxStack(slot.item) - slot.count)
        slot.count = slot.count + moved
        held.count = held.count - moved
        if held.count <= 0 then
            self.held = nil
        end
    else
        slots[index], self.held = held, slot
    end
end


function CharacterScreen:rightClick(index)
    -- Empty hand picks up half the stack, a full hand places one item
    self.equipHint = nil
    local slots = self.owner.inventory.slots
    local slot, held = slots[index], self.held
    if held == nil then
        if slot then
            local half = math.ceil(slot.count / 2)
            self.held = {item = slot.item, count = half}
            slot.count = slot.count - half
            if slot.count <= 0 then
                slots[index] = false
            end
        end
    elseif not slot then
        slots[index] = {item = held.item, count = 1}
        held.count = held.count - 1
    elseif slot.item == held.item and slot.count < Items.maxStack(slot.item) then
        slot.count = slot.count + 1
        held.count = held.count - 1
    end
    if self.held ~= nil and self.held.count <= 0 then
        self.held = nil
    end
end


function drawStack(stack, x, y)
    -- An item icon centered in a slot sized square at x, y with its count in the corner
    local pad = (CELL - ICON) / 2
    love.graphics.setColor(1, 1, 1, 1)
    Items.drawIcon(stack.item, x + pad, y + pad, ICON)
    if stack.count > 1 then
        local text = tostring(stack.count)
        local font = love.graphics.getFont()
        local tx, ty = x + CELL - font:getWidth(text) - 4, y + CELL - font:getHeight() - 2
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(text, tx + 1, ty + 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, tx, ty)
    end
end


function CharacterScreen:drawGrid(gridW, gridH)
    if self.gridCanvas == nil or self.gridCanvas:getHeight() ~= gridH then
        self.gridCanvas = love.graphics.newCanvas(gridW, gridH)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.gridCanvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    for i, slot in ipairs(self.owner.inventory.slots) do
        local x = ((i - 1) % COLUMNS) * CELL
        local y = math.floor((i - 1) / COLUMNS) * CELL
        -- The first row is the hotbar, its selected slot outlined in gold
        local selected = i == self.owner.hotbarSlot
        love.graphics.setColor(i <= HOTBAR_SIZE and HOTBAR_SLOT_COLOR or SLOT_COLOR)
        love.graphics.rectangle("fill", x + 2, y + 2, CELL - 4, CELL - 4, 4)
        love.graphics.setColor(i == self.hovered and HOVER_EDGE or (selected and SELECTED_EDGE or SLOT_EDGE))
        love.graphics.setLineWidth((i == self.hovered or selected) and 2 or 1)
        love.graphics.rectangle("line", x + 2, y + 2, CELL - 4, CELL - 4, 4)
        if slot then
            drawStack(slot, x, y)
        end
    end
    love.graphics.pop()
end


function CharacterScreen:drawHeld()
    -- The stack in the hand follows the mouse, drawn over every window
    if self.held == nil then
        return
    end
    local mx, my = love.mouse.getPosition()
    love.graphics.push("all")
    love.graphics.origin()
    drawStack(self.held, mx - CELL / 2, my - CELL / 2)
    love.graphics.pop()
end


-- Closing
function CharacterScreen:throwHeld()
    -- The held stack lands in front of the player
    local x, y = self.owner.body:getWorldCenter()
    local mx = love.mouse.getX()
    local side = mx >= love.graphics.getWidth() / 2 and 1 or -1
    map.drops:spawn(self.held.item, self.held.count, x + side * TILE_SIZE, y - TILE_SIZE / 2, true, ITEM_THROW_DELAY)
    self.held = nil
end


function CharacterScreen:close()
    -- Whatever is still in the hand goes back to the inventory, or to the ground when it doesnt fit
    if self.held ~= nil then
        self.held.count = Inventories.add(self.owner.inventory, self.held.item, self.held.count)
        if self.held.count > 0 then
            self:throwHeld()
        end
        self.held = nil
    end
end

return CharacterScreen
