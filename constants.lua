DEBUG = false                   -- Visual debugging: physics shapes, the debug text and the fps in the console
-- Development tools, they work without DEBUG and go away once the game has its own ways to do these
DEBUG_DAY_LENGTH = nil          -- A whole day takes this many seconds instead of the world setting(nil for the world setting)
DEBUG_ONE_HIT_BLOCKS = false    -- Any hit breaks a block(bedrock still cant break), for digging around
DEBUG_GLYPH_WALL_KEY = "j"      -- Places a glyph wall at the mouse that teaches a rune you dont know yet
DEBUG_CASTER_KEY = "x"          -- Places a test caster at the mouse(a placeholder until the first casting enemy)
DEBUG_FORGET_KEY = "f"          -- Forgets every rune but the starting ones(to test glyph walls)
DEBUG_GIVE_KEY = "g"            -- Gives every armor piece and wand part to test equipment

SCREEN_X  = 1920
SCREEN_Y  = 1080

TILE_SIZE = 32
TILES_PER_METER = 1

GRAVITY_MULTIPLIER = 2.5       -- Real world gravity felt too floaty, this makes falling snappier
GRAVITY = 9.8 * TILE_SIZE * TILES_PER_METER * GRAVITY_MULTIPLIER
MAX_FALL_SPEED = 20 * TILE_SIZE -- Gravity stops speeding entities up past this, other pushes can still go faster
LINEAR_DAMPING = 0.2
JUMP_GRAVITY_SCALE = 0.4        -- Gravity while rising with the jump key held
GROUND_RAY_SPOTS = {0, -0.4, 0.4}   -- Where the ground rays go across the feet, as a part of the body width
GROUND_RAY_START = 0.3          -- How far inside the body the rays start, as a part of the width

-- Jump launch speed, worked out from how high a held jump should go so changing gravity keeps the height
JUMP_TILES = 4.5
BASE_JUMP_HEIGHT = math.sqrt(2 * JUMP_GRAVITY_SCALE * GRAVITY * JUMP_TILES * TILE_SIZE)
BASE_MOVE_SPEED = 4 * TILE_SIZE
BASE_HP = 100
BASE_BLOCK_HP = 5           -- Spells only deal terrainDamage of their damage to blocks
BASE_HP_REGEN = 0
BASE_MANA = 100
BASE_MANA_REGEN = 1
MAX_COOLDOWN_REDUCTION = 0.9
MIN_COOLDOWN_REDUCTION = -1     -- Negative stats can at most double cooldowns

BASE_MAX_COMPLEXITY = 50        -- Spells above the caster max complexity cant be cast
MIN_MAX_COMPLEXITY = 10         -- Negative intelligence cant go below this
COOLDOWN_PER_COMPLEXITY = 0.02  -- Seconds of cooldown for each point of spell complexity

MAX_SPELL_DEPTH = 3     -- How many circles deep triggers can nest(the main circle counts as 1)
SPELL_SLOTS = 6         -- Rune slots in the ring of every magic circle

-- Params every form has, so "default" modifier effects can always use them(forms override in their defaults)
BASE_SPELL_PARAMS = {
    damage = 10,
    lifetime = 2,
    count = 1,                  -- Projectiles per cast, Split multiplies it
    spread = math.rad(30),      -- Fan angle used when count > 1
    terrainDamage = 0.1,        -- Part of the damage blocks take, Dig rune raises it
    manaScale = 1,              -- Multiplies the whole spell mana cost(cheap rapid fire forms and weakening runes lower it)
    complexityScale = 1,        -- Multiplies the whole spell complexity(weakening runes lower it)
    cooldownScale = 1,          -- Multiplies the cooldown(rapid fire forms lower it)
    recoil = 0,                 -- Pushes the caster away from the aim, Recoil rune raises it
    repeats = 1,                -- Casts in a row per cast, Repeat rune multiplies it
    gravityX = 0,               -- Way gravity pulls the spell(bullets fall, lasers bend), an arrow on Gravity turns it
    gravityY = 1,
    knockback = 1,              -- How hard a hit shoves what it hits, the way the spell was going
    recoilDirX = 0,             -- Way an arrow on Recoil pushes, drawn as if facing right(see Spell.facingDirection)
    recoilDirY = 0,             -- 0, 0 is no arrow: recoil pushes away from the aim and dashes go toward it
    glow = 0,                   -- Light runes on it, each makes it a brighter light source(see Form:light)
    -- Element runes switch these on(see magic/elements), 0 is off
    burnDps = 0, burnTime = 0,          -- Fire: damage per second while burning, and for how long
    burnKindle = 0, burnSpread = 0,     -- Fire: spiral marks(the burn ramps up) and spark marks(it passes on when the target dies)
    frostSlow = 0, frostTime = 0,       -- Frost: part of the speed taken away, and for how long
    frostShatter = 0,                   -- Frost: extra part of the damage hits deal to something it slowed
    poisonDps = 0, poisonTime = 0,      -- Poison: damage per second per stack, and for how long
    poisonMax = 0,                      -- Poison: most stacks it builds to(dots on the rune raise it)
    chainTargets = 0,                   -- Lightning: how many enemies a hit jumps to(forks on the rune raise it)
    chainDamage = 0, chainRange = 0,    -- Lightning: part of the hit that jumps to nearby enemies, and how far(pixels)
}

