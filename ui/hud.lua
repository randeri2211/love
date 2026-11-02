local Spellbooks = require "magic.spellbooks"
local Items = require "items.items"

local Hud = {}

-- Layout
local MARGIN = 20
local BAR_W = 260
local BAR_H = 16
local GAP = 6
local COOLDOWN_H = 4
local HOTBAR_CELL = 44
local OVERHEAD_W = TILE_SIZE * 1.4  -- Hp bar over enemies
local OVERHEAD_H = 5
local OVERHEAD_GAP = 6              -- Pixels above the head

-- Colors
local BG_COLOR = {0.06, 0.07, 0.11, 0.85}
local EDGE_COLOR = {0.6, 0.6, 0.75, 1}
local HP_COLOR = {0.85, 0.2, 0.25, 1}
local MANA_COLOR = {0.25, 0.5, 1, 1}
local TRAIL_COLOR = {1, 1, 1, 0.35}
local TEXT_COLOR = {1, 1, 1, 0.9}
local MARKER_COLOR = {1, 1, 1, 0.9}
local MARKER_BLOCKED_COLOR = {1, 0.3, 0.3, 1}

local TRAIL_SPEED = 3       -- How fast the trail catches up after a loss(fraction per second)

function Hud:new(entity)
    -- Shows the hpBar and manaBar components of an entity, it only reads them
    local hud = {}
    setmetatable(hud, self)
    self.__index = self

    hud.entity = entity
    hud.trails = {}     -- Trail ratio per bar, drains toward the real value after a loss

    return hud
end


local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end


function Hud:drawBar(key, x, y, label, current, max, color, markerValue, w, h)
    -- One bar with a trail behind it, values on top and an optional marker(like a mana cost)
    -- w and h default to the screen bar size, bars without a label show no text(small bars over enemies)
    local BAR_W, BAR_H = w or BAR_W, h or BAR_H
    local ratio = clamp(current / max, 0, 1)

    -- Trail jumps up with gains and drains slowly after losses
    local trail = self.trails[key] or ratio
    if ratio >= trail then
        trail = ratio
    else
        trail = math.max(ratio, trail - TRAIL_SPEED * love.timer.getDelta() * (trail - ratio + 0.05))
    end
    self.trails[key] = trail

    love.graphics.setColor(BG_COLOR)
    love.graphics.rectangle("fill", x, y, BAR_W, BAR_H, 3)
    love.graphics.setColor(TRAIL_COLOR)
    love.graphics.rectangle("fill", x, y, BAR_W * trail, BAR_H, 3)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, BAR_W * ratio, BAR_H, 3)
    love.graphics.setColor(EDGE_COLOR)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, BAR_W, BAR_H, 3)

    -- Marker line, red when the bar is below it
    if markerValue ~= nil and markerValue > 0 then
        local mx = x + BAR_W * clamp(markerValue / max, 0, 1)
        if current < markerValue then
            love.graphics.setColor(MARKER_BLOCKED_COLOR)
        else
            love.graphics.setColor(MARKER_COLOR)
        end
        love.graphics.setLineWidth(2)
        love.graphics.line(mx, y - 2, mx, y + BAR_H + 2)
    end

    if label ~= nil then
        local font = love.graphics.getFont()
        local text = string.format("%s  %d / %d", label, math.floor(current + 0.5), math.floor(max + 0.5))
        love.graphics.setColor(TEXT_COLOR)
        love.graphics.print(text, x + 6, y + (BAR_H - font:getHeight()) / 2)
    end
end


function Hud:drawOverhead(x, top)
    -- Small hp bar centered above an entity in world space(inside the camera), only once it is hurt
    local hpBar = self.entity.hpBar
    if hpBar == nil or hpBar.currentHP >= hpBar.maxHP then
        return
    end
    love.graphics.push("all")
    self:drawBar("hp", x - OVERHEAD_W / 2, top - OVERHEAD_GAP - OVERHEAD_H, nil, hpBar.currentHP, hpBar.maxHP, HP_COLOR, nil, OVERHEAD_W, OVERHEAD_H)
    love.graphics.pop()
