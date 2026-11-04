local Rune = require "runes.rune"

local WeakenRune = Rune:new("Weaken", "modifier", 1, 0, {0.6, 0.6, 0.68})
registerRune("Weaken", WeakenRune)
WeakenRune.lore = "A smaller spell asks less of its caster."    -- A line of lore, the grimoire shows it

-- A minus in a circle, less power(it used to be two chevrons, too close to Speed when drawn)
WeakenRune.glyph = {
    {"circle", 0, 0, 0.7},
    {"line", -0.42, 0, 0.42, 0},
}

-- Every element after it in the flow is weaker(always fully, a drawback cant be drawn badly to dodge it)
WeakenRune.affectsHelp = "Makes every element after it weaker"    -- The grimoire shows it
WeakenRune.affects = {
    element = function(settings, strength)
        settings.power = settings.power * 0.6
    end,
}

WeakenRune.effects = {
    -- Weaker spell that is cheaper and simpler, every form has damage so this works on all of them
    default = function(params)
        params.damage = params.damage * 0.6
        params.complexityScale = params.complexityScale * 0.8
        params.manaScale = params.manaScale * 0.8
    end,
    -- On the caster it is a weaker, cheaper buff
    Self = function(params)
        params.heal = params.heal * 0.6
        params.lifetime = params.lifetime * 0.8
        params.complexityScale = params.complexityScale * 0.8
        params.manaScale = params.manaScale * 0.8
    end,
}

return WeakenRune