-- Elements(see magic/elements and magic/statuses)
STATUS_TICK = 0.5               -- Seconds between burn and poison damage
POISON_MAX_STACKS = 3           -- Poison hits add up to this many stacks
FROST_MAX_SLOW = 1              -- All of the speed is a full freeze(Frost dots get there)
FREEZE_IMMUNITY = 4             -- Seconds after a full freeze ends before that creature can be frozen solid again
FREEZE_IMMUNE_SLOW = 0.7        -- Most Frost slows it during those seconds, so nothing is frozen to death without moving
FROST_SHATTER = 0.25            -- Hits on something Frost slowed deal this much more damage(Damage runes and crack marks raise it)
-- Frost marks: every dot adds FREEZE_STEP slow and keeps FREEZE_TIME of the time(three dots freeze solid),
-- every crack multiplies the shatter by SHATTER_STEP and keeps SHATTER_TIME of the time
FREEZE_STEP = 0.2
FREEZE_TIME = 0.75
SHATTER_STEP = 1.8
SHATTER_TIME = 0.6
CHAIN_TARGETS = 2               -- Enemies a Lightning hit jumps to
-- Poison dots: every dot allows one more stack and makes every stack weaker by POISON_DOT_SCALE(a higher cap, a slower ramp)
POISON_DOT_SCALE = 0.9
-- Lightning forks: every fork adds a jump target and makes every jump weaker by LIGHTNING_FORK_SCALE
LIGHTNING_FORK_SCALE = 0.85
-- Fire marks: every flame burns FLARE_STEP times faster for that much less time(waves the other way, the same total),
-- every spiral starts the burn KINDLE_STEP weaker and lets it grow to KINDLE_STEP stronger over KINDLE_TIME of burning,
-- every spark passes the burn on once to the nearest creature within WILDFIRE_RANGE when the burning one dies
FLARE_STEP = 1.5
KINDLE_STEP = 0.3
KINDLE_TIME = 3
WILDFIRE_RANGE = 5 * TILE_SIZE
WILDFIRE_COMPLEXITY = 2         -- Extra complexity and mana a spark costs, it adds power instead of trading it
WILDFIRE_MANA = 1
ELEMENT_PARTICLES = 1500        -- Most element particles at once

-- Self form(spells on the caster)
SELF_HEAL = 20                  -- HP the first Damage rune heals over a Self spell, more runes heal more
SELF_DASH_SPEED = 32 * TILE_SIZE    -- Push speed of a Recoil dash on Self, about 5 tiles of dash
SELF_DASH_VERTICAL = 0.6        -- Up and down dashes are weaker, vertical pushes only fight gravity

KNOCKBACK_SPEED = 8 * TILE_SIZE -- Push speed of a knockback 1 hit, about a tile and a third of shove
KNOCKBACK_LIFT = 0.25           -- Small hop on every knockback, so knocked enemies leave the ground
KNOCKBACK_VERTICAL = 0.35       -- Up and down pushes are weaker, sideways pushes fade fast but vertical ones only fight gravity

