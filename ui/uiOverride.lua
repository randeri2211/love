local Slab = require "libraries.Slab"

local Wrapper = {}

function Wrapper:Button(id, options)
    -- Loads an image stretched to the edges and returns true if its clicked
    Slab.BeginLayout("wrapperButtonLayout"..id)
        local imgW, imgH = UI_IMG["button"]:getDimensions()
        local scale = 1
        

        if type(options) == table and type(options.X) == "number" and type(options.Y) == "number" then
            scale = math.min(options.X / imgW, options.Y / imgH)
        else
            
        end

        Slab.Image("buttonImage"..id, {
            Image = UI_IMG["button"],
            ReturnOnClick = true,
            W = imgW * scale,
            H = imgH * scale,
        })

        -- Detect click
        if Slab.IsControlClicked() then
            Slab.EndLayout()
            return true
        end
    Slab.EndLayout()
    return false
end

return Wrapper