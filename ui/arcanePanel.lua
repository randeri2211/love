local Slab = require "libraries.Slab"
local Items = require "items.items"
local Tools = require "items.tools"
local ArcaneTables = require "items.arcaneTables"

-- The arcane table screen, shown where the character stats are while a table is open(see CharacterScreen)
-- The input slots are laid out in the shape of the tool, the output slot shows what they make
-- Clicks use the hand of the character screen, so parts move between the inventory and the table like any stack
local ArcanePanel = {}

-- Layout
local CELL = 46
local ICON = 32
local CANVAS_H = 300
-- Slot centers in the canvas, in slot order(see Tools.LAYOUTS): a wand lies from its cap up to its core,
-- a staff stands with its tip on top and a core on each side of it
local SLOT_SPOTS = {
    Wand = {{120, 160}, {178, 92}, {62, 228}},
    Staff = {{120, 230}, {64, 112}, {176, 112}, {120, 50}},
}
local OUTPUT_SPOT = {236, 160}
local LABELS = {rod = "Rod", largeRod = "Large rod", core = "Core", cap = "Cap", tip = "Tip"}

-- Colors
local SLOT_COLOR = {0.12, 0.11, 0.22, 1}
local SLOT_EDGE = {0.32, 0.28, 0.5, 1}
local HOVER_EDGE = {0.45, 0.9, 1, 1}
local OUTPUT_EDGE = {1, 0.83, 0.42, 1}
local SHAPE_COLOR = {0.45, 0.35, 0.75, 0.35}
local LABEL_COLOR = {1, 1, 1, 0.3}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local BAD_COLOR = {1, 0.5, 0.5, 1}


function ArcanePanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.screen = screen   -- The character screen, its held stack is the hand
    panel.hovered = nil     -- Input index or "output" under the mouse
    panel.hint = nil
    return panel
end


local function spots(station)
    return SLOT_SPOTS[station.kind]
end


function ArcanePanel:update(x, y, w, h, block)
    local station = block.arcane
    Slab.BeginWindow("ArcaneTable", {
        Title = "Arcane Table", X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        -- Wand or staff, the selected one is lit
        for i, kind in ipairs({"Wand", "Staff"}) do
            if i > 1 then
                Slab.SameLine()
            end
            local selected = station.kind == kind
            if Slab.Button(kind, {W = 90, Color = selected and HOVER_EDGE or nil}) and not selected then
                local ok, reason = ArcaneTables.setKind(station, kind)
                self.hint = reason
            end
        end

        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self.canvasX, self.canvasY = ox, oy     -- Where the slots are on screen
        self:handleMouse(station, ox, oy)
        self:draw(station, w - 20)
        Slab.Image("ArcaneSlots", {Image = self.canvas})

        if self.hint ~= nil then
            Slab.Text(self.hint, {Color = HINT_COLOR})
        else
            Slab.Text("Fill the slots, take the " .. station.kind:lower(), {Color = HINT_COLOR})
            Slab.Text("Put a tool in the output", {Color = HINT_COLOR})
            Slab.Text("to take it apart", {Color = HINT_COLOR})
        end

        -- What the finished tool would do in the main hand
        local tool = ArcaneTables.output(station)
        if tool ~= nil then
            Slab.NewLine()
            Slab.Text(Items.stackName(tool), {Color = OUTPUT_EDGE})
            for i, line in ipairs(Tools.effectLines(Tools.effect({mainHand = tool}))) do
                local color = line.good == true and GOOD_COLOR or (line.good == false and BAD_COLOR or HINT_COLOR)
                Slab.Text(line.text, {Color = color})
            end
        end
    Slab.EndWindow()
end


function ArcanePanel:slotAt(station, mx, my)
    -- Input index or "output" under a canvas point, nil for none
    local half = CELL / 2
    for i, spot in ipairs(spots(station)) do
        if math.abs(mx - spot[1]) < half and math.abs(my - spot[2]) < half then
            return i
        end
    end
    if math.abs(mx - OUTPUT_SPOT[1]) < half and math.abs(my - OUTPUT_SPOT[2]) < half then
        return "output"
    end
    return nil
end


function ArcanePanel:handleMouse(station, ox, oy)
    local mx, my = Slab.GetMousePosition()
    self.hovered = self:slotAt(station, mx - ox, my - oy)
    if self.hovered == nil or not (Slab.IsMouseClicked(1) or Slab.IsMouseClicked(2)) then
        return
    end
    local screen = self.screen
    local hint
    if self.hovered == "output" then
        screen.held, hint = ArcaneTables.clickOutput(station, screen.held)
    else
        screen.held, hint = ArcaneTables.clickInput(station, self.hovered, screen.held)
    end
    self.hint = hint
end


local function drawSlot(x, y, stack, edge, label)
    -- A slot centered on x, y with its stack, or what goes in it when empty
    love.graphics.setColor(SLOT_COLOR)
    love.graphics.rectangle("fill", x - CELL / 2 + 2, y - CELL / 2 + 2, CELL - 4, CELL - 4, 4)
    love.graphics.setColor(edge)
    love.graphics.setLineWidth(edge == SLOT_EDGE and 1 or 2)
    love.graphics.rectangle("line", x - CELL / 2 + 2, y - CELL / 2 + 2, CELL - 4, CELL - 4, 4)
    if stack then
        love.graphics.setColor(1, 1, 1, 1)
        Items.drawIcon(stack.item, x - ICON / 2, y - ICON / 2, ICON, stack)
    elseif label ~= nil then
        local font = love.graphics.getFont()
        local scale = font:getWidth(label) <= CELL - 8 and 1 or 0.5
        love.graphics.setColor(LABEL_COLOR)
        love.graphics.print(label, x - font:getWidth(label) * scale / 2, y - font:getHeight() * scale / 2, 0, scale, scale)
    end
end


function ArcanePanel:draw(station, width)
    if self.canvas == nil or self.canvas:getWidth() ~= width then
        self.canvas = love.graphics.newCanvas(width, CANVAS_H)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)

    -- The outline of the tool behind its slots
    local list = spots(station)
    love.graphics.setColor(SHAPE_COLOR)
    love.graphics.setLineWidth(10)
    if station.kind == "Wand" then
        love.graphics.line(list[3][1], list[3][2], list[2][1], list[2][2])
    else
        love.graphics.line(list[1][1], list[1][2] + 30, list[4][1], list[4][2])
        love.graphics.line(list[2][1], list[2][2], list[4][1], list[4][2], list[3][1], list[3][2])
    end
    -- Arrow to the output
    love.graphics.setLineWidth(3)
    love.graphics.line(OUTPUT_SPOT[1] - 50, OUTPUT_SPOT[2], OUTPUT_SPOT[1] - 30, OUTPUT_SPOT[2])
    love.graphics.polygon("fill", OUTPUT_SPOT[1] - 30, OUTPUT_SPOT[2] - 6, OUTPUT_SPOT[1] - 30, OUTPUT_SPOT[2] + 6, OUTPUT_SPOT[1] - 24, OUTPUT_SPOT[2])

    local layout = Tools.LAYOUTS[station.kind]
    for i, spot in ipairs(list) do
        drawSlot(spot[1], spot[2], station.inputs[i], self.hovered == i and HOVER_EDGE or SLOT_EDGE, LABELS[layout[i]])
    end
    local tool = ArcaneTables.output(station)
    drawSlot(OUTPUT_SPOT[1], OUTPUT_SPOT[2], tool, self.hovered == "output" and HOVER_EDGE or (tool and OUTPUT_EDGE or SLOT_EDGE), nil)
    love.graphics.pop()
end

return ArcanePanel