REPEAT_DELAY = 0.1              -- Seconds between the casts of a Repeat
RECOIL_SPEED = 6 * TILE_SIZE * math.sqrt(GRAVITY_MULTIPLIER)    -- Push speed of one Recoil rune on a normal cast(scaled so rocket jumps keep their height)
PUSH_DECAY = 6                  -- How fast horizontal knockback fades(per second)

AREA_PULL_SPEED = 120           -- Pixels per second a gravity Area pulls enemies toward its center

-- Magic circle shown in the world when a spell is cast
CAST_CIRCLE_SCALE = 0.2         -- Size compared to the editor circle
CAST_CIRCLE_TIME = 1.0          -- Seconds until it fades out
CAST_DRAW_IN_TIME = 0.4         -- Seconds for the circle to draw itself
-- Enemy casts(see magic/enemyCasting): the circle builds part by part(MagicCircle.timeline) before the spell goes off
CAST_RING_TIME = 0.4            -- Seconds a circle takes to spiral in
CAST_RUNE_TIME = 0.3            -- Seconds every rune takes to appear after it
-- Player casts build quicker than enemy ones, cast speed(the Concentration stat, gear later) makes both quicker
PLAYER_CAST_RING_TIME = 0.15
PLAYER_CAST_RUNE_TIME = 0.07
CONCENTRATION_CAST_SPEED = 0.03 -- Cast speed every point of Concentration adds
STRENGTH_ARMOR = 0.05           -- Part of the worn armor defense every point of Strength adds(10 Strength, +50% defense)
CONSTITUTION_HP_REGEN = 0.05    -- HP a second every point of Constitution adds
MIN_CAST_SPEED = 0.2
LASER_RELEASE_FADE = 0.12       -- Seconds a held laser takes to fade after the cast button is let go
ENEMY_CAST_RANGE = 18           -- Tiles an enemy casts at the player from, it needs a clear line to them
ENEMY_CAST_REST = 1.5           -- Seconds after a cast before an enemy starts the next one
ENEMY_CAST_SCALE = 0.3          -- Size of an enemy cast circle compared to the editor circle
ENEMY_CAST_OFFSET = 2.4         -- Tiles in front of the enemy the circle builds, toward the player
CAST_CIRCLE_OFFSET = TILE_SIZE  -- Distance in front of the cast point, toward the aim

-- Mana added to the parent spell cost for each trigger it has, by trigger event
-- The child spell pays its own cost when the trigger happens
TRIGGER_CHAIN_COST = {
    onHit = 3,
    onExpire = 2,
}


DATA_SPACING = 4

CAMERA_RENDER_OFFSET = 20

PLAYER_FILENAME = "player"
MAP_FILENAME = "map"
ENTITIES_FILENAME = "entities_file"
SPELLS_FILENAME = "spells"
INVENTORY_FILENAME = "inventory"
EQUIPMENT_FILENAME = "equipment"
SAVE_FOLDER = "saves"

SPAWN_X = 0.5       -- Relative to world so on a scale of 0-1
SPAWN_Y = 0.1       -- Relative to world so on a scale of 0-1

PLAYER_WIDTH = TILE_SIZE * 0.8
PLAYER_HEIGHT = 2 * TILE_SIZE * 0.98
PLAYER_SKIN = "player"     -- Skin sheet in assets/skins(nil draws the plain colored body)

-- Zombie, a slow humanoid that walks at the player
ZOMBIE_HP = 30
ZOMBIE_SPEED = BASE_MOVE_SPEED * 0.45
ZOMBIE_SIGHT = 14 * TILE_SIZE      -- How close the player has to be for it to start walking at them
ZOMBIE_CONTACT_DAMAGE = 10         -- Touching the player hits them, shown as a swipe(see Zombie:onMeleeHit)

-- Hit reaction and death
HIT_FLASH_TIME = 0.15               -- Seconds an enemy shows the hit tint
HIT_TINT = {1, 0.35, 0.35}
DEATH_FALL_TIME = 0.35              -- Seconds falling over
DEATH_FADE_TIME = 0.6               -- Seconds fading out after it fell
ZOMBIE_SKIN = "zombie"

-- Enemies away from the player freeze where blocks have no hitboxes, unless something is happening to them
ENEMY_AWAKE_TIME = 5            -- Seconds an enemy stays awake after it was last hit
ENEMY_LOAD_RADIUS = 6           -- Tiles around an awake enemy that get hitboxes, so it lands on real ground

