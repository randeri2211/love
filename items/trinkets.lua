-- Trinkets and focuses: worn in their own slots(ACCESSORY_SLOTS), each carries an effect(see items/sets for the format)
-- Two different trinkets can be worn at once, one focus. Trinkets tune one form or rune, a focus shapes a whole style:
-- an element, a form or casting itself. Where each comes from is decided one by one(structure chests for now)
local TRINKETS = {
    {name = "GlassLens", displayName = "Glass Lens", tint = {0.7, 0.9, 1, 1},
        effect = {spells = {{form = "Laser", param = "width", mult = 1.4}}, text = {"Laser beams 40% wider"}}},
    {name = "SandHourglass", displayName = "Sand Hourglass", tint = {0.95, 0.8, 0.5, 1},
        effect = {spells = {{form = "Area", param = "expandTime", mult = 0.6}}, text = {"Area spells grow 40% faster"}}},
    {name = "Prism", displayName = "Prism", tint = {0.85, 0.7, 1, 1},
        effect = {spells = {{param = "count", add = 1, when = "count", above = 1}}, text = {"Split spells fan one more"}}},
    {name = "Feather", displayName = "Feather Charm", tint = {0.95, 0.95, 0.9, 1},
        effect = {spells = {{form = "Bullet", param = "speed", mult = 1.3}}, text = {"Bullets fly 30% faster"}}},
}

local FOCUSES = {
    -- An element: much stronger burns that spread once more when the burning one dies
    {name = "EmberFocus", displayName = "Ember Focus", tint = {1, 0.5, 0.25, 1},
        effect = {spells = {{param = "burnDps", mult = 1.3, when = "burnDps"}, {param = "burnSpread", add = 1, when = "burnDps"}},
            text = {"Fire burns 30% hotter", "Burns spread once more on a kill"}}},
    -- A form: lasers hit harder and wider
    {name = "LancerFocus", displayName = "Lancer Focus", tint = {0.6, 1, 0.8, 1},
        effect = {spells = {{form = "Laser", param = "damage", mult = 1.25}, {form = "Laser", param = "width", mult = 1.2}},
            text = {"Lasers deal 25% more damage", "Laser beams 20% wider"}}},
    -- Casting: faster circles, cheaper spells
    {name = "ArcaneFocus", displayName = "Arcane Focus", tint = {0.55, 0.6, 1, 1},
        effect = {castSpeed = 0.2, manaCost = 0.9, text = {"+20% cast speed", "Spells cost 10% less mana"}}},
}

for i, info in ipairs(TRINKETS) do
    registerItem(info.name, {displayName = info.displayName, maxStack = 1, icon = "trinket", tint = info.tint,
        trinket = true, effect = info.effect})
end
for i, info in ipairs(FOCUSES) do
    registerItem(info.name, {displayName = info.displayName, maxStack = 1, icon = "focus", tint = info.tint,
        focus = true, effect = info.effect})
end
