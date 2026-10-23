# Rune Marks

Marks are small shapes drawn in the ring around a rune on the drawing pad (outside the dotted line).
The main recognizer finds the rune, then hands the marks to that rune's own `readMarks`, which decides what they mean.
Runes without `readMarks` ignore marks.

This file lists every mark planned for every rune. **Done** marks are in the game; the rest are ideas to build from.

## How marks work in code

| Piece | Where | What it does |
|---|---|---|
| `Strokes.MARK_SHAPES` | `magic/strokes.lua` | Shapes a mark can be recognized as (any rotation) |
| `Strokes.readMarks` | `magic/strokes.lua` | Turns the ring strokes into `{kind, quality, angle, outward, direction, strokes}` per mark |
| `rune:readMarks(marks)` | each rune | Reads the marks into a small table that is saved with the slot, or returns `nil, reason` to refuse them |
| `rune:checkMarks(saved)` | each rune | Clamps saved marks when a save loads (edited saves cant ask for 99 projectiles) |
| `rune:markCost(marks)` | each rune | Extra complexity and mana |
| `rune:describeMarks(marks)` | each rune | Text under the pad |
| `rune:settings(marks)` | each rune | Starting settings that other runes can change through `affects` |
| `form:applyMarks(params, marks)` | forms | Forms have no effects, their marks change the params here |

## Mark or rune?

Runes add verbs (pierce, repeat, chain, bend). Marks set the numbers on verbs a rune already has (how many, which way, how wide).
Check a new idea in this order:

