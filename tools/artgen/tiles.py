# What every block tile shows, added to the theme prompt for that tile(see artgen.py)
# Names are the tile names of TILE_ORDER in assets/assetLoader.lua, a tile missing here gets its name split into words
# "full" tiles cover the whole square and must repeat without seams, the rest keep the shape(alpha) of the current tile

TILES = {
    "grass":        ("block of dirt with a layer of grass on top", "full"),
    "dirt":         ("block of plain earth, soil with small pebbles", "full"),
    "stone1":       ("block of grey stone, rough rock", "full"),
    "stone2":       ("block of grey stone, rough rock with cracks", "full"),
    "stone3":       ("block of grey stone, rough rock with small chips", "full"),
    "deepstone1":   ("block of dark dense deep stone, slate", "full"),
    "deepstone2":   ("block of dark dense deep stone, slate with cracks", "full"),
    "deepstone3":   ("block of dark dense deep stone, slate with layers", "full"),
    "bedrock1":     ("block of black unbreakable bedrock", "full"),
    "bedrock2":     ("block of black unbreakable bedrock, jagged", "full"),
    "bedrock3":     ("block of black unbreakable bedrock, rough", "full"),
    "sand":         ("block of desert sand", "full"),
    "sandstone":    ("block of layered sandstone", "full"),
    "snow":         ("block of packed snow", "full"),
    "ice":          ("block of clear blue ice", "full"),
    "bricks":       ("block of old grey shrine bricks", "full"),
    "slab":         ("half height stone slab", "shape"),
    "ore1":         ("small ore nuggets embedded in stone, nuggets only, light grey", "shape"),
    "ore2":         ("ore nuggets embedded in stone, nuggets only, light grey", "shape"),
    "ore3":         ("cluster of ore nuggets, nuggets only, light grey", "shape"),
    "ore4":         ("vein of ore nuggets, nuggets only, light grey", "shape"),
    "oakLog":       ("oak tree trunk, bark seen from the side", "full"),
    "oakLeaves":    ("oak tree leaves, dense foliage", "shape"),
    "pineLog":      ("pine tree trunk, dark bark seen from the side", "full"),
    "pineLeaves":   ("pine needles, dense evergreen foliage", "shape"),
    "cactus":       ("cactus stem segment with spines", "shape"),
    "tallGrass":    ("tuft of tall grass blades", "shape"),
    "woodworking":  ("woodworking bench with a saw and tools", "shape"),
    "forge":        ("stone smelting forge furnace with fire inside", "shape"),
    "arcaneTable":  ("long wide arcane enchanting table with a glowing rune, twice as wide as it is tall", "shape"),
    "stoneBricks":  ("block of stone bricks, castle wall", "full"),
    "crackedStoneBricks": ("block of cracked old stone bricks, ruined wall", "full"),
    "planks":       ("block of wooden planks", "full"),
    "campfire":     ("small campfire with logs and flames", "shape"),
    "torch":        ("wall torch with a flame", "shape"),
    "woodenChest":  ("wooden treasure chest", "shape"),
    "ironChest":    ("iron bound treasure chest", "shape"),
    "arcaniteChest": ("glowing blue crystal treasure chest", "shape"),
    "infusionTable": ("long wide wooden table with an iron bowl of glowing violet mana, twice as wide as it is tall", "shape"),
    "lairStone":    ("block of dark purple stone bricks with faint violet veins", "full"),
    "altar":        ("stone summoning altar pedestal with a glowing violet bowl", "shape"),
}


# Tiles that are magical: only these get the theme's magic_hint(a glow), so magic stands out against plain materials
MAGICAL = {"arcaneTable", "arcaniteChest", "infusionTable", "lairStone", "altar"}


def describe(name):
    # The tile's subject and kind, from the table or from its name("crackedStoneBricks" -> "cracked stone bricks")
    if name in TILES:
        return TILES[name]
    words = "".join(" " + c.lower() if c.isupper() else c for c in name).strip()
    return (words, "shape")
