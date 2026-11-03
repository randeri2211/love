local Strokes = require "magic.strokes"

local MagicCircle = {}

-- Circle sizes at scale 1(child circles are drawn smaller)
MagicCircle.RING_RADIUS = 130
MagicCircle.SLOT_RADIUS = 26
MagicCircle.CORE_RADIUS = 42
MagicCircle.CHILD_SCALE = 0.4

-- Colors
MagicCircle.RING_COLOR = {0.6, 0.6, 0.75, 1}
MagicCircle.EMPTY_COLOR = {0.35, 0.35, 0.4, 1}
MagicCircle.SLOT_BG_COLOR = {0.06, 0.07, 0.11, 1}
MagicCircle.BLOCKED_COLOR = {0.9, 0.2, 0.2, 1}     -- Runes the circle form doesnt allow
MagicCircle.MARK_ALPHA = 0.75                       -- Marks around a drawn rune are a little fainter than the rune

local TAU = math.pi * 2
local TOP = -math.pi / 2


-- Layout
function MagicCircle.layout(spell, cx, cy, scale, depth, drawer)
    -- Walks a magic circle and its trigger children, handing every part to the drawer
    -- Every drawer function is optional:
    -- drawer.ring(x, y, radius, scale, depth, spell)
    -- drawer.signature(slots, x, y, scale, depth)     slots = {x, y, dx, dy, rune, blocked, index}, drawn under the slots
    -- drawer.flow(slots, x, y, radius, scale, depth)    along the ring, drawn under the slots
    -- drawer.spoke(x1, y1, x2, y2, slot, scale, depth)
    -- drawer.slot(x, y, radius, rune, spell, index, depth, scale, blocked)    rune is nil for empty slots
    -- drawer.showChild(slot, depth)                   return false to skip a child circle for now
    -- drawer.link(x1, y1, x2, y2, slot, scale, depth)  line from a trigger slot to its child circle
    -- drawer.core(x, y, radius, rune, spell, depth, scale)
    local ring = MagicCircle.RING_RADIUS * scale
    local slotR = MagicCircle.SLOT_RADIUS * scale
    local coreR = MagicCircle.CORE_RADIUS * scale

    -- Slot positions first, clockwise from the top
    local slots = {}
    for i = 1, SPELL_SLOTS do
        local angle = TOP + (i - 1) * TAU / SPELL_SLOTS
        local dx, dy = math.cos(angle), math.sin(angle)
        local runeName, childSpell = spell:readSlot(spell.slots[i])
        slots[i] = {
            angle = angle,
            x = cx + dx * ring,
            y = cy + dy * ring,
            dx = dx,
            dy = dy,
            rune = runeName and RUNE_REGISTRY[runeName] or nil,
            blocked = runeName and (spell.isBlocked(spell.core, runeName) or spell:isRepeatedElement(i)) or false,
            child = childSpell,
            index = i,
        }
    end

    if drawer.ring then drawer.ring(cx, cy, ring, scale, depth, spell) end
    if drawer.signature then drawer.signature(slots, cx, cy, scale, depth, spell) end
    if drawer.flow then drawer.flow(slots, cx, cy, ring, scale, depth, spell) end

    for i, slot in ipairs(slots) do
        local dx, dy = slot.dx, slot.dy
        if drawer.spoke then
            drawer.spoke(cx + dx * coreR, cy + dy * coreR, slot.x - dx * slotR, slot.y - dy * slotR, slot, scale, depth, spell)
        end
        if drawer.slot then drawer.slot(slot.x, slot.y, slotR, slot.rune, spell, i, depth, scale, slot.blocked) end

        -- Child circle outside its trigger slot
        if slot.child ~= nil and (drawer.showChild == nil or drawer.showChild(slot, depth, spell)) then
            local childScale = scale * MagicCircle.CHILD_SCALE
            local childOuter = (MagicCircle.RING_RADIUS + MagicCircle.SLOT_RADIUS) * childScale
            local dist = ring + slotR + childOuter + 8 * scale
            local ccx, ccy = cx + dx * dist, cy + dy * dist
            if drawer.link then
                drawer.link(slot.x + dx * slotR, slot.y + dy * slotR, ccx - dx * childOuter, ccy - dy * childOuter, slot, scale, depth)
            end
            MagicCircle.layout(slot.child, ccx, ccy, childScale, depth + 1, drawer)
        end
    end

    -- Core form rune in the center
    if drawer.core then drawer.core(cx, cy, coreR, RUNE_REGISTRY[spell.core], spell, depth, scale) end
