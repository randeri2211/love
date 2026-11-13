# Game Design

The plan for the game as a whole: what is decided, what is still open, and the order to build it in.
Rune marks have their own file, `docs/rune-marks.md`.

**Vision:** a very sandboxy magic game. Every step should branch into many options to try, and skill at drawing runes is rewarded on top of gear progression.

Status: **Decided** is agreed and ready to build, **Done** is in the game, **Open** still needs a decision.

---

## Rune knowledge and the grimoire

Players can reach the whole skill tree early, but stronger and easier versions open with progression.

### Three states per rune (Decided)

| State | Grimoire | Spell editor | How it is reached |
|---|---|---|---|
| **Unknown** | Not listed | Not in the rune list, **drawing it does nothing** | Start state |
| **Discovered** | Shows the shape (and its marks) | Can be drawn freehand, no trace guide | Reading a glyph wall |
| **Templated** | Shows the shape | The trace guide ("click a rune to trace it") is available | Boss kill or quest |

- **Unknown runes cannot be cast**, even when drawn correctly from a wiki or a friend. The recognizer only matches discovered runes, so glyph walls are a real progression gate.
- The reward for skilled players is drawing a **discovered** rune freehand before its template unlocks.
- **Starting knowledge:** Bullet, Damage and Dig start discovered *and* templated, so the first minutes teach drawing with a guide.
- **Marks:** all marks start discovered for now. Gating them can be added to the plan later.

### Glyph walls (Decided, a tribute to Skyrim's Word Walls)

| Skyrim | This game |
|---|---|
| A Word Wall teaches the word | A glyph wall in a boss arena adds the rune to the grimoire |
| A dragon soul unlocks it | A boss kill or quest unlocks the template |

### Templates (Decided)
- A traced rune always counts as at least **about 70% quality**. Good freehand drawing can still reach 100%.
  New players get spells that reliably work, skilled players stay ahead before and after the template.

### Where the walls go (Decided)
Each rune's wall sits in a structure in the biome that fits it (Gravity in deep caves, Speed on desert plains). Built in two steps:
1. **Now:** shrine structures in world generation holding a wall, maybe guarded by tougher normal enemies.
2. **Later:** bosses move into those arenas.

