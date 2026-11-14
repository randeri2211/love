local Slab = require "libraries.Slab"
local Items = require "items.items"

-- One item slot inside a Slab window, worked with the stack held in the character screen's hand(see CharacterScreen):
-- a click with nothing held takes the slot's stack, with a held stack the slot takes it if accepts says so(merging
-- the same item, swapping another). Used by stations with a single slot(the Scribe's Desk, a Spell Turret)
local SlotWidget = {}

local CELL = 46
local ICON = 32
local SLOT_COLOR = {0.12, 0.11, 0.22, 1}
local SLOT_EDGE = {0.32, 0.28, 0.5, 1}
local HOVER_EDGE = {0.45, 0.9, 1, 1}
local LABEL_COLOR = {1, 1, 1, 0.3}

local canvases = {}     -- A canvas a slot id


local function draw(id, stack, hovered, label)
    canvases[id] = canvases[id] or love.graphics.newCanvas(CELL, CELL)
    love.graphics.push("all")
    love.graphics.setCanvas(canvases[id])
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(SLOT_COLOR)
    love.graphics.rectangle("fill", 2, 2, CELL - 4, CELL - 4, 4)
    love.graphics.setColor(hovered and HOVER_EDGE or SLOT_EDGE)
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", 2, 2, CELL - 4, CELL - 4, 4)
    if stack then
        love.graphics.setColor(1, 1, 1, 1)
        Items.drawIcon(stack.item, (CELL - ICON) / 2, (CELL - ICON) / 2, ICON, stack)
        if stack.count > 1 then
            love.graphics.print(tostring(stack.count), CELL - 16, CELL - 18, 0, 0.5, 0.5)
        end
    elseif label ~= nil then
        local font = love.graphics.getFont()
        love.graphics.setColor(LABEL_COLOR)
        love.graphics.print(label, (CELL - font:getWidth(label) * 0.5) / 2, (CELL - font:getHeight() * 0.5) / 2, 0, 0.5, 0.5)
    end
    love.graphics.pop()
end


function SlotWidget.update(id, stack, screen, accepts, label)
    -- Draws the slot and handles a click on it, returns the slot's stack after the click(false when empty)
    -- and the reason the held stack didnt go in(nil when it did, or nothing was tried)
    local x, y = Slab.GetCursorPos({Absolute = true})
    local mx, my = Slab.GetMousePosition()
    local hovered = mx >= x and mx < x + CELL and my >= y and my < y + CELL
    draw(id, stack, hovered, label)
    Slab.Image(id, {Image = canvases[id]})
    if not hovered or not Slab.IsMouseClicked(1) then
        return stack, nil
    end
    local held = screen.held
    if held == nil then
        screen.held = stack or nil
        return false, nil
    end
    local ok, reason = accepts(held)
    if not ok then
        return stack, reason
    end
    if stack and stack.item == held.item and held.data == nil and stack.data == nil then
        -- The same item tops the slot up, what doesnt fit stays in the hand
        local room = Items.maxStack(stack.item) - stack.count
        local moved = math.min(room, held.count)
        stack.count = stack.count + moved
        held.count = held.count - moved
        screen.held = held.count > 0 and held or nil
        return stack, nil
    end
    screen.held = stack or nil
    return held, nil
end

return SlotWidget
