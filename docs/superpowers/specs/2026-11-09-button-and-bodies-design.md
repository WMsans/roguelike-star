# One button and real body shapes

Date: 2026-11-09. Branch base: `garage-battle-ui`.

Markers: **Decided** was agreed with the user. **My call** was settled by the designer and can be
overruled. **Proposed** numbers are starting points the balance runner tunes.

## Intent

Two problems from playtesting (user's words: "the balancing is still shit"):

1. **Choosing a body feels the same.** Cutter, Dozer and Corsair are still wooden rectangles that
   differ only in size, HP, energy and slots. The body roster in
   `2026-11-06-bodies-and-balance-design.md` §1, §1b was never built; only its runner and part
   tuning were. In a CATS-style game the body is the big choice, and shape is what makes it one.
2. **Fights are watched, not played.** The player's only input is left/right, and the runner found
   that standing still is the best policy (`docs/superpowers/handoffs/2026-11-07-demo-balance-handoff.md`,
   "Side bias and player skill"). The player either sits and watches or holds forward.

The two are linked: body shape only matters once contact and timing matter.

## Goals

- **One button, like Bad Piggies (Decided).** Every part is linked to it. A press fires each part's
  **triggered** ability; **passive** abilities run on their own. This gives `core-mechanics.md`
  §4.2's trigger/passive split a real meaning in the fight.
- **Volley rule (Decided):** a press fires every *ready* triggered part at once; each pays its own
  energy. A part that can't be paid does not fire and stays ready for the next press. Cooldowns
  start when a part fires. Mashing spends energy on whatever is ready; waiting for reach, a frozen
  target or a full pool is the skill.
- **Bodies that play differently through shape (Decided, from the 11-06 spec):** Cutter, Dozer and
  Corsair become the Wedge, Tower and Barge silhouettes with their own mass and grip, and enemies
  drive by body style so hulls actually meet.
- Both land in this one piece of work (Decided).

## Non-goals

- The two new types (Dome, Skiff) and procedural slot rolls (`ChBodyType.roll`). They wait for a
  shop that offers bodies (my call; the garage cycles three fixed bodies today).
- Per-part buttons, toggles or hold-to-charge. One button, press = volley.
- Body special abilities (11-06 Decided: shape and stats only).
- New parts. The existing 12 are re-sorted into triggered and passive.

## Anti-goals

- **Mashing is optimal.** If a held or spammed button matches a timed player, the button is
  decoration and we are back to watching.
- **A body that is strictly better** than another.
- **A shape that can't play:** a hull that rests on its belly, flips at spawn, or puts a slot where
  no weapon can hit anything.
- **Auto-fire under another name**, such as presses that queue parts to fire later.

## Constraints (from the code)

- Firing lives in `ChBattleContext._tick_chariot`: ready parts `request` energy, `ChEnergy.tick`
  pays a strict FIFO queue, paid parts `fire`. Queue readers: `ChBattleHud` ("N parts waiting"),
  `ChFightStats` (`energy_starved_seconds`, per-part `seconds_waiting`), and
  `ChChariotRuntime.break_part`, which cancels a broken part's entry.
- `ChBattle._step` builds the drive per side from `drivers[side]` (the runner's policies) or
  `_player_drive()` / `ai_drive()`. The press needs the same per-side shape.
- Hull collision comes from the texture's opaque pixels (`PixelRigidBody.SHAPE_HULL`, convex).
  `PixelRigidBody` exposes `mass`, `friction`, `restitution`, `linear_damping`,
  `angular_damping`. There is no centre-of-mass setter, so the centre of mass comes from the
  shape.
- `ChBodyDef` header: the two lowest slots are the wheel mounts and sit on the hull's bottom edge
  (checked by `tests/data/test_catalog.gd`).
- Layouts store slot **indices**. `dozer_cook.tres`, the five runner reference builds and tests
  address Dozer and Corsair slots by index.
- `ChEnemyAI.decide` holds at reach + both half-widths, so hulls never touch.
- The fight must stay deterministic per seed, and the runner must run headless.

## Approaches

**The button.**

1. **Press fires the volley in the tick (picked, my call).** `_tick_chariot` takes a `pressed`
   flag; on a press it pays ready triggered parts directly from the pool, dearest first. The FIFO
   queue goes away.
2. Keep the queue, and have a press enqueue every ready part. Rejected: unpaid parts would fire
   later with no press, which is auto-fire under another name (anti-goal).
3. Volley vs hold-to-charge vs overdrive was the user's choice: **volley** (Decided).

**The shapes.**

1. **An outline polygon on `ChBodyDef`, filled by `ChTextures` (picked, my call).** One mask
   generator, plus data per body. The engine already hulls the pixels.
2. Hand-drawn PNG per body. Rejected for now: it needs art, and slots must be matched by hand.
3. The full 11-06 `ChBodyType` with seeded slot rolls. Deferred (non-goals).

## Design

### 1. The button

**Input (my call):** `Space` (action `fire`, added the way `_add_input_actions` adds the drive
keys). The edge counts, not the hold: holding Space fires once. A runner or AI side presses through
a per-side callable, mirroring `drivers`.

**Triggered vs passive (Decided split):**

| Triggered (fire on press) | Passive (never on the button) |
|---|---|
| Rocket, Chainsaw, Ice Cream Mace, Flamethrower, Firebolt, Hearth, Ring of Fire, Harpoon | Ember Battery, Freeze Charge, Wheel, Strut, and every hook (Ignition, Sparks, Shatter, Ember's gain) |

The rule in code (my call): a part is triggered when `def.cooldown > 0`. That is the line the AI's
`reach()` already draws. No new field.

**A press, in tick order (my call on the details):**

1. Regen, then the drive. Driving is still paid first.
2. If pressed: collect ready triggered parts (cooldown done, charges left, not frozen, not
   broken). Sort them by `energy_cost`, dearest first, with ties in mount order. Pay each one that
   fits the pool. A part that doesn't fit is skipped, and cheaper parts after it can still pay.
3. Paid parts `fire`, restart their cooldown and spend a charge, exactly as today
   (`_emit_fired` included).
4. Unpaid ready parts stay ready. Nothing is remembered between presses.

"Dearest first" makes it predictable that a short pool still lands the big hit. Skipping instead of
blocking keeps a volley from going empty because its head can't pay.

A part's cooldown no longer fires it. It only decides when the part is *ready*. Behaviours that do
something over time after a fire (Hearth's 1 s charge, Flamethrower's 1 s burst) start on the
press.

**`ChEnergy` (my call):** drop `request`/`cancel`/`queue`; add `try_pay(cost) -> bool`, which
spends and adds to `spent` when the cost fits. `tick` keeps regen and the drive. `break_part`
stops cancelling.

**Readiness has to be visible.** Timing is the whole decision:

- Each ready triggered part glows on the chariot. Reuse the existing feedback/juice layer, so this
  is a new profile and not a new system.
- The HUD's "N parts waiting" line becomes "N ready". The pool bar marks the cost of the full ready
  volley, so the player can see whether a press would pay for all of it.
- A press with nothing ready, or nothing affordable, gives a small "dud" nudge so the press still
  registers.

**Enemy press rule (my call; thresholds Proposed, tuned with the runner):** press when at least one
ready triggered part has a target in its reach and the pool covers **≥ 60%** of the ready volley's
cost, or when energy is at the cap. Reach uses the same `ChEnemyAI.reach` data per part.
Ranged parts with no reach count as in reach while facing the enemy.

**Runner (my call):** scenarios gain `"press": {"player": ..., "enemy": ...}` with policies `ai`
(the enemy rule above), `mash` (press every tick) and `never`. The default is `ai`. A per-part
`seconds_ready_unfired` metric replaces `seconds_waiting`, and the per-side `energy_starved_seconds`
becomes "seconds with a ready part the pool can't pay". README updated.

**Docs:** `core-mechanics.md` §3.2 is rewritten ("one button fires every ready triggered part;
passives run on their own"). §3.3 loses the FIFO queue. Tooltips gain a **Press:** prefix on
triggered lines and **Passive:** on passive lines, using the existing `ChKeywords` tags.

### 2. Body shapes

Ids and display names are kept (11-06 my call), and the type name shows as a subtitle in the
garage. **Slot count and slot order per body are kept** (my call), so `dozer_cook.tres`, the runner
suites and tests still load. Slot *positions* move onto the new outlines.

`ChBodyDef` gains:

- `outline: PackedVector2Array`: convex polygon in body-local cells (origin = centre, +x = forward).
  When empty, the body is the old `size` box, so hand-made test bodies still work.
- `mass`, `friction`, `restitution` (0 = engine default), applied by `ChChariotBuilder._body` to
  the chassis.
- `drive_style: StringName`: `&"brawler"`, `&"kiter"` or empty (today's hold-at-reach).

`ChTextures.polygon(outline, colour)` fills the outline with a darker rim, like `box`. The garage
pit draws the same texture.

**Roster (silhouettes and matchups Decided in 11-06; numbers Proposed, current stats kept as the
start):**

| Body | Type | Silhouette | Approx. cells | HP / cap / regen | Mass, grip | Drive style | Should beat | Should lose to |
|---|---|---|---|---|---|---|---|---|
| Cutter | Wedge | Low, nose slopes down to the ground in front | 34×9 | 650 / 10 / 3.5 | medium, low, grippy | brawler | Tower: gets under, lifts, flips; ducks its high guns | Barge: too heavy to lift |
| Dozer | Tower | Tall, narrow, slightly tapered top | 22×30 | 1000 / 14 / 3.0 | medium, high centre | kiter | Ranged fights; fires over mounds and over a Wedge's low guns | Wedge: tips when lifted |
| Corsair | Barge | Long, flat, wide wheelbase | 52×10 | 900 / 12 / 3.0 | heavy | brawler | Shoving; stays upright | Slow and easy to hit |

The slope of the Wedge's nose is the lever that lifts. The nose's lowest point should sit near
wheel-tyre height, so it slides under a flat-fronted hull.

**Drive styles (11-06 §1b, Decided):**

- **Brawler:** closes to contact and keeps pushing into the enemy hull (`decide` with no
  half-width gap).
- **Kiter:** holds at its weapon reach, and backs off when the enemy is inside it.
- Driving still pays the normal energy, so a brawler's push costs it firepower.

The player is never auto-driven. The style is the AI's and the runner's `ai` policy.

**The cook moves to the Barge (Decided).** `dozer_cook.tres` is the game's only enemy, and its kit
(Hearth 2 cells, Mace 6, Harpoon) is a brawler's. As a Tower kiter it would rarely land its main
hits. It becomes a Corsair/Barge brawler with the same parts:

- Its parts are re-slotted onto Corsair indices so Hearth and Mace face front and reach.
- `max_hp` 1800 is kept as the starting point and re-tuned in §3.
- The file and id keep the name `dozer_cook` (my call), so tests and suites still load. The display
  name can drop "Dozer".

A player Tower now has a real job against it: keep its distance.

**Garage:** body buttons still cycle the three. The pit shows the new silhouette, and the subtitle
shows the type.

### 3. Re-balance

Moving from cooldown auto-fire to presses lowers every part's real fire rate. Re-tune with the
runner after the mechanics land, not before. Order: button → shapes → re-tune → tests and tooltips.

New suite **`bodies`** (11-06 §5): every body against every body, `ai` driving and pressing on
both sides.

- **Reference loadout (my call):** two wheels, plus one Rocket and one Chainsaw on the body's two
  highest front-facing non-wheel slots. That gives one ranged and one melee part, both mounted
  where the body's height decides whether they hit. Other slots stay empty, so every body carries
  the same parts.
- **Box control (my call):** each body keeps its own size, slots, stats, mass and grip, but its
  outline is the plain `size` box. That isolates shape, the claim being tested.

### 4. Success criteria (Proposed)

- **The button matters:** in `demo` and `demo-matrix`, the `ai` press policy beats `mash` by at
  least 15 points of win rate for every build, and `never` wins no fight. A draw (timeout) counts as "not a win" (my call): the
  criterion checks that the button is needed, not how long fights last.
- **Bodies matter:** in `bodies`, no body wins more than 65% overall, each wins one matchup ≥ 60%
  and loses one ≥ 60%, and the shaped roster is further from even than the box control. Runner
  metrics `flipped_seconds` and `rams` must show the Wedge flipping the Tower.
- **No unplayable shape:** every body drives the length of the arena and isn't flipped at spawn
  (tests).
- **Builds:** the five reference builds stay within the handoff's 0.35–0.65 round-robin band.
- Tests end `0 failed`.

## Left to the builder

- Exact outlines, mass, friction and restitution, tuned with `bodies` until the matchups hold.
- Where each slot moves on its new outline (count and order fixed).
- Brawler push and kiter back-off thresholds.
- The enemy press thresholds, and part re-costing after the switch to presses.
- The ready glow's look, and the dud feedback.
- Which tests change. Each test's own comments say what it pins: change constants, and don't
  weaken what is checked.
