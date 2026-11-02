
local Slab = require "libraries.Slab"
local Theme = require "ui.theme"
local PixelFont = require "ui.pixelFont"
local MenuBackdrop = require "ui.menuBackdrop"

-- The main menu and the world list are drawn by hand over the menu backdrop(see DrawMenu and DrawPickWorld),
-- Menu and PickWorld run in the Slab frame: they handle the clicks and open the Slab dialogs on top

-- World list
local worlds = nil              -- Saved worlds with what the cards show, read again when it is nil
local scroll = 0                -- Pixels the world list is scrolled down

-- World select dialogs
local worldToDelete = nil       -- World waiting for the delete confirmation
local creatingWorld = false     -- New world name window is open
local newWorldText = ""         -- Name typed for the new world
local focusNameBox = false      -- Gives the name box keyboard focus on the first frame of the new world window
local biomeSize = DEFAULT_BIOME_SIZE    -- Picked biome size, an index in BIOME_SIZES

local ERROR_COLOR = {1, 0.4, 0.4, 1}


function worldNameOpen()
    -- True while the new world name box is showing(text boxes keep keyboard focus)
    return creatingWorld
end


local function closeNewWorld()
    -- Closing the name box also takes its keyboard focus away, or game keys would stay blocked
    creatingWorld = false
    Slab.SetInputFocus(nil)
end


