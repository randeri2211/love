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
            blocked = runeName and spell.isBlocked(spell.core, runeName) or false,
            child = childSpell,
            index = i,
        }
    end

    if drawer.ring then drawer.ring(cx, cy, ring, scale, depth, spell) end
    if drawer.signature then drawer.signature(slots, cx, cy, scale, depth) end
    if drawer.flow then drawer.flow(slots, cx, cy, ring, scale, depth) end

    for i, slot in ipairs(slots) do
        local dx, dy = slot.dx, slot.dy
        if drawer.spoke then
            drawer.spoke(cx + dx * coreR, cy + dy * coreR, slot.x - dx * slotR, slot.y - dy * slotR, slot, scale, depth)
        end
        if drawer.slot then drawer.slot(slot.x, slot.y, slotR, slot.rune, spell, i, depth, scale, slot.blocked) end

        -- Child circle outside its trigger slot
        if slot.child ~= nil and (drawer.showChild == nil or drawer.showChild(slot, depth)) then
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

local function depthProgress(depth)
    -- Each nested circle draws in a little after its parent
    if not style.drawIn then
        return 1
    end
    return clamp((style.progress - (depth - 1) * 0.28) / 0.55, 0, 1)
end

local function slotAppear(index, depth)
    -- Slots pop in one after another during the draw-in
    if not style.drawIn then
        return 1
    end
    return clamp(depthProgress(depth) * (SPELL_SLOTS + 1) - (index - 1) - 0.5, 0, 1)
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
    ring = function(x, y, radius, scale, depth)
        local p = depthProgress(depth)
        if p <= 0 then
            return
        end
        -- Main ring traces itself during the draw-in
        strokeArc(x, y, radius, TOP, TOP + TAU * p, MagicCircle.RING_COLOR, width(scale) * 0.8, 0.9)
        if style.bands then
            drawBands(x, y, radius, scale, depth, p)
        end
    end,

    signature = function(slots, x, y, scale, depth)
        -- Faint star through every slot, bright polygon through the filled ones
        local p = depthProgress(depth)
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

    spoke = function(x1, y1, x2, y2, slot, scale, depth)
        local appear = slotAppear(slot.index, depth)
        if appear <= 0 then
            return
        end
        strokeLine(x1, y1, x2, y2, MagicCircle.RING_COLOR, width(scale) * 0.6, 0.55 * appear)
    end,

    flow = function(slots, x, y, radius, scale, depth)
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
        local p = slotAppear(last.index, depth)
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
        local appear = slotAppear(index, depth)
        if appear <= 0 then
            return
        end
        local r = radius
        if style.drawIn then
            r = radius * easeBack(appear)
        end
        local lineWidth = width(scale)

        if rune == nil then
            strokeArc(x, y, r, 0, TAU, MagicCircle.EMPTY_COLOR, lineWidth * 0.6, 0.8 * appear)
        elseif blocked then
            -- Inactive rune, dim glyph with a red ring and slash
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, appear)
            if rune.glyph then
                setColor(rune.color, 0.3 * appear)
                MagicCircle.drawGlyph(rune.glyph, x, y, r * 0.6, lineWidth * 0.8)
            end
            strokeArc(x, y, r, 0, TAU, MagicCircle.BLOCKED_COLOR, lineWidth, 0.8 * appear)
            local d = r * 0.7
            strokeLine(x - d, y + d, x + d, y - d, MagicCircle.BLOCKED_COLOR, lineWidth, 0.8 * appear)
        elseif style.glyphs and rune.glyph then
            fillCircle(x, y, r, MagicCircle.SLOT_BG_COLOR, appear)
            strokeArc(x, y, r, 0, TAU, rune.color, lineWidth, appear)
            setColor(rune.color, appear)
            MagicCircle.drawGlyph(rune.glyph, x, y, r * 0.6, lineWidth * 0.8)
        else
            fillCircle(x, y, r, rune.color, appear)
        end
    end,

    showChild = function(slot, depth)
        -- Children start once their trigger slot has popped in
        return slotAppear(slot.index, depth) >= 1
    end,

    link = function(x1, y1, x2, y2, slot, scale, depth)
        strokeLine(x1, y1, x2, y2, slot.rune.color, width(scale) * 0.8, 0.9)
    end,

    core = function(x, y, radius, rune, spell, depth, scale)
        local coreAppear = 1
        local r = radius
        if style.drawIn then
            coreAppear = clamp(depthProgress(depth) * 3, 0, 1)
            r = radius * easeBack(coreAppear)
        end
        local lineWidth = width(scale)

        if style.glyphs and rune.glyph then
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


function MagicCircle.draw(spell, cx, cy, scale, options)
    -- Draws the circle with love.graphics, every layer is on unless turned off in options
    -- options.alpha(0-1), options.time(seconds, drives rotation and sparks), options.progress(0-1 draw-in)
    options = options or {}
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
