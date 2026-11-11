# RoguelikeStar: elements list

Elements exist on two layers:

- **Materials** are cells in the falling-sand sim: a pool of acid, a pile of gunpowder, a crate
  of TNT.
- **Statuses** are stacking numbers on individual parts: 5 Acid on a wheel, 12 Flame on the
  body.

The two layers link in both directions: a part touching a material gains a status, and a status
changes the cells around the part. Materials and statuses also react with each other. Every status
here can be read, counted and triggered on by parts.

Markers follow `core-mechanics.md`: **Decided** was agreed in discussion, **Proposed** is a
starting point to tune or replace, **Open** is unsettled. Numbers are all Proposed.

Research: [research/elements/noita-materials.md](research/elements/noita-materials.md).

## 1. Statuses

**Decided**
- 9 statuses, each strong enough to anchor a build.
- A status is a stack on one part. On an ordinary part it acts on that part's **integrity**. On
  the body it acts on chariot **HP**.
- All effects are statuses. "Speed up 1s" means "gain 1 Speedup".
- Block only comes from parts, never from the sim.
- Wet and Oil don't decay. Only reactions use them up.

| Status | What it does | How it goes away |
|---|---|---|
| **Flame** | Each second, deals damage equal to its stacks. | Loses 1 stack per second. Cancelled by Wet and Freeze. |
| **Freeze** | While above 0, the part's cooldown is paused and a wheel's motor is locked. | Loses 1 stack per second. Cancelled by Flame. |
| **Block** | Absorbs damage on this part before integrity (or HP, on the body) takes it. | Doesn't decay. Used up by damage and eaten by Acid. |
| **Acid** | Each second, deals damage equal to its stacks, hitting Block first. | Loses 1 stack per second. Cancelled by Wet. |
| **Wet** | Nothing alone. Cancels Flame and Acid, doubles Freeze gained, extends Shock. | Doesn't decay. Used up by reactions. |
| **Oil** | Nothing alone. Makes the part waterproof (it can't gain Wet) and doubles Flame gained. | Doesn't decay. Used up by reactions. |
| **Shock** | Each second, deals damage equal to its stacks. When gained, part of it jumps to neighbouring parts. | Loses 1 stack per second. |
| **Speedup** | While above 0, the cooldown runs at double speed. | Loses 1 stack per second. Cancelled by Slow. |
| **Slow** | While above 0, the cooldown runs at half speed. | Loses 1 stack per second. Cancelled by Speedup. |

So 1 Speedup gives exactly 1 extra second of cooldown, and 1 Slow takes away half a second.

**Proposed**
- **Shock jumps:** when a part gains Shock, each part physically touching it gains half that
  amount (rounded down). Jumped Shock doesn't jump again, except from a Wet part, where it jumps
  one more hop.
- **Statuses on the body**, which has no cooldown:
  - Freeze pauses energy regen.
  - Speedup doubles energy regen and Slow halves it.
  - Flame, Acid and Shock hit HP, and Block protects HP.
- **Decay ticks:** all statuses tick together once per second, on a shared battle clock.
- **Damage from statuses** (Flame, Acid, Shock) wears integrity on the part it sits on. It does
  not also hit HP unless it sits on the body. Weapon hits still lower HP and integrity together,
  as in `core-mechanics.md` §3.4.

**Open**
- Stack caps, if any.
- Whether Freeze should also deal damage.

## 2. Status reactions on the same part

**Decided**
- Flame and Wet cancel one for one.
- Flame and Freeze cancel one for one.
- Wet and Acid cancel one for one.
- Speedup and Slow cancel one for one.
- Oil blocks Wet entirely: an oiled part can't gain Wet, so water won't put out an oiled fire.
- Acid eats Block before it reaches integrity.
- Shock on a Wet part jumps further.

**Proposed**
- **Order:** when a part gains a status, the new stacks first cancel the opposite status, and
  only the remainder is added. Example: a part with 3 Wet gains 5 Flame, loses its 3 Wet, and
  ends with 2 Flame.
- **Oil doubling:** when an oiled part gains Flame, it gains extra Flame equal to the smaller of
  the Flame gained and its Oil stacks, and loses that much Oil.
- **Wet doubling:** when a Wet part gains Freeze, it gains extra Freeze equal to the smaller of
  the Freeze gained and its Wet stacks, and loses that much Wet.
- Flame cancelling Wet releases a puff of steam cells next to the part.

## 3. Materials

**Decided**
- The 19 materials from `core-mechanics.md` §7, plus electric spark, gunpowder, TNT and battery.
- Gunpowder, TNT and batteries appear in arena terrain from the start and can also be spawned by
  parts.

**In the sim today** (the demo arena; the rest of this table is still proposed)
- Gunpowder: a powder that lights at low heat and explodes in a small blast that chains through
  the pile.
- TNT: a solid that explodes in a large blast when fire or another blast reaches it.
- Acid: a liquid that dissolves sand, wood, gunpowder and TNT into air and a little smoke. Terrain
  only: it doesn't dissolve rock (rock holds it in the arena's cistern), it gives off no acid gas,
  and it does nothing to a chariot (the Acid status isn't built yet).
- TNT and gunpowder blasts damage and push chariots (`core-mechanics.md` §3.5).

**Proposed**

| Material | Kind | Hardness | Burns | Notes |
|---|---|---|---|---|
| Sand | Powder | 1 | No | Piles at a slope. |
| Gunpowder | Powder | 1 | Explodes | Flame or a spark sets off a quick chain of small blasts through the whole pile. |
| Dirt | Powder | 2 | No | Surface terrain. |
| Wood | Solid | 3 | Yes | Burns away to nothing. |
| Coal | Solid | 3 | Yes | Burns for a long time. |
| TNT | Solid | 3 | Explodes | Flame or an electric spark sets off one big blast. |
| Ice | Solid | 4 | No | Melts back to water near fire. |
| Battery | Solid | 4 | No | Gives off an electric spark every second. When broken, it leaks acid. |
| Rock | Solid | 5 | No | Bulk of the ground. |
| Steel | Solid | 7 | No | Conducts sparks. |
| Obsidian | Solid | 8 | No | Made by lava and frost. Acid can't dissolve it. |
| Concrete | Solid | can't be dug | No | Arena walls and floor. Acid can't dissolve it. |
| Water | Liquid | — | No | Conducts sparks. Puts out fire. |
| Oil | Liquid | — | Yes, fast | Floats on water. |
| Lava | Liquid | — | Sets fire | Lies under the surface. Exposed by digging. |
| Acid | Liquid | — | No | Dissolves rock, dirt, sand, wood, steel, gunpowder, TNT and battery. |
| Frost | Liquid | — | No | A freezing liquid. |
| Smoke | Gas | — | No | From burning. |
| Steam | Gas | — | No | Condenses back into water over time. |
| Flammable gas | Gas | — | Explodes | Rises and pools. |
| Acid gas | Gas | — | No | Rises. |
| Fire | Particle | — | — | Short-lived. Spreads to burnable cells. |
| Electric spark | Particle | — | — | Short-lived. Travels through water and steel. Sets off TNT and gunpowder. |

Hardness decides what a part's cut or blast can dig: a part with dig power 5 digs anything of
hardness 5 or less.

Wind is a force, not a material or a status. It pushes gases (smoke, steam, flammable gas, acid
gas) and fire particles, and affects nothing else (`core-mechanics.md` §7).

## 4. Material reactions

**Proposed**

| Inputs | Result |
|---|---|
| Water + fire | Steam |
| Water + lava | Rock |
| Water + frost | Ice |
| Lava + frost | Obsidian |
| Ice + fire, or ice next to lava | Water |
| Steam, over time | Water |
| Fire + wood, coal, oil | Burning (fire spreads, the fuel is used up) |
| Fire or spark + flammable gas | Explosion (medium) |
| Fire or spark + gunpowder | Explosion (small, chains through the pile) |
| Fire or spark + TNT | Explosion (large) |
| Acid + a dissolvable solid or powder | Both cells removed, some acid gas released |
| Battery broken | Acid released where it stood |

## 5. Links: materials to statuses

**Decided**
- A part touching a material gains that material's status.

**Proposed**
- A part is "touching" a material when a cell of it is next to the part's outline.
- Statuses are gained once per second while touching. A part more than half surrounded (for
  example sunk in a pool) gains double.

| Material | Status gained per second |
|---|---|
| Fire (including burning wood, coal, oil) | +2 Flame |
| Lava | +6 Flame |
| Frost | +3 Freeze |
| Ice | +1 Freeze |
| Water | +3 Wet |
| Steam | +1 Wet |
| Oil | +3 Oil |
| Acid | +3 Acid |
| Acid gas | +1 Acid |
| Smoke | +1 Slow |
| Electric spark | +2 Shock per spark that reaches the part |
| Sand, gunpowder, dirt, wood, coal, TNT, battery, rock, steel, obsidian, concrete, flammable gas | None |

## 6. Links: statuses to the sim

**Proposed**

While a part has any stacks of the status, each second it affects the cells next to it:

| Status | Effect on touching cells |
|---|---|
| Flame | Ignites wood, coal, oil and flammable gas. Sets off gunpowder and TNT. Boils water into steam. Melts ice. |
| Freeze | Turns water into ice, which can trap wheels. |
| Acid | Dissolves one dissolvable cell. |
| Shock | Sends a spark into touching water or steel, which travels through it. Sets off gunpowder and TNT. |
| Oil | Drips one oil cell every 2 seconds, leaving a trail that can be lit. Doesn't use up stacks. |
| Wet, Block, Speedup, Slow | Nothing. |

## 7. Explosions

**Proposed**
- Three sizes: small (gunpowder, per cluster), medium (flammable gas) and large (TNT). Parts can
  also cause explosions of any size.
- An explosion:
  - deals damage to parts in its radius, falling off with distance. Hits lower HP and integrity
    together, like a weapon hit.
  - digs terrain up to a hardness set by its size (small 2, medium 4, large 6), never concrete.
  - throws out fire cells.
  - sets off any gunpowder and TNT in its radius, so blasts chain. The per-event chain cap in
    `core-mechanics.md` §5.3 applies.
- An explosion is one event carrying its position, size and source, so parts can trigger on
  "an explosion near this part".

## 8. Theme index

The materials and statuses behind each shop theme in `core-mechanics.md` §6.3.

| Theme | Materials | Statuses | Play |
|---|---|---|---|
| Fire | Fire, lava, coal, oil, flammable gas | Flame, Oil | Stack Flame, keep it alight with Oil so water can't put it out. |
| Ice | Frost, ice, water, steam | Freeze, Wet | Soak with Wet, then double Freeze. Lock cooldowns and wheels. |
| Wind | Smoke, steam, flammable gas, acid gas (all pushed by wind) | Slow (smoke), Speedup | Steer gases onto the enemy. Speed your own parts up. |
| Earth | Sand, dirt, rock, obsidian, concrete, gunpowder, TNT | Block | Dig, blast, expose lava. Block comes from earth parts. |
| Electric | Battery, electric spark, steel, water | Shock | Chain Shock through neighbouring parts and wet terrain. |
| Acid | Acid, acid gas, battery (when broken) | Acid | Eat through Block and terrain. |

**Decided**
- Electric and Acid are shop themes of their own (`core-mechanics.md` §6.3).

## 9. Events parts can trigger on

Each event carries its part, position and side.

- A part gains a status, loses its last stack of a status, or reaches N stacks.
- Two statuses cancel on a part (for example "when Flame is put out").
- A doubling reaction happens (Oil doubles Flame, Wet doubles Freeze).
- Shock jumps to another part.
- A part starts or stops touching a material.
- Cells react near a part (water boils, ice forms, a cell dissolves).
- An explosion happens, by size.
- A battery breaks.

## 10. Changes made to `core-mechanics.md`

These followed from the discussion and have been applied:

- §3.4 says burning deals damage to chariot HP while any part burns. Per §1 here, Flame on a part
  wears that part's integrity, and only Flame on the body hits HP.
- §3.4's freeze, water and burning lines become statuses as described here.
- §4.2 says parts never change. Parts can scale over a run, Balatro style. The rule is that the
  shop always offers a part in its base state.
- §7's material list gains electric spark, gunpowder, TNT and battery.
- §6.3 gains Electric and Acid themes.
