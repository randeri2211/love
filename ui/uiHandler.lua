require "ui.menu"
local Slab = require "libraries.Slab"
local SpellEditor = require "ui.spellEditor"
local CharacterScreen = require "ui.characterScreen"
local Hud = require "ui.hud"
local Grimoire = require "ui.grimoire"
local ItemBrowser = require "ui.itemBrowser"
local Theme = require "ui.theme"
local PixelFont = require "ui.pixelFont"
local Spellbooks = require "magic.spellbooks"

local UIHandler = {}

function UIHandler:new()
    uihandler = {}
    setmetatable(uihandler,self)
    self.__index = self

    uihandler.showMap = false
    uihandler.spellEditor = nil     -- Open spell editor, nil when closed
    uihandler.characterScreen = nil -- Open character and inventory screen, nil when closed(the game keeps running)
    uihandler.grimoire = nil        -- Open grimoire, nil when closed(the game keeps running)
    uihandler.itemBrowser = nil     -- Debug list of every item, nil when closed
    uihandler.toasts = {}           -- Short messages at the top of the screen, {text, color, time}
    uihandler.showQuitConfirm = false
    uihandler.leavingWorld = false  -- The confirmation is for going back to the main menu instead of quitting
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
    elseif self.itemBrowser ~= nil then
        self:toggleItemBrowser()
    elseif self.grimoire ~= nil then
        self:toggleGrimoire()
    elseif self.characterScreen ~= nil then
        self:toggleCharacterScreen()
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
    local ww, wh = 260, 260
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
            if Slab.Button("Main menu", {W = buttonW}) then
                self:openQuitConfirm(true)
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


function UIHandler:openQuitConfirm(leavingWorld)
    -- Pauses the game behind the confirmation, leavingWorld asks about going back to the main menu instead
    self.showQuitConfirm = true
    self.leavingWorld = leavingWorld == true
    self.wasPaused = paused
    paused = true
    player_control = false
end


function UIHandler:closeQuitConfirm()
    self.showQuitConfirm = false
    self.leavingWorld = false
    paused = self.wasPaused
    player_control = not paused
end


function UIHandler:leaveWorld(save)
    -- Back to the main menu from a world, saving it first when asked
    -- Every world menu closes(the character screen puts a held stack back first, so the save keeps it)
    self.showQuitConfirm, self.leavingWorld, self.showPauseMenu = false, false, false
    if self.characterScreen ~= nil then
        self:toggleCharacterScreen()
    end
    self.spellEditor, self.grimoire, self.itemBrowser, self.showMap = nil, nil, nil, false
    self.toasts = {}
    Slab.SetInputFocus(nil)
    if save then
        saveScene(currentWorld)
    end
    -- A fresh empty world until the next one is picked, like when the game starts
    initVars()
    game_state = MENU_STATE
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
        -- The spell name box goes away with the editor, so it cant keep the keyboard focus
        Slab.SetInputFocus(nil)
    end
    player_control = not paused
end


function UIHandler:toggleCharacterScreen()
    -- The character and inventory screen, the world keeps going behind it
    if self.showQuitConfirm or self.showPauseMenu or self.spellEditor ~= nil then
        return
    end
    if self.characterScreen == nil then
        self.grimoire = nil     -- One big screen at a time
        self.characterScreen = CharacterScreen:new(player)
    else
        self.characterScreen:close()
        self.characterScreen = nil
    end
end


function UIHandler:openStation(block)
    -- Interacting with a block that has slots(an arcane table) opens it next to the inventory
    if self.showQuitConfirm or self.showPauseMenu or self.spellEditor ~= nil then
        return
    end
    if self.characterScreen == nil then
        self.characterScreen = CharacterScreen:new(player, block)
    else
        self.characterScreen.block = block
    end
end


function UIHandler:toggleGrimoire()
    -- The grimoire, closes the character screen so they dont overlap
    if self.showQuitConfirm or self.showPauseMenu or self.spellEditor ~= nil then
        return
    end
    if self.grimoire == nil then
        if self.characterScreen ~= nil then
            self:toggleCharacterScreen()
        end
        self.grimoire = Grimoire:new(player)
    else
        self.grimoire = nil
    end
end


function UIHandler:toggleItemBrowser()
    -- Debug: every item with a filter, its text box lets go of the keyboard when it closes
    if self.itemBrowser == nil then
        self.itemBrowser = ItemBrowser:new(player)
    else
        self.itemBrowser = nil
        Slab.SetInputFocus(nil)
    end
end