Structure generation is the dependency (it doesn't exist yet, ruins and loot chests need it too).

### The grimoire screen (Decided)
For every discovered rune:
- its shape and all of its marks
- its state (discovered or templated)
- which forms it works with
- its mana cost and complexity
- where its wall was found
- one line of lore

The shapes can reuse the spell editor's rune drawing code.

### Built (placeholder walls)
- **Done:** the three states(`magic/knowledge`), saved with the player. Unknown runes are not listed or recognized in the spell editor,
  only templated runes can be traced, templated runes never count as drawn worse than `TEMPLATE_QUALITY`.
- **Done:** the grimoire(`ui/grimoire`, key B): every rune as a known glyph or a blank, a page with the shape, state, cost, forms, marks,
  where it was found and its lore. Every rune file carries its own page text: `lore`, `markHelp` and `affectsHelp`.
- **Placeholder:** `GlyphWall` blocks teach their rune when read(interact key). The development key J places one at the mouse and F forgets
  every rune but the starting ones. Real shrines come with boss arenas in world generation.
- For testing `ALL_RUNES_TEMPLATED` is on: every rune starts templated, `STARTING_RUNES` is what a character starts with once it is off.

### Building notes
- Knowledge is per world: `{runeName = "discovered" | "templated"}` on the player, saved with the world.
- The spell editor's rune list and the recognizer read it. The trace guide only shows for templated runes.
- Walls are something to interact with (`INTERACT_KEY`) inside a generated structure.

---

## Mining progression (Decided)

**Done: only the casting tool decides what can be mined.** A block takes damage when its hardness(`damageThreshold`) is
**below the dig cap** of the wand or staff the spell was cast with(`Block:damage`, `Form:digReach`), bare hands have 10.
The spell itself, its damage and Dig runes, only decides how fast: the HP a hit takes from the block(`damage × terrainDamage`).
Trigger spells inherit the cap from the spell that cast them, so an OnHit chain can't get around it.

(Before this, hardness was checked against a dig strength made from the spell damage, so stacking Dig runes opened every ore
on day one, and the wand damage multiplier made wands worse miners than staves. Both are gone.)

Tiers (each cap is one point above the block it opens):

| Casting tool core | Dig cap | Newly mineable |
|---|---|---|
| Bare hands | 10 | Dirt, sand, snow, sandstone |
| Wood | 15 | Stone, copper |
| Copper | 21 | Deepstone, iron |
| Iron | 26 | Gold |
| Gold | 31 | Deep gold |
| Boss drop | 36 | Arcanite |

---

## Wands and staves

### Decided
- **Wands and staves go in equipment slots** (main hand and off hand, next to the armor), not the hotbar.
  Left click always casts with what is equipped, right click always places blocks, so building and casting never compete. No wand equipped means casting barehanded (dig cap 10).
- **Dual wielding:** a second wand in the off hand **does not cast a spell of its own**.
  It adds **all of its overall stats** on top of the main wand(`OFF_HAND_SHARE = 1`): its wand base and all of its parts, as it would be on its own.
  Two caps match one staff tip(a tip does twice a cap), so dual wands and a staff cost and give about the same in parts;
  the difference is the base: two wands hit for 0.72x every 0.64x the cooldown(the fast build), a staff 1.3x every 1.25x(the big hits).
- **Wands give mana regen**(+3/s each, `TOOL_KINDS`) instead of cheaper casts, to keep up with casting fast. Staves give none,
  they are the mana efficient choice already(fewer, bigger casts).
- **Wands are modular** and built from parts, and each part is responsible for different stats and optional rune bonuses.
  Plain materials do nothing special (wood), special ones add an effect (a bloodwood rod gives life leech on hit).
- **Staves are slower and stronger, wands weaker and faster** with more mana regen and on-hit bonuses. Staves can favour a form or rune.
- **Wand parts:** rod, magic core, end cap (3 parts).
- **Staff parts:** large rod, **2 magic cores**, tip (4 parts). Two cores make a staff cost the same as two wands.
  The staff's dig cap is the **higher** of its two cores, not their sum.
  Tips come in different shapes with different bonus options, from drops and crafting.
- A staff is two-handed, so it takes the off hand too and can't be dual-wielded.

### Crafting the parts and the wand (Decided)
- **Woodworking station:** makes the rods (and large rods).
- **Arcane table:** puts wands and staves together, and takes them apart.

Arcane table screen:
- Pick **Wand** or **Staff**. The input slots are laid out in the shape of the tool: 3 slots for a wand, 4 for a staff. There is 1 output slot.
- **Assembling:** fill the inputs and the finished tool shows in the output. Taking it from the output uses up the parts.
- **Taking apart:** put an existing wand or staff in the output slot and its parts show in the input slots.
  Taking one part out makes the tool disappear (the other parts stay in their slots).
- Swapping one part is then: put the wand in, take out the old part, put in the new one, take the new wand. Nothing is lost.

### Proposed part roles
Each part answers a different question:

| Part | Answers | Examples |
|---|---|---|
| **Rod** (wood types) | How does it feel? Cast speed and a special effect | Oak: nothing. Bloodwood: life leech on hit. Ironbark: knockback. Frostpine: slow on hit |
| **Magic core** (gems, refined ore) | How powerful is it? **Dig cap**, max complexity, maybe how deep trigger chains can go | Copper core: cap 21. Iron core: cap 26. Arcanite (boss): cap 36 |
| **End cap** (metals, trophies) | What does it favour? Mana cost, cooldown, crit, a rune or form bonus | Gold cap: −15% mana cost. Fang cap: +crit. Prism cap: +laser width |

The dig cap on the core keeps ore progression in one place. Rods and caps are sideways choices, so no tier is just the best one.
A staff being two-handed (no dual wield) gives it a clear identity against wands.

### Decided (details)
- **Dig cap with two wands:** the higher of the main and off-hand cores, like a staff.
- **Staff cores both count at full strength.** It makes up for having only one rod and one tip, against dual wands at 100% + 50%.
  If that turns out unbalanced, a primary and a secondary core can be added later.

### Blocks with item slots keep their items (Decided, applies to every such block)
Items left in a block's slots **stay in the block** when its screen closes, so the block works as a small storage until they are taken out.
This is the same for every block with a screen and slots (arcane table, future stations, chests).

- The arcane table stores what it really holds: either parts in the inputs, or a whole tool in the output (its parts shown are only a view of it).
- Breaking such a block **drops its items into the world** (as dropped items, like the block itself).

### Building notes
- A wand is the first item with data of its own: `{item = "Wand", count = 1, parts = {rod = "Bloodwood", core = "IronCore", cap = "GoldCap"}}`.
  The inventory, saving and display names ("Bloodwood Wand") need to handle stacks with extra fields.
- Equipment gets `mainHand` and `offHand` slots next to the armor (`ARMOR_SLOTS`, `Equipments.fits`):
  a wand fits either, a staff only fits the main hand and needs the off hand empty.
- The arcane table output is worked out from the inputs every time something changes, so assembling and taking apart are one rule.
- Saving is already there: a chunk saves the whole block when `Block:hasOwnState()` is true (damaged blocks use it today, and its comment already names chests).
  A block with slots only has to return true while it holds something.
- One shared "block with slots" piece (slots data, the screen, `hasOwnState`, dropping on break) keeps every station and chest the same.
- Gear stats need one generic path into the compiled spell (in `compile`/`shoot`), so every new part or trinket is a data line.

---

## Casting

- **Every cast winds up:** the circle builds part by part(`MagicCircle.timeline`): the ring spirals in, then every rune in flow order,
  a trigger rune hands over to its child circle, which builds fully before the parent goes on. The spell goes off when it is done.
  Letting go, switching spells or being frozen solid cancels it, the mana is only paid when it goes off.
- Player times are quick(ring 0.15s, rune 0.07s), enemies slower(0.4s, 0.3s) so their casts can be read and dodged.
- **Cast speed** divides those times: Concentration adds 3% a point, gear(`castSpeed`) can add more later.
- **Laser is held:** it winds up once, then the beam stays while the button is held and follows the aim every frame.
  Its cooldown is how often it hits each thing(and digs each block), the spell mana is paid once per cooldown, Recoil pushes once per cooldown.
- **Enemies cast too**(magic/enemyCasting): a mana bar and regen, a spell list(one spell for now), the same wind-up in front of them,
  only a full freeze breaks their cast, their spells hit the player and other enemies. The first real casting enemy is still to be picked.

## Gear

### Ores (Done in part)
Several ores at different depths with different hardnesses. Copper, Iron, Gold, Deep Gold and Arcanite are generated today.

### Armor sets by crafting station (Decided)

| Station | Set focus |
|---|---|
| **Loom** | Mage armor: mana and spell damage |
| **Forge** | Area armor: more resistances, maybe Area form buffs |
| **Tanning table** | Crit and cooldown reduction |
| **Woodworking** | Staves and wands |

- Sets give a **set bonus** plus **individual piece bonuses**: mana regen, health regen, intelligence, speed and so on.
- **Done:** Copper and Iron armor, defense as diminishing damage reduction.

- **Done: item sets** (`items/sets`): armor pieces name their set, 2 and 4 worn pieces turn on its bonuses.
  Copper: +8 every resistance / Area spells 20% bigger. Iron: +4 defense / +12 every resistance and Area spells 30% bigger.
  Tooltips show the set with the tiers you have lit, the character screen lists the active bonuses.

### Trinkets and focuses (Done in part)
More creative bonuses: laser speed and width, area growth rate, Split amplification and so on.

- **Slots:** two trinket slots (two different trinkets) and one focus slot, on a row under the armor and the hands.
- **Effects:** sets, trinkets and focuses carry the same kind of effect (`items/sets` explains the format): stats,
  defense, resistances, crit, cast speed, mana cost, cooldown, complexity, mana regen, and **spell modifiers** that change
  a form's (or any form's) params when it is cast, optionally only when the spell has something (`when`, like Fire).
