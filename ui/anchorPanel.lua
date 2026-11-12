local Slab = require "libraries.Slab"
local Simulation = require "world_utils.simulation"
local ManaNetwork = require "world_utils.manaNetwork"

-- The Chunk Anchor screen, shown where the character stats are while an anchor is open(see CharacterScreen)
-- Its radius in chunks with - and + buttons, what it costs and whether its network can pay
local AnchorPanel = {}

-- Colors
local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local MANA_TEXT = {0.55, 0.9, 1, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local BAD_COLOR = {1, 0.5, 0.5, 1}


function AnchorPanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.screen = screen
    return panel
end


function AnchorPanel:update(x, y, w, h, anchor)
    Slab.BeginWindow("ChunkAnchor", {
        Title = "Chunk Anchor", X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        local side = 2 * anchor.anchorRadius + 1
        Slab.Text("Keeps the chunks around it running")
        Slab.Text("while you are away", {Color = HINT_COLOR})
        Slab.NewLine()

        Slab.Text(string.format("Radius: %d  (%d x %d chunks)", anchor.anchorRadius, side, side))
        if Slab.Button("-", {W = 40}) and anchor.anchorRadius > 0 then
            anchor.anchorRadius = anchor.anchorRadius - 1
        end
        Slab.SameLine()
        if Slab.Button("+", {W = 40}) and anchor.anchorRadius < CHUNK_ANCHOR_MAX_RADIUS then
            anchor.anchorRadius = anchor.anchorRadius + 1
        end
        Slab.NewLine()

        Slab.Text(string.format("Costs %.1f mana/s", Simulation.anchorCost(anchor)), {Color = MANA_TEXT})
        Slab.Text(string.format("(%.1f for each chunk around its own)", CHUNK_ANCHOR_MANA), {Color = HINT_COLOR})
        local total = 0
        for i, battery in ipairs(ManaNetwork.batteriesOf(anchor)) do
            total = total + battery.mana
        end
        Slab.Text(string.format("Its network holds %d mana", math.floor(total)))
        if Simulation.isPowered(anchor) then
            Slab.Text("Running", {Color = GOOD_COLOR})
        else
            Slab.Text("No mana: only its own chunk runs", {Color = BAD_COLOR})
        end
        Slab.NewLine()
        Slab.Text("The minimap (" .. MINIMAP_KEY:upper() .. ") shows the chunks", {Color = HINT_COLOR})
        Slab.Text("that keep running", {Color = HINT_COLOR})
    Slab.EndWindow()
end

return AnchorPanel
