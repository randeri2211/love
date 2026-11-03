local Slab = require "libraries.Slab"
local MagicCircle = require "magic.magicCircle"
local Knowledge = require "magic.knowledge"
local RuneBook = require "magic.runeBook"
local PixelFont = require "ui.pixelFont"

-- The grimoire: every rune, the known ones with their shape and what they do, the unknown ones as blanks
-- Click a known rune on the left to read its page on the right
local Grimoire = {}

-- Layout
local COLUMNS = 5
local CELL = 56
local ICON_RADIUS = 21
local PAGE_W = 420
local GLYPH_SIZE = 200
local GAP = 12
local WINDOW_H = 640

-- Colors
local STAGE_COLOR = {0.07, 0.06, 0.13, 1}
local UNKNOWN_COLOR = {0.3, 0.28, 0.42, 1}
local SELECT_COLOR = {1, 0.83, 0.42, 1}
local HEADER_COLOR = {0.85, 0.75, 1, 1}
local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local LORE_COLOR = {0.8, 0.72, 0.95, 1}

-- Order on the page: forms, then the ring runes, then triggers, each by name
local KIND_ORDER = {form = 1, modifier = 2, trigger = 3}
local KIND_NAMES = {form = "Form", modifier = "Modifier", trigger = "Trigger"}


function Grimoire:new(owner)
    local grimoire = {}
    setmetatable(grimoire, self)
    self.__index = self

    grimoire.owner = owner
    grimoire.selected = nil     -- Rune name whose page is open
    return grimoire
end


local function allRunes()
    local runes = {}
    for name, rune in pairs(RUNE_REGISTRY) do
        table.insert(runes, rune)
    end
    table.sort(runes, function(a, b)
        if KIND_ORDER[a.kind] ~= KIND_ORDER[b.kind] then
            return KIND_ORDER[a.kind] < KIND_ORDER[b.kind]
        end
        return a.name < b.name
    end)
    return runes
end


local function forms()
    local list = {}
    for name, rune in pairs(RUNE_REGISTRY) do
        if rune.kind == "form" then
            table.insert(list, name)
        end
    end
    table.sort(list)
    return list
end