end


-- Glyphs
function MagicCircle.drawGlyph(glyph, x, y, radius, lineWidth)
    -- Glyph points are in a -1 to 1 box, scaled to the slot(color is set by the caller)
    if radius <= 0.01 then
        return
    end
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(radius)
    love.graphics.setLineWidth(lineWidth / radius)   -- Same thickness at any size
    for i, shape in ipairs(glyph) do
        local kind = shape[1]
        if kind == "line" then
            love.graphics.line(unpack(shape, 2))
        elseif kind == "polygon" then
            love.graphics.polygon("line", unpack(shape, 2))
        elseif kind == "fill" then
            love.graphics.polygon("fill", unpack(shape, 2))
        elseif kind == "circle" then
            love.graphics.circle("line", shape[2], shape[3], shape[4], 24)
        elseif kind == "dot" then
            love.graphics.circle("fill", shape[2], shape[3], shape[4], 24)
        elseif kind == "arc" then
            love.graphics.arc("line", "open", shape[2], shape[3], shape[4], shape[5], shape[6], 24)
        end
    end
    love.graphics.pop()
end


-- Drawings
local function drawingLines(drawing)
    -- The player strokes as flat point lists for love.graphics.line, split into the rune and its marks
    -- Built once and kept on the drawing(saving only keeps quality, marks and strokes)
    if drawing.lines == nil then
        local runeStrokes, markStrokes = Strokes.splitZones(drawing.strokes, 1)
        local total = 0
        local function flatten(strokes)
            local lines = {}
            for i, stroke in ipairs(strokes) do
                local flat = {}
                for j, point in ipairs(stroke) do
                    table.insert(flat, point[1])
                    table.insert(flat, point[2])
                end
                total = total + #stroke
                table.insert(lines, flat)
            end
            return lines
        end
        drawing.lines = {rune = flatten(runeStrokes), marks = flatten(markStrokes)}
        drawing.lines.points = total
    end
    return drawing.lines
end


function MagicCircle.hasDrawing(drawing)
    -- True when a rune was drawn by the player, runes without strokes show their clean glyph
    return drawing ~= nil and drawing.strokes ~= nil and #drawing.strokes > 0
end