-- Spawning(see world_utils/spawner), distances in tiles
SPAWNING = true                 -- Off for a calm world while testing
SPAWN_INTERVAL = 3              -- Seconds between spawn tries
SPAWN_MIN_DISTANCE = 34         -- Columns from the player a spawn happens at least, just off the screen
SPAWN_MAX_DISTANCE = 56
SPAWN_HEIGHT = 16               -- Rows above or below the player a spawn can start looking for ground
SPAWN_CAP = 6                   -- Most spawned enemies near the player at once
SPAWN_CAP_DISTANCE = 80         -- How near counts for the cap
SPAWN_DAY_CHANCE = 0.25         -- By day a surface spawn try only goes ahead this often, nights and caves are full rate
DESPAWN_DISTANCE = 90           -- Spawned enemies further than this from the player start to fade from the world
DESPAWN_TIME = 15               -- Seconds far away before a spawned enemy is gone

-- Contact damage, enemies with contactDamage hurt the player by touching them
CONTACT_IMMUNITY_TIME = 0.8         -- Seconds after a melee hit(touch or swing) when no melee hit can land(spells still can)
CONTACT_KNOCKBACK = 5 * TILE_SIZE   -- Push away from whatever hit, so the player isnt stuck inside it(0 turns it off)
CONTACT_BLINK_RATE = 12             -- Blinks per second while immune

INTERACT_DISTANCE = 5

MAP_X = 1000        -- The world is infinite sideways, this only sets where column 0 sits in map coordinates
MAP_Y = 5000        -- Height of the world in tiles, bedrock at the bottom

-- World generation(tile rows grow downward, row 0 is the old flat ground)
CHUNK_SIZE = 32         -- Map cells per chunk side, chunks generate the first time they are needed
CHUNK_UNLOAD_DISTANCE = 3   -- Chunks further than this many chunks from the player go back to compact data
CHUNK_UNLOAD_INTERVAL = 2   -- Seconds between checks for chunks to unload
SURFACE_ROW = 0         -- Lowest the ground surface goes, hills rise above it
HILL_HEIGHT = 14        -- How many tiles hills rise above SURFACE_ROW
DIRT_DEPTH = 4          -- Dirt layers under the grass before the stone starts
CAVE_START_DEPTH = 10   -- No caves this close to the surface
ORE_START_DEPTH = 20    -- Ore only this deep under the surface
ORE_THRESHOLD = 0.74    -- Noise above this is ore, 0.74 is about 2% of the deep stone(0.70 is about 5%)
BEDROCK_ROWS = 3        -- Unbreakable rows at the bottom of the world

