local Slab = require "libraries.Slab"
local Humanoid = require "animations.humanoid"
local Items = require "items.items"
local Inventories = require "items.inventories"
local Equipments = require "items.equipments"
local CraftingPanel = require "ui.craftingPanel"
local ArcanePanel = require "ui.arcanePanel"
local ChestPanel = require "ui.chestPanel"
local BatteryPanel = require "ui.batteryPanel"
local Crafting = require "items.crafting"
local ArcaneTables = require "items.arcaneTables"
local ItemTooltip = require "ui.itemTooltip"
local Levels = require "components.stats.levels"
local Sets = require "items.sets"

-- Character screen: the character with its stats on the left, the inventory grid on the right with crafting under it
-- A block with slots(an arcane table, a chest) opened with the interact key takes the place of the stats while it is in reach
-- Items move with a stack held in the hand: left click picks up, places, merges or swaps a whole stack,
-- right click picks up half a stack or places one item, clicking outside the window throws the held stack
-- Shift+click sends a stack between the inventory and an open chest, Ctrl+click locks an inventory slot
-- (locked slots and the hotbar stay put when storing to chests)
local CharacterScreen = {}

-- Layout
local COLUMNS = 10
local CELL = 46             -- Pixels per inventory slot
local ICON = 32
local STATS_W = 300
local PREVIEW_H = 146
local PREVIEW_SCALE = 2.2   -- The character preview drawn bigger than in the world
local MARGIN = 16
local STATS_H = 972         -- Tall enough for the preview, the two rows of equipment slots and every stat line
local INVENTORY_EXTRA_H = 112   -- Inventory window height over the grid: title, the hint lines and Quick stack

-- The equipment slots under the character: the armor and the hands on the first row, trinkets and the focus under them
-- Every slot keeps where it is drawn(col and row, from 0)
local EQUIP_SLOTS = {}
local EQUIP_COLUMNS = #ARMOR_SLOTS + #HAND_SLOTS
for i, slot in ipairs(ARMOR_SLOTS) do
    table.insert(EQUIP_SLOTS, {name = slot.name, label = slot.label, col = i - 1, row = 0})