- **A focus** can be about an element, a form or casting itself.
- **First ones** (`items/trinkets`): Glass Lens (lasers 40% wider), Sand Hourglass (Area grows 40% faster), Prism (Split fans
  one more), Feather Charm (bullets 30% faster); Ember Focus (Fire 30% hotter, burns spread once more), Lancer Focus
  (lasers +25% damage, 20% wider), Arcane Focus (+20% cast speed, 10% cheaper spells).
- **Where they come from** is decided per item as they are added (structure chests, crafting, rare drops).
  For now camp chests can hold the Feather and the Hourglass, tower chests the Lens, the Prism and the focuses.

### Boss drops (Open)
Some set items and trinkets are boss drops. Which ones and why is decided once bosses exist.

---

## Still missing (from the planning review)

| # | Gap | Why it matters |
|---|---|---|
| 1 | **Raw materials:** trees (wood), plants or silk (fibre), enemy drops (hides), gems | Every crafting station needs inputs, and they give biomes a reason to visit. **Done:** oak, pine, cactus and tall grass (see `world_utils/flora`), enemy loot tables (empty for now). Still to come: hides, gems |
| 2 | **Crafting core:** recipe registry, a "near a station" check, a crafting screen | Stations do nothing without it. **Done:** recipes folder (`registerRecipe`), stations within interaction distance, a crafting list in the Tab screen by tier and category, Woodworking Station and Forge, bars and rods |
| 3 | **Damage types, crit and status effects** | Forge resistances and tanning crit have nothing to work on yet (elements are decided, see below) |
| 4 | **Light:** torches and light from spells | Night and underground are dark, and deep ores are planned. **Done:** tile light (see Light below). |
| 5 | **Storage and home:** chests, spawn point or bed, the respawn timer | Basic sandbox loop (death itself is decided, see below). **Done:** chests (see Storage below) and the respawn timer. Still to come: a bed or spawn point |
| 6 | **Spawner and enemy roster:** biome and depth buckets, night spawns, enemies that cast runes | Materials and bosses depend on enemy variety. **Done:** spawner(off screen, biome lists, cap, calmer days, temporary spawns), Scorched, Frostbitten and Rotting zombies. Still to come: day animals for hides, enemies that cast runes |
| 7 | **Consumables:** potions from an alchemy station | Mana economy, and a second use for plants |
| 8 | **Sound and onboarding** | No audio yet. Drawing runes is a skill, so it needs teaching |