function Grimoire:update()
    local w, h = love.graphics.getDimensions()
    local runes = allRunes()
    local rows = math.ceil(#runes / COLUMNS)
    local listW = COLUMNS * CELL + 20
    local x = math.floor(w / 2 - (listW + GAP + PAGE_W) / 2)
    local y = math.floor(h / 2 - WINDOW_H / 2) - 40
    local knowledge = self.owner.knowledge
    if self.selected == nil or not Knowledge.knows(knowledge, self.selected) then
        self.selected = nil
        for i, rune in ipairs(runes) do
            if Knowledge.knows(knowledge, rune.name) then
                self.selected = rune.name
                break
            end
        end
    end

    Slab.BeginWindow("GrimoireRunes", {
        Title = "Grimoire", X = x, Y = y, W = listW, H = WINDOW_H,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        local known, total = Knowledge.counts(knowledge)
        Slab.Text(string.format("%d of %d runes known", known, total), {Color = HEADER_COLOR})
        local ox, oy = Slab.GetCursorPos({Absolute = true})
        self:handleListMouse(runes, ox, oy, rows)
        self:drawList(runes, rows)
        Slab.Image("GrimoireList", {Image = self.listCanvas})
        Slab.Text("Glyph walls teach new runes", {Color = HINT_COLOR})
    Slab.EndWindow()

    Slab.BeginWindow("GrimoirePage", {
        Title = self.selected or "Grimoire", X = x + listW + GAP, Y = y, W = PAGE_W, H = WINDOW_H,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        if self.selected ~= nil then
            self:page(RUNE_REGISTRY[self.selected], knowledge)
        else
            Slab.Text("No runes known yet", {Color = HINT_COLOR})
        end
    Slab.EndWindow()
end


function Grimoire:handleListMouse(runes, ox, oy, rows)
    local mx, my = Slab.GetMousePosition()
    self.hovered = nil
    local column, row = math.floor((mx - ox) / CELL), math.floor((my - oy) / CELL)
    if mx >= ox and my >= oy and column < COLUMNS and row < rows then
        local rune = runes[row * COLUMNS + column + 1]
        if rune ~= nil and Knowledge.knows(self.owner.knowledge, rune.name) then
            self.hovered = rune.name
            if Slab.IsMouseClicked(1) then
                self.selected = rune.name
            end
        end
    end
end


function Grimoire:drawList(runes, rows)
    local w, h = COLUMNS * CELL, rows * CELL
    if self.listCanvas == nil or self.listCanvas:getHeight() ~= h then
        self.listCanvas = love.graphics.newCanvas(w, h)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.listCanvas)
    love.graphics.origin()
    love.graphics.clear(STAGE_COLOR)
    for i, rune in ipairs(runes) do
        local cx = ((i - 1) % COLUMNS + 0.5) * CELL
        local cy = (math.floor((i - 1) / COLUMNS) + 0.5) * CELL
        love.graphics.setColor(MagicCircle.SLOT_BG_COLOR)
        love.graphics.circle("fill", cx, cy, ICON_RADIUS, 32)
        if Knowledge.knows(self.owner.knowledge, rune.name) then
            local selected = rune.name == self.selected
            local bright = selected or rune.name == self.hovered
            love.graphics.setColor(selected and SELECT_COLOR or rune.color)
            love.graphics.setLineWidth(bright and 3 or 1.5)
            love.graphics.circle("line", cx, cy, ICON_RADIUS, 32)
            love.graphics.setColor(rune.color[1], rune.color[2], rune.color[3], bright and 1 or 0.75)
            MagicCircle.drawGlyph(rune.glyph, cx, cy, ICON_RADIUS * 0.6, 1.4)
            -- A small dot for runes that have their template
            if Knowledge.isTemplated(self.owner.knowledge, rune.name) then
                love.graphics.setColor(SELECT_COLOR)
                love.graphics.circle("fill", cx + ICON_RADIUS * 0.75, cy + ICON_RADIUS * 0.75, 3)
            end
        else
            -- Unknown, only a blank seal
            love.graphics.setColor(UNKNOWN_COLOR)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", cx, cy, ICON_RADIUS, 32)
            PixelFont.print("?", cx, cy - PixelFont.capHeight(2) / 2, 2, "center")
        end
    end
    love.graphics.pop()
end


function Grimoire:page(rune, knowledge)
    -- The rune drawn big, then everything the grimoire knows about it
    if self.glyphCanvas == nil then
        self.glyphCanvas = love.graphics.newCanvas(GLYPH_SIZE, GLYPH_SIZE)
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.glyphCanvas)
    love.graphics.origin()
    love.graphics.clear(STAGE_COLOR)
    local c = GLYPH_SIZE / 2
    love.graphics.setColor(MagicCircle.SLOT_BG_COLOR)
    love.graphics.circle("fill", c, c, c * 0.9, 64)
    love.graphics.setColor(rune.color)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", c, c, c * 0.9, 64)
    MagicCircle.drawGlyph(rune.glyph, c, c, c * 0.55, 3)
    love.graphics.pop()
    Slab.Image("GrimoireGlyph", {Image = self.glyphCanvas})

    Slab.Text(rune.name, {Color = rune.color})
    if Knowledge.isTemplated(knowledge, rune.name) then
        Slab.Text("Template unlocked: trace it in the spell editor", {Color = GOOD_COLOR})
    else
        Slab.Text("No template yet: draw it from memory", {Color = HINT_COLOR})
    end
    Slab.Text(string.format("%s  -  %s mana, %d complexity", KIND_NAMES[rune.kind], tostring(rune.manaCost), rune.complexity))

    -- Which forms it works on, forms and triggers go with all of them
    if rune.kind == "modifier" then
        local works = {}
        for i, form in ipairs(forms()) do
            if rune:worksWith(form) then
                table.insert(works, form)
            end
        end
        Slab.Textf("Works on: " .. table.concat(works, ", "), {W = PAGE_W - 20})
    end

    Slab.NewLine()
    Slab.Text("Marks", {Color = HEADER_COLOR})
    local marks = RuneBook.MARKS[rune.name]
    if marks ~= nil then
        for i, line in ipairs(marks) do
            Slab.Textf(line, {W = PAGE_W - 20})
        end
    else
        Slab.Text("None", {Color = HINT_COLOR})
    end
    if RuneBook.AFFECTS[rune.name] ~= nil then
        Slab.Textf(RuneBook.AFFECTS[rune.name], {W = PAGE_W - 20})
    end

    Slab.NewLine()
    Slab.Text(Knowledge.where(knowledge, rune.name) or "", {Color = HINT_COLOR})
    if RuneBook.LORE[rune.name] ~= nil then
        Slab.Textf(RuneBook.LORE[rune.name], {Color = LORE_COLOR, W = PAGE_W - 20})
    end
end

return Grimoire
