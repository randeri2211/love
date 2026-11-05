local Slab = require "libraries.Slab"
local Items = require "items.items"
local Inventories = require "items.inventories"

-- The open chest, in the place of the character next to the inventory(see CharacterScreen)
-- Its slots work like the inventory ones(the screen does the clicks and the drawing), Shift+click sends a stack across
-- Store all and Store matching leave the hotbar and locked slots where they are
local ChestPanel = {}

local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
ChestPanel.EXTRA_H = 128        -- Window height over the grid: title, the buttons and the hint lines


function ChestPanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self
    panel.screen = screen
    panel.message = nil         -- What the last button did
    return panel
end


function ChestPanel:update(x, y, w, gridW, gridH, block)
    local screen = self.screen
    local chest, inventory = block.inventory, screen.owner.inventory
    Slab.BeginWindow("ChestWindow", {
        Title = Items.displayName(block.name), X = x, Y = y, W = w, H = gridH + ChestPanel.EXTRA_H,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        local buttonW = math.floor((w - 40) / 3)
        if Slab.Button("Store all", {W = buttonW}) then
            self:report(Inventories.storeAll(inventory, chest, false, screen:storeSkip()), "Stored")
        end
        Slab.SameLine()
        if Slab.Button("Store matching", {W = buttonW}) then
            self:report(Inventories.storeAll(inventory, chest, true, screen:storeSkip()), "Stored")
        end
        Slab.SameLine()
        if Slab.Button("Take all", {W = buttonW}) then
            self:report(Inventories.storeAll(chest, inventory, false), "Took")
        end

        local ox, oy = Slab.GetCursorPos({Absolute = true})
        screen.chestHovered = screen:handleSlots(chest, ox, oy, gridW, gridH)
        Slab.Image("ChestGrid", {Image = screen:drawSlots("chestCanvas", chest, gridW, gridH, screen.chestHovered)})

        local slot = screen.chestHovered and chest.slots[screen.chestHovered]
        if slot then
            Slab.Text(string.format("%s  x%d", Items.stackName(slot), slot.count))
        elseif self.message ~= nil then
            Slab.Text(self.message, {Color = GOOD_COLOR})
        else
            Slab.Text("Shift+click: move a stack across", {Color = HINT_COLOR})
        end
        Slab.Text("The hotbar and locked slots stay put", {Color = HINT_COLOR})
    Slab.EndWindow()
end


function ChestPanel:report(moved, verb)
    self.message = moved > 0 and string.format("%s %d stack%s", verb, moved, moved > 1 and "s" or "") or "Nothing to move"
end

return ChestPanel
