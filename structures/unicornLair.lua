local LeyLines = require "world_utils.leyLines"
local Generator = require "world_utils.generator"

-- The Unicorn's lair(see docs/game-design: Bosses), the first boss: an unbreakable hall of lair stone built where two
-- strong ley lines(LAIR_LEY_RATE or more) cross near the surface, from LAIR_ABOVE tiles above the ground to LAIR_BELOW
-- under it. Its altar summons the Unicorn with a Mana-Infused Hay Bale, and its glyph wall teaches Laser once the
-- Unicorn is beaten. A long open floor for its charges, the way in on the right
registerStructure("UnicornLair", {
    title = "unicorn lair",
    where = "surface",
    cell = LAIR_CELL,
    chance = 1,                 -- Every cell with a crossing that fits has one(see find)
    priority = 3,               -- Before mage towers and camps
    version = 2,                -- Worlds from before the lairs dont get them
    ground = 11,                -- The floor sits on the surface
    find = function(def, cell, seed, settings)
        -- The first crossing in the cell that fits, the hall centered on it, kept off the cell edges so a lair is always
        -- found by the chunks it overlaps(see Structures.inArea)
        local w = #def.blueprint[1]
        local x1, x2 = cell * def.cell + w, (cell + 1) * def.cell - w
        local crossings = LeyLines.crossings(x1, x2, function(column)
            local surface = Generator.surfaceRow(column, seed, settings)
            return surface - LAIR_ABOVE, surface + LAIR_BELOW
        end, LAIR_LEY_RATE, seed)
        if #crossings == 0 then
            return nil
        end
        return crossings[1].x - 20
    end,
    -- L lair stone, T torch, G the glyph wall(sealed until the Unicorn is beaten), A the summoning altar, d dirt,
    -- D the way in(sealed during the fight), . air outside(cut through any hill), , air inside with the lair stone wall
    -- behind it. Lair stone fills down to the ground under the hall, dirt under the step outside the door
    blueprint = {
        "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL...",
        "L,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,L...",
        "L,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,L...",
        "LT,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,TL...",
        "L,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,L...",
        "L,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,L...",
        "L,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,L...",
        "L,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,D...",
        "G,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,D...",
        "L,,,,,,,,,,,,,,,,,,A,,,,,,,,,,,,,,,,,,,D...",
        "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLddd",
        "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLddd",
        "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLddd",
    },
    legend = {
        ["."] = false,
        [","] = false,
        ["L"] = "LairStone",
        ["T"] = "Torch",
        ["G"] = {glyph = true},
        ["A"] = {altar = true},
        ["D"] = {door = true},
        ["d"] = "Dirt",
    },
    backWall = {[","] = true, ["T"] = true, ["A"] = true},
    fill = {["L"] = "LairStone", ["d"] = "Dirt"},
    backWallTile = "lairStone",
    guards = {},
    glyph = "Laser",
    boss = "Unicorn",
    summon = "ManaInfusedHayBale",
})
