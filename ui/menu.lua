
local Slab = require "libraries.Slab"

function Menu()
    -- Main menu window
    local w, h = love.graphics.getDimensions()
    local ww, wh = 300, 200
    Slab.BeginWindow("MainMenu", {
        -- Title = "Main Menu",
        AllowMove = false,
        AllowResize = false,
        AutoSizeWindow = false,
        ShowMinimize = false,
        ConstrainPosition = true,
        W = ww,
        H = wh,
        X = w / 2 - ww / 2,
        Y = h / 2 - wh / 2,
    })
        -- Centered title at the top
        Slab.BeginLayout("TitleLayout", {
            AlignX = "center"
        })
            Slab.Text("Welcome to the Game!")
        Slab.EndLayout()
        -- Slab.Separator() -- adds a line and spacing after title

        Slab.BeginLayout("CENTERED", {
            AlignX = "center",
            AlignY = "center",
        })
            -- Slab.Text("Welcome to the Game!")
            if Slab.Button("Start Game") then
                game_state = PICK_WORKD_STATE
            end

            if Slab.Button("Quit") then
                love.event.quit()
            end
        Slab.EndLayout()
    Slab.EndWindow()
end

function PickWorld()
    -- Main menu window
    local w, h = love.graphics.getDimensions()
    local ww, wh = 300, 200
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
    })
        -- Centered title at the top
        Slab.BeginLayout("TitleLayout", {
            AlignX = "center"
        })
            Slab.Text("Choose a world")
        Slab.EndLayout()
        -- Slab.Separator() -- adds a line and spacing after title

        Slab.BeginLayout("CENTERED", {
            AlignX = "center",
            AlignY = "center",
        })
            -- Slab.Text("Welcome to the Game!")
            if Slab.Button("Start Game") then
                game_state = IN_WORLD_STATE
            end

            if Slab.Button("Quit") then
                love.event.quit()
            end
        Slab.EndLayout()
    Slab.EndWindow()
end