function closeWorldDialogs()
    -- Closes the delete confirmation or the new world window, true when one was open
    if worldToDelete ~= nil or creatingWorld then
        worldToDelete = nil
        closeNewWorld()
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
                worlds = nil
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
    Slab.BeginWindow("NewWorld", dialogOptions("New world", 340, 200))
        Slab.BeginLayout("NewWorldLayout", {AlignX = "center"})
            Slab.Text("World name")
            -- Focus has to be set inside the window the box is in, Slab looks the box up in the current window
            if focusNameBox then
                Slab.SetInputFocus("NewWorldName")
                Slab.SetInputCursorPos(#newWorldText)   -- Cursor after the suggested name, so typing adds to it
                focusNameBox = false
            end
            -- SelectOnFocus selects the suggested name, so typing replaces it
            if Slab.Input("NewWorldName", {Text = newWorldText, ReturnOnText = true, SelectOnFocus = true, W = 280}) then
                newWorldText = Slab.GetInputText()
            end

            -- Biome size, the world saves the width it stands for
            Slab.Text("Biome size")
            for i, size in ipairs(BIOME_SIZES) do
                if i > 1 then
                    Slab.SameLine()
                end
                if Slab.RadioButton(size[1], {Index = i, SelectedIndex = biomeSize}) then
                    biomeSize = i
                end
            end

            local problem = worldNameProblem(newWorldText)
            if problem ~= nil then
                Slab.Text(problem, {Color = ERROR_COLOR})
            else
                Slab.NewLine()
            end

            if Slab.Button("Create", {Disabled = problem ~= nil}) then
                -- Builds and saves the world, then stays in the world list where it now shows up
                closeNewWorld()
                initVars({biomeWidth = BIOME_SIZES[biomeSize][2], dayLength = DAY_LENGTH})      -- New random seed, the generator builds the terrain from it
                saveScene(newWorldText)
                worlds = nil
            end
            Slab.SameLine()
            if Slab.Button("Cancel") then
                closeNewWorld()
            end
        Slab.EndLayout()
    Slab.EndWindow()
end

-- Main menu and world list screens
local GAME_TITLE = "Some Magic Craft Game"
local MENU_BUTTON_W, MENU_BUTTON_H = 320, 60
local CARD_H = 74
local CARD_GAP = 10
local LIST_W = 760              -- Widest the world list gets
local SCROLL_STEP = 40


local function titleScale(text, maxScale)
    -- Biggest whole scale that fits the screen with a margin
    local w = love.graphics.getWidth()
    return math.max(2, math.min(maxScale, math.floor((w - 80) / PixelFont.width(text, 1))))
end


local function menuButtons()
    -- The buttons of the main menu under the title
    local w, h = love.graphics.getDimensions()
    local x, y = w / 2 - MENU_BUTTON_W / 2, h * 0.55
    return {
        play = {x = x, y = y, w = MENU_BUTTON_W, h = MENU_BUTTON_H, label = "Play"},
        quit = {x = x, y = y + MENU_BUTTON_H + 16, w = MENU_BUTTON_W, h = MENU_BUTTON_H, label = "Quit", danger = true},
    }
end


function Menu()
    -- Main menu clicks, drawn by DrawMenu
    Theme.inputBlocked = uihandler.showQuitConfirm
    local buttons = menuButtons()
    if Theme.clicked(buttons.play) then
        worlds = nil
        scroll = 0
        game_state = PICK_WORKD_STATE
    elseif Theme.clicked(buttons.quit) then
        uihandler:openQuitConfirm()
    end
end


function DrawMenu()
    local w, h = love.graphics.getDimensions()
    local scale = titleScale(GAME_TITLE, 8)
    local titleY = h * 0.3 - PixelFont.height(scale) / 2
    MenuBackdrop.draw(w / 2, h * 0.3, math.min(w, h) * 0.32)
    Theme.title(GAME_TITLE, w / 2, titleY, scale)
    love.graphics.setColor(Theme.COLORS.textDim)
    PixelFont.print("Draw runes, shape the world", w / 2, titleY + PixelFont.height(scale) + 18, 2, "center")
    for name, button in pairs(menuButtons()) do
        Theme.drawButton(button)
    end
end


local function timeAgo(seconds)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. " min ago"
    elseif seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        return hours .. (hours == 1 and " hour ago" or " hours ago")
    end
    local days = math.floor(seconds / 86400)
    return days .. (days == 1 and " day ago" or " days ago")
end


local function biomeLabel(settings)
    -- The size choice the world was made with, worlds made before biomes are all plains
    if settings == nil or settings.biomeWidth == nil then
        return "Classic world"
    end
    for i, size in ipairs(BIOME_SIZES) do
        if size[2] == settings.biomeWidth then
            return size[1] .. " biomes"
        end
    end
    return "Biomes " .. settings.biomeWidth .. " wide"
end


local function readWorlds()
    -- Every valid world folder with its card details, the last played first
    local list = {}
    for i, name in ipairs(love.filesystem.getDirectoryItems(SAVE_FOLDER)) do
        -- A valid world folder has the player, map and entities files
        local folder = SAVE_FOLDER .. "/" .. name
        local playerInfo = love.filesystem.getInfo(folder .. "/" .. PLAYER_FILENAME)
        local valid = playerInfo ~= nil
            and love.filesystem.getInfo(folder .. "/" .. MAP_FILENAME) ~= nil
            and love.filesystem.getInfo(folder .. "/" .. ENTITIES_FILENAME) ~= nil
        if valid then
            local mapData = readData(folder .. "/" .. MAP_FILENAME) or {}
            local dayLength = mapData.settings and mapData.settings.dayLength or DAY_LENGTH
            table.insert(list, {
                name = name,
                biomes = biomeLabel(mapData.settings),
                day = math.floor((mapData.time or 0) / dayLength) + 1,
                played = playerInfo.modtime or 0,
            })
        end
    end
    table.sort(list, function(a, b) return a.played > b.played end)
    return list
end


local function pickLayout()
    -- Where everything on the world list screen goes, the cards scroll inside the list box
    local w, h = love.graphics.getDimensions()
    local listW = math.min(LIST_W, w - 60)
    local layout = {
        list = {x = w / 2 - listW / 2, y = 150, w = listW, h = h - 150 - 120},
        cards = {},
    }
    local buttonY = h - 95
    layout.newWorld = {x = w / 2 - 230, y = buttonY, w = 220, h = 56, label = "New world"}
    layout.back = {x = w / 2 + 10, y = buttonY, w = 220, h = 56, label = "Back"}

    local list = layout.list
    local contentH = #worlds * (CARD_H + CARD_GAP) + CARD_GAP
    scroll = math.max(0, math.min(scroll, contentH - list.h))
    for i, world in ipairs(worlds) do
        local y = list.y + CARD_GAP + (i - 1) * (CARD_H + CARD_GAP) - scroll
        local card = {x = list.x + CARD_GAP, y = y, w = list.w - CARD_GAP * 2, h = CARD_H, world = world}
        card.delete = {x = card.x + card.w - 112, y = y + CARD_H / 2 - 20, w = 100, h = 40, label = "Delete", small = true, danger = true}
        -- Cards scrolled out of the list box cant be clicked
        local visible = y + CARD_H > list.y and y < list.y + list.h
        card.disabled = not visible
        card.delete.disabled = not visible
        table.insert(layout.cards, card)
    end
    return layout
end


function ScrollWorlds(amount)
    -- Mouse wheel on the world list
    scroll = scroll - amount * SCROLL_STEP
end


function PickWorld()
    -- World list clicks, drawn by DrawPickWorld, the dialogs go on top of it
    if worlds == nil then
        worlds = readWorlds()
    end
    local dialogOpen = worldToDelete ~= nil or creatingWorld
    Theme.inputBlocked = dialogOpen or uihandler.showQuitConfirm
    local layout = pickLayout()

    local mx, my = love.mouse.getPosition()
    local inList = my >= layout.list.y and my <= layout.list.y + layout.list.h
    for i, card in ipairs(layout.cards) do
        -- The delete button sits on the card, it goes first
        if Theme.clicked(card.delete) then
            worldToDelete = card.world.name
        elseif inList and Theme.clicked(card) then
            currentWorld = card.world.name
            loadScene(card.world.name)
            game_state = IN_WORLD_STATE
            return
        end
    end
    if Theme.clicked(layout.newWorld) then
        -- Opens the name window, starting with the next free "World N"
        creatingWorld = true
        newWorldText = newWorldName()
        focusNameBox = true
    elseif Theme.clicked(layout.back) then
        game_state = MENU_STATE
    end

    -- Dialogs on top of the world list
    if worldToDelete ~= nil then
        deleteDialog()
    elseif creatingWorld then
        newWorldDialog()
    end
end


local function drawCard(card, inList)
    local hovered = inList and Theme.hovered(card) and not Theme.hovered(card.delete)
    local C = Theme.COLORS
    Theme.panel(card.x, card.y, card.w, card.h, hovered and C.buttonHover or C.panelLight, hovered and C.glow or C.edge, hovered and 1 or 0)

    -- A small rune mark at the left, gold on the hovered card
    local cx, cy = card.x + 36, card.y + card.h / 2
    love.graphics.setColor(hovered and C.gold or C.edge)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, 18)
    love.graphics.polygon("line", cx, cy - 12, cx + 10, cy + 7, cx - 10, cy + 7)

    local world = card.world
    local textX = card.x + 70
    love.graphics.setColor(hovered and C.gold or C.text)
    PixelFont.print(world.name, textX, card.y + 16, 3)
    love.graphics.setColor(C.textDim)
    local details = "Day " .. world.day .. "  -  " .. world.biomes .. "  -  " .. timeAgo(os.time() - world.played)
    PixelFont.print(details, textX, card.y + 48, 2)

    Theme.drawButton(card.delete)