### Damage types (Done): element runes
Elements are **modifier runes**, by the rule in `rune-marks.md`: a new behavior that makes sense on 2+ forms is a modifier rune.
Tying elements to forms would remove a choice, a fire laser and a frost laser should both be possible builds.

| Rune | Effect | Look |
|---|---|---|
| Fire | Burn damage over time | Red-orange glow, fire particles |
| Frost (ice) | Slows the target and shatters: hits on it deal +25% (the Decelerate rune slows the spell itself) | Pale blue glow, frost particles |
| Poison | Poison damage over time | Green glow, poison particles |
| Lightning | Chains to a nearby enemy | Yellow-white glow, sparks |
| (none) | Plain damage stays the default arcane type | As today |

- **Every element changes how the spell looks on every form:** a fire laser has red particles along the beam, a fire bullet glows red and trails fire particles, and so on for each element.
- **Done:** resistances per element, blocking `r / (r + 50)` of that element like defense blocks plain damage(below 0 is a weakness).
  Armor blocks plain damage, resistances block element damage(burn and poison ticks, lightning jumps, elemental touches).
  Armor pieces can carry `resist`, enemies `resistances`, an elemental touch(`contactElement`, `contactElements`) hurts and leaves statuses.
- **Done:** crit, 5% base chance for 200% damage, spell hits, lightning jumps and every burn and poison tick roll.
- Still to come: forge armor with resistances, biome enemies that resist or are weak to elements, tanning table crit sets.
- **Done:** Fire burns 4/s for 3s(refreshes), Frost slows 40% for 3s, Poison 2/s for 8s stacking to x3, Lightning jumps 50% of the hit
  to 2 enemies within 6 tiles. Damage before an element makes it stronger, Size makes it last longer(or jump further), Weaken weakens it.
  The numbers are in `magic/elements`, the status rules in `magic/statuses`, the look in `magic/elementFx`.
- **Each element at most once per circle:** a second Fire rune in the same circle is refused (shown as blocked in the editor).
  Each trigger circle counts on its own, so an OnHit child circle can have its own Fire.
- **Different elements can share a circle:** a Fire + Frost bullet burns and slows.
- **Other runes power up elements through the mana flow,** with the rune-to-rune `affects` that Focus already uses on Split:
  a rune affects the elements placed **after** it, so Damage before Fire makes a stronger burn.

