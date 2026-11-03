local Zombie = require "entities.zombie"
local Spell = require "magic.spell"
local ManaBar = require "components.manaBar"

-- A placeholder caster to test enemy casting(see magic/enemyCasting), placed with DEBUG_CASTER_KEY
-- The zombie body and walk with a mana bar and a spell list, the first real casting enemy replaces it later
local DebugCaster = Zombie:new()
DebugCaster.entityName = "DebugCaster"
DebugCaster.skin = "zombie_frostbitten"
registerEntity("DebugCaster", DebugCaster)

-- Its spells, made new for every caster so each has its own cooldown
-- A compound spell on purpose, its wind-up shows the trigger child building in between
local function spellList()
    return {
        Spell:new("Bullet", {"Fire", {"OnHit", Spell:new("Area", {"Frost", false, false, false, false, false})}, false, false, false, false}),
    }
end


function DebugCaster:new(x, y)
    local caster = Zombie.new(self, x, y)
    if x == nil then
        return caster
    end
    caster.manaBar = ManaBar(40, 40, 6)     -- Mana and regen decide how often it can cast
    caster.spells = spellList()
    return caster
end


function DebugCaster:load(data)
    Zombie.load(self, data)
    self.manaBar = data.manaBar or self.manaBar
end

return DebugCaster
