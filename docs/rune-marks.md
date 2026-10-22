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

## Design rules

- Each mark kind keeps a consistent feel across runes: **dots count steps**, **arrows give a direction**, outward means more / grow and inward means less / shrink.
- Go beyond arrows, dots and lines: a mark's visual should hint at its meaning (the pierce mark is a bolt passing through bars).
- New shapes must stay apart from the existing ones in the recognizer: test them with noisy generated marks before adding them.
- Marks that are really about another rune can be `affects` instead (rune-on-rune effects along the mana flow).

## Mark shapes

| Kind | Visual | Used by |
|---|---|---|
| `arrow` | Shaft with a head, direction read from the arrow itself | Split, Bullet |
| `dot` | Small circle | Bullet |
| `line` | Straight stroke | (free) |
| `pierce` | A line crossed by two short bars at its thirds | Bullet |

## Forms

| Rune | Mark | Meaning | Status |
|---|---|---|---|
| **Bullet** | One arrow | Aim offset: the shot turns from the aim the way the arrow points (mirrored when aiming left so up stays up). Works on triggered children too. Two arrows is an error | **Done** |
| | Dots | Burst: every dot adds a shot in a row (`BURST_DELAY` apart). Every shot does full damage; each extra shot costs more mana than the last (+0.5, +0.75, +1 of the spell...) | **Done** |
| | Pierce marks | Pierce: passes through enemies and blocks (blocks still take terrain damage). The count is the sum of how well each pierce mark is drawn (rounded) | **Done** |
| **Laser** | Dots | Pulses: the beam flickers N times instead of staying on | Idea |
| | Line along the ring | Sweep: the beam rotates across the arc the line covers | Idea |
| | Arrow in | Charge: longer cast, wider and stronger beam | Idea |
| **Area** | Arrows out | Directed burst: a cone instead of a circle, aimed by the arrows' angle | Idea |
| | Dots | Pulses: explodes N times at intervals | Idea |
| | Arrows in | Implode: pulls inward first, then bursts | Idea |
| **Trap** | Dots | Charges: triggers N times before vanishing | Idea |
| | Line | Tripwire: a line trigger instead of a radius | Idea |
| | Arrow | Launch direction of what it fires when triggered | Idea |

## Modifiers

| Rune | Mark | Meaning | Status |
|---|---|---|---|
| **Damage** | Dots | Each dot: +X% damage, more cost per dot | Idea |
| | Line | Crit chance instead of flat damage | Idea |
| **Speed** | Arrows out | More acceleration: starts slow, ends fast | Idea |
| | Arrows in | Slows down over its lifetime, so it hangs in the air at the end | Idea |
| **Size** | Arrows out | Grows over its lifetime | Idea |
| | Arrows in | Shrinks over its lifetime, so it's stronger early | Idea |
| **Split** | Arrows out | Projectile count (2 to 8) and fan width (angle the arrows cover). Every projectile does full damage, extra projectiles cost mana and complexity. Count and fan scale with drawing quality | **Done** |
| | Arrows in | Delayed split: splits mid-flight instead of at the cast | Idea |
| | Dots | Splits into random scatter instead of an even fan | Idea |
| **Focus** | (affects) | Narrows the fan of every Split after it in the flow (×0.5, scaled by quality), and still concentrates the spell itself | **Done** |
| | Dots | Each dot narrows more but costs more | Idea |
| | Arrow | Narrows toward one side, an asymmetric fan | Idea |
| **Gravity** | Arrow | Gravity direction: fall sideways, or fall up | Idea |
| | Dots | Gravity strength steps | Idea |
| **Rebound** | Dots | Exact bounce count instead of doubling | Idea |
| | Arrow in | Each bounce loses speed but gains damage | Idea |
| | Arrow out | Each bounce gains speed | Idea |
| **Recoil** | Arrow | Push direction relative to the aim; up gives rocket jumps | Idea |
| | Dots | Push strength steps | Idea |
| **Dig** | Line | Tunnel: digs a line along the path instead of only at impact | Idea |
| | Dots | Dig radius | Idea |
| | Arrow in | Only digs, does no damage to enemies (cheaper) | Idea |
| **Slow** | Dots | Stronger slow, bigger discount | Idea |
| | Arrow in | Comes to a stop and hovers until it expires | Idea |
| **Weaken** | Dots | Stronger discount, weaker spell | Idea |
| | Line | Weakens its children instead (cheap triggers) | Idea |

## Triggers

| Rune | Mark | Meaning | Status |
|---|---|---|---|
| **OnHit** | Arrow | Aim of the child: along the hit surface, back at the caster, or toward the arrow | Idea |
| | Dots | Can trigger N times (piercing spells) | Idea |
| | Line | Child spawns at the caster instead of the hit point | Idea |
| **OnExpire** | Arrow | Child direction relative to the parent's last direction | Idea |
| | Dots | Delay before the child spawns | Idea |
| | Arrows out (several) | One child per arrow, a fan of children (Split for triggers) | Idea |