### Light (Done in part)
Tile light, colored (`world_utils/lighting`): every tile around the screen gets a light level and the world is multiplied by it.

- **Sky:** open air above the cave walls is as bright as the time of day (`AMBIENT_LIGHT`), the ground right under it too.
- **Spreading:** light keeps 86% of itself per tile of air and 50% per solid block, so a wall's first block is lit and the ground's inside is dark.
- **Sources:** torches (walk-through, 4 from 1 wood by hand, fall off when their block breaks, interact picks one up),
  the Forge, Arcanite ore (a faint blue glow that shows where it is), a dim glow around the player, and spells.
- **Spells give only a faint glow** in their color (Area a bit more while it lasts, Laser along the beam), so a bullet doesnt light a cave.

### Light magic (Done)
Room for magic in the light system, the user's idea:
- **Done: the Light rune** (a sun glyph, 1 complexity and 1 mana, works on every form). It makes a spell a real light source
  in its color, every Light rune after the first reaches further (`LIGHT_RUNE_GLOW`).
  - **Trap + Light** is a magic torch while the trap lasts (15s).
  - **Self + Light** makes its target glow, the caster or, through OnHit, the enemy it hit. Size makes it last longer.
- **Done: the Block form** (two nested squares, 3 complexity and 4 mana) makes a solid **mana block** in the spell color
  (`forms/blockForm`, `blocks/manaBlock`). With Light it is a magic light source you place with a spell.
  - **Cast directly** it appears in the tile just in front of the hands, where a bullet would start (the hands tile when that
    one is solid). Whoever is in that tile is pushed out: onto it first, else a step to either side, a step up to either side,
    or under it. With no tile or no room for them the cast fails before mana or cooldown is paid.
  - **Triggered** (OnHit → Block) it fills the empty tile in front of the hit surface, where an OnHit bullet would start.
  - **Lasts 60s.** Every Decelerate adds 60s, past 180s (three of them) it is **permanent**: a plain block saved with the map.
    Every Decelerate also adds 4 mana until the block is permanent, so a longer block costs more and a permanent one the most
    (4 / 8 / 12 / 16 mana). Decelerate past permanent adds nothing.
    A timed block is not saved, it is gone after loading. The editor shows a permanent one as "Permanent".
  - **1 hp and no hardness**, any spell clears it. Every Dig rune multiplies its hp by 4. It never drops anything.
  - **Enemies claw at it:** an enemy pushing against one hits it with its touch once per contact cooldown, at a tenth of the
    touch damage (a zombie takes 1 hp a swipe, like a plain spell), setting off its onHit.
  - **Triggers on it:** onHit every time it is damaged, onExpire when it is gone (broken or timed out), permanent blocks too.
    OnHit children are aimed at the attacker: the caster of the spell that hit it, or the enemy clawing at it
    (back the way the spell came when its caster is gone). OnExpire children go the way the block was cast.
    They are cast by whoever made the block and paid from their mana like any trigger. A permanent block saves its spell,
    one the player made always casts from the player (after loading or a respawn too).
  - Only Decelerate, Dig and Light work on it (`BlockRune.allows`), the editor shows the rest as blocked.

### Early game: experience, enemies and structures (Decided)
Enemies get stronger the further they are from spawn and the deeper they are, give more experience, and many of them live in
structures placed by world generation.

- **Experience and levels:** XP from killing enemies (scaled by their level), clearing a structure (when its last guard dies)
  and learning a rune you didn't know. A level up gives **stat points to spend** on the six stats.
- **Enemy levels:** from the horizontal distance to spawn and the depth, like ores get better deeper down.
  An enemy follows the player's rules: its level gives it the stat points a player of that level would have,
  spread by a fixed **build** per enemy type, so its stats scale everything (HP, touch, speed, spell damage, mana, cast speed).
- **Done (phase 1)** (`components/stats/levels`): XP to the next level is `100 x level^1.5` (100, 283, 520, 800...),
  3 stat points a level, spent with the + on the character screen, an XP bar under mana, enemies show their level.
  Enemies are one level higher every 200 tiles from spawn and every 100 tiles underground, a zombie gives 10 XP x its level
  and puts its points 5:3:2 into Constitution, Strength and Swiftness. A new rune gives 50 XP.
  Constitution now gives +5 HP a point, Strength also strengthens a creature's touch (+5% a point).
