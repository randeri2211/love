local Slab = require "libraries.Slab"

local Wrapper = {}

function Wrapper:Button(id, options)
    -- Inside layout
    Slab.BeginLayout("WrapperButtonLayout_"..id, {
        Ignore = true
    })
        local img = UI_IMG["button"]
        local imgW, imgH = img:getDimensions()
        local scale = 1
        local center = false

        if type(options) == "table" then
            if type(options.W) == "number" and type(options.H) == "number" then
                scale = math.min(options.W / imgW, options.H / imgH)
            end
            if type(options.Center) == "boolean" then
                center = options.Center
            end
        end

        local w = imgW * scale
        local h = imgH * scale

        -- Get layout size
        local layoutW, layoutH = Slab.GetLayoutSize()

        -- Get current cursor position
        local cursorX, cursorY = Slab.GetCursorPos()

        -- Center inside layout width
        local centerX = cursorX
        if center then
            centerX = (layoutW / 2) - (w / 2)
        end

        -- Set cursor (relative) inside layout
        Slab.SetCursorPos(centerX, cursorY)

        -- Draw image
        Slab.Image("buttonImage"..id, {
            Image = img,
            ReturnOnClick = true,
            W = w,
            H = h,
        })
        local clicked = Slab.IsControlClicked()

        -- Center text inside image
        if id then
            local font = love.graphics.getFont()
            if type(options) == "table" and options.font then
                font = options.font
            end

            local textW = font:getWidth(id)
            local textH = font:getHeight(id)

            -- Get new cursor after image
            local afterX, afterY = Slab.GetCursorPos()

            -- Move back over image
            local textX = centerX + (w / 2) - (textW / 2)
            local textY = cursorY + (h / 2) - (textH / 2)

            Slab.SetCursorPos(textX, textY)

            -- TODO Change text font for custom font
            Slab.Text(id, {Color = {1, 1, 1, 1}})

            -- Restore cursor if needed
            Slab.SetCursorPos(afterX, afterY)
        end
    Slab.EndLayout()

    return clicked
end

return Wrapper
