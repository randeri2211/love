DEBUG = false
DEBUG_ONE_HIT_BLOCKS = true     -- With DEBUG on, any hit breaks a block(bedrock still cant break), for digging around in development

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
}

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

PLAYER_CATEGORY = 2
BLOCKS_CATEGORY = 3
SPELLS_CATEGORY = 4
ENEMY_CATEGORY = 5

IN_WORLD_STATE = "IN_WORLD"
PICK_WORKD_STATE = "PICK_WORLD"
MENU_STATE = "MENU"