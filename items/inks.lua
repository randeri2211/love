-- Inks(see docs/game-design: Early game review): every rune of a spell is written with an ink(see Spell.inkPower),
-- writing a spell gives its new runes the ink and costs one ink item(see ui/spellEditor). A rune's strength is how well
-- it was drawn times its ink's power, so a perfect rune in Slime Ink is weaker than a perfect rune in a better ink.
-- Runes without ink count as DEFAULT_INK
local INKS = {
    {name = "SlimeInk", displayName = "Slime Ink", power = 0.8, tint = {0.45, 0.85, 0.45, 1}},
    -- A placeholder for the inks after it, from skeleton bones
    {name = "BoneInk", displayName = "Bone Ink", power = 1.0, tint = {0.85, 0.82, 0.72, 1}},
}

for i, info in ipairs(INKS) do
    registerItem(info.name, {displayName = info.displayName, icon = "ink", tint = info.tint, ink = info.power,
        tooltipLines = function()
            return {{text = string.format("Ink: runes at %d%% strength", math.floor(info.power * 100 + 0.5)), good = true},
                {text = "Writing a spell uses one"}}
        end})
end
