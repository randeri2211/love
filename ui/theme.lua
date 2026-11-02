local Slab = require "libraries.Slab"
local SlabCursor = require "libraries.Slab.Internal.Core.Cursor"
local PixelFont = require "ui.pixelFont"

-- The look of every menu and window: deep indigo panels with violet titles, cyan and gold for magic
-- Theme.apply colors the Slab windows, Theme.panel and Theme.button draw the custom menu screens in the same colors
local Theme = {}

Theme.COLORS = {
    panel = {0.08, 0.07, 0.16, 0.94},
    panelLight = {0.13, 0.11, 0.25, 0.96},
    title = {0.3, 0.17, 0.52, 1},
    edge = {0.45, 0.35, 0.75, 1},
    glow = {0.45, 0.9, 1, 1},           -- Cyan, hovered and selected things
    gold = {1, 0.83, 0.42, 1},          -- Titles and highlights
    text = {0.9, 0.88, 1, 1},
    textDim = {0.58, 0.55, 0.75, 1},
    danger = {1, 0.42, 0.45, 1},
    button = {0.2, 0.15, 0.38, 1},
    buttonHover = {0.3, 0.22, 0.55, 1},
    buttonPressed = {0.4, 0.3, 0.7, 1},
    input = {0.05, 0.04, 0.1, 1},
}
local C = Theme.COLORS

local BUTTON_TEXT_SCALE = 3
local BUTTON_SMALL_TEXT_SCALE = 2
local CORNER = 4        -- Pixels cut from each panel corner, chunky like the pixel art


local function copy(color, alpha)
    return {color[1], color[2], color[3], alpha or color[4]}
end


function Theme.apply()
    -- Colors the Slab windows and gives them the pixel font, called once after Slab.Initialize
    local style = Slab.GetStyle()
    Slab.PushFont(GAME_FONT)
    SlabCursor.SetNewLineSize(GAME_FONT:getHeight())     -- Empty lines are as tall as a line of text
    style.WindowBackgroundColor = copy(C.panel)
    style.WindowTitleFocusedColor = copy(C.title)
    style.WindowCloseBgColor = copy(C.edge)
    style.WindowCloseColor = copy(C.panel, 1)
    style.MenuColor = copy(C.panelLight)
    style.ButtonColor = copy(C.button)
    style.ButtonHoveredColor = copy(C.buttonHover)
    style.ButtonPressedColor = copy(C.buttonPressed)
    style.ButtonDisabledTextColor = copy(C.textDim, 0.6)
    style.RadioButtonSelectedColor = copy(C.glow)
    style.CheckBoxSelectedColor = copy(C.glow)
    style.TextColor = copy(C.text)
    style.TextDisabledColor = copy(C.textDim)
    style.TextHoverBgColor = copy(C.buttonHover)
    style.SeparatorColor = copy(C.edge, 0.6)
    style.ScrollBarColor = copy(C.button)
    style.ScrollBarHoveredColor = copy(C.edge)
    style.InputBgColor = copy(C.input)
    style.InputEditBgColor = copy(C.input)
    style.InputSelectColor = copy(C.glow, 0.35)
    style.InputSliderColor = copy(C.glow)
    style.MultilineTextColor = copy(C.text)
    style.ComboBoxColor = copy(C.button)
    style.ComboBoxHoveredColor = copy(C.buttonHover)
    style.ComboBoxDropDownColor = copy(C.panelLight)
    style.ComboBoxDropDownHoveredColor = copy(C.buttonHover)
    style.ComboBoxArrowColor = copy(C.glow)
    style.WindowRounding = 0
    style.ButtonRounding = 0
    style.InputBgRounding = 0
    style.CheckBoxRounding = 0
    style.ComboBoxRounding = 0
    style.ScrollBarRounding = 0
end


local function cutRect(mode, x, y, w, h, corner)
    -- A rectangle with its corners cut off, the pixel art version of rounded corners
    local c = corner
    love.graphics.polygon(mode, x + c, y, x + w - c, y, x + w, y + c, x + w, y + h - c, x + w - c, y + h, x + c, y + h, x, y + h - c, x, y + c)
end


function Theme.panel(x, y, w, h, fill, edge, glowAmount)
    -- A cut corner panel with an edge, glowAmount(0-1) adds a soft cyan glow around it
    love.graphics.push("all")
    if glowAmount ~= nil and glowAmount > 0 then
        for i = 3, 1, -1 do
            love.graphics.setColor(C.glow[1], C.glow[2], C.glow[3], 0.12 * glowAmount)
            love.graphics.setLineWidth(i * 3)
            cutRect("line", x, y, w, h, CORNER)
        end
    end
    love.graphics.setColor(fill or C.panel)
    cutRect("fill", x, y, w, h, CORNER)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(edge or C.edge)
    cutRect("line", x, y, w, h, CORNER)
    love.graphics.pop()
end


-- Buttons of the custom drawn screens: a screen lays out {x, y, w, h, label} tables,
-- Theme.hovered and Theme.clicked check them in update and Theme.drawButton draws them, so both always agree
Theme.inputBlocked = false      -- A screen sets it while a dialog is open on top of it

function Theme.hovered(button)
    -- Not while the mouse is over a Slab window(a dialog on top of the screen)
    local mx, my = love.mouse.getPosition()
    return not button.disabled and not Theme.inputBlocked and Slab.IsVoidHovered()
        and mx >= button.x and mx <= button.x + button.w and my >= button.y and my <= button.y + button.h
end


function Theme.clicked(button)
    return Theme.hovered(button) and Slab.IsMouseClicked(1)
end


function Theme.drawButton(button)
    -- Dark panel with a pixel font label, it lights up cyan under the mouse
    local hovered = Theme.hovered(button)
    local pressed = hovered and love.mouse.isDown(1)
    local fill = pressed and C.buttonPressed or hovered and C.buttonHover or C.button
    local edge = hovered and C.glow or C.edge
    if button.danger then
        edge = hovered and C.danger or copy(C.danger, 0.55)
    end
    Theme.panel(button.x, button.y, button.w, button.h, fill, edge, hovered and 1 or 0)

    local scale = button.small and BUTTON_SMALL_TEXT_SCALE or BUTTON_TEXT_SCALE
    local textColor = button.disabled and C.textDim or hovered and C.gold or C.text
    local ty = button.y + (button.h - PixelFont.capHeight(scale)) / 2
    -- One pixel shadow under the label
    love.graphics.setColor(0, 0, 0, 0.5)
    PixelFont.print(button.label, button.x + button.w / 2, ty + scale, scale, "center")
    love.graphics.setColor(textColor)
    PixelFont.print(button.label, button.x + button.w / 2, ty, scale, "center")
    love.graphics.setColor(1, 1, 1, 1)
end


function Theme.title(text, x, y, scale)
    -- Big gold pixel title with a violet drop shadow, centered on x
    love.graphics.setColor(C.title)
    PixelFont.print(text, x + scale, y + scale, scale, "center")
    love.graphics.setColor(C.gold)
    PixelFont.print(text, x, y, scale, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return Theme
