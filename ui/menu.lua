
local Slab = require "libraries.Slab"
local UIOverride = require "ui.uiOverride"

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
                love.event.quit()
            end
        Slab.EndLayout()
    Slab.EndWindow()
end

function PickWorld()
    -- Main menu window
    local w, h = love.graphics.getDimensions()
    local ww, wh = w * 0.8, h * 0.7
    local cols = 4
    local minRows = 4
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

        Slab.BeginLayout("SavesLayout",{
            AlignX = "center",
            AlignY = "top",
            AlignRowY = "center",
            Columns = cols, 
        })
            local location = 1
            local saves = love.filesystem.getDirectoryItems(SAVE_FOLDER)
            for key, name in pairs(saves) do
                local inSaves = love.filesystem.getDirectoryItems(SAVE_FOLDER.."/"..name)
                local eFile, pFile, mFile = false, false, false
                for key2, value2 in pairs(inSaves) do
                    if value2 == ENTITIES_FILENAME then
                        eFile = true
                    elseif value2 == MAP_FILENAME then
                        mFile = true
                    elseif value2 == PLAYER_FILENAME then
                        pFile = true
                    end
                end
                
                -- Valid save directory
                if eFile and pFile and mFile then
                    Slab.SetLayoutColumn(location)
                    -- local button_id = "btn_" .. name

                    -- local imgW, imgH = UI_IMG["button"]:getDimensions()
                    -- local scale = math.min(ww / imgW / cols, wh / imgH / minRows)
                    -- Slab.Image(button_id, {
                    --     Image = UI_IMG["button"],
                    --     ReturnOnClick = true,
                    --     W = imgW * scale,
                    --     H = imgH * scale,
                    -- })
                    
                    -- -- Detect click
                    -- if Slab.IsControlClicked() then
                    --     loadScene(name)
                    --     game_state = IN_WORLD_STATE
                    -- end

                    -- Slab.Text(name) -- Display text below the button
                    
                    if UIOverride:Button(name) then
                        loadScene(name)
                        game_state = IN_WORLD_STATE
                    end

                    -- Switch column
                    if location >= cols then
                        location = 1 -- line up next button horizontally
                    else
                        location = location + 1
                    end
                end
            end
        Slab.EndLayout()

        -- This is the layout for the back button
        Slab.BeginLayout("CENTERED", {
            AlignX = "center",
            AlignY = "bottom",
            Columns = 2,
        })
            Slab.SetLayoutColumn(1)
            if Slab.Button("New World") then
                -- TODO:Make it create a world somehow
                tempMap()

                game_state = IN_WORLD_STATE
            end

            Slab.SetLayoutColumn(2)
            if Slab.Button("Back") then
                game_state = MENU_STATE
            end
        Slab.EndLayout()
    Slab.EndWindow()
end