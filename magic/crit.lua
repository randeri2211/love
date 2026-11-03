local ElementFx = require "magic.elementFx"

-- Critical hits: a source(a spell instance, a status left by one) carries critChance and critMultiplier from its caster,
-- every hit or tick from it rolls on its own
local Crit = {}


function Crit.from(caster)
    -- The crit values a caster casts with, its combat stats or the base ones
    local combat = caster and caster.combatStats
    return combat and combat.critChance or BASE_CRIT_CHANCE, combat and combat.critMultiplier or CRIT_MULTIPLIER
end


function Crit.roll(source, amount, x, y)
    -- The damage after the roll and true when it crit, a crit sparks at x, y when given
    if source == nil or (source.critChance or 0) <= 0 or love.math.random() >= source.critChance then
        return amount, false
    end
    if x ~= nil then
        ElementFx.emit("Crit", x, y, 4, 14)
    end
    return amount * (source.critMultiplier or CRIT_MULTIPLIER), true
end

return Crit
