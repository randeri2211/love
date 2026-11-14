local Slab = require "libraries.Slab"
local SlotWidget = require "ui.slotWidget"
local ManaNetwork = require "world_utils.manaNetwork"

-- The Spell Turret screen, shown where the character stats are while a turret is open(see CharacterScreen)
-- Its scroll slot, what it aims at, and its tier, kind and stats with the most complex scroll it takes
local TurretPanel = {}

local HINT_COLOR = {0.6, 0.62, 0.7, 1}
local GOOD_COLOR = {0.6, 1, 0.6, 1}
local BAD_COLOR = {1, 0.5, 0.5, 1}
local SELECTED = {0.45, 0.9, 1, 1}


function TurretPanel:new(screen)
    local panel = {}
    setmetatable(panel, self)
    self.__index = self

    panel.screen = screen
    panel.hint = nil
    return panel
end


function TurretPanel:update(x, y, w, h, turret)
    Slab.BeginWindow("SpellTurret", {
        Title = turret.info.title, X = x, Y = y, W = w, H = h,
        AllowMove = false, AllowResize = false, AutoSizeWindow = false, ShowMinimize = false, NoSavedSettings = true,
    })
        local caster = turret:caster()
        Slab.Text(turret.info.kind.text, {Color = HINT_COLOR})
        Slab.NewLine()

        Slab.Text("Scroll:")
        local reason
        turret.scroll, reason = SlotWidget.update("TurretSlot", turret.scroll, self.screen,
            function(stack) return turret:canTake(stack) end, "Scroll")
        if reason ~= nil then
            self.hint = reason
        end
        if self.hint ~= nil then
            Slab.Text(self.hint, {Color = BAD_COLOR})
        end
        if turret.scroll then
            Slab.Text("Casting " .. tostring(turret.scroll.data.name), {Color = GOOD_COLOR})
        end
        Slab.NewLine()

        Slab.Text("Aims at:")
        for i, option in ipairs({{"nearest", "Nearest"}, {"weakest", "Lowest hp"}}) do
            if i > 1 then
                Slab.SameLine()
            end
            if Slab.Button(option[2], {W = 110, Color = turret.aim == option[1] and SELECTED or nil}) then
                turret.aim = option[1]
            end
        end
        Slab.Text(string.format("Sees enemies %d tiles away", TURRET_RANGE), {Color = HINT_COLOR})
        Slab.NewLine()

        local cs = caster.combatStats
        Slab.Text(string.format("Level %d stats", caster.level or 1))
        Slab.Text(string.format("Int %d  Con %d  Wis %d", caster.stats.intelligence, caster.stats.concentration, caster.stats.wisdom))
        Slab.Text(string.format("Spell damage  %d%%", math.floor(cs.spellDamage * 100 + 0.5)))
        Slab.Text(string.format("Cast speed  %d%%", math.floor(cs.castSpeed * 100 + 0.5)))
        Slab.Text(string.format("Cooldown  %d%%", math.floor(cs.spellCooldown * 100 + 0.5)))
        Slab.Text(string.format("Mana cost  %d%%", math.floor(cs.spellManaCost * 100 + 0.5)))
        Slab.Text(string.format("Max complexity  %d", cs.maxComplexity))
        Slab.NewLine()

        local node = ManaNetwork.nodeNear(turret:center())
        if node == nil then
            Slab.Text("No mana network in reach", {Color = BAD_COLOR})
        else
            Slab.Text(string.format("Network: %d mana", math.floor(ManaNetwork.stored(node))), {Color = GOOD_COLOR})
        end
    Slab.EndWindow()
end

return TurretPanel
