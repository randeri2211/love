-- What the grimoire says about each rune(see ui/grimoire): a line of lore and what it does to runes after it
-- What its marks do each rune says itself(rune.markHelp, next to the code that reads them)
local RuneBook = {}

RuneBook.LORE = {
    Area = "A breath held, then let go all at once.",
    Bullet = "The first shape every apprentice draws: a spark with somewhere to be.",
    Laser = "Light that refuses to bend, unless it is told to.",
    Trap = "Patience, written into the ground.",
    Self = "Magic turned inward, the caster becomes the page.",
    Damage = "A blade's edge, pressed into mana.",
    Dig = "Miners carved this into their picks long before there were wands.",
    Focus = "Three paths that meet at a single point.",
    Gravity = "The pull of the world, borrowed for a moment.",
    Pierce = "Walls are only suggestions.",
    Rebound = "What is thrown comes back, if the walls agree.",
    Recoil = "Every push pushes back.",
    Repeat = "Said once, said again, said louder.",
    Repel = "The polite way of saying not that close.",
    Size = "Grow the core and the rest follows.",
    Decelerate = "The snail does not hurry, and still arrives.",
    Speed = "Two chevrons, both impatient.",
    Split = "One becomes many, and none become weaker.",
    Weaken = "A smaller spell asks less of its caster.",
    OnHit = "When it lands, begin again.",
    OnExpire = "Even an ending can be a beginning.",
    Fire = "A flame drawn is a flame kept.",
    Frost = "Six arms, and every one of them cold.",
    Poison = "A slow drink of something unkind.",
    Lightning = "It never strikes the same place once.",
    Light = "Every spell shines a little. This one means it.",
    Block = "Mana, told to hold still and be a wall for a while.",
}

-- What a rune does to other runes after it in the flow
RuneBook.AFFECTS = {
    Focus = "Narrows the fan of every Split after it",
    Damage = "Makes every element after it stronger",
    Size = "Makes every element after it last longer",
    Weaken = "Makes every element after it weaker",
}

return RuneBook
