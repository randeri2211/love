local Rune = require "runes.rune"
local BlockForm = require "forms.blockForm"

local BlockRune = Rune:new("Block", "form", 3, 4, {0.55, 0.75, 1})
registerRune("Block", BlockRune)
BlockRune.lore = "Mana, told to hold still and be a wall for a while."    -- A line of lore, the grimoire shows it

BlockRune.form = BlockForm

-- A block inside a frame
BlockRune.glyph = {
    {"polygon", -0.8, -0.8, 0.8, -0.8, 0.8, 0.8, -0.8, 0.8},
    {"polygon", -0.3, -0.3, 0.3, -0.3, 0.3, 0.3, -0.3, 0.3},
}

-- The only modifiers that mean something for a block: how long it lasts, how much it takes to break and its light
-- (triggers always work: onHit when it is damaged, onExpire when it is gone)
BlockRune.allows = {Decelerate = true, Dig = true, Light = true}

-- A block deals no damage and is always one, the editor leaves those lines out
BlockRune.hiddenStats = {damage = true, count = true}

-- Shown in the spell editor
BlockRune.stats = {
    {"Duration", "lifetime", function(lifetime)
        return lifetime > MANA_BLOCK_PERMANENT and "Permanent" or string.format("%.0fs", lifetime)
    end},
    {"HP", "blockHP", "%.0f"},
}

function BlockRune:defaults()
    return {
        damage = 0,
        knockback = 0,
        lifetime = MANA_BLOCK_TIME,     -- Decelerate runes add to it, past MANA_BLOCK_PERMANENT it stays for good
        blockHP = 1,                    -- Dig runes multiply it
    }
end

return BlockRune
