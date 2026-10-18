require "ui.menu"
local Slab = require "libraries.Slab"
local SpellEditor = require "ui.spellEditor"
local Hud = require "ui.hud"
local Spellbooks = require "magic.spellbooks"

local UIHandler = {}

function UIHandler:new()
    uihandler = {}
    setmetatable(uihandler,self)
    self.__index = self

    uihandler.showMap = false
    uihandler.spellEditor = nil     -- Open spell editor, nil when closed
    uihandler.showQuitConfirm = false
    uihandler.wasPaused = false     -- Pause state to go back to when the quit confirmation is cancelled
    uihandler.showPauseMenu = false
    uihandler.pauseMessage = nil    -- Feedback line in the pause menu, like "Saved"

    return uihandler
end


function UIHandler:escape()
    -- Closes the top open menu, if nothing is open opens the pause menu in a world or asks to quit
    if self.showQuitConfirm then
        self:closeQuitConfirm()
    elseif self.showPauseMenu then
        self:closePauseMenu()
    elseif self.spellEditor ~= nil then
        -- Escape cancels binding a key first, then closes the editor
        if self.spellEditor.bindingKey then
            self.spellEditor.bindingKey = false
        else
            self:toggleSpellEditor()
        end
    elseif self.showMap then
        self.showMap = false
    elseif game_state == PICK_WORKD_STATE then
        -- Escape closes an open world dialog first, then goes back to the main menu
        if not closeWorldDialogs() then
            game_state = MENU_STATE
        end
    elseif game_state == IN_WORLD_STATE then
        self:openPauseMenu()
    else
        self:openQuitConfirm()
    end
end


function UIHandler:openPauseMenu()
    self.showPauseMenu = true
    self.pauseMessage = nil
    paused = true
    player_control = false
end


function UIHandler:closePauseMenu()
    self.showPauseMenu = false
    paused = false
    player_control = true
end


function UIHandler:pauseMenu()
    -- Escape menu in a world: resume, save, load the last save or quit
    local w, h = love.graphics.getDimensions()
    local ww, wh = 260, 230
    local buttonW = ww - 40

    Slab.BeginWindow("PauseMenu", {
        Title = "Paused",
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
        Slab.BeginLayout("PauseMenuLayout", {
            AlignX = "center",
        })
            Slab.Text(currentWorld)
            Slab.NewLine()

            if Slab.Button("Resume", {W = buttonW}) then
                self:closePauseMenu()
            end
            if Slab.Button("Save", {W = buttonW}) then
                saveScene(currentWorld)
                self.pauseMessage = "Saved"
            end
            -- Load goes back to the last save, a world that was never saved has nothing to load
            if Slab.Button("Load last save", {W = buttonW, Disabled = not hasSave(currentWorld)}) then
                loadScene(currentWorld)
                self:closePauseMenu()
            end
            if Slab.Button("Quit game", {W = buttonW}) then
                self:openQuitConfirm()
            end

            if self.pauseMessage ~= nil then
                Slab.NewLine()
                Slab.Text(self.pauseMessage, {Color = {0.6, 1, 0.6, 1}})
            end
        Slab.EndLayout()
    Slab.EndWindow()
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
    -- Opens the editor on the player spellbook and pauses the game while editing
    if self.showQuitConfirm or self.showPauseMenu then
        return
    end
    if self.spellEditor == nil then
        self.spellEditor = SpellEditor:new(player.spellbook)
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

    if self.showPauseMenu then
        self:pauseMenu()
    end

    -- Drawn last so it sits on top of every other menu
    if self.showQuitConfirm then
        self:quitConfirm()
    end
end


function UIHandler:draw()
    -- In world screen space drawing, called from love.draw after the camera
    if game_state == IN_WORLD_STATE then
        -- Loading a world makes a new player, so the hud follows it
        if self.hud == nil or self.hud.entity ~= player then
            self.hud = Hud:new(player)
        end
        self.hud:draw(Spellbooks.selectedEntry(player.spellbook))
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