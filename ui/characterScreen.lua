local Slab = require "libraries.Slab"
local Humanoid = require "animations.humanoid"
local Items = require "items.items"
local Inventories = require "items.inventories"
local Equipments = require "items.equipments"
local CraftingPanel = require "ui.craftingPanel"
local ArcanePanel = require "ui.arcanePanel"
local ArcaneTables = require "items.arcaneTables"
local ItemTooltip = require "ui.itemTooltip"

-- Character screen: the character with its stats on the left, the inventory grid on the right with crafting under it
-- A block with slots(an arcane table) opened with the interact key takes the place of the stats while it is in reach
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
local STATS_H = 962         -- Tall enough for the preview, the equipment slots and every stat line
local INVENTORY_EXTRA_H = 78    -- Inventory window height over the grid: title and the hint lines

-- The row of equipment slots under the character: the armor, then the hands
local EQUIP_SLOTS = {}
for i, slot in ipairs(ARMOR_SLOTS) do
    table.insert(EQUIP_SLOTS, slot)
end
for i, slot in ipairs(HAND_SLOTS) do
    table.insert(EQUIP_SLOTS, slot)
end

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


function CharacterScreen:new(owner, block)
    local screen = {}
    setmetatable(screen, self)
    self.__index = self

    screen.owner = owner            -- The player whose stats and inventory it shows
    screen.held = nil               -- Stack in the hand, {item, count}
    screen.hovered = nil            -- Slot index under the mouse
    screen.crafting = CraftingPanel:new(owner)
    screen.block = block            -- Open block with slots, nil when only the character shows
    screen.arcane = ArcanePanel:new(screen)
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
    -- A little above the middle, so the bottom stays clear of the hotbar
    local y = math.max(MARGIN, math.floor(h / 2 - STATS_H / 2) - 40)

    -- The open block closes when it is gone or out of reach
    if self.block ~= nil and not self:blockInReach() then
        self.block = nil
    end
    if self.block ~= nil then
        self.hoveredEquip = nil     -- The equipment row is hidden behind the table
        self.arcane:update(x, y, STATS_W, STATS_H, self.block)
    else
        self:characterWindow(x, y)
    end
    local inventoryX, inventoryH = x + STATS_W + MARGIN, gridH + INVENTORY_EXTRA_H
    self:inventoryWindow(inventoryX, y, gridW, gridH)
    -- Crafting fills the rest of the height under the inventory
    self.crafting:update(inventoryX, y + inventoryH + MARGIN, gridW + 20, STATS_H - inventoryH - MARGIN, self.held ~= nil)

    -- A click on no window throws the held stack into the world
    if self.held ~= nil and Slab.IsVoidClicked(1) then
        self:throwHeld()
    end
end


function CharacterScreen:blockInReach()
    -- True while the open block is still in the map and within interaction distance(a little more, so it doesnt flicker)
    local block = self.block
    if map:get(block.mx, block.my) ~= block then
        return false
    end
    local px, py = self.owner:mapCenter()
    return distance(px, py + 1, block.mx, block.my) <= INTERACT_DISTANCE + 1
end


function CharacterScreen:wheel(dy)
    -- Mouse wheel while the screen is open, the crafting list scrolls under it
    return self.crafting:wheel(dy)
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

        -- Armor and hand slots under the character
        local ex, ey = Slab.GetCursorPos({Absolute = true})
        self.equipX, self.equipY = ex, ey     -- Where the equipment slots are on screen
        self:handleEquipmentMouse(ex, ey)
        self:drawEquipment()
        Slab.Image("CharacterEquipment", {Image = self.equipCanvas})
        if self.equipHint ~= nil then
            Slab.Text(self.equipHint, {Color = HINT_COLOR})
        elseif self.hoveredEquip ~= nil and owner.equipment[self.hoveredEquip] then
            local stack = owner.equipment[self.hoveredEquip]
            local armor = ITEM_REGISTRY[stack.item].armor
            if armor ~= nil then
                Slab.Text(string.format("%s  defense %d", Items.stackName(stack), armor.defense))
            else
                Slab.Text(Items.stackName(stack))
            end
        else
            Slab.Text("Armor and hands", {Color = HINT_COLOR})
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
            -- Spell values as one change each, the same multipliers spells use(see Spell.multipliers)
            local function change(multiplier)
                return string.format("%+d%%", math.floor((multiplier - 1) * 100 + 0.5))
            end
            Slab.Text("Spell damage  " .. change(combat.spellDamage))
            Slab.Text("Spell cooldown  " .. change(combat.spellCooldown))
            Slab.Text("Mana cost  " .. change(combat.spellManaCost))
            Slab.Text(string.format("Max complexity  %d", combat.maxComplexity))
            Slab.Text("Cast speed  " .. change(combat.castSpeed))
            Slab.Text(string.format("Defense  %d", math.floor(combat.defense + 0.5)))
            Slab.Text(string.format("Blocks  %d%% of damage", math.floor(combat.damageReduction * 100 + 0.5)))
            Slab.Text(string.format("Crit  %d%% for %d%%", math.floor(combat.critChance * 100 + 0.5), math.floor(combat.critMultiplier * 100 + 0.5)))
            -- Resistances as the part of each element they block
            local function resist(element)
                return string.format("%s %d%%", element, math.floor(combat.resistReduction[element] * 100 + 0.5))
            end
            Slab.Text("Resist  " .. resist("Fire") .. "  " .. resist("Frost"))
            Slab.Text("        " .. resist("Poison") .. "  " .. resist("Lightning"))
            Slab.Text(string.format("Dig cap  %d", combat.digCap))
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
    -- Equipment slot under the mouse, a click swaps it with the held stack when the held item goes in that slot
    local mx, my = Slab.GetMousePosition()
    self.hoveredEquip = nil
    if my < oy or my >= oy + CELL or mx < ox or mx >= ox + #EQUIP_SLOTS * CELL then
        return
    end
    local slot = EQUIP_SLOTS[math.floor((mx - ox) / CELL) + 1]
    self.hoveredEquip = slot.name
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
    else
        local fits, reason = Equipments.fits(slot.name, held, equipment)
        if fits then
            -- Armor and tools are one piece, a held stack of them can only be one
            equipment[slot.name], self.held = held, worn or nil
            self.owner.statsDirty = true
        else
            self.equipHint = reason or ("Only " .. slot.label:lower() .. " armor goes there")
        end
    end
