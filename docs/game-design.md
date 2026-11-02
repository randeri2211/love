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

### Open
- Do templates also set a minimum drawing quality, so a sloppy traced rune still works? Or do they only show the guide?
- Where the walls go: arena structures in the biome that fits each rune (Gravity in deep caves, Speed on desert plains)?
- What the grimoire screen looks like and what it shows beyond the shape (lore, mana cost, which forms the rune works with).

### Building notes
- Knowledge is per world: `{runeName = "discovered" | "templated"}` on the player, saved with the world.
- The spell editor's rune list and the recognizer read it. The trace guide only shows for templated runes.
- Walls are something to interact with (`INTERACT_KEY`) inside a generated structure.

---

## Mining progression (Decided)

**Done:** a block only takes damage when the hit's dig strength is **greater than** its `damageThreshold` (`Block:damage`, `Form:digStrength`).
Dig strength is `damage × terrainDamage / 0.1`, so each Dig rune doubles it and each Damage rune multiplies it by 1.5.

**Problem:** stacking runes alone clears every threshold. Two Dig runes (40) break everything but bedrock on day one.

**Decided: the casting tool caps dig strength.** Every hit's dig strength is limited to the cap of the wand or staff it was cast with.
Trigger spells inherit the cap from the spell that cast them, so an OnHit chain can't get around it.

Proposed tiers (each cap is one point above the block it opens):

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
  It adds its bonuses to the main wand at **50% effectiveness**.
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

### Trinkets (Decided)
More creative bonuses: laser speed and width, area growth rate, Split amplification and so on.

### Boss drops (Open)
Some set items and trinkets are boss drops. Which ones and why is decided once bosses exist.

---

## Still missing (from the planning review)

| # | Gap | Why it matters |
|---|---|---|
| 1 | **Raw materials:** trees (wood), plants or silk (fibre), enemy drops (hides), gems | Every crafting station needs inputs, and they give biomes a reason to visit |
| 2 | **Crafting core:** recipe registry, a "near a station" check, a crafting screen | Stations do nothing without it |
| 3 | **Damage types, crit and status effects** | Forge resistances and tanning crit have nothing to work on yet |
| 4 | **Light:** torches and light from spells | Night and underground are dark, and deep ores are planned |
| 5 | **Storage and home:** chests, spawn point or bed, what happens on death | Basic sandbox loop |
| 6 | **Spawner and enemy roster:** biome and depth buckets, night spawns, enemies that cast runes | Materials and bosses depend on enemy variety |
| 7 | **Consumables:** potions from an alchemy station | Mana economy, and a second use for plants |
| 8 | **Sound and onboarding** | No audio yet. Drawing runes is a skill, so it needs teaching |

### Open
- Damage types: new element runes (Fire, Frost, Lightning), or properties of forms (Laser burns, Area blasts)?
- Death: how punishing should it be, for a sandbox that rewards experimenting?

---

## Build order (proposed)

1. Trees, plants and enemy drops (materials)
2. Crafting core (recipes, stations, screen)
3. Wands and staves with the dig cap (parts, hand slots, dual wield, woodworking station, arcane table)
4. Damage types, crit and resistances
5. Spawner and enemy variety
6. Rune knowledge, glyph walls and the grimoire
7. Bosses, trinkets and set bonuses