1. **Is it how much / which way / what shape of something this rune already does?** Then it is a mark, even when other runes have the same kind of mark (an aim arrow on Bullet and on Laser each tunes that form's own launch).
2. **Otherwise it is a new behavior. Does it make sense on 2+ forms?** Then it is a modifier rune, and its marks tune it (Repeat's dots set the count).
3. **A new behavior on only one rune** can be a mark, as long as it tunes rather than adds power. Slots (6 per circle) are the budget, a mark that adds free power makes them pointless.

Also:
- **Drop a mark that repeats what a rune already controls.** Laser reach is Speed and Slow, beam width is Size and Focus, a beam that sweeps is Gravity's direction or the player's own aim.
- **Dots that only mean "more of this rune's effect" duplicate stacking the rune**, which already costs a slot. Prefer dots that count something new (repeats, bounces).
- **Marks on a form are about how it launches** (aim, where it appears). Everything about what it does after that belongs to modifiers.
- **Marks that are really about another rune** can be `affects` instead (rune-on-rune effects along the mana flow).

## Design rules for shapes

- Each mark kind keeps a consistent feel across runes: **dots count steps**, **arrows give a direction**, outward means more / grow and inward means less / shrink.
- Go beyond arrows, dots and lines: a mark's visual should hint at its meaning (the pierce mark is a bolt passing through bars).
- New shapes must stay apart from the existing ones in the recognizer: test them with noisy generated marks before adding them.

## Mark shapes

| Kind | Visual | Used by |
|---|---|---|
| `arrow` | Shaft with a head, direction read from the arrow itself | Split, Bullet, Laser, Gravity |
| `dot` | Small circle | Repeat |
| `line` | Straight stroke | (free) |
| `pierce` | A line crossed by two short bars at its thirds | Pierce |

## Forms

| Rune | Mark | Meaning | Status |
|---|---|---|---|
| **Bullet** | One arrow | Aim offset: the shot turns from the aim the way the arrow points (mirrored when aiming left so up stays up). Works on triggered children too. Two arrows is an error | **Done** |
| **Laser** | One arrow | Aim offset, same as Bullet: the beam starts turned from the aim, then bends and bounces as usual | **Done** |
| **Area** | One arrow | Where it appears: offset from in front of the caster the way the arrow points | Idea |
| | Arrows out | Directed burst: a cone instead of a circle, aimed by the arrows' angle | Idea |
| **Trap** | One arrow | Throw direction when placed | Idea |
| | Line | Tripwire: a line trigger instead of a radius | Idea |

## Modifier runes made from mark ideas

New behaviors that showed up as marks on several forms.

| Rune | Forms | Marks | Replaces | Status |
|---|---|---|---|---|
| **Repeat** | All | Plain: casts twice. Each dot adds a cast (up to 6). Casts come `REPEAT_DELAY` apart, every one does full damage, each costs more mana than the one before (+0.5, +0.75, +1 of the spell...). Repeat runes multiply | Bullet burst, Laser pulses, Area pulses, Trap charges | **Done** |
| **Pierce** | Bullet, Laser | Plain: passes 1 enemy or block. Pierce marks add the sum of how well each is drawn (rounded, up to 8). Pierce runes add up | Bullet pierce | **Done** |
| **Chain** | Bullet, Laser | Zigzag: one jump to the nearest other enemy per peak | Laser chain idea | Idea |

## Modifiers

| Rune | Mark | Meaning | Status |
|---|---|---|---|
| **Split** | Arrows out | Projectile count (2 to 8) and fan width (angle the arrows cover). Every projectile does full damage, extra projectiles cost mana and complexity. Count and fan scale with drawing quality | **Done** |
| | Arrows in | Delayed split: splits mid-flight instead of at the cast | Idea |
| | Dots | Splits into random scatter instead of an even fan | Idea |
| **Focus** | (affects) | Narrows the fan of every Split after it in the flow (×0.5, scaled by quality), and still concentrates the spell itself | **Done** |
| | Arrow | Narrows toward one side, an asymmetric fan | Idea |
| **Gravity** | Arrow | Gravity direction in the world (an arrow up falls up whichever way it is aimed): bullets fall that way, lasers bend that way. Area still pulls to its center. One arrow only | **Done** |
| **Speed** | Arrows out | More acceleration: starts slow, ends fast | Idea |
| | Arrows in | Slows down over its lifetime, so it hangs in the air at the end | Idea |
| **Size** | Arrows out | Grows over its lifetime | Idea |
| | Arrows in | Shrinks over its lifetime, so it's stronger early | Idea |
| **Rebound** | Dots | Exact bounce count instead of doubling | Idea |
| | Arrow in | Each bounce loses speed but gains damage | Idea |
| | Arrow out | Each bounce gains speed | Idea |
| **Recoil** | Arrow | Push direction relative to the aim; up gives rocket jumps | Idea |
| **Dig** | Line | Tunnel: digs a line along the path instead of only at impact | Idea |
| | Dots | Dig radius | Idea |
| | Arrow in | Only digs, does no damage to enemies (cheaper) | Idea |
| **Slow** | Arrow in | Comes to a stop and hovers until it expires | Idea |
| **Weaken** | Line | Weakens its children instead (cheap triggers) | Idea |

## Triggers

| Rune | Mark | Meaning | Status |
|---|---|---|---|
| **OnHit** | Arrow | Aim of the child: along the hit surface, back at the caster, or toward the arrow | Idea |
| | Dots | Can trigger N times (piercing spells) | Idea |
| | Line | Child spawns at the caster instead of the hit point | Idea |
| **OnExpire** | Arrow | Child direction relative to the parent's last direction | Idea |
| | Dots | Delay before the child spawns | Idea |
| | Arrows out (several) | One child per arrow, a fan of children (Split for triggers) | Idea |

## Ruled out

| Idea | Why |
|---|---|
| Laser sweep | Gravity's direction arrow and the player's own aim already shape the beam |
| Laser reach | Speed and Slow change reach |
| Laser charge (wider, stronger beam) | Size, Focus and Damage |
| Laser prism | OnHit + Split does it |
| Area implode | Gravity on Area already pulls in |
| Dots for more of the same (Damage, Focus, Gravity, Recoil, Slow, Weaken strength) | Stacking the rune does it and costs a slot |
| Damage crit line | A new behavior, would be its own rune if wanted |
