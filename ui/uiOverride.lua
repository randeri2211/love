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
        local Xcenter = false

        if type(options) == "table" then
            if type(options.W) == "number" and type(options.H) == "number" then
                scale = math.min(options.W / imgW, options.H / imgH)
            elseif type(options.W) == "number" then
                scale = options.W / imgW
            elseif type(options.H) == "number" then
                scale = options.H / imgH
            end
            if type(options.CenterX) == "boolean" then
                Xcenter = options.CenterX
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
        if Xcenter then
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
            -- Get new cursor after image
            local afterX, afterY = Slab.GetCursorPos()

            -- Setup font
            local desiredFontHeight = math.floor(h / 2)
            
            Wrapper.FontCache = Wrapper.FontCache or {}
            local fontKey = "RamadhanMubarok-"..desiredFontHeight
            if not Wrapper.FontCache[fontKey] then
                Wrapper.FontCache[fontKey] = love.graphics.newFont("assets/RamadhanMubarok-Regular.otf", desiredFontHeight)
            end

            local font = Wrapper.FontCache[fontKey]
            Slab.PushFont(font)
            local font = love.graphics.getFont()
            if type(options) == "table" and options.font then
                font = options.font
            end



            local textW = font:getWidth(id)
            local textH = font:getHeight(id)

            -- Move back over image
            local textX = centerX + (w / 2) - (textW / 2)
            local textY = cursorY + (h / 2) - (textH / 2)

            Slab.SetCursorPos(textX, textY)
            
            -- TODO Change text font for custom font
            Slab.Text(id, {Color = {1, 1, 0, 1}})
            Slab.PopFont()
            -- Restore cursor if needed
            Slab.SetCursorPos(afterX, afterY)
        end
    Slab.EndLayout()

    return clicked
end

return Wrapper
