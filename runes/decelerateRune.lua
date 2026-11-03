local Rune = require "runes.rune"

local DecelerateRune = Rune:new("Decelerate", "modifier", 1, 0, {0.45, 0.7, 0.55})
registerRune("Decelerate", DecelerateRune)

-- A snail shell spiral
DecelerateRune.glyph = {
    {"arc", 0, 0, 0.22, 0, 3.14},
    {"arc", 0.11, 0, 0.44, 3.14, 6.28},
    {"arc", -0.11, 0, 0.66, 0, 3.14},
}

local function discount(params)
    -- A slower spell is cheaper and simpler
    params.complexityScale = params.complexityScale * 0.8
    params.manaScale = params.manaScale * 0.8
end

-- The opposite of Speed, so it works on the same forms(it slows the spell itself, Frost slows what it hits)
DecelerateRune.effects = {
    Bullet = function(params)
        params.speed = params.speed * 0.6
        discount(params)
    end,
    Laser = function(params)
        params.reach = params.reach * 0.6
        discount(params)
    end,
    -- On the caster it is a shorter, cheaper buff
    Self = function(params)
        params.lifetime = params.lifetime * 0.6
        discount(params)
    end,
    -- A mana block lasts longer, enough of them make it stay for good(see forms/blockForm)
    -- The longer it lasts the more mana it takes to make, up to a permanent block(more Decelerate after that cost nothing)
    Block = function(params)
        if params.lifetime <= MANA_BLOCK_PERMANENT then
            params.manaCost = params.manaCost + DECELERATE_BLOCK_MANA
        end
        params.lifetime = params.lifetime + DECELERATE_BLOCK_TIME
    end,
}

return DecelerateRune