end


function Hud:drawCooldown(x, y, spell, caster)
    -- Thin strip that refills while the current spell cools down
    local cooldown = spell:getCooldown(caster)
    local ready = 1
    if cooldown > 0 then
        ready = 1 - clamp(spell:cooldownLeft() / cooldown, 0, 1)
    end
    love.graphics.setColor(BG_COLOR)
    love.graphics.rectangle("fill", x, y, BAR_W, COOLDOWN_H)
    love.graphics.setColor(spell:getParams().color)
    love.graphics.rectangle("fill", x, y, BAR_W * ready, COOLDOWN_H)
end


function Hud:drawHotbar()
    -- The first row of the inventory along the bottom of the screen, the selected slot outlined and its item named above
    local entity = self.entity
    if entity.inventory == nil then
        return
    end
    local w, h = love.graphics.getDimensions()
    local size, gap = HOTBAR_CELL, 4
    local x0 = math.floor(w / 2 - (HOTBAR_SIZE * (size + gap) - gap) / 2)
    local y0 = h - size - MARGIN
    local font = love.graphics.getFont()
    for i = 1, HOTBAR_SIZE do
        local x = x0 + (i - 1) * (size + gap)
        local selected = i == entity.hotbarSlot
        love.graphics.setColor(BG_COLOR)
        love.graphics.rectangle("fill", x, y0, size, size, 4)
        love.graphics.setColor(selected and MARKER_COLOR or EDGE_COLOR)
        love.graphics.setLineWidth(selected and 2 or 1)
        love.graphics.rectangle("line", x, y0, size, size, 4)
        local stack = entity.inventory.slots[i]
        if stack then
            love.graphics.setColor(1, 1, 1, 1)
            Items.drawIcon(stack.item, x + 6, y0 + 6, size - 12)
            if stack.count > 1 then
                love.graphics.setColor(TEXT_COLOR)
                love.graphics.print(stack.count, x + size - font:getWidth(tostring(stack.count)) - 3, y0 + size - font:getHeight() - 1)
            end
        end
        -- Key number in the corner
        love.graphics.setColor(1, 1, 1, 0.45)
        love.graphics.print(i % 10, x + 3, y0 + 2, 0, 0.5, 0.5)
    end
    local stack = entity.inventory.slots[entity.hotbarSlot]
    if stack then
        local name = Items.displayName(stack.item)
        love.graphics.setColor(TEXT_COLOR)
        love.graphics.print(name, math.floor(w / 2 - font:getWidth(name) / 2), y0 - font:getHeight() - 4)
    end
end


function Hud:draw(spellEntry)
    -- Drawn in screen space after the camera, spellEntry is the spellbook entry the entity casts(optional)
    local entity = self.entity
    if entity == nil then
        return
    end
    local spell = spellEntry and spellEntry.spell
    love.graphics.push("all")
    love.graphics.origin()

    -- Each bar only shows if the entity has that component
    local x, y = MARGIN, MARGIN
    if entity.hpBar ~= nil then
        self:drawBar("hp", x, y, "HP", entity.hpBar.currentHP, entity.hpBar.maxHP, HP_COLOR)
        y = y + BAR_H + GAP
    end

    if entity.manaBar ~= nil then
        local manaCost = nil
        if spell ~= nil then
            manaCost = spell:getParams().manaCost
        end
        self:drawBar("mana", x, y, "Mana", entity.manaBar.currentMana, entity.manaBar.maxMana, MANA_COLOR, manaCost)
        y = y + BAR_H + 3
    end

    self:drawHotbar()

    if spell ~= nil then
        self:drawCooldown(x, y, spell, entity)

        -- Name of the spell and the key it is bound to
        local label = spellEntry.name
        if entity.spellbook ~= nil then
            local key = Spellbooks.keyFor(entity.spellbook, spellEntry.id)
            if key ~= nil then
                label = "[Shift+" .. key .. "] " .. label
            end
        end
        love.graphics.setColor(TEXT_COLOR)
        love.graphics.print(label, x, y + COOLDOWN_H + 4)
    end

    love.graphics.pop()
end

return Hud