function MagicCircle.drawDrawing(drawing, x, y, radius, lineWidth, color, alpha, progress)
    -- Draws the player strokes, the rune zone(pad radius 1) fills radius and the marks sit around it
    -- progress(0-1) draws the strokes in the order they were drawn, like the rune being written
    if radius <= 0.01 then
        return
    end
    local lines = drawingLines(drawing)
    local budget = math.floor((progress or 1) * lines.points + 0.5)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(radius)
    love.graphics.setLineWidth(lineWidth / radius)   -- Same thickness at any size

    local function drawLines(list, a)
        love.graphics.setColor(color[1], color[2], color[3], a)
        for i, flat in ipairs(list) do
            local count = math.min(#flat / 2, budget)
            if count <= 0 then
                return
            end
            budget = budget - count
            if count == 1 then
                -- A tap, drawn as a small dot
                love.graphics.circle("fill", flat[1], flat[2], lineWidth / radius, 8)
            elseif count * 2 == #flat then
                love.graphics.line(flat)
            else
                love.graphics.line({unpack(flat, 1, count * 2)})
            end
        end
    end
    drawLines(lines.rune, alpha)
    drawLines(lines.marks, alpha * MagicCircle.MARK_ALPHA)
    love.graphics.pop()
end


-- World Drawer
local style = {}    -- Options of the circle currently being drawn

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function easeBack(t)
    -- Overshooting pop, clamped since rounding can dip just under 0
    local s = 1.7
    t = t - 1
    return math.max(0, t * t * ((s + 1) * t + s) + 1)
end

local function mix(a, b)
    return {(a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2}
end

local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha * style.alpha)
end

local function width(scale)
    return math.max(0.8, 2 * scale)
end

local function span(range)
    -- How far through its time slot of the timeline something is, 0 to 1
    return clamp((style.clock - range[1]) / (range[2] - range[1]), 0, 1)
end

local function depthProgress(depth, spell)
    -- Each nested circle draws in a little after its parent, with a timeline when its ring has its turn
    if not style.drawIn then
        return 1
    end
    if style.timeline ~= nil then
        local entry = style.timeline.entries[spell]
        return entry and span(entry.ring) or 0
    end
    return clamp((style.progress - (depth - 1) * 0.28) / 0.55, 0, 1)
end

local function slotAppear(index, depth, spell)
    -- Slots pop in one after another during the draw-in, with a timeline each rune in its own turn(empty slots with the ring)
    if not style.drawIn then
        return 1
    end
    if style.timeline ~= nil then
        local entry = style.timeline.entries[spell]
        if entry == nil then
            return 0
        end
        local range = entry.slots[index]
        return range and span(range) or depthProgress(depth, spell)
    end
    return clamp(depthProgress(depth, spell) * (SPELL_SLOTS + 1) - (index - 1) - 0.5, 0, 1)
end

local function glowPass(draw, color, lineWidth, alpha)
    -- Wide faint strokes added under the sharp one fake a bloom
    if style.glow then
        love.graphics.setBlendMode("add")
        setColor(color, alpha * 0.06)
        love.graphics.setLineWidth(lineWidth * 6)
        draw()
        setColor(color, alpha * 0.14)
        love.graphics.setLineWidth(lineWidth * 3)
        draw()
        love.graphics.setBlendMode("alpha")
    end
    setColor(color, alpha)
    love.graphics.setLineWidth(lineWidth)
    draw()
end

local function strokeLine(x1, y1, x2, y2, color, lineWidth, alpha)
    glowPass(function() love.graphics.line(x1, y1, x2, y2) end, color, lineWidth, alpha)
end

local function strokeArc(x, y, radius, a1, a2, color, lineWidth, alpha)
    if radius <= 0 or a2 <= a1 then
        return
    end
    local segments = math.max(12, math.floor(radius * (a2 - a1) / 4))
    glowPass(function() love.graphics.arc("line", "open", x, y, radius, a1, a2, segments) end, color, lineWidth, alpha)
end

local function fillCircle(x, y, radius, color, alpha)
    if radius > 0 then
        setColor(color, alpha)
        love.graphics.circle("fill", x, y, radius, math.max(12, math.floor(radius)))
    end
end

local function drawBands(cx, cy, ring, scale, depth, p)
    -- Ticked outer band and dotted inner ring turning opposite ways(alternating per depth)
    local lineWidth = width(scale)
    local b1 = ring + MagicCircle.SLOT_RADIUS * scale + 10 * scale
    local b2 = b1 + 9 * scale
    strokeArc(cx, cy, b1, TOP, TOP + TAU * p, MagicCircle.RING_COLOR, lineWidth * 0.5, 0.6)
    strokeArc(cx, cy, b2, TOP, TOP + TAU * p, MagicCircle.RING_COLOR, lineWidth * 0.5, 0.6)

    local direction = depth % 2 == 1 and 1 or -1
    local rotation = style.time * 0.35 * direction
    local ticks = 72
    for k = 0, math.floor(ticks * p) - 1 do
        local a = rotation + k * TAU / ticks
        local long = k % 6 == 0
        local r1 = b1 + (long and 0 or 3 * scale)
        local r2 = b2 - (long and 0 or 3 * scale)
        local c, s = math.cos(a), math.sin(a)
        strokeLine(cx + c * r1, cy + s * r1, cx + c * r2, cy + s * r2, MagicCircle.RING_COLOR, lineWidth * (long and 0.6 or 0.4), long and 0.8 or 0.45)
    end

    local inner = MagicCircle.CORE_RADIUS * scale + 14 * scale
    for k = 0, 23 do
        local a = -rotation * 1.6 + k * TAU / 24
        fillCircle(cx + math.cos(a) * inner, cy + math.sin(a) * inner, math.max(0.6, 1.6 * scale), MagicCircle.RING_COLOR, 0.6 * p)
    end
end

local worldDrawer = {
    ring = function(x, y, radius, scale, depth, spell)
        local p = depthProgress(depth, spell)
        if p <= 0 then
            return
        end
        -- Main ring traces itself during the draw-in
        strokeArc(x, y, radius, TOP, TOP + TAU * p, MagicCircle.RING_COLOR, width(scale) * 0.8, 0.9)
        -- A spiral arm curls out from the middle to the tip of the growing ring(enemy wind-ups)
        if style.spiral and p < 1 then
            local head = TOP + TAU * p
            local points = {}
            for k = 0, 24 do
                local s = k / 24
                local a = head - TAU * 1.25 * (1 - s)
                table.insert(points, x + math.cos(a) * radius * s)
                table.insert(points, y + math.sin(a) * radius * s)
            end
            glowPass(function() love.graphics.line(points) end, MagicCircle.RING_COLOR, width(scale) * 0.7, 0.7 * (1 - p * 0.5))
        end
        if style.bands then
            drawBands(x, y, radius, scale, depth, p)
        end
    end,

    signature = function(slots, x, y, scale, depth, spell)
        -- Faint star through every slot, bright polygon through the filled ones
        local p = depthProgress(depth, spell)
        if not style.signature or p <= 0.4 then
            return
        end
        local a = clamp((p - 0.4) / 0.6, 0, 1)
        local lineWidth = width(scale)
        for i, s1 in ipairs(slots) do
            local s2 = slots[(i + 1) % #slots + 1]
            strokeLine(s1.x, s1.y, s2.x, s2.y, MagicCircle.RING_COLOR, lineWidth * 0.4, 0.22 * a)
        end

        local filled = {}
        for i, slot in ipairs(slots) do
            if slot.rune and not slot.blocked then
                table.insert(filled, slot)
            end
        end
        for k = 1, #filled do
            -- Two filled slots only need one line between them
            if #filled < 2 or (#filled == 2 and k == 2) then
                break
            end
            local s1, s2 = filled[k], filled[k % #filled + 1]
            strokeLine(s1.x, s1.y, s2.x, s2.y, mix(s1.rune.color, s2.rune.color), lineWidth * 0.7, 0.75 * a)
        end
    end,

    spoke = function(x1, y1, x2, y2, slot, scale, depth, spell)
        local appear = slotAppear(slot.index, depth, spell)
        if appear <= 0 then
            return
        end
        strokeLine(x1, y1, x2, y2, MagicCircle.RING_COLOR, width(scale) * 0.6, 0.55 * appear)
    end,

    flow = function(slots, x, y, radius, scale, depth, spell)
        -- Mana sparks travel clockwise along the ring from the first active rune to the last,
        -- showing the order the runes are applied in
        if not style.particles then
            return
        end
        local active = {}
        for i, slot in ipairs(slots) do
            if slot.rune and not slot.blocked then
                table.insert(active, slot)
            end
        end
        if #active < 2 then
            return
        end

        local first, last = active[1], active[#active]
        local span = last.angle - first.angle
        local p = slotAppear(last.index, depth, spell)
        if p < 1 then
            return      -- Wait for the draw-in to place the last rune
        end

        -- Same spark speed and spacing on any span
        local count = math.max(3, math.floor(span / (TAU / 18)))
        love.graphics.setBlendMode("add")
        for k = 0, count - 1 do
            local f = (style.time * 0.9 / span + k / count) % 1
            local a = first.angle + span * f
            -- Spark color fades from the rune it left to the next one
            local position = 1 + f * (#active - 1)
            local from = active[math.floor(position)]
            local to = active[math.min(#active, math.floor(position) + 1)]
            local color = mix(from.rune.color, to.rune.color)
            fillCircle(x + math.cos(a) * radius, y + math.sin(a) * radius, math.max(0.7, 2.4 * scale), color, math.sin(f * math.pi) * 0.9)
        end
        love.graphics.setBlendMode("alpha")
    end,

    slot = function(x, y, radius, rune, spell, index, depth, scale, blocked)
        local appear = slotAppear(index, depth, spell)
        if appear <= 0 then
            return
        end
        local r = radius
        if style.drawIn then
            r = radius * easeBack(appear)
        end
        local lineWidth = width(scale)
        local _, _, drawing = spell:readSlot(spell.slots[index])
        local drawn = style.glyphs and MagicCircle.hasDrawing(drawing)

        if rune == nil then
            strokeArc(x, y, r, 0, TAU, MagicCircle.EMPTY_COLOR, lineWidth * 0.6, 0.8 * appear)
        elseif blocked then
            -- Inactive rune, dim glyph with a red ring and slash
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, appear)
            if drawn then
                MagicCircle.drawDrawing(drawing, x, y, r, lineWidth * 0.8, rune.color, 0.3 * appear * style.alpha, appear)
            elseif rune.glyph then
                setColor(rune.color, 0.3 * appear)
                MagicCircle.drawGlyph(rune.glyph, x, y, r * 0.6, lineWidth * 0.8)
            end
            strokeArc(x, y, r, 0, TAU, MagicCircle.BLOCKED_COLOR, lineWidth, 0.8 * appear)
            local d = r * 0.7
            strokeLine(x - d, y + d, x + d, y - d, MagicCircle.BLOCKED_COLOR, lineWidth, 0.8 * appear)
        elseif drawn then
            -- The player drawing, the slot ring is where the pad divider was so the marks sit around the slot
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, appear)
            strokeArc(x, y, r, 0, TAU, rune.color, lineWidth, appear)
            MagicCircle.drawDrawing(drawing, x, y, r, lineWidth * 0.8, rune.color, appear * style.alpha, appear)
        elseif style.glyphs and rune.glyph then
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, appear)
            strokeArc(x, y, r, 0, TAU, rune.color, lineWidth, appear)
            setColor(rune.color, appear)
            MagicCircle.drawGlyph(rune.glyph, x, y, r * 0.6, lineWidth * 0.8)
        else
            fillCircle(x, y, r, rune.color, appear)
        end
    end,

    showChild = function(slot, depth, spell)
        -- Children start once their trigger slot has popped in
        return slotAppear(slot.index, depth, spell) >= 1
    end,

    link = function(x1, y1, x2, y2, slot, scale, depth)
        strokeLine(x1, y1, x2, y2, slot.rune.color, width(scale) * 0.8, 0.9)
    end,

    core = function(x, y, radius, rune, spell, depth, scale)
        local coreAppear = 1
        local r = radius
        if style.drawIn then
            coreAppear = clamp(depthProgress(depth, spell) * 3, 0, 1)
            r = radius * easeBack(coreAppear)
        end
        local lineWidth = width(scale)

        if style.glyphs and MagicCircle.hasDrawing(spell.coreDrawing) then
            -- The player drawing of the form, its marks sit between the core and the ring
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, coreAppear)
            strokeArc(x, y, r, 0, TAU, rune.color, lineWidth * 1.2, coreAppear)
            MagicCircle.drawDrawing(spell.coreDrawing, x, y, r, lineWidth * 0.8, rune.color, coreAppear * style.alpha, coreAppear)
        elseif style.glyphs and rune.glyph then
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, coreAppear)
            strokeArc(x, y, r, 0, TAU, rune.color, lineWidth * 1.2, coreAppear)
            strokeArc(x, y, r * 0.8, 0, TAU, rune.color, lineWidth * 0.5, 0.5 * coreAppear)
            setColor(rune.color, coreAppear)
            MagicCircle.drawGlyph(rune.glyph, x, y, r * 0.5, lineWidth * 0.8)
        else
            fillCircle(x, y, r, rune.color, coreAppear)
        end
    end,
}


-- Timeline
function MagicCircle.timeline(spell, ringTime, runeTime)
    -- A circle built part by part(cast wind-ups): its ring and core first, then its runes one by one in flow order,
    -- a trigger rune hands over to its child circle, which builds completely before the parent goes on with its next rune
    -- ringTime and runeTime are seconds per ring and per rune(enemy times by default)
    -- Returns {entries = {[circle] = {ring = {start, finish}, slots = {[index] = {start, finish}}}}, total = seconds}
    ringTime, runeTime = ringTime or CAST_RING_TIME, runeTime or CAST_RUNE_TIME
    local entries, clock = {}, 0
    local function walk(circle)
        local entry = {ring = {clock, clock + ringTime}, slots = {}}
        entries[circle] = entry
        clock = clock + ringTime
        for i = 1, SPELL_SLOTS do
            local runeName, child = circle:readSlot(circle.slots[i])
            if runeName then
                entry.slots[i] = {clock, clock + runeTime}
                clock = clock + runeTime
                if child ~= nil then
                    walk(child)
                end
            end
        end
    end
    walk(spell)
    return {entries = entries, total = clock}
end


function MagicCircle.draw(spell, cx, cy, scale, options)
    -- Draws the circle with love.graphics, every layer is on unless turned off in options
    -- options.alpha(0-1), options.time(seconds, drives rotation and sparks), options.progress(0-1 draw-in)
    -- options.timeline(MagicCircle.timeline) with options.clock(seconds into it) builds the circle part by part instead,
    -- options.spiral adds the spiral arm that leads every ring in
    options = options or {}
    style.timeline = options.timeline
    style.clock = options.clock or 0
    style.spiral = options.spiral == true
    style.alpha = options.alpha or 1
    style.time = options.time or love.timer.getTime()
    style.progress = options.progress or 1
    style.glyphs = options.glyphs ~= false
    style.glow = options.glow ~= false
    style.bands = options.bands ~= false
    style.signature = options.signature ~= false
    style.particles = options.particles ~= false
    style.drawIn = options.drawIn ~= false

    love.graphics.push("all")
    love.graphics.setLineJoin("bevel")
    MagicCircle.layout(spell, cx, cy, scale, 1, worldDrawer)
    love.graphics.pop()
end

return MagicCircle