-- Items and inventory(see items/ and world_utils/drops)
INVENTORY_SIZE = 40             -- Slots, 4 rows of 10
PLACE_REACH = 6 * TILE_SIZE     -- How far from the player blocks can be placed
PLACE_INTERVAL = 0.12           -- Seconds between blocks while the place button is held
PLACE_OK_COLOR = {0.4, 1, 0.5, 0.9}
PLACE_BLOCKED_COLOR = {1, 0.35, 0.35, 0.9}
HOTBAR_SIZE = 10                -- The first row of the inventory is the hotbar, picked with 1-9 and 0
-- Armor slots in the order they show, name is the key in the equipment component and armor.slot of the items
ARMOR_SLOTS = {
    {name = "head", label = "Helmet"},
    {name = "chest", label = "Chest"},
    {name = "legs", label = "Leggings"},
    {name = "feet", label = "Boots"},
}
-- Hand slots next to the armor: wands and staves(see items/tools), a staff takes both hands
HAND_SLOTS = {
    {name = "mainHand", label = "Main"},
    {name = "offHand", label = "Off"},
}
BARE_HANDS_DIG_CAP = 10         -- Hardest block a spell can damage without a wand or staff, below 10(dirt, sand, snow, sandstone, not stone)
OFF_HAND_SHARE = 1              -- How much of what it does on its own an off hand wand adds to the main one
-- What the tool kind does to every spell before its parts: wands are faster and weaker, staves slower and stronger
-- Wands also give mana regen(per second, each wand) to keep up with casting fast
TOOL_KINDS = {
    Wand = {damage = 0.85, cooldown = 0.8, manaRegen = 3},
    Staff = {damage = 1.3, cooldown = 1.25, manaRegen = 0},
}
RESPAWN_TIME = 3                -- Seconds dead before the player is back at its spawn, nothing else is lost for now
BASE_CRIT_CHANCE = 0.05        -- Part of hits that crit(spell hits, lightning jumps and every burn and poison tick roll)
CRIT_MULTIPLIER = 2             -- A crit deals this many times the damage
DEFENSE_SCALE = 50            -- Damage blocked is defense / (defense + this): 10 defense blocks about 17%, 50 blocks half
ITEM_STACK = 99                 -- Most items in one slot, items can set their own maxStack
ITEM_DROP_SIZE = 14             -- Pixels, the icon of an item lying in the world
ITEM_POP_SPEED = 3 * TILE_SIZE  -- How hard a drop jumps out of a broken block
ITEM_DROP_DAMPING = 0.5
ITEM_PICKUP_DELAY = 0.4         -- Seconds before a new drop can fly to the player, so it is seen popping out
ITEM_THROW_DELAY = 2            -- Seconds before a thrown item can be picked up again, so it doesnt come right back
ITEM_MAGNET_DISTANCE = 3 * TILE_SIZE    -- Drops this close fly to the player
ITEM_MAGNET_SPEED = 9 * TILE_SIZE
ITEM_PICKUP_DISTANCE = 0.75 * TILE_SIZE -- Drops this close go into the inventory
ITEM_MERGE_DISTANCE = 0.8 * TILE_SIZE   -- Drops of the same item this close become one
ITEM_MERGE_INTERVAL = 0.5       -- Seconds between merge checks
ITEM_LIFETIME = 300             -- Seconds a drop lies in the world before it disappears
ITEM_PICKUP_SHOW_TIME = 1.2     -- Seconds the "+3 Dirt" line shows over the player

-- Day and night(see world_utils/worldClock)
DAY_LENGTH = 20 * 60            -- Seconds in a day for new worlds, saved with the world so changing it never changes old ones
DAY_START = 0.35                -- Part of the day a new world starts at, morning
-- Moments of the day and where they are(0 midnight, 0.5 noon), values blend between neighbors
-- A moment can repeat to hold a look for a while: night lasts from 0.82 around midnight to 0.18
TIME_KEYS = {
    {"night", 0}, {"night", 0.18}, {"dawn", 0.25}, {"day", 0.32}, {"day", 0.68}, {"dusk", 0.75}, {"night", 0.82},
}
-- Background colors a biome gives for the day are tinted by these at other moments, unless it gives its own per moment
SKY_TINT = {night = {0.12, 0.14, 0.3}, dawn = {1, 0.72, 0.7}, day = {1, 1, 1}, dusk = {1, 0.6, 0.45}}
HILL_TINT = {night = {0.2, 0.22, 0.38}, dawn = {0.85, 0.7, 0.7}, day = {1, 1, 1}, dusk = {0.85, 0.6, 0.5}}
-- Light of the sky over the world(blocks, creatures), spells are drawn after it so they glow at night
AMBIENT_LIGHT = {night = {0.32, 0.35, 0.55}, dawn = {0.85, 0.78, 0.78}, day = {1, 1, 1}, dusk = {0.92, 0.72, 0.62}}

-- Tile light(see world_utils/lighting): light spreads from tile to tile, keeping this much of itself each tile
LIGHT_AIR_DECAY = 0.86          -- Through air and walk-through blocks(a full light fades out in about 15 tiles)
LIGHT_SOLID_DECAY = 0.5         -- Through solid blocks, the first block of a wall is lit and the inside stays dark
LIGHT_PASSES = 2                -- Spreading sweeps each frame, more lets light turn more corners
LIGHT_MARGIN = 16               -- Tiles past the screen edge the light is worked out for, so lights off screen reach in
LIGHT_SNAP = 8                  -- The light grid moves in steps of this many tiles(the map is read again when it moves)
WALL_START = 2                  -- Tiles under the surface where the cave walls start, the open air above them sees the sky
-- Light sources, colors at full strength
PLAYER_LIGHT = {0.3, 0.28, 0.26}    -- A dim glow around the player, darkness is never fully blind
TORCH_LIGHT = {1, 0.72, 0.42}
FORGE_LIGHT = {0.8, 0.42, 0.18}
ARCANITE_LIGHT = {0.22, 0.5, 0.65}  -- Glowing ore, it shows where the deep ore is
SPELL_LIGHT = 0.3               -- Strength of the glow of a spell in its color, faint so a bullet doesnt light a cave
AREA_LIGHT = 0.45               -- A burst lights more around it while it lasts
LASER_LIGHT = 0.25              -- Every tile along a beam
LIGHT_RUNE_GLOW = 0.8           -- Strength every Light rune adds to a spell light(above 1 it reaches further)