end


function CharacterScreen:drawEquipment()
    local w = #EQUIP_SLOTS * CELL
    if self.equipCanvas == nil then
        self.equipCanvas = love.graphics.newCanvas(w, CELL)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.equipCanvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    local font = love.graphics.getFont()
    for i, slot in ipairs(EQUIP_SLOTS) do
        local x = (i - 1) * CELL
        local hovered = slot.name == self.hoveredEquip
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
    Slab.BeginWindow("CharacterInventory", windowOptions("Inventory", x, y, gridW + 20, gridH + INVENTORY_EXTRA_H))
        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self.gridX, self.gridY = ox, oy     -- Where the grid is on screen
        self:handleGridMouse(ox, oy, gridW, gridH)
        self:drawGrid(gridW, gridH)
        Slab.Image("InventoryGrid", {Image = self.gridCanvas})

        -- Name of what is under the mouse, or how to use the grid
        local slot = self.hovered and self.owner.inventory.slots[self.hovered]
        if slot then
            Slab.Text(string.format("%s  x%d", Items.stackName(slot), slot.count))
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
    elseif slot.item == held.item and not slot.data and not held.data then
        -- Items with data(wands) never merge, they swap like different items
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
            self.held = Items.copy(slot, half)
            slot.count = slot.count - half
            if slot.count <= 0 then
                slots[index] = false
            end
        end
    elseif not slot then
        slots[index] = Items.copy(held, 1)
        held.count = held.count - 1
    elseif slot.item == held.item and not slot.data and slot.count < Items.maxStack(slot.item) then
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
    Items.drawIcon(stack.item, x + pad, y + pad, ICON, stack)
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


function CharacterScreen:hoveredStack()
    -- The stack under the mouse in any part of the screen, nil for none
    -- (crafting rows show what they make)
    if self.block ~= nil then
        local spot = self.arcane.hovered
        if spot == "output" then
            return ArcaneTables.output(self.block.arcane)
        elseif spot ~= nil then
            return self.block.arcane.inputs[spot] or nil
        end
    elseif self.hoveredEquip ~= nil then
        return self.owner.equipment[self.hoveredEquip] or nil
    end
    if self.hovered ~= nil then
        return self.owner.inventory.slots[self.hovered] or nil
    end
    local recipe = self.crafting.hovered
    if recipe ~= nil then
        return {item = recipe.output, count = recipe.count}
    end
    return nil
end


function CharacterScreen:drawTooltip()
    -- What the hovered item is and does, not while a stack is in the hand
    if self.held ~= nil then
        return
    end
    local stack = self:hoveredStack()
    if stack ~= nil then
        local mx, my = love.mouse.getPosition()
        ItemTooltip.draw(stack, mx, my)
    end
end


-- Closing
function CharacterScreen:throwHeld()
    -- The held stack lands in front of the player
    local x, y = self.owner.body:getWorldCenter()
    local mx = love.mouse.getX()
    local side = mx >= love.graphics.getWidth() / 2 and 1 or -1
    map.drops:spawn(self.held.item, self.held.count, x + side * TILE_SIZE, y - TILE_SIZE / 2, true, ITEM_THROW_DELAY, self.held.data)
    self.held = nil
end


function CharacterScreen:close()
    -- Whatever is still in the hand goes back to the inventory, or to the ground when it doesnt fit
    if self.held ~= nil then
        self.held.count = Inventories.addStack(self.owner.inventory, self.held)
        if self.held.count > 0 then
            self:throwHeld()
        end
        self.held = nil
    end
end

return CharacterScreen