end
for i, slot in ipairs(HAND_SLOTS) do
    table.insert(EQUIP_SLOTS, {name = slot.name, label = slot.label, col = #ARMOR_SLOTS + i - 1, row = 0})
end
for i, slot in ipairs(ACCESSORY_SLOTS) do
    table.insert(EQUIP_SLOTS, {name = slot.name, label = slot.label, col = i - 1, row = 1})
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
local LOCK_COLOR = {1, 0.82, 0.4, 1}               -- The lock on a locked slot
local GOOD_COLOR = {0.6, 1, 0.6, 1}


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
    screen.chest = ChestPanel:new(screen)
    screen.battery = BatteryPanel:new(screen)
    screen.chestHovered = nil       -- Slot index under the mouse in an open chest
    screen.message = nil            -- What Quick stack did
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

    -- The open block closes when it is gone or out of reach
    if self.block ~= nil and not self:blockInReach() then
        self.block = nil
    end
    local chest = self.block ~= nil and self.block.inventory ~= nil
    self.chestHovered = nil
    -- An open chest is as wide as its grid, the stats and the arcane table are narrower
    local leftW = chest and gridW + 20 or STATS_W
    local totalW = leftW + gridW + 40 + MARGIN
    local x = math.floor(w / 2 - totalW / 2)
    -- A little above the middle, so the bottom stays clear of the hotbar
    local y = math.max(MARGIN, math.floor(h / 2 - STATS_H / 2) - 40)

    if chest then
        self.hoveredEquip = nil     -- The equipment row is hidden behind the chest
        local chestRows = math.ceil(self.block.inventory.size / COLUMNS)
        self.chest:update(x, y, leftW, gridW, chestRows * CELL, self.block)
    elseif self.block ~= nil and self.block.mana ~= nil then
        self.hoveredEquip = nil     -- The equipment row is hidden behind the battery
        self.battery:update(x, y, STATS_W, STATS_H, self.block)
    elseif self.block ~= nil then
        self.hoveredEquip = nil     -- The equipment row is hidden behind the table
        self.arcane:update(x, y, STATS_W, STATS_H, self.block)
    else
        self:characterWindow(x, y)
    end
    local inventoryX, inventoryH = x + leftW + MARGIN, gridH + INVENTORY_EXTRA_H
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
        -- Level and experience, then the stats with what the armor adds and a + for every unspent point
        if owner.level ~= nil then
            Slab.Text(string.format("Level %d  -  %d / %d XP", owner.level, math.floor(owner.xp), Levels.xpToNext(owner.level)))
            Slab.NewLine()
        end
        local points = owner.statPoints or 0
        Slab.Text("Stats", {Color = HEADER_COLOR})
        if points > 0 then
            Slab.SameLine()
            Slab.Text(string.format("  %d point%s to spend", points, points > 1 and "s" or ""), {Color = LEVEL_COLOR})
        end
        local stats = owner.stats
        local bonus = owner.combatStats and owner.combatStats.statBonus or {}
        for i, stat in ipairs(Levels.STATS) do
            local name = stat:sub(1, 1):upper() .. stat:sub(2)
            local extra = bonus[stat] or 0
            if points > 0 then
                -- Every + has its own id, Slab tells buttons apart by their label
                Slab.PushID(stat)
                if Slab.Button("+", {W = 22, H = 18}) then
                    Levels.spend(owner, stat)
                end
                Slab.PopID()
                Slab.SameLine()
            end
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
            -- Set bonuses turned on by the armor worn
            for i, bonus in ipairs(Sets.active(owner.equipment)) do
                Slab.Textf(string.format("%s set %d: %s", bonus.set.title, bonus.pieces, table.concat(bonus.effect.text, ", ")),
                    {Color = BONUS_COLOR, W = STATS_W - 20})
            end
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
    local col, row = math.floor((mx - ox) / CELL), math.floor((my - oy) / CELL)
    local slot = nil
    for i, s in ipairs(EQUIP_SLOTS) do
        if s.col == col and s.row == row and mx >= ox and my >= oy then
            slot = s
        end
    end
    if slot == nil then
        return
    end
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
    local w = EQUIP_COLUMNS * CELL
    if self.equipCanvas == nil then
        self.equipCanvas = love.graphics.newCanvas(w, CELL * 2)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.equipCanvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    local font = love.graphics.getFont()
    for i, slot in ipairs(EQUIP_SLOTS) do
        local x, y = slot.col * CELL, slot.row * CELL
        local hovered = slot.name == self.hoveredEquip
        love.graphics.setColor(SLOT_COLOR)
        love.graphics.rectangle("fill", x + 2, y + 2, CELL - 4, CELL - 4, 4)
        love.graphics.setColor(hovered and HOVER_EDGE or SLOT_EDGE)
        love.graphics.setLineWidth(hovered and 2 or 1)
        love.graphics.rectangle("line", x + 2, y + 2, CELL - 4, CELL - 4, 4)
        local worn = self.owner.equipment[slot.name]
        if worn then
            drawStack(worn, x, y)
        else
            -- Empty slots say what goes in them
            love.graphics.setColor(EMPTY_LABEL_COLOR)
            local label = slot.label
            -- Half size when it doesnt fit, the pixel font stays sharp at whole and half sizes
            local scale = font:getWidth(label) <= CELL - 8 and 1 or 0.5
            love.graphics.print(label, x + CELL / 2 - font:getWidth(label) * scale / 2, y + CELL / 2 - font:getHeight() * scale / 2, 0, scale, scale)
        end
    end
    love.graphics.pop()
end


-- Inventory
function CharacterScreen:inventoryWindow(x, y, gridW, gridH)
    Slab.BeginWindow("CharacterInventory", windowOptions("Inventory", x, y, gridW + 20, gridH + INVENTORY_EXTRA_H))
        local inventory = self.owner.inventory
        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self.gridX, self.gridY = ox, oy     -- Where the grid is on screen
        self.hovered = self:handleSlots(inventory, ox, oy, gridW, gridH)
        Slab.Image("InventoryGrid", {Image = self:drawSlots("gridCanvas", inventory, gridW, gridH, self.hovered, true)})

        -- Name of what is under the mouse, or how to use the grid
        local slot = self.hovered and inventory.slots[self.hovered]
        if slot then
            Slab.Text(string.format("%s  x%d", Items.stackName(slot), slot.count))
            Slab.Text(inventory.locked[self.hovered] and "Locked, Ctrl+click to unlock" or "Ctrl+click: lock the slot", {Color = HINT_COLOR})
        elseif self.held ~= nil then
            Slab.Text("Click outside to throw it", {Color = HINT_COLOR})
            Slab.Text("")
        else
            Slab.Text("Left click: take or place a stack", {Color = HINT_COLOR})
            Slab.Text("Right click: take half or place one", {Color = HINT_COLOR})
        end

        -- Every unlocked item outside the hotbar goes to a chest in reach that already has that item
        if Slab.Button("Quick stack to nearby chests", {W = gridW}) then
            self:quickStack()
        end
        if self.message ~= nil then
            Slab.SameLine()
            Slab.Text(self.message, {Color = GOOD_COLOR})
        end
    Slab.EndWindow()
end


function CharacterScreen:storeSkip()
    -- The slots storing to a chest leaves alone: the hotbar and the locked ones
    local locked = self.owner.inventory.locked
    return function(index)
        return index <= HOTBAR_SIZE or locked[index] == true
    end
end


function CharacterScreen:quickStack()
    -- Store matching into every chest within reach, nearest first
    local moved, chests = 0, Crafting.nearbyChests(self.owner)
    for i, chest in ipairs(chests) do
        moved = moved + Inventories.storeAll(self.owner.inventory, chest.inventory, true, self:storeSkip())
    end
    if #chests == 0 then
        self.message = "No chest in reach"
    else
        self.message = moved > 0 and string.format("Stored %d stack%s", moved, moved > 1 and "s" or "") or "Nothing matches"
    end
end


function CharacterScreen:handleSlots(inventory, ox, oy, gridW, gridH)
    -- Slot of an inventory grid(the player one or a chest) under the mouse and what a click on it does, returns its index
    local mx, my = Slab.GetMousePosition()
    if mx < ox or my < oy or mx >= ox + gridW or my >= oy + gridH then
        return nil
    end
    local index = math.floor((my - oy) / CELL) * COLUMNS + math.floor((mx - ox) / CELL) + 1
    if index > inventory.size then
        return nil
    end
    if Slab.IsMouseClicked(1) then
        local chest = self.block ~= nil and self.block.inventory or nil
        if love.keyboard.isDown("lctrl", "rctrl") and inventory == self.owner.inventory then
            -- Locks or unlocks the slot
            inventory.locked[index] = not inventory.locked[index] or nil
        elseif love.keyboard.isDown("lshift", "rshift") and chest ~= nil and self.held == nil then
            -- Sends the stack across, to the chest from the inventory or back
            Inventories.moveSlot(inventory, index, inventory == chest and self.owner.inventory or chest)
        else
            self:leftClick(inventory, index)
        end
    elseif Slab.IsMouseClicked(2) then
        self:rightClick(inventory, index)
    end
    return index
end


function CharacterScreen:leftClick(inventory, index)
    -- Pick up, place, merge or swap a whole stack
    self.equipHint = nil
    local slots = inventory.slots
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


function CharacterScreen:rightClick(inventory, index)
    -- Empty hand picks up half the stack, a full hand places one item
    self.equipHint = nil
    local slots = inventory.slots
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


local function drawLock(x, y)
    -- A small padlock in the top left corner of a slot
    love.graphics.setColor(LOCK_COLOR)
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", x + 10, y + 10, 3, math.pi, 2 * math.pi, 8)
    love.graphics.rectangle("fill", x + 6, y + 10, 8, 6, 1)
end


function CharacterScreen:drawSlots(key, inventory, gridW, gridH, hovered, isPlayer)
    -- Draws an inventory grid onto the canvas kept as self[key] and returns it
    -- The player one has the hotbar row(its selected slot outlined in gold) and the locks
    if self[key] == nil or self[key]:getWidth() ~= gridW or self[key]:getHeight() ~= gridH then
        self[key] = love.graphics.newCanvas(gridW, gridH)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self[key])
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    for i, slot in ipairs(inventory.slots) do
        local x = ((i - 1) % COLUMNS) * CELL
        local y = math.floor((i - 1) / COLUMNS) * CELL
        local selected = isPlayer and i == self.owner.hotbarSlot
        love.graphics.setColor(isPlayer and i <= HOTBAR_SIZE and HOTBAR_SLOT_COLOR or SLOT_COLOR)
        love.graphics.rectangle("fill", x + 2, y + 2, CELL - 4, CELL - 4, 4)
        love.graphics.setColor(i == hovered and HOVER_EDGE or (selected and SELECTED_EDGE or SLOT_EDGE))
        love.graphics.setLineWidth((i == hovered or selected) and 2 or 1)
        love.graphics.rectangle("line", x + 2, y + 2, CELL - 4, CELL - 4, 4)
        if slot then
            drawStack(slot, x, y)
        end
        if isPlayer and inventory.locked[i] then
            drawLock(x, y)
        end
    end
    love.graphics.pop()
    return self[key]
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
    if self.chestHovered ~= nil then
        return self.block.inventory.slots[self.chestHovered] or nil
    end
    if self.block ~= nil and self.block.arcane ~= nil then
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
