local Hud = {}

-- Layout
local MARGIN = 20
local BAR_W = 260
local BAR_H = 16
local GAP = 6
local COOLDOWN_H = 4

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


function Hud:drawBar(key, x, y, label, current, max, color, markerValue)
    -- One bar with a trail behind it, values on top and an optional marker(like a mana cost)
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

    local font = love.graphics.getFont()
    local text = string.format("%s  %d / %d", label, math.floor(current + 0.5), math.floor(max + 0.5))
    love.graphics.setColor(TEXT_COLOR)
    love.graphics.print(text, x + 6, y + (BAR_H - font:getHeight()) / 2)
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


function Hud:draw(spell)
    -- Drawn in screen space after the camera, spell is the one the entity casts(optional)
    local entity = self.entity
    if entity == nil then
        return
    end
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

    if spell ~= nil then
        self:drawCooldown(x, y, spell, entity)
    end

    love.graphics.pop()
end

return Hud
