DEBUG = false

SCREEN_X  = 1920
SCREEN_Y  = 1080

TILE_SIZE = 32
TILES_PER_METER = 1

GRAVITY_MULTIPLIER = 2.5       -- Real world gravity felt too floaty, this makes falling snappier
GRAVITY = 9.8 * TILE_SIZE * TILES_PER_METER * GRAVITY_MULTIPLIER
MAX_FALL_SPEED = 20 * TILE_SIZE -- Gravity stops speeding entities up past this, other pushes can still go faster
LINEAR_DAMPING = 0.2
JUMP_GRAVITY_SCALE = 0.4        -- Gravity while rising with the jump key held

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
}

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

INTERACT_DISTANCE = 5

MAP_X = 1000        -- The world is infinite sideways, this only sets where column 0 sits in map coordinates
MAP_Y = 5000        -- Height of the world in tiles, bedrock at the bottom

-- World generation(tile rows grow downward, row 0 is the old flat ground)
CHUNK_SIZE = 32         -- Map cells per chunk side, chunks generate the first time they are needed
SURFACE_ROW = 0         -- Lowest the ground surface goes, hills rise above it
HILL_HEIGHT = 14        -- How many tiles hills rise above SURFACE_ROW
DIRT_DEPTH = 4          -- Dirt layers under the grass before the stone starts
CAVE_START_DEPTH = 10   -- No caves this close to the surface
ORE_START_DEPTH = 20    -- Ore only this deep under the surface
ORE_THRESHOLD = 0.74    -- Noise above this is ore, 0.74 is about 2% of the deep stone(0.70 is about 5%)
BEDROCK_ROWS = 3        -- Unbreakable rows at the bottom of the world

PLAYER_CATEGORY = 2
BLOCKS_CATEGORY = 3
SPELLS_CATEGORY = 4
ENEMY_CATEGORY = 5

IN_WORLD_STATE = "IN_WORLD"
PICK_WORKD_STATE = "PICK_WORLD"
MENU_STATE = "MENU"