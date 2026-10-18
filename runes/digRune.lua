local Rune = require "runes.rune"

local DigRune = Rune:new("Dig", "modifier", 3, 2, {0.8, 0.65, 0.45})
registerRune("Dig", DigRune)

-- A pickaxe
DigRune.glyph = {
    {"line", -0.65, -0.4, -0.15, -0.68, 0.4, -0.62, 0.8, -0.25},
    {"line", 0.1, -0.66, -0.5, 0.82},
}

DigRune.effects = {
    -- Trades damage to enemies for damage to terrain, every form has both so it works on all of them
    default = function(params)
        params.damage = params.damage * 0.5
        params.terrainDamage = params.terrainDamage * 4
    end,
}

return DigRune
