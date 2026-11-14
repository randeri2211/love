local Slab = require "libraries.Slab"
local Inventories = require "items.inventories"
local SlotWidget = require "ui.slotWidget"
local Scrolls = require "items.scrolls"

-- The Scribe's Desk screen, shown where the character stats are while a desk is open(see CharacterScreen)
-- Blank Scrolls go in its slot, every spell of the player has a Bind button that turns one into a Bound Scroll
-- holding a copy of that spell, put in the inventory(or dropped at the desk when it is full)
local ScribePanel = {}

local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local BAD_COLOR = {1, 0.5, 0.5, 1}


function ScribePanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.screen = screen
    panel.hint = nil
    return panel
end


local function acceptsBlank(stack)
    if stack.item ~= "BlankScroll" then
        return false, "Only Blank Scrolls go here"
    end
    return true
end


function ScribePanel:bind(desk, entry)
    -- One Blank Scroll from the slot becomes a Bound Scroll of the spell
    local stack = Scrolls.bind(entry.name, entry.spell)
    desk.slot.count = desk.slot.count - 1
    if desk.slot.count <= 0 then
        desk.slot = false
    end
    if Inventories.addStack(self.screen.owner.inventory, stack) > 0 then
        map.drops:spawn(stack.item, 1, desk.x + desk.width / 2, desk.y, true, nil, stack.data)
    end
    self.hint = {text = "Bound " .. entry.name, color = GOOD_COLOR}
end


function ScribePanel:update(x, y, w, h, desk)
    Slab.BeginWindow("ScribesDesk", {
        Title = "Scribe's Desk", X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        Slab.Text("Blank Scrolls:")
        local reason
        desk.slot, reason = SlotWidget.update("ScribeSlot", desk.slot, self.screen, acceptsBlank, "Blank")
        if reason ~= nil then
            self.hint = {text = reason, color = BAD_COLOR}
        end
        Slab.NewLine()
        Slab.Text("Bind a spell into a scroll:")
        local book = self.screen.owner.spellbook
        for i, entry in ipairs(book.spells) do
            Slab.PushID("Bind" .. entry.id)
            local params = entry.spell:getParams()
            if Slab.Button("Bind", {W = 50, Disabled = not desk.slot}) and desk.slot then
                self:bind(desk, entry)
            end
            Slab.SameLine()
            Slab.Text(string.format("%s  (%s, %.1f mana)", entry.name, entry.spell.core, params.manaCost))
            Slab.PopID()
        end
        Slab.NewLine()
        if self.hint ~= nil then
            Slab.Text(self.hint.text, {Color = self.hint.color})
        elseif not desk.slot then
            Slab.Text("Put Blank Scrolls in the slot", {Color = HINT_COLOR})
        end
        Slab.Text("A scroll keeps the spell as it is now,", {Color = HINT_COLOR})
        Slab.Text("editing the spell later doesnt change it", {Color = HINT_COLOR})
    Slab.EndWindow()
end

return ScribePanel