- **Done (phase 2)**, in the open world:
  - **Slimes** (`entities/slime`): big, medium and small, all three spawn; a big one splits into two medium, a medium into
    two small (the halves keep its level). They sit, squash and hop at the player. Surface by day and night,
    colored by the biome (green, sand in the desert, pale in the snow).
  - **Cave bats** (`entities/bat`): fly at the player in a wavy line, bite, fly off for a moment and swoop again. Caves only.
  - **Skeleton archers** (`entities/skeletonArcher`): the zombie body with a skeleton skin, keep 5 to 11 tiles away,
    draw a bow and shoot arrows aimed for their arc. Surface at night and in caves.
  - **Arrows** (`world_utils/projectiles`) are real projectiles, not spells: plain damage (armor blocks it), stronger with
    the archer's Strength, they stick in blocks for 3s, and a mana block in the way takes the hit and fires back.
    An archer that cant see the player doesnt shoot, so a mana block wall is cover.
- **Done (phases 3 and 4)**, the structure system (`world_utils/structures`, a `structures/` folder registered like biomes):
  - Each type has its own grid of cells along the world; the seed decides if a cell has one, where, and (surface) only on
    ground flat enough. Rarer types are placed first, none overlap, none within 60 tiles of spawn.
    Worlds made before structures (no `structures` setting) never get them.
  - A chunk being made writes in its part of every structure over it, from the blueprint (one character per block,
    `.` air, a space keeps the world, `,` air with a back wall drawn behind it). Ruins lose some blocks, from the top down.
  - Chests get seeded loot, glyph walls a rune the player doesnt start with, guard spots spawn guards with the
    structure's level. Guards are saved, never despawn, and when the last dies the structure is cleared for good
    (a message and 20 XP x its level).
  - New blocks: stone bricks (need an iron dig cap), cracked stone bricks, planks, a campfire (gives light).
  - **Ruined camp** (about one per 340 columns): broken walls, a plank lean-to, a campfire, a wooden chest, 3 guards
    (the biome's zombies or skeleton archers). **Slime pit** (caves 25 to 100 deep, about one per 320 columns): a pocket
    with 6 slimes and a copper or iron vein. **Mage tower** (about one per 940 columns): three floors joined by a
    stairwell of ledges, torches, 4 apprentice mages, an iron chest and a glyph wall at the top.
  - **Apprentice mage** (`entities/apprenticeMage`): the first real caster, keeps its distance and builds a cast circle
    for a fire or frost bullet, its points go into Intelligence and Concentration.
- **New enemies:** Slime (hops, splits into two small slimes when killed), Cave bat (flies in caves, swoops),
  Skeleton archer (keeps its distance, shoots arrows), **Apprentice mage** (the first real caster: builds a cast circle, casts a simple spell).
- **Structures**, placed from the seed per chunk like ores and trees, laid out from blueprints. Their guards spawn once,
  **a cleared structure stays cleared** (saved with the map), the open world spawner keeps making normal enemies:
  - **Ruined camp** (surface): broken walls and a campfire, zombies or skeleton archers around a wooden chest.
  - **Slime pit** (caves): a cave pocket full of slimes with an ore vein.
  - **Mage tower** (surface): a stone tower with apprentice mages on its floors and a glyph wall at the top, clearing it teaches a rune.
  - **Later: a castle** with zombie knights, a large structure once the system has proven itself.
- **Build order:** 1) XP, levels and enemy levels, 2) slime, bat and skeleton archer in the open world, 3) the structure system
  (blueprints, new blocks, guards and cleared state, chest loot), 4) the camp, slime pit and mage tower.

### Storage (Done)
Chests (`blocks/chestBlock`, `ui/chestPanel`), opened with the interact key next to the inventory, rows as wide as the inventory:

| Chest | Rows | Made from | Station |
|---|---|---|---|
| Wooden Chest | 4 | 12 wood | Woodworking Station |
| Iron Chest | 6 | a Wooden Chest + 8 iron bars | Forge |
| Arcanite Chest | 10 | an Iron Chest + 8 arcanite bars (it glows faintly) | Forge |