function UIHandler:toast(text, color)
    -- A short message at the top of the screen that fades(learning a rune)
    table.insert(self.toasts, {text = text, color = color, time = 0})
end


function UIHandler:checkKeyIngame(key)
    -- This will handle things like opening inventory on pressing the inventory
    if key == MINIMAP_KEY then
        self.showMap = not self.showMap
    end
end


function UIHandler:update()
    -- Safety net: a text box can only keep keyboard focus while a window that has one is open,
    -- a stale focus blocks every game key and crashes Slab when a key is typed into a box that isnt drawn
    if Slab.IsAnyInputFocused() and self.spellEditor == nil and self.itemBrowser == nil and not worldNameOpen() then
        Slab.SetInputFocus(nil)
    end

    if game_state == MENU_STATE then
        Menu()
    elseif game_state == PICK_WORKD_STATE then
        PickWorld()
    elseif game_state == IN_WORLD_STATE then
        if self.showMap then
            self:map()
        end

        if self.itemBrowser ~= nil then
            if self.itemBrowser.owner ~= player then
                self.itemBrowser = nil
            else
                self.itemBrowser:update()
            end
        end

        if self.grimoire ~= nil then
            if self.grimoire.owner ~= player then
                self.grimoire = nil
            else
                self.grimoire:update()
            end
        end

        if self.characterScreen ~= nil then
            -- Loading a world makes a new player, the screen closes with the old one
            if self.characterScreen.owner ~= player then
                self.characterScreen = nil
            else
                self.characterScreen:update()
            end
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


function UIHandler:drawTop()
    -- Drawn after Slab, over every window: the item stack held in the character screen, or the tooltip of the hovered item
    if self.characterScreen ~= nil then
        self.characterScreen:drawHeld()
        self.characterScreen:drawTooltip()
    end
    if self.itemBrowser ~= nil then
        self.itemBrowser:drawTooltip()
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
        self:drawToasts()
        if player:isDead() then
            self:drawDeath()
        end
    end
end


function UIHandler:drawDeath()
    -- The world darkens, "You died" and the seconds left until the respawn in the middle of the screen
    local w, h = love.graphics.getDimensions()
    love.graphics.push("all")
    love.graphics.setColor(0.05, 0.02, 0.08, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)
    Theme.title("You died", w / 2, h / 2 - 90, 6)
    love.graphics.setColor(Theme.COLORS.text)
    PixelFont.print("Back in " .. math.max(1, math.ceil(player.deathTimer)), w / 2, h / 2 + 10, 4, "center")
    love.graphics.pop()
end


local TOAST_TIME = 3     -- Seconds a message stays

function UIHandler:drawToasts()
    -- Newest at the top, each fades out over its last second
    local w = love.graphics.getWidth()
    local font = love.graphics.getFont()
    local y = 110
    for i = #self.toasts, 1, -1 do
        local toast = self.toasts[i]
        toast.time = toast.time + love.timer.getDelta()
        if toast.time >= TOAST_TIME then
            table.remove(self.toasts, i)
        else
            local alpha = math.min(1, TOAST_TIME - toast.time)
            local tw = font:getWidth(toast.text) + 24
            love.graphics.push("all")
            local panel = Theme.COLORS.panel
            Theme.panel(w / 2 - tw / 2, y, tw, font:getHeight() + 14, {panel[1], panel[2], panel[3], panel[4] * alpha},
                toast.color and {toast.color[1], toast.color[2], toast.color[3], alpha} or nil)
            local c = toast.color or {1, 1, 1}
            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.print(toast.text, math.floor(w / 2 - font:getWidth(toast.text) / 2), y + 7)
            love.graphics.pop()
            y = y + font:getHeight() + 22
        end
    end
end


function UIHandler:quitConfirm()
    -- Small centered window asking before closing the game
    local w, h = love.graphics.getDimensions()
    local ww, wh = 300, 110
    if self.leavingWorld then
        ww = 360
    end

    Slab.BeginWindow("QuitConfirm", {
        Title = self.leavingWorld and "Main menu" or "Quit",
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
            if self.leavingWorld then
                -- Worlds only keep what was saved, so leaving offers to save first
                Slab.Text("Save before going to the main menu?")
                Slab.NewLine()
                if Slab.Button("Save and leave") then
                    self:leaveWorld(true)
                end
                Slab.SameLine()
                if Slab.Button("Leave") then
                    self:leaveWorld(false)
                end
            else
                Slab.Text("Are you sure you want to quit?")
                Slab.NewLine()
                if Slab.Button("Quit") then
                    love.event.quit()
                end
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