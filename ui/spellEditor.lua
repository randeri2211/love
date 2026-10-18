local Slab = require "libraries.Slab"
local Spell = require "magic.spell"
local MagicCircle = require "magic.magicCircle"

local SpellEditor = {}

-- Window sizes
local PALETTE_W = 260
local CANVAS_W = 640
local INFO_W = 300
local EDITOR_H = 640
local GAP = 10

-- Colors(circle colors live in MagicCircle)
local HOVER_COLOR = {1, 1, 0.3, 1}
local HINT_COLOR = {0.6, 0.6, 0.6, 1}
local STAGE_COLOR = {0.07, 0.08, 0.12, 1}

local EDITOR_DRAW_IN_TIME = 1.2    -- Seconds for the circle to draw itself when the editor opens

local KIND_TITLES = {form = "Forms (center)", modifier = "Modifiers", trigger = "Triggers"}


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


function SpellEditor:new(spell)
    local editor = {}
    setmetatable(editor, self)
    self.__index = self

    editor.spell = spell            -- Root spell being edited
    editor.selectedRune = nil       -- Rune name picked in the palette
    editor.targets = {}             -- Clickable parts of the circle, rebuilt every frame
    editor.closed = false
    editor.openTime = love.timer.getTime()  -- The circle draws itself in from this moment
    editor.circleCanvas = nil               -- Created on first draw with the window size
    editor:fillSlots(spell)

    return editor
end


function SpellEditor:fillSlots(spell)
    -- Empty slots are false so ipairs doesnt stop at them, children are filled too
    for i = 1, SPELL_SLOTS do
        if spell.slots[i] == nil then
            spell.slots[i] = false
        elseif type(spell.slots[i]) == "table" then
            self:fillSlots(spell.slots[i][2])
        end
    end
end


function SpellEditor:update()
    -- Draws all 3 editor windows centered on the screen
    local w, h = love.graphics.getDimensions()
    local x = w / 2 - (PALETTE_W + CANVAS_W + INFO_W + GAP * 2) / 2
    local y = h / 2 - EDITOR_H / 2

    self:palette(x, y)
    self:canvas(x + PALETTE_W + GAP, y)
    self:info(x + PALETTE_W + CANVAS_W + GAP * 2, y)
end


-- Palette Window
function SpellEditor:palette(x, y)
    -- List of every registered rune grouped by kind
    Slab.BeginWindow("SpellRunes", windowOptions("Runes", x, y, PALETTE_W, EDITOR_H))
        for i, kind in ipairs({"form", "modifier", "trigger"}) do
            Slab.Text(KIND_TITLES[kind])
            Slab.Separator()
            for j, rune in ipairs(self:runesOfKind(kind)) do
                Slab.Rectangle({W = 14, H = 14, Color = rune.color, Rounding = 7})
                Slab.SameLine({Pad = 6})
                Slab.Text(rune.name .. "   " .. rune.manaCost .. " mana", {IsSelectable = true, IsSelected = self.selectedRune == rune.name})
                if Slab.IsControlClicked() then
                    self.selectedRune = rune.name
                end
            end
            Slab.NewLine()
        end

        Slab.Separator()
        Slab.Text("Left click a slot to place", {Color = HINT_COLOR})
        Slab.Text("Right click a slot to clear", {Color = HINT_COLOR})
    Slab.EndWindow()
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
        self:collectTargets(ox + cw / 2, oy + ch / 2)
        local target = self:targetAtMouse()

        self:drawCircle(cw, ch, target, ox, oy)
        Slab.SetCursorPos(ox, oy, {Absolute = true})
        Slab.Image("SpellCircleImage", {Image = self.circleCanvas})

        -- Clicks
        if target ~= nil then
            if Slab.IsMouseClicked(1) then
                self:place(target)
            elseif Slab.IsMouseClicked(2) then
                self:clear(target)
            end
        end
    Slab.EndWindow()
end


function SpellEditor:collectTargets(cx, cy)
    -- Same layout as the drawing, but only remembers where the slots are
    local editor = self
    MagicCircle.layout(self.spell, cx, cy, 1, 1, {
        slot = function(x, y, radius, rune, spell, slot, depth)
            editor:addTarget(x, y, radius, spell, slot, depth)
        end,
        core = function(x, y, radius, rune, spell, depth)
            editor:addTarget(x, y, radius, spell, "core", depth)
        end,
    })
end


function SpellEditor:drawCircle(w, h, hovered, ox, oy)
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

    -- Hover ring around the slot under the mouse, red when the selected rune cant go there
    if hovered ~= nil then
        if self:canPlace(hovered) then
            love.graphics.setColor(HOVER_COLOR)
        else
            love.graphics.setColor(MagicCircle.BLOCKED_COLOR)
        end
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


function SpellEditor:canPlace(target)
    -- Whether the selected palette rune fits this part of the circle
    if self.selectedRune == nil then
        return true     -- Nothing selected, just hovering
    end
    local rune = RUNE_REGISTRY[self.selectedRune]
    if target.slot == "core" then
        return rune.kind == "form"
    end
    if rune.kind == "form" or Spell.isBlocked(target.spell.core, rune.name) then
        return false
    end
    return rune.kind ~= "trigger" or target.depth < MAX_SPELL_DEPTH
end


function SpellEditor:place(target)
    -- Puts the palette rune into the clicked part of the circle
    if self.selectedRune == nil or not self:canPlace(target) then
        return
    end
    local rune = RUNE_REGISTRY[self.selectedRune]
    local spell = target.spell

    if target.slot == "core" then
        -- Changing the form keeps every rune, the ones the new form blocks turn inactive
        spell.core = rune.name
    elseif rune.kind == "modifier" then
        spell.slots[target.slot] = rune.name
    elseif rune.kind == "trigger" then
        -- New triggers start with a plain bullet child, swapping trigger types keeps the old child
        local _, child = spell:readSlot(spell.slots[target.slot])
        if child == nil then
            child = Spell:new("Bullet", {})
            self:fillSlots(child)
        end
        spell.slots[target.slot] = {rune.name, child}
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
    local params = self.spell:getParams()

    Slab.BeginWindow("SpellInfo", windowOptions("Spell", x, y, INFO_W, EDITOR_H))
        Slab.Text("Selected rune: " .. (self.selectedRune or "none"))
        Slab.Separator()

        Slab.Text("Mana: " .. self:manaText(params))
        Slab.Text("Complexity: " .. params.complexity)
        Slab.NewLine()

        Slab.Text(string.format("Damage: %.1f", params.damage))
        Slab.Text(string.format("Speed: %.0f", params.speed))
        Slab.Text(string.format("Size: %.1f", params.radius))
        Slab.Text("Projectiles: " .. params.count)
        Slab.Text(string.format("Lifetime: %.1fs", params.lifetime))

        Slab.Rectangle({W = INFO_W - 20, H = 20, Color = params.color, Rounding = 4})
        Slab.NewLine()

        if Slab.Button("Clear") then
            self.spell.core = "Bullet"
            self.spell.slots = {}
            self:fillSlots(self.spell)
            self.spell.dirty = true
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
