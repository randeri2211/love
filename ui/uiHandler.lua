require "ui.menu"
local Slab = require "libraries.Slab"
local SpellEditor = require "ui.spellEditor"

local UIHandler = {}

function UIHandler:new()
    uihandler = {}
    setmetatable(uihandler,self)
    self.__index = self

    uihandler.showMap = false
    uihandler.spellEditor = nil     -- Open spell editor, nil when closed
    uihandler.showQuitConfirm = false
    uihandler.wasPaused = false     -- Pause state to go back to when the quit confirmation is cancelled

    return uihandler
end


function UIHandler:escape()
    -- Closes the top open menu, if nothing is open asks to quit the game
    if self.showQuitConfirm then
        self:closeQuitConfirm()
    elseif self.spellEditor ~= nil then
        self:toggleSpellEditor()
    elseif self.showMap then
        self.showMap = false
    elseif game_state == PICK_WORKD_STATE then
        game_state = MENU_STATE
    else
        self:openQuitConfirm()
    end
end


function UIHandler:openQuitConfirm()
    -- Pauses the game behind the confirmation
    self.showQuitConfirm = true
    self.wasPaused = paused
    paused = true
    player_control = false
end


function UIHandler:closeQuitConfirm()
    self.showQuitConfirm = false
    paused = self.wasPaused
    player_control = not paused
end


function UIHandler:toggleSpellEditor()
    -- Opens the editor on the test spell and pauses the game while editing
    if self.showQuitConfirm then
        return
    end
    if self.spellEditor == nil then
        self.spellEditor = SpellEditor:new(spellTest)
        paused = true
    else
        self.spellEditor = nil
        paused = false
    end
    player_control = not paused
end


function UIHandler:checkKeyIngame(key)
    -- This will handle things like opening inventory on pressing the inventory
    if key == MINIMAP_KEY then
        self.showMap = not self.showMap
    end
end


function UIHandler:update()
    if game_state == MENU_STATE then
        Menu()
    elseif game_state == PICK_WORKD_STATE then
        PickWorld()
    elseif game_state == IN_WORLD_STATE then
        if self.showMap then
            self:map()
        end

        if self.spellEditor ~= nil then
            self.spellEditor:update()
            if self.spellEditor.closed then
                self:toggleSpellEditor()
            end
        end
    end

    -- Drawn last so it sits on top of every other menu
    if self.showQuitConfirm then
        self:quitConfirm()
    end
end


function UIHandler:quitConfirm()
    -- Small centered window asking before closing the game
    local w, h = love.graphics.getDimensions()
    local ww, wh = 300, 110

    Slab.BeginWindow("QuitConfirm", {
        Title = "Quit",
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        ShowMinimize = false,
        NoSavedSettings = true,
        X = w / 2 - ww / 2,
        Y = h / 2 - wh / 2,
        W = ww,
        H = wh,
    })
        Slab.BeginLayout("QuitConfirmLayout", {
            AlignX = "center",
        })
            Slab.Text("Are you sure you want to quit?")
            Slab.NewLine()

            if Slab.Button("Quit") then
                love.event.quit()
            end
            Slab.SameLine()
            if Slab.Button("Cancel") then
                self:closeQuitConfirm()
            end
        Slab.EndLayout()
    Slab.EndWindow()
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