- **Only an empty chest breaks**, so a stray spell never scatters what it holds.
- **Crafting uses every chest within interaction distance**, nearest first, then the inventory, so what you carry stays with you.
- **Moving items:** Shift+click sends a stack between the chest and the inventory. The chest has Store all, Store matching
  (only items it already holds) and Take all. **Quick stack** on the inventory sends every item to any chest in reach
  that already holds that item and has room.
- **Locked slots:** Ctrl+click locks an inventory slot (saved with the inventory). Storing to chests leaves locked slots and the hotbar alone.

### Death (Decided)
For now **no punishment**: the player respawns after a respawn timer.

Later: a **per-world death setting** chosen when making the world and saved with it, like the biome size:

| Setting | On death |
|---|---|
| Gentle | Nothing lost, respawn after the timer (today's behavior) |
| Normal | Inventory items drop where the player died, equipment stays on |
| Hardcore | Both the character and the world are lost |

Worlds made before the setting exists count as Gentle.
Today the character is saved inside its world (`saves/<world>/`), so Hardcore death deletes that world folder. If characters ever become separate from worlds, Hardcore deletes both.

### Mana network (Decided, base automation)
Mana powers the base the way it powers spells: a battery stores it, conduits carry it, blocks around them use it.

- **Mana battery** (2x2 tiles): stores mana and shows how full it is (the mana effect filling it up). It is the controller of
  a network and reaches **5 tiles** around it.
- **Mana conduit** (1 tile): extends the network, it also reaches 5 tiles. A battery and conduits within reach of each other
  are one network, linked by **range only** (beams pass through blocks). A beam of the mana effect is drawn between linked nodes.
- **Consumers** connect to the nearest node in reach, with a beam to it.
- **Filling it, from the player:** while the player is in reach of a node with full mana, the mana they regenerate goes into
  the network instead of being wasted, with a beam from that node to the player.
- **Filling it, from the world: ley lines.** Lines of mana running through the world, made from the seed as random lines
  scattered everywhere (through rock and sky alike). They are invisible unless the player wears **Ley Goggles**, an item that
  shows them. A network node on a ley line taps it and fills the batteries by itself, **wider lines give more mana a second**
  (a range from thin to wide lines).
- **Feeding the player** (a toggle in the battery screen): while the player is in reach, spells are paid from the network
  first and from the player's pool when it runs out.
- **First consumers:**
  - **Spell mana blocks** (the Block form) in reach have their lifetime topped up from the network, so a base wall stays up.
    Damage they take is paid in network mana instead of HP, **unless the player dealt it**, which hurts the block as usual
    so the player can still take their own walls down.
  - **Rune turret:** a block that casts a spell at enemies in range, paid from the network. The spell comes from a
    **spell scroll** (a spell bound into a scroll item) placed in the turret. Details later.
  - **Powered stations** (later): need a rethink of crafting first. Today crafting is a list in the inventory screen that
    only checks for a station nearby. Powered stations would need crafting that happens in the station (its own screen,
    inputs and time), which mana can then speed up or unlock.
- **The mana effect:** one shader (`manaShader`) drawn **smooth at screen resolution**, flowing over time, a deliberate
  contrast with the pixel art (a style snapped to 2 pixel blocks with banded colors was tried and dropped). It is reused
  for the battery fill, the beams, and later mana spell effects.
- **Done (step 1):** the mana effect (`world_utils/manaShader`: a filling liquid and a beam, smooth), big blocks (`blocks/bigBlock`: an anchor and parts that point
  back at it, placing checks the whole footprint, breaking drops one item, parts in another chunk save and load on their own)
  and the Mana Battery as the first one: placed, broken and saved with its mana, its window shows the fill and glows at
  night (the `battery 60` dev command fills the one under the mouse).
- **Done (step 2)** (`world_utils/manaNetwork`, `ui/batteryPanel`): batteries within 5 tiles of the player (from their edge)
  are one buffer. A full player's regen goes into the nearest one with room, with a beam from the player. Every spell
  payment goes through `ManaNetwork.available` and `ManaNetwork.pay`, so batteries with **Feed the player** on pay first
  (nearest first, a beam to the player) and the pool pays the rest. Interacting opens the battery screen: a tank of the
  mana effect, the batteries in reach and the Feed toggle (saved with the battery). Recipe: 8 iron bars and 16 stone at
  the Forge.
- **Done (step 3)** (`blocks/manaConduit`): the **Mana Conduit** (1 tile, walk-through like a torch, picked up with the
  interact key, 2 for 2 iron bars and 4 stone at the Forge). Batteries and conduits are network nodes: two link when their
  edges are within 5 tiles, linked nodes are one network. The player joins through the nearest node in reach and its
  whole network's batteries are their buffer, the beam to the player comes from that node. Beams show only the shortest
  links that join every node (a minimum spanning tree), not every pair in reach. The map keeps a list of every node, and a
  chunk holding a node never unloads (the save lists those chunks and loads them with the world), so a network works
  however far it reaches. Nodes are linked again only when one is added or removed.
- **Done: simulated chunks** (`world_utils/simulation`, `blocks/chunkAnchor`, `ui/anchorPanel`): chunks that keep
  **running while the player is away, simulated but not drawn**. A chunk holding a **Chunk Anchor** or a machine
  runs for free. Batteries and conduits only keep their chunk *loaded* (so the network holds together), nothing in it
  runs, otherwise a line of cheap conduits would keep any chunk running. A **Chunk Anchor** (a network node, 6 iron bars, 2 gold bars and 12 stone at the Forge) also runs the chunks around
  its own, a radius of 0 to 2 chunks set in its screen (radius 2 is 5 x 5 chunks), for **0.5 mana a second per extra
  chunk** from its network; without the mana only its own chunk runs. A running chunk stays loaded and has hitboxes of
  its own, so enemies, drops, arrows and spells in it move and collide; **nothing spawns there** (the spawner stays
  around the player, and spawned enemies far from the player still despawn). Blocks with an `update` are ticked near the player
  or in a running chunk, which is how machines (a furnace) will keep working. The **minimap** (M, `ui/minimap`) shows the blocks
  around the player, a pixel a tile in the average color of each tile's art (ores in their nugget color), only from
  loaded chunks. Two options: the **chunk grid**, and the **anchor chunks** (the chunks kept running, with the anchors'
  mana a second), which also outlines them in the world.
- **Done (step 4)** (`blocks/manaBlock`, `forms/blockForm`): a mana block within 5 tiles of a network node is a consumer.
  A timed one's timer is kept full while the network pays its upkeep, **about 0.067 mana a second** (the price of the time
  a Decelerate rune buys, `MANA_BLOCK_UPKEEP`), so base walls stay up. Damage a mana block takes is paid **1 mana a point**
  from the network instead of its hp (a short beam from the nearest node shows it), what the network cant pay hits the hp,
  and **the player's own hits always hurt it**. onHit still goes off on every hit. Its tooltip says whether it is timed
  (seconds left), kept up by a network or permanent.
