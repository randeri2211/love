local Items = require "items.items"
local Tools = require "items.tools"
local Theme = require "ui.theme"

-- The box next to the mouse that says what an item is and does, drawn over every window(see UIHandler:drawTop)
-- Parts and tools describe themselves(Tools.describe), armor shows its defense and stats, other items only their name
local ItemTooltip = {}

local PAD = 8
local OFFSET = 18       -- Pixels from the mouse
local NAME_COLOR = {1, 0.83, 0.42, 1}
local INFO_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local BAD_COLOR = {1, 0.5, 0.5, 1}


function ItemTooltip.lines(stack)
    -- {text, good} lines under the name of the stack
    local item = ITEM_REGISTRY[stack.item]
    local lines = Tools.describe(stack)
    if lines == nil and item ~= nil and item.armor ~= nil then
        lines = {{text = string.format("Defense  %d", item.armor.defense), good = true}}
        for stat, amount in pairs(item.armor.stats or {}) do
            table.insert(lines, {text = string.format("%+d %s", amount, stat), good = amount > 0})
        end
    end
    return lines or {}
end


function ItemTooltip.draw(stack, mx, my)
    -- Screen space, beside the mouse and kept on the screen
    local font = love.graphics.getFont()
    local rows = {{text = Items.stackName(stack), color = NAME_COLOR}}
    for i, line in ipairs(ItemTooltip.lines(stack)) do
        local color = line.good == true and GOOD_COLOR or (line.good == false and BAD_COLOR or INFO_COLOR)
        table.insert(rows, {text = line.text, color = color})
    end
    local w, lineH = 0, font:getHeight()
    for i, row in ipairs(rows) do
        w = math.max(w, font:getWidth(row.text))
    end
    local h = #rows * lineH + PAD * 2
    w = w + PAD * 2
    local sw, sh = love.graphics.getDimensions()
    local x = math.min(mx + OFFSET, sw - w - 4)
    local y = math.min(my + OFFSET, sh - h - 4)

    love.graphics.push("all")
    love.graphics.origin()
    Theme.panel(x, y, w, h)
    for i, row in ipairs(rows) do
        love.graphics.setColor(row.color)
        love.graphics.print(row.text, x + PAD, y + PAD + (i - 1) * lineH)
    end
    love.graphics.pop()
end

return ItemTooltip