-- Mana blocks(the Block form, see forms/blockForm)
MANA_BLOCK_TIME = 60            -- Seconds a mana block lasts
DECELERATE_BLOCK_TIME = 60      -- Seconds every Decelerate rune adds
DECELERATE_BLOCK_MANA = 4       -- Mana every Decelerate rune adds to the block, until it is permanent(more add nothing)
MANA_BLOCK_PERMANENT = 180      -- Lasting longer than this it stays for good, a plain block that drops nothing
MANA_BLOCK_DIG_HP = 4           -- Every Dig rune multiplies its hp(1 hp breaks to any spell)
BLOCK_CAST_REACH = 0.5          -- Tiles in front of the hands a directly cast block goes, like where a bullet starts
MANA_BLOCK_CONTACT_SCALE = 0.1  -- Part of an enemy touch damage a mana block takes(a zombie takes 1 hp a swipe, like a spell)
-- How bright the stars in the sky are
STAR_ALPHA = {night = 1, dawn = 0.15, day = 0, dusk = 0.3}
STAR_COUNT = 160

-- Biomes(see world_utils/biomes and the biomes folder)
UNDERGROUND_DEPTH = 45  -- Tiles under the surface where the underground layers take over from the surface biome
UNDERGROUND_WOBBLE = 8  -- Tiles the underground border moves up and down, so it isnt a straight line
DEEP_DEPTH = 400        -- Tiles under the surface where the deep layer starts
BIOME_BLEND = 12        -- Tiles on each side of a biome border where the terrain height blends
BIOME_BLOCK_WOBBLE = 5  -- Tiles the block side of a biome border moves left and right from row to row
BIOME_BORDER_JITTER = 0.6   -- How much biome borders move, as a part of the biome width(below 1 keeps them in order)
-- Biome size choices when making a world, the world saves the width itself so changing these never changes old worlds
BIOME_SIZES = {
    {"Small", 90},
    {"Medium", 220},
    {"Large", 600},
}
DEFAULT_BIOME_SIZE = 2      -- Index in BIOME_SIZES

-- Runes that were renamed, saves with the old name load the new rune(spells, knowledge)
RUNE_RENAMES = {Slow = "Decelerate"}

-- Rune knowledge(see magic/knowledge): unknown runes cant be drawn, discovered ones are drawn from memory,
-- templated ones have a trace guide and a quality floor
ALL_RUNES_TEMPLATED = true      -- Every rune starts templated, for testing, until glyph walls and bosses are in the world
STARTING_RUNES = {"Bullet", "Damage", "Dig"}    -- What a new character knows(templated) once that is off
TEMPLATE_QUALITY = 0.7          -- A templated rune always counts as drawn at least this well

-- Crafting(see items/crafting and the recipes folder)
CRAFT_TIERS = {"Basic", "Copper", "Iron", "Gold", "Arcanite"}  -- Recipe tiers in the order the crafting list shows them

-- Trees and plants(see world_utils/flora)
FLORA_VERSION = 1       -- Saved with new worlds, worlds without it grow no trees or plants so their saved chunks still match
TREE_CELL = 8           -- Columns per tree spot, each spot has at most one tree so canopies never touch
ROOT_HP_SCALE = 4       -- A block with a tree or cactus growing on it takes this many times longer to break

PLAYER_CATEGORY = 2
BLOCKS_CATEGORY = 3
SPELLS_CATEGORY = 4
ENEMY_CATEGORY = 5
ITEM_CATEGORY = 6       -- Dropped items, they only collide with blocks

IN_WORLD_STATE = "IN_WORLD"
PICK_WORKD_STATE = "PICK_WORLD"
MENU_STATE = "MENU"