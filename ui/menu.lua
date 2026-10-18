
local Slab = require "libraries.Slab"
local UIOverride = require "ui.uiOverride"

-- World select dialogs
local worldToDelete = nil       -- World waiting for the delete confirmation
local creatingWorld = false     -- New world name window is open
local newWorldText = ""         -- Name typed for the new world

local ERROR_COLOR = {1, 0.4, 0.4, 1}


function closeWorldDialogs()
    -- Closes the delete confirmation or the new world window, true when one was open
    if worldToDelete ~= nil or creatingWorld then
        worldToDelete = nil
        creatingWorld = false
        return true
    end
    return false
end


local function dialogOptions(title, ww, wh)
    -- Small centered window on top of the world list
    local w, h = love.graphics.getDimensions()
    return {
        Title = title,
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        ShowMinimize = false,
        NoSavedSettings = true,
        X = w / 2 - ww / 2,
        Y = h / 2 - wh / 2,
        W = ww,
        H = wh,
    }
end


local function deleteDialog()
    -- Asks before a world is deleted for good
    Slab.BeginWindow("DeleteWorld", dialogOptions("Delete world", 340, 120))
        Slab.BeginLayout("DeleteWorldLayout", {AlignX = "center"})
            Slab.Text("Delete " .. worldToDelete .. "?")
            Slab.Text("This cant be undone.", {Color = ERROR_COLOR})
            Slab.NewLine()
            if Slab.Button("Delete") then
                deleteWorld(worldToDelete)
                worldToDelete = nil
            end
            Slab.SameLine()
            if Slab.Button("Cancel") then
                worldToDelete = nil
            end
        Slab.EndLayout()
    Slab.EndWindow()
end


local function newWorldDialog()
    -- Name box for a new world, the world is created and saved right away
    Slab.BeginWindow("NewWorld", dialogOptions("New world", 340, 150))
        Slab.BeginLayout("NewWorldLayout", {AlignX = "center"})
            Slab.Text("World name")
            if Slab.Input("NewWorldName", {Text = newWorldText, ReturnOnText = true, W = 280}) then
                newWorldText = Slab.GetInputText()
            end

            local problem = worldNameProblem(newWorldText)
            if problem ~= nil then
                Slab.Text(problem, {Color = ERROR_COLOR})
            else
                Slab.NewLine()
            end

            if Slab.Button("Create", {Disabled = problem ~= nil}) then
                -- Builds and saves the world, then stays in the world list where it now shows up
                creatingWorld = false
                initVars()
                tempMap()
                saveScene(newWorldText)
            end
            Slab.SameLine()
            if Slab.Button("Cancel") then
                creatingWorld = false
            end
        Slab.EndLayout()
    Slab.EndWindow()
end

function Menu()
    -- Main menu window
    local w, h = love.graphics.getDimensions()
    local ww, wh = 800, 800
    local buttonAmount = 2
    Slab.BeginWindow("MainMenu", {
        -- Title = "Main Menu",
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        ShowMinimize = false,
        ConstrainPosition = true,
        NoSavedSettings = true,
        W = ww,
        H = wh,
        X = w / 2 - ww / 2,
        -- X = 10,
        Y = h / 2 - wh / 2,
        -- Y = 0,
    })
        -- Centered title at the top
        Slab.BeginLayout("TitleLayout", {
            AlignX = "center",
        })
            Slab.Text("Welcome to the Game!")
        Slab.EndLayout()

        Slab.BeginLayout("CENTERED", {
            AlignX = "center",
            AlignY = "center",
        })  
            local buttonOptions = {
                CenterX = true,
                H = 100,
                -- W = 300
            }

            if UIOverride:Button("Single Player", buttonOptions) then
                game_state = PICK_WORKD_STATE
            end

            if UIOverride:Button("Exit", buttonOptions) then
                uihandler:openQuitConfirm()
            end
        Slab.EndLayout()
    Slab.EndWindow()
end

function PickWorld()
    -- Main menu window
    local w, h = love.graphics.getDimensions()
    local ww, wh = w * 0.8, h * 0.7
    Slab.BeginWindow("PickWorld", {
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        ShowMinimize = false,
        ConstrainPosition = true,
        W = ww,
        H = wh,
        X = w / 2 - ww / 2,
        Y = h / 2 - wh / 2,
        NoSavedSettings = true,
    })
        -- Centered title at the top
        Slab.BeginLayout("TitleLayout", {
            AlignX = "center"
        })
            Slab.Text("Choose a world")
        Slab.EndLayout()

        -- One row per saved world: the world button and its delete button beside it
        local rowH = 56
        local gap = 12
        local imgW, imgH = UI_IMG["button"]:getDimensions()
        local worldW = imgW * rowH / imgH
        local startX = math.max(0, (ww - worldW - gap - 140) / 2)
        Slab.NewLine()
        local _, rowY = Slab.GetCursorPos()

        -- The world list ignores clicks while a dialog is open on top of it
        local dialogOpen = worldToDelete ~= nil or creatingWorld
        for key, name in ipairs(love.filesystem.getDirectoryItems(SAVE_FOLDER)) do
            -- A valid world folder has the player, map and entities files
            local folder = SAVE_FOLDER .. "/" .. name
            local valid = love.filesystem.getInfo(folder .. "/" .. PLAYER_FILENAME) ~= nil
                and love.filesystem.getInfo(folder .. "/" .. MAP_FILENAME) ~= nil
                and love.filesystem.getInfo(folder .. "/" .. ENTITIES_FILENAME) ~= nil

            if valid then
                Slab.SetCursorPos(startX, rowY)
                if UIOverride:Button(name, {H = rowH}) and not dialogOpen then
                    currentWorld = name
                    loadScene(name)
                    game_state = IN_WORLD_STATE
                end

                -- Label includes the name since Slab buttons use their label as id
                Slab.SetCursorPos(startX + worldW + gap, rowY + rowH / 2 - 11)
                if Slab.Button("Delete " .. name) and not dialogOpen then
                    worldToDelete = name
                end

                rowY = rowY + rowH + 8
            end
        end
        Slab.SetCursorPos(0, rowY)

        -- This is the layout for the back button
        Slab.BeginLayout("CENTERED", {
            AlignX = "center",
            AlignY = "bottom",
            Columns = 2,
        })
            Slab.SetLayoutColumn(1)
            if Slab.Button("New World") and worldToDelete == nil then
                -- Opens the name window, starting with the next free "World N"
                creatingWorld = true
                newWorldText = newWorldName()
                Slab.SetInputFocus("NewWorldName")
            end

            Slab.SetLayoutColumn(2)
            if Slab.Button("Back") and worldToDelete == nil and not creatingWorld then
                game_state = MENU_STATE
            end
        Slab.EndLayout()
    Slab.EndWindow()

    -- Dialogs on top of the world list
    if worldToDelete ~= nil then
        deleteDialog()
    elseif creatingWorld then
        newWorldDialog()
    end
end