- **New engine piece: big blocks.** The battery is the first block bigger than one tile: one block owning several cells,
  placed only where they are all free, broken as one and saved once. Later machines reuse it.
- **Numbers (for now):** a battery holds **10,000 mana**, a point of damage to a mana block costs **1 mana**.
- **Several batteries** in one network are one shared buffer: mana goes in and out through the nearest battery with room
  (or with mana), and the network has the sum of them all.
- **Open:** the mana a second for thin and wide ley lines, how many lines there are and how long, whether a node taps a
  line it touches or one within its reach, what the goggles are (a helmet, a trinket) and how they are made,
  how a scroll is made and bound.
- **Build order:** 1) the mana shader with the pixel toggle and big blocks, 2) the battery (storage, fill, screen, player
  overflow), 3) conduits and networks (linking, beams), 4) mana block upkeep and damage, 5) the rune turret,
  6) ley lines from the seed and the Ley Goggles, 7) station crafting and powered stations.

---

## Build order (proposed)

1. Trees, plants and enemy drops (materials) **Done**
2. Crafting core (recipes, stations, screen) **Done**
3. Wands and staves with the dig cap (parts, hand slots, dual wield, woodworking station, arcane table) **Done**
4. Damage types, crit and resistances **Done**
5. Spawner and enemy variety **Done** (the Apprentice mage is the first real caster)
6. Rune knowledge, glyph walls and the grimoire **Done** (placeholder walls)
7. Light: tile light, torches, glowing blocks **Done**, the Light rune and the Block form **Done**
8. Bosses, trinkets and set bonuses (trinkets and sets **Done**)
9. Mana network: batteries, conduits, consumers (see Mana network)
