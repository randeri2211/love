local Slab = require "libraries.Slab"

local UIHandler = {}

function UIHandler:new()
    uihandler = {}
    setmetatable(uihandler,self)
    self.__index = self

    uihandler.showWindow = false

    return uihandler
end


function UIHandler:checkKey(key)
    if key == MINIMAP_KEY then
        self.showWindow = not self.showWindow
    end
end


function UIHandler:update()
    if self.showWindow then
        self:map()
    end
end


function UIHandler:map()
    local w, h = love.graphics.getDimensions()

    self.showWindow = Slab.BeginWindow('Minimap', {
        Title = "Minimap",
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        -- IsOpen = self.showWindow,
        ShowMinimize = false,
        X = w - 200,
        Y = 0,
        W = 200,
        H = 200,
        NoSavedSettings = true,
    })

    Slab.Text("THIS WILL BE A MINIMAP.")

    Slab.EndWindow()
end


return UIHandler