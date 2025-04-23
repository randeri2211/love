require "ui.menu"
local Slab = require "libraries.Slab"

local UIHandler = {}

function UIHandler:new()
    uihandler = {}
    setmetatable(uihandler,self)
    self.__index = self

    uihandler.showMap = false

    return uihandler
end


function UIHandler:checkKey(key)
    if key == MINIMAP_KEY then
        self.showMap = not self.showMap
    end
end


function UIHandler:update()
    if game_state == MENU_STATE then
        Menu()
    elseif game_state == PICK_WORKD_STATE then
        -- PickWorld()
    elseif game_state == IN_WORLD_STATE then
        if self.showMap then
            self:map()
        end
    end
end


function UIHandler:map()
    local w, h = love.graphics.getDimensions()

    self.showMap = Slab.BeginWindow('Minimap', {
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