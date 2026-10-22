local Slab = require "libraries.Slab"
local Spell = require "magic.spell"
local MagicCircle = require "magic.magicCircle"
local Spellbooks = require "magic.spellbooks"
local Strokes = require "magic.strokes"

local SpellEditor = {}

-- Window sizes
local SPELLS_W = 240
local DRAW_W = 260
local CANVAS_W = 640
local INFO_W = 300
local EDITOR_H = 640
local GAP = 10

-- Colors(circle colors live in MagicCircle)
local HOVER_COLOR = {1, 1, 0.3, 1}
local INSPECT_COLOR = {0.8, 0.85, 1, 0.6}     -- Ring around the circle the stats panel shows
local HINT_COLOR = {0.6, 0.6, 0.6, 1}
local STAGE_COLOR = {0.07, 0.08, 0.12, 1}

local TARGET_COLOR = {0.4, 0.9, 1, 1}         -- Ring around the slot the drawing pad draws into
local MARK_STROKE_COLOR = {0.55, 0.75, 1, 1}  -- Strokes in the mark ring
local ERROR_COLOR = {1, 0.4, 0.4, 1}

local EDITOR_DRAW_IN_TIME = 1.2    -- Seconds for the circle to draw itself when the editor opens

-- Drawing pad, in pad units the rune zone is a circle of radius 1(see magic/strokes)
local PAD_SIZE = 240                -- Pixels
local PAD_RUNE_RADIUS = 72          -- Pixels for one pad unit, the dotted divider sits here
local PAD_EDGE_RADIUS = 116         -- Pixels, outer edge of the mark ring
local PAD_POINT_SPACING = 2         -- Pixels the mouse has to move before a new point is added to a stroke

-- Rune reference under the pad
local REF_COLUMNS = 4
local REF_CELL = 54                 -- Pixels per icon cell
local REF_ICON_RADIUS = 20
local GUIDE_ALPHA = 0.22            -- How faint the traced rune shows on the pad

-- Runes the pad can recognize, by where they go(the center takes forms, ring slots the rest)
local candidates = {}


local function windowOptions(title, x, y, w, h)
    -- Fixed editor windows that cant be moved or resized
    return {
        Title = title,
        X = x,
        Y = y,
        W = w,
        H = h,
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        NoSavedSettings = true,
    }
end


function SpellEditor:new(book)
    -- Edits the spells of a spellbook component, the selected spell is the one being edited
    local editor = {}
    setmetatable(editor, self)
    self.__index = self

    editor.book = book
    editor.targets = {}             -- Clickable parts of the circle, rebuilt every frame
    editor.circleTargets = {}       -- Every circle(main and children) as a click area, rebuilt every frame
    editor.bindingKey = false       -- True while waiting for a key to bind to the spell
    editor.closed = false
    editor.circleCanvas = nil       -- Created on first draw with the window size
    editor:openSpell(Spellbooks.selectedEntry(book))

    return editor
end


function SpellEditor:openSpell(entry)
    -- Edits this spellbook entry, it also becomes the spell the shoot key casts
    self.entry = entry
    self.spell = entry.spell        -- Root spell being edited
    self.inspected = entry.spell    -- Circle the stats panel shows, picked by clicking inside a circle
    self.bindingKey = false
    self.openTime = love.timer.getTime()    -- The circle draws itself in from this moment
    Spellbooks.select(self.book, entry.id)
    self:fillSlots(entry.spell)
    self.target = nil               -- Slot the drawing pad draws into, {spell, slot, depth}, picked by clicking a slot
    self.guide = nil                -- Rune shown faintly on the pad to trace over, picked in the reference
    self:clearDrawing()
end


function SpellEditor:clearDrawing()
    self.strokes = {}               -- Finished strokes on the pad, lists of {x, y} in pad units
    self.currentStroke = nil        -- Stroke being drawn while the mouse is held
    self.result = nil               -- What the strokes were recognized as(see recognizeDrawing)
end


function SpellEditor:handleKey(key)
    -- Keys the editor uses while open, true when the key was used
    if self.bindingKey then
        if key:match("^%d$") then
            Spellbooks.bind(self.book, key, self.entry.id)
            self.bindingKey = false
        end
        return true     -- Other keys are ignored while binding
    end
    return false
end


function SpellEditor:fillSlots(spell)
    -- Empty slots are false so ipairs doesnt stop at them, children are filled too
    for i = 1, SPELL_SLOTS do
        if spell.slots[i] == nil then
            spell.slots[i] = false
        elseif type(spell.slots[i]) == "table" and spell.slots[i][2] then
            self:fillSlots(spell.slots[i][2])
        end
    end
end


function SpellEditor:update()
    -- Draws all 4 editor windows centered on the screen
    local w, h = love.graphics.getDimensions()
    local x = w / 2 - (SPELLS_W + DRAW_W + CANVAS_W + INFO_W + GAP * 3) / 2
    local y = h / 2 - EDITOR_H / 2

    self:spellList(x, y)
    x = x + SPELLS_W + GAP
    self:drawPad(x, y)
    self:canvas(x + DRAW_W + GAP, y)
    self:info(x + DRAW_W + CANVAS_W + GAP * 2, y)
end


-- Spell List Window
function SpellEditor:spellList(x, y)
    -- Every spell in the spellbook with its key, and buttons to manage them
    Slab.BeginWindow("SpellList", windowOptions("Spells", x, y, SPELLS_W, EDITOR_H))
        for i, entry in ipairs(self.book.spells) do
            local key = Spellbooks.keyFor(self.book, entry.id)
            local label = "[" .. (key or " ") .. "]  " .. entry.name
            Slab.Text(label, {IsSelectable = true, IsSelected = entry == self.entry})
            if Slab.IsControlClicked() and entry ~= self.entry then
                self:openSpell(entry)
            end
        end
        Slab.NewLine()
        Slab.Separator()

        -- Name of the open spell(Id per spell so switching spells shows the right name)
        Slab.Text("Name")
        if Slab.Input("SpellName" .. self.entry.id, {Text = self.entry.name, ReturnOnText = true, W = SPELLS_W - 20}) then
            self.entry.name = Slab.GetInputText()
        end
        Slab.NewLine()

        -- Three buttons in a row fit the list window
        local buttonW = (SPELLS_W - 30) / 3
        if Slab.Button("New", {W = buttonW}) then
            self:openSpell(Spellbooks.add(self.book, "Spell " .. self.book.nextId, Spell:new("Bullet", {})))
        end
        Slab.SameLine()
        if Slab.Button("Copy", {W = buttonW}) then
            self:openSpell(Spellbooks.duplicate(self.book, self.entry.id))
        end
        Slab.SameLine()
        -- The last spell cant be deleted
        if Slab.Button("Delete", {W = buttonW, Disabled = #self.book.spells <= 1}) then
            if Spellbooks.remove(self.book, self.entry.id) then
                self:openSpell(Spellbooks.selectedEntry(self.book))
            end
        end

        Slab.NewLine()
        if self.bindingKey then
            Slab.Text("Press 0-9 to bind", {Color = HOVER_COLOR})
            Slab.Text("Esc to cancel", {Color = HINT_COLOR})
        elseif Slab.Button("Bind key") then
            self.bindingKey = true
        end
    Slab.EndWindow()
end


-- Drawing Pad Window
function SpellEditor:drawPad(x, y)
    -- Draw a rune in the middle and its marks around it, then inscribe it into the picked slot
    Slab.BeginWindow("SpellDraw", windowOptions("Draw a rune", x, y, DRAW_W, EDITOR_H))
        -- The picked slot can disappear(its trigger cleared), then there is nothing to draw into
        if self.target ~= nil and self:circlePath(self.spell, self.target.spell, "") == nil then
            self.target = nil
        end
        Slab.Text(self:targetLabel(), {Color = self.target and TARGET_COLOR or HINT_COLOR})

        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self:handlePadMouse(ox + PAD_SIZE / 2, oy + PAD_SIZE / 2)
        self:drawPadCanvas()
        Slab.Image("SpellDrawPad", {Image = self.padCanvas})

        -- What the drawing is recognized as
        local result = self.result
        if result ~= nil then
            if result.name ~= nil then
                Slab.Text(string.format("%s   %.0f%%", result.name, result.quality * 100), {Color = RUNE_REGISTRY[result.name].color})
            else
                Slab.Text("Not recognized", {Color = ERROR_COLOR})
            end
            if result.reading ~= nil then
                local rune = RUNE_REGISTRY[result.name]
                Slab.Text(rune.describeMarks and rune:describeMarks(result.reading) or "Marks read")
            elseif #result.marks > 0 then
                Slab.Text(#result.marks .. " marks, " .. (result.name or "this rune") .. " doesnt use them", {Color = HINT_COLOR})
            end
            if result.problem ~= nil then
                Slab.Text(result.problem, {Color = ERROR_COLOR})
            end
        else
            Slab.Text("Rune inside the dotted line,", {Color = HINT_COLOR})
            Slab.Text("marks around it", {Color = HINT_COLOR})
        end
        Slab.NewLine()

        local buttonW = (DRAW_W - 30) / 3
        local canInscribe = self.target ~= nil and result ~= nil and result.name ~= nil and result.problem == nil
        if Slab.Button("Inscribe", {W = buttonW, Disabled = not canInscribe}) then
            self:place(self.target, result.name, {quality = result.quality, marks = result.reading, strokes = self.strokes})
            self:clearDrawing()
        end
        Slab.SameLine()
        if Slab.Button("Undo", {W = buttonW, Disabled = #self.strokes == 0}) then
            table.remove(self.strokes)
            self:recognizeDrawing()
        end
        Slab.SameLine()
        if Slab.Button("Clear", {W = buttonW, Disabled = #self.strokes == 0}) then
            self:clearDrawing()
        end

        Slab.NewLine()
        Slab.Separator()
        self:runeReference()
    Slab.EndWindow()
end


function SpellEditor:runeReference()
    -- Icons of the runes that fit the picked slot, hover for details, click one to trace it on the pad
    local runes = {}
    local target = self.target or {slot = 1}
    for i, candidate in ipairs(self:candidatesFor(target)) do
        table.insert(runes, RUNE_REGISTRY[candidate.name])
    end
    -- A guide from the other kind of slot doesnt help here
    if self.guide ~= nil and self:placeKindMismatch(target, self.guide) then
        self.guide = nil
    end

    local rows = math.ceil(#runes / REF_COLUMNS)
    local w, h = REF_COLUMNS * REF_CELL, rows * REF_CELL
    if self.refCanvas == nil or self.refCanvas:getHeight() ~= h then
        self.refCanvas = love.graphics.newCanvas(w, h)
    end

    -- Icon under the mouse
    local ox, oy = Slab.GetCursorPos({Absolute = true})
    local mx, my = Slab.GetMousePosition()
    local hovered = nil
    local column, row = math.floor((mx - ox) / REF_CELL), math.floor((my - oy) / REF_CELL)
    if mx >= ox and my >= oy and column < REF_COLUMNS and row < rows then
        hovered = runes[row * REF_COLUMNS + column + 1]
    end
    if hovered ~= nil and Slab.IsMouseClicked(1) then
        if self.guide == hovered.name then
            self.guide = nil
        else
            self.guide = hovered.name
        end
    end

    love.graphics.push("all")
    love.graphics.setCanvas(self.refCanvas)
    love.graphics.origin()
    love.graphics.clear(STAGE_COLOR)
    for i, rune in ipairs(runes) do
        local cx = ((i - 1) % REF_COLUMNS + 0.5) * REF_CELL
        local cy = (math.floor((i - 1) / REF_COLUMNS) + 0.5) * REF_CELL
        -- Same look as a slot in the magic circle, brighter when hovered or traced
        local bright = rune == hovered or rune.name == self.guide
        love.graphics.setColor(MagicCircle.SLOT_BG_COLOR)
        love.graphics.circle("fill", cx, cy, REF_ICON_RADIUS, 32)
        love.graphics.setColor(rune.color[1], rune.color[2], rune.color[3], bright and 1 or 0.7)
        love.graphics.setLineWidth(bright and 3 or 1.5)
        love.graphics.circle("line", cx, cy, REF_ICON_RADIUS, 32)
        MagicCircle.drawGlyph(rune.glyph, cx, cy, REF_ICON_RADIUS * 0.6, 1.4)
    end
    love.graphics.pop()
    Slab.Image("SpellRuneReference", {Image = self.refCanvas})

    if hovered ~= nil then
        Slab.Text(string.format("%s  (%s, %s mana)", hovered.name, hovered.kind, tostring(hovered.manaCost)), {Color = hovered.color})
    elseif self.guide ~= nil then
        Slab.Text("Tracing " .. self.guide .. ", click it to hide", {Color = HINT_COLOR})
    else
        Slab.Text("Click a rune to trace it on the pad", {Color = HINT_COLOR})
    end
end


function SpellEditor:placeKindMismatch(target, runeName)
    -- True when a rune is the wrong kind for the slot(forms only go in the center)
    local isForm = RUNE_REGISTRY[runeName].kind == "form"
    return isForm ~= (target.slot == "core")
end


function SpellEditor:targetLabel()
    if self.target == nil then
        return "Click a slot in the circle to draw"
    end
    local place = " slot " .. self.target.slot
    if self.target.slot == "core" then
        place = " center"
    end
    return "Drawing into: " .. self:circlePath(self.spell, self.target.spell, "Main circle") .. place
end


function SpellEditor:handlePadMouse(cx, cy)
    -- Records strokes while the left mouse button is held on the pad, cx, cy is the pad center on screen
    local mx, my = Slab.GetMousePosition()
    local px, py = (mx - cx) / PAD_RUNE_RADIUS, (my - cy) / PAD_RUNE_RADIUS
    local onPad = distance(mx, my, cx, cy) <= PAD_EDGE_RADIUS

    if self.currentStroke == nil then
        if Slab.IsMouseClicked(1) and onPad and self.target ~= nil then
            self.currentStroke = {{px, py}}
        end
    elseif Slab.IsMouseDown(1) then
        local last = self.currentStroke[#self.currentStroke]
        if distance(px, py, last[1], last[2]) * PAD_RUNE_RADIUS >= PAD_POINT_SPACING then
            table.insert(self.currentStroke, {px, py})
        end
    else
        -- Stroke finished, the drawing is recognized again with it
        table.insert(self.strokes, self.currentStroke)
        self.currentStroke = nil
        self:recognizeDrawing()
    end
end


function SpellEditor:recognizeDrawing()
    -- Rune zone strokes are matched against the runes that fit the picked slot, ring strokes are read as marks
    if #self.strokes == 0 or self.target == nil then
        self.result = nil
        return
    end
    local runeStrokes, markStrokes = Strokes.splitZones(self.strokes, 1)
    local name, quality = Strokes.recognize(runeStrokes, self:candidatesFor(self.target))

    -- The recognized rune reads the marks its own way, runes without readMarks ignore them
    local marks = Strokes.readMarks(markStrokes, 0, 0)
    local reading, markProblem = nil, nil
    local rune = name and RUNE_REGISTRY[name]
    if rune and rune.readMarks ~= nil and #marks > 0 then
        reading, markProblem = rune:readMarks(marks)
    end

    local problem = nil
    if name ~= nil then
        problem = self:placeProblem(self.target, name) or markProblem
    elseif #runeStrokes == 0 then
        problem = "Draw the rune inside the dotted line"
    end
    self.result = {name = name, quality = quality, marks = marks, reading = reading, problem = problem}
end


function SpellEditor:candidatesFor(target)
    -- Forms for the center, modifiers and triggers for the ring slots(cached, the recognizer keeps its clouds on them)
    local key = target.slot == "core" and "core" or "ring"
    if candidates[key] == nil then
        candidates[key] = {}
        local kinds = key == "core" and {"form"} or {"modifier", "trigger"}
        for i, kind in ipairs(kinds) do
            for j, rune in ipairs(self:runesOfKind(kind)) do
                if rune.glyph ~= nil then
                    table.insert(candidates[key], {name = rune.name, glyph = rune.glyph})
                end
            end
        end
    end
    return candidates[key]
end


function SpellEditor:drawPadCanvas()
    -- Pad background, the mark ring edge, the dotted divider and the strokes
    if self.padCanvas == nil then
        self.padCanvas = love.graphics.newCanvas(PAD_SIZE, PAD_SIZE)
    end
    local c = PAD_SIZE / 2
    love.graphics.push("all")
    love.graphics.setCanvas(self.padCanvas)
    love.graphics.origin()
    love.graphics.clear(STAGE_COLOR)
    love.graphics.setLineWidth(1)

    -- Faint outer edge of the mark ring
    love.graphics.setColor(MagicCircle.RING_COLOR[1], MagicCircle.RING_COLOR[2], MagicCircle.RING_COLOR[3], 0.25)
    love.graphics.circle("line", c, c, PAD_EDGE_RADIUS, 64)

    -- Dim dotted divider between the rune and its marks
    love.graphics.setColor(MagicCircle.RING_COLOR[1], MagicCircle.RING_COLOR[2], MagicCircle.RING_COLOR[3], 0.45)
    local dashes = 40
    for k = 0, dashes - 1, 2 do
        local a1 = k * 2 * math.pi / dashes
        love.graphics.arc("line", "open", c, c, PAD_RUNE_RADIUS, a1, a1 + 2 * math.pi / dashes, 4)
    end

    -- Rune picked in the reference, faint so the drawing goes over it
    if self.guide ~= nil then
        local rune = RUNE_REGISTRY[self.guide]
        love.graphics.setColor(rune.color[1], rune.color[2], rune.color[3], GUIDE_ALPHA)
        MagicCircle.drawGlyph(rune.glyph, c, c, PAD_RUNE_RADIUS * 0.7, 3)
    end

    -- Strokes, the rune zone in the recognized rune color and marks in their own color
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("bevel")
    local runeColor = {1, 1, 1, 1}
    if self.result ~= nil and self.result.name ~= nil then
        runeColor = RUNE_REGISTRY[self.result.name].color
    end
    local runeStrokes, markStrokes = Strokes.splitZones(self.strokes, 1)
    self:drawPadStrokes(runeStrokes, runeColor, c)
    self:drawPadStrokes(markStrokes, MARK_STROKE_COLOR, c)
    if self.currentStroke ~= nil then
        self:drawPadStrokes({self.currentStroke}, {1, 1, 1, 1}, c)
    end

    love.graphics.pop()
end


function SpellEditor:drawPadStrokes(strokes, color, c)
    love.graphics.setColor(color)
    for i, stroke in ipairs(strokes) do
        if #stroke == 1 then
            love.graphics.circle("fill", c + stroke[1][1] * PAD_RUNE_RADIUS, c + stroke[1][2] * PAD_RUNE_RADIUS, 2)
        else
            local points = {}
            for j, p in ipairs(stroke) do
                table.insert(points, c + p[1] * PAD_RUNE_RADIUS)
                table.insert(points, c + p[2] * PAD_RUNE_RADIUS)
            end
            love.graphics.line(points)
        end
    end
end


function SpellEditor:runesOfKind(kind)
    -- Registered runes of a kind sorted by name
    local runes = {}
    for name, rune in pairs(RUNE_REGISTRY) do
        if rune.kind == kind then
            table.insert(runes, rune)
        end
    end
    table.sort(runes, function(a, b) return a.name < b.name end)
    return runes
end


-- Circle Window
function SpellEditor:canvas(x, y)
    Slab.BeginWindow("SpellCircle", windowOptions("Magic Circle", x, y, CANVAS_W, EDITOR_H))
        -- Window content area in screen coordinates
        local ox, oy = Slab.GetCursorPos({Absolute = true})
        local cw, ch = Slab.GetWindowActiveSize()
        cw, ch = math.floor(cw), math.floor(ch)

        -- Click targets in screen coordinates, the circle itself is drawn into a canvas
        self.targets = {}
        self.circleTargets = {}
        self:collectTargets(ox + cw / 2, oy + ch / 2)
        local target = self:targetAtMouse()
        -- Space inside a circle but not on a rune picks that circle for the stats panel
        local circle = nil
        if target == nil then
            circle = self:circleAtMouse()
        end

        self:drawCircle(cw, ch, target, circle, ox, oy)
        Slab.SetCursorPos(ox, oy, {Absolute = true})
        Slab.Image("SpellCircleImage", {Image = self.circleCanvas})

        -- Clicks
        if target ~= nil then
            if Slab.IsMouseClicked(1) then
                -- Picks the slot the drawing pad draws into, the current drawing is read again for it
                self.target = {spell = target.spell, slot = target.slot, depth = target.depth}
                self:recognizeDrawing()
            elseif Slab.IsMouseClicked(2) then
                self:clear(target)
            end
        elseif circle ~= nil and Slab.IsMouseClicked(1) then
            self.inspected = circle.spell
        end
    Slab.EndWindow()
end


function SpellEditor:collectTargets(cx, cy)
    -- Same layout as the drawing, but only remembers where the slots and circles are
    local editor = self
    MagicCircle.layout(self.spell, cx, cy, 1, 1, {
        ring = function(x, y, radius, scale, depth, spell)
            -- The whole circle out to the edge of its slots
            local outer = radius + MagicCircle.SLOT_RADIUS * scale
            table.insert(editor.circleTargets, {x = x, y = y, radius = outer, spell = spell, depth = depth})
        end,
        slot = function(x, y, radius, rune, spell, slot, depth)
            editor:addTarget(x, y, radius, spell, slot, depth)
        end,
        core = function(x, y, radius, rune, spell, depth)
            editor:addTarget(x, y, radius, spell, "core", depth)
        end,
    })
end


function SpellEditor:drawCircle(w, h, hovered, hoveredCircle, ox, oy)
    -- Draws the circle with every layer into a canvas that Slab shows as an image
    if self.circleCanvas == nil or self.circleCanvas:getWidth() ~= w or self.circleCanvas:getHeight() ~= h then
        self.circleCanvas = love.graphics.newCanvas(w, h)
    end

    love.graphics.push("all")
    love.graphics.setCanvas(self.circleCanvas)
    love.graphics.origin()
    -- Opaque background so the additive glow doesnt need premultiplied alpha
    love.graphics.clear(STAGE_COLOR)

    local progress = (love.timer.getTime() - self.openTime) / EDITOR_DRAW_IN_TIME
    MagicCircle.draw(self.spell, w / 2, h / 2, 1, {progress = progress})

    -- Soft ring around the circle the stats panel shows, fainter one around the circle under the mouse
    for i, circle in ipairs(self.circleTargets) do
        if circle.spell == self.inspected then
            love.graphics.setColor(INSPECT_COLOR)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", circle.x - ox, circle.y - oy, circle.radius + 6, 64)
        end
    end
    if hoveredCircle ~= nil and hoveredCircle.spell ~= self.inspected then
        love.graphics.setColor(INSPECT_COLOR[1], INSPECT_COLOR[2], INSPECT_COLOR[3], 0.25)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", hoveredCircle.x - ox, hoveredCircle.y - oy, hoveredCircle.radius + 6, 64)
    end

    -- Ring around the slot the drawing pad draws into
    if self.target ~= nil then
        for i, target in ipairs(self.targets) do
            if target.spell == self.target.spell and target.slot == self.target.slot then
                love.graphics.setColor(TARGET_COLOR)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", target.x - ox, target.y - oy, target.radius + 6, 48)
            end
        end
    end

    -- Hover ring around the slot under the mouse
    if hovered ~= nil then
        love.graphics.setColor(HOVER_COLOR)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", hovered.x - ox, hovered.y - oy, hovered.radius + 4, 48)
    end

    love.graphics.pop()
end


-- Clicking
function SpellEditor:addTarget(x, y, radius, spell, slot, depth)
    -- slot is the ring index or "core"
    table.insert(self.targets, {x = x, y = y, radius = radius, spell = spell, slot = slot, depth = depth})
end


function SpellEditor:targetAtMouse()
    local mx, my = Slab.GetMousePosition()
    -- Going backwards so children drawn last are picked first
    for i = #self.targets, 1, -1 do
        local target = self.targets[i]
        if distance(mx, my, target.x, target.y) <= target.radius then
            return target
        end
    end
end


function SpellEditor:circleAtMouse()
    -- Deepest circle under the mouse, so clicking a child circle picks the child and not its parent
    local mx, my = Slab.GetMousePosition()
    local found = nil
    for i, circle in ipairs(self.circleTargets) do
        if distance(mx, my, circle.x, circle.y) <= circle.radius then
            if found == nil or circle.depth > found.depth then
                found = circle
            end
        end
    end
    return found
end


function SpellEditor:circlePath(spell, target, path)
    -- Names of the triggers leading from spell to target, nil if target isnt in the tree
    if spell == target then
        return path
    end
    for i, slot in ipairs(spell.slots) do
        local runeName, childSpell = spell:readSlot(slot)
        if childSpell ~= nil then
            local found = self:circlePath(childSpell, target, path .. " > " .. runeName)
            if found ~= nil then
                return found
            end
        end
    end
    return nil
end


function SpellEditor:placeProblem(target, runeName)
    -- Why a rune cant go in this part of the circle, nil when it can
    local rune = RUNE_REGISTRY[runeName]
    if target.slot == "core" then
        if rune.kind ~= "form" then
            return "The center takes a form rune"
        end
        return nil
    end
    if rune.kind == "form" then
        return "Forms go in the center"
    end
    if Spell.isBlocked(target.spell.core, rune.name) then
        return rune.name .. " doesnt work on " .. target.spell.core
    end
    if rune.kind == "trigger" and target.depth >= MAX_SPELL_DEPTH then
        return "Too deep for another trigger"
    end
    return nil
end


function SpellEditor:place(target, runeName, drawing)
    -- Puts a rune into the picked part of the circle, drawing is {quality, marks, strokes} from the pad
    if self:placeProblem(target, runeName) ~= nil then
        return
    end
    local rune = RUNE_REGISTRY[runeName]
    local spell = target.spell

    if target.slot == "core" then
        -- Changing the form keeps every rune, the ones the new form blocks turn inactive
        spell.core = rune.name
        spell.coreDrawing = drawing
    elseif rune.kind == "modifier" then
        spell.slots[target.slot] = {rune.name, nil, drawing = drawing}
    elseif rune.kind == "trigger" then
        -- New triggers start with a plain bullet child, swapping trigger types keeps the old child
        local _, child = spell:readSlot(spell.slots[target.slot])
        if child == nil then
            child = Spell:new("Bullet", {})
            self:fillSlots(child)
        end
        spell.slots[target.slot] = {rune.name, child, drawing = drawing}
    end

    -- Recompiling the root also recompiles every child
    self.spell.dirty = true
end


function SpellEditor:clear(target)
    if target.slot ~= "core" then
        target.spell.slots[target.slot] = false
        self.spell.dirty = true
    end
end


-- Info Window
function SpellEditor:info(x, y)
    -- Compiling the root also compiles every child, so child params are up to date too
    self.spell:getParams()

    -- The inspected circle may have been removed(its trigger slot cleared), then show the main circle
    local path = self:circlePath(self.spell, self.inspected, "Main circle")
    if path == nil then
        self.inspected = self.spell
        path = "Main circle"
    end
    local inspected = self.inspected
    local isMain = inspected == self.spell
    local params = inspected:getParams()

    Slab.BeginWindow("SpellInfo", windowOptions("Spell", x, y, INFO_W, EDITOR_H))
        Slab.Text("Showing: " .. path)
        Slab.Text("Click inside a circle to show it", {Color = HINT_COLOR})
        Slab.Separator()

        Slab.Text("Mana: " .. self:manaText(params))
        if params.complexityScale < 1 then
            Slab.Text(string.format("Complexity discount: -%.0f%%", (1 - params.complexityScale) * 100))
        end

        if isMain then
            -- Complexity against the player limit, red when the spell is too complex to cast
            local maxComplexity = self.spell:getMaxComplexity(player)
            local complexityOptions = nil
            if params.complexity > maxComplexity then
                complexityOptions = {Color = MagicCircle.BLOCKED_COLOR}
            end
            Slab.Text("Complexity: " .. params.complexity .. " / " .. maxComplexity, complexityOptions)
            if complexityOptions ~= nil then
                Slab.Text("Too complex to cast", complexityOptions)
            end
            Slab.Text(string.format("Cooldown: %.2fs", self.spell:getCooldown(player)))
        else
            -- Child circles count toward the main circle complexity and skip cooldowns
            Slab.Text("Complexity: " .. params.complexity .. " (part of main)")
            Slab.Text("Triggered, no cooldown")
        end
        Slab.NewLine()

        -- Stats every form has
        Slab.Text(string.format("Damage: %.1f", params.damage))
        Slab.Text(string.format("Terrain damage: %.1f (%.0f%%)", params.damage * params.terrainDamage, params.terrainDamage * 100))
        Slab.Text("Count: " .. params.count)
        Slab.Text(string.format("Lifetime: %.1fs", params.lifetime))
        if params.recoil > 0 then
            Slab.Text(string.format("Recoil: %.0f", params.recoil * RECOIL_SPEED * params.cooldownScale))
        end

        -- Stats the form rune lists for itself(label, param name, format)
        local formRune = RUNE_REGISTRY[inspected.core]
        for i, stat in ipairs(formRune.stats or {}) do
            local value = params[stat[2]]
            if value ~= nil then
                Slab.Text(stat[1] .. ": " .. string.format(stat[3], value))
            end
        end

        Slab.Rectangle({W = INFO_W - 20, H = 20, Color = params.color, Rounding = 4})
        Slab.NewLine()

        if Slab.Button("Clear") then
            self.spell.core = "Bullet"
            self.spell.coreDrawing = nil
            self.spell.slots = {}
            self:fillSlots(self.spell)
            self.spell.dirty = true
            self.inspected = self.spell
            self.target = nil
        end
        Slab.SameLine()
        if Slab.Button("Done") then
            self.closed = true
        end
    Slab.EndWindow()
end


function SpellEditor:manaText(params)
    -- Cast cost plus what each trigger costs when it happens, e.g. "9 (+15 onHit)"
    local text = tostring(params.manaCost)
    for event, children in pairs(params.triggers) do
        for i, childSpell in ipairs(children) do
            text = text .. " (+" .. childSpell:getParams().manaCost .. " " .. event .. ")"
        end
    end
    return text
end

return SpellEditor