end


function DrawPickWorld()
    if worlds == nil then
        return
    end
    local w = love.graphics.getWidth()
    MenuBackdrop.draw()
    Theme.title("Choose a world", w / 2, 50, titleScale("Choose a world", 6))

    local layout = pickLayout()
    local list = layout.list
    Theme.panel(list.x, list.y, list.w, list.h)

    local mx, my = love.mouse.getPosition()
    local inList = my >= list.y and my <= list.y + list.h
    love.graphics.setScissor(list.x, list.y + 2, list.w, list.h - 4)
    for i, card in ipairs(layout.cards) do
        if not card.disabled then
            drawCard(card, inList)
        end
    end
    love.graphics.setScissor()

    if #worlds == 0 then
        love.graphics.setColor(Theme.COLORS.textDim)
        PixelFont.print("No worlds yet", w / 2, list.y + list.h / 2 - 20, 3, "center")
        PixelFont.print("Make one with New world", w / 2, list.y + list.h / 2 + 12, 2, "center")
    end

    -- A scroll bar when the list is longer than the box
    local contentH = #worlds * (CARD_H + CARD_GAP) + CARD_GAP
    if contentH > list.h then
        local barH = list.h * list.h / contentH
        local barY = list.y + (list.h - barH) * scroll / (contentH - list.h)
        love.graphics.setColor(Theme.COLORS.edge)
        love.graphics.rectangle("fill", list.x + list.w - 6, barY, 3, barH)
    end

    Theme.drawButton(layout.newWorld)
    Theme.drawButton(layout.back)
    love.graphics.setColor(1, 1, 1, 1)
end

