# Run, shop and card feel design

Date: 2026-11-12. Branch base: `garage-battle-ui`.

## Intent

Two pieces of work, built in this order:

1. **Card feel.** The current juice feels "mechanical and sloppy" (user's words). The user wants it closer to
   Balatro: tighter beats, motion in rotation as well as scale, and everything draggable.
2. **The run and the shop.** Turn today's garage → same fight → garage loop into the real run from
   `docs/design-doc/core-mechanics.md` §2 and §6: ten fights in a line, a four-stage shop phase after each
   won fight, gold, buying, selling and a 5-slot inventory.

The feel comes first because the shop is made of cards and should be built with the new feel from the
start.

Success: a player can start a run, fight, shop with drag or click, and either lose the run or beat the
boss. Every card follows the hand, tilts and snaps instead of ringing.

## Decided by the user

- **A real run.** It follows the full §2 structure: battle, battle, elite, three times, then the boss.
  - **Every opponent is the cook** (`game/data/enemies/dozer_cook.tres`), including elites and the boss.
  - **The shop offers only the parts that exist today:** the 12 in `game/data/parts/` and the 3 bodies.
- **The run starts directly in a battle.** Fight 1 comes first, and the first shop comes after it.
- **The starting kit is fixed and small.** The exact kit is a designer's call (see below).
- **Drag does four things,** and click keeps working alongside every one of them:
  - shop item → inventory: buy
  - inventory card → sell zone: sell
  - inventory card → chariot slot: mount. This replaces today's click-to-pick strip, but click-to-pick
    still works.
  - inventory card → another inventory position: reorder
- **Layout:** the inventory bar is always at the bottom. The middle area shows either the shop or the
  garage, and a toggle button on the centre-left switches between them.
- **A minimal HUD.** Gold is the only readout on the shop screen. There is no fight counter, no "elite next"
  line and no stage label. The Next button sits under the stage content, in the middle.
- **Card motion uses approach A:** our own card Control and drag layer, not Godot's built-in drag and drop.
  A fake-3D perspective tilt shader may come later as its own step. It is not part of this work.

```
┌──────────────────────────────────────────────────────────┐
│                                              Gold 14     │
│        ┌───────┐  ┌───────┐  ┌───────┐                   │
│ [Garage│ Fire  │  │Weapon │  │ +Gold │                   │
│   ⇄   ]│ shop  │  │ pack  │  │       │                   │
│ [Shop ]└───────┘  └───────┘  └───────┘                   │
│                     [ Next → ]                           │
├──────────────────────────────────────────────────────────┤
│ [card][card][card][ empty ][ empty ]          [ SELL ]   │
└──────────────────────────────────────────────────────────┘
```

## Goals

- `ChCard` is one card Control. It is used for shop items, inventory parts, pack choices, body offers and
  stage options.
- The screen owns a drag layer: press, move, lift, follow, drop on a zone, or glide back.
- `ChJuice` beats are retuned from ringing springs to short decaying wiggles. This also reaches battle parts
  and buttons.
- A run state object, a shop-phase screen with the garage embedded in it, and run start and end flows.
- Elite and boss modifiers, so §2's elites and boss mean something even when every enemy is the cook.

## Non-goals

- Enemy generation, rarer enemy parts, or any enemy other than the cook.
- New parts, relics or stat items. Themes with nothing to offer simply don't appear.
- Parts that scale over a run (§4.2). No such part exists yet.
- Saving a run across sessions. Quitting loses the run.
- Sound, as in the feedback-system spec.
- The perspective tilt shader. It is a later, separate step.
- Changing popups, particles or screen shake, beyond retuning their size if the new motion makes them feel
  off.

## Anti-goals

- **No twitchy or ringing motion.** A beat that bounces several times is the thing being fixed. A repeated
  beat must stack and grow, not restart (carried over from the feedback-system spec).
- **No HUD creep.** No counters, labels or hint lines beyond what is listed above.
- **Feedback still writes nothing to fight state** (feedback-system spec).
- **Drag must never lose a part.** A drop that fails for any reason (full inventory, not enough gold, no slot
  under the cursor) returns the card to where it came from.

## Constraints found in the code

- `ChSpring` has stiffness 320 and damping 14. That is a damping ratio of about 0.39, so it rings through
  several bounces. The profiles kick it with large velocity impulses: `placed` is 7.0 in scale and 10° in
  rotation, and `hover` is 2.0 and 4°. This is the "sloppy" feel.
- `ChJuice` targets either a Control (centred pivot) or a Node2D. Battle parts are juiced through their
  visuals, and pit parts are `ChPitPiece` nodes.
- The garage (`game/garage/ch_garage.gd`, 709 lines) is a full screen in its own right:
  - It has a top bar with a body cycle, stats and a Fight button.
  - It has a 12-card strip (`ChPartCard`, a `Button`) and a pit.
  - Drag was removed on purpose earlier (`ch_garage.gd:5`). Picking a part puts it "in hand" for
    click-to-place.
  - `setup(inventory, layout, catalog)` already says "the shop later" wraps it.
- `ChInventory` has `capacity` (-1 = unlimited), `add`, `take` and `has`. There is no reorder.
- `ChPartDef` has no `rarity`, no `price` and **no tags in any .tres**, although the field exists.
- `ChChariotLayout` carries `max_hp`, which overrides the body's HP. It is the hook both for scaling the cook
  and for "revive health". `swap_body` returns the parts that didn't fit.
- `ChBattle.start(player_layout, enemy_layout, catalog, seed)` emits `finished` with `win`, `loss`, `draw` or
  `aborted`. A fight runs at most `FIGHT_TICKS` = 3600 (60 s). After that it is a draw.
- `ChMain` owns the inventory and layout and switches between the garage, the battle and `ChResultPanel`.
  The panel has to sit on its own CanvasLayer (see `ChMain._init`).
- Hits carry a `multiplier` through `ChBehaviour`'s hit dict. Burning goes through `ChDamage.burn_tick`.
- `ChEventBus` delivers synchronously with a budget of `MAX_DELIVERIES` = 256.
- Headless tests in `tests/` (runner `tests/run_tests.gd`) drive real fights. The balance runner is
  `tests/balance/`.

## Approaches considered (card motion and drag)

- **A. Our own card Control and drag layer (chosen).** `ChCard` owns its drawn offset, tilt, hover and sway.
  The screen lifts a pressed card onto an overlay, the card chases the cursor each frame, and on release the
  screen hit-tests its drop zones. We control every frame, and Balatro works the same way. The cost is
  roughly 200 lines we own.
- **B. Godot's built-in drag and drop** (`_get_drag_data` and `_drop_data`). It needs less hit-test code. But
  it drags a preview copy pinned to the cursor while the original stays put, so lag, tilt and glide-back all
  mean fighting the engine. It works against the request.
- **C. A plus a perspective tilt shader.** This is closest to Balatro's look. It was deferred so the flat tilt
  can be judged first.

## Part 1: card feel

### Beats (`ChJuice`, `ChFeedbackProfile`)

- A beat becomes a **juice-up**: a scale and rotation wiggle that decays fast, in the style of Balatro's
  `juice_up`. It is roughly `offset = amount · sin(ω·t) · (1 − t/T)^3`, with T ≈ 0.3 s and ω around
  45–50 rad/s, so there are about two visible swings and then it stops.
- Beats are additive. A new beat adds its own decaying term, and amplitude is clamped so a burst of beats
  grows but stays bounded. This keeps the "repeated triggers wobble harder" rule.
- The profiles' `scale_kick` and `rotation_kick_deg` are reinterpreted as amplitudes: a scale delta such as
  0.12 and a rotation in degrees. All 13 `.tres` files are retuned.
- `ChSpring` stays for follow motion and is retuned close to critical damping (ratio about 0.9–1.0).
- The battle and buttons get the new beats automatically through `Feedback.play`. Battle beats should be
  checked by eye after the retune.

### `ChCard` (new, in `game/ui/`)

- It is a Control with a **target position**, set by whatever lays it out (a bar slot or a shop row).
  - The drawn position follows the target on a critically damped spring, so a card never teleports. A
    reorder or a glide-back is just a new target.
  - **Tilt:** rotation is proportional to horizontal drawn velocity, clamped to about ±12°, and eases back to
    0 when the card stops.
  - **Hover:** a small lift (a few px up), scale about 1.06, a slight lean toward the cursor's x offset, and a
    juice-up on enter.
  - **Idle sway:** about ±1° on a slow sine, with a random phase per card so a row never moves in lockstep.
- It draws its content through a paint callback or child, so the same card shows a part (reusing
  `ChPartCard.paint` and the name and cost layout), a body, a stage option or an empty slot.
- **Refusal** is a rotation-only juice-up (a "no" shake) plus the card gliding back.

### Drag layer (owned by the shop screen)

- Press on a card, then move past a threshold of about 6 px, and it becomes a drag. Release under the
  threshold is a click. This is how drag and click coexist.
- While dragging, the card moves to an overlay on top of everything. Its target is the cursor minus the grab
  offset. Because it follows through the same spring, it lags slightly and tilts with speed. It gets a lift
  (scale about 1.1) and a juice-up when it is picked up.
- **Drop zones** are rects registered by the screen with an accept test: inventory slots, the sell zone and
  the pit's free slot markers. While dragging, zones that would accept the card highlight with `ChUi.ACCENT`.
  The sell zone shows the sell price while a card hovers it.
- On release over an accepting zone the action runs and the card settles into its new home with a `placed`
  beat. Anywhere else, the card glides back.
- The pit's mounted parts (`ChPitPiece`) can be dragged too. Dropping one on the inventory bar unmounts it,
  along with everything mounted on it, the same as the existing `lift`. This was the designer's addition and
  the user accepted it in the playback.
- Hit-testing and accept rules are plain functions, so they can be tested headless without a pointer.

## Part 2: the run and the shop

### Run structure (`ChRun`, a new RefCounted in `game/data/` or a new `game/run/`)

- **Fights 1–10:** N, N, E, N, N, E, N, N, E, Boss. A loss ends the run. Beating the boss wins it.
- `ChRun` holds:
  - the fight index
  - gold
  - the max-HP bonus
  - the inventory and the layout
  - the chosen elite and boss modifiers
  - a run RNG seeded once per run
- **Run start:** 20 gold, an empty inventory with capacity 5, and the starting kit mounted. Fight 1 starts
  immediately.
- **After a won fight** (except the boss), the result panel says "You win" and offers Continue, which goes to
  the shop phase. The shop's Fight button starts the next fight.
- **After a loss, or a draw** (designer's call, see "Calls" below): "Run over", then a New run button.
- **After beating the boss:** "Run won", then a New run button.
- **Each fight's seed** is derived from the run seed and the fight index, so the terrain differs from fight
  to fight.

### The cook's difficulty curve (§8: max HP is the curve)

- The enemy layout is the cook, with `max_hp` set per fight.
- Fight 1's HP is tuned so the starting kit wins it reliably, checked in the balance runner. From there it
  ramps linearly to around today's 1500 by fight 9.
- Elites get ×1.25 and the boss gets ×1.5.
- The builder tunes the exact numbers with `tests/balance/`.

### Elite and boss modifiers

These are from the §2 examples. They handicap the player.

| Modifier | Elite | Boss version |
|---|---|---|
| Fire damage reduced | the player's fire damage ×0.5: hits from fire-tagged parts, and burn ticks on the enemy | ×0.25 |
| Time limit | kill within 40 s or lose | 30 s |
| Chains weakened | each delivery to a player-side event listener goes through with 50% chance (seeded) | 25% |

- At run start, each of the three elites draws a modifier from the run RNG. The boss draws one and uses its
  stronger version.
- The fight shows its modifier as a short banner when it starts (about 2 s, then gone).
- **Countdown (user decision):** in a time-limit fight only, the battle HUD shows a small countdown of the
  seconds left. No other fight shows a timer.

### Part data (designer's calls)

Rarity sets price: common 2, uncommon 6, rare 12. Sell value is floor(price / 2). Tags drive themes.

| Part | Rarity | Tags |
|---|---|---|
| Wheel | common | passive |
| Strut | common | passive, tricky |
| Cutter Chainsaw | common | weapon, triggered |
| Corsair Harpoon | common | weapon, triggered, tricky |
| Ice Cream Mace | common | weapon, triggered, ice |
| Firebolt Launcher | uncommon | weapon, triggered, fire |
| Flamethrower | uncommon | weapon, triggered, fire |
| Hearth | uncommon | weapon, triggered, fire |
| Freeze Charge | uncommon | passive, ice, tricky |
| Ember Battery | uncommon | passive, fire, tricky |
| Cutter Rocket | rare | weapon, triggered, earth |
| Ring of Fire | rare | weapon, triggered, fire |

- `ChPartDef` gains `rarity` and the tags are filled in.
- Bodies get a rarity too: Cutter common, Dozer uncommon, Corsair rare.
- Rolls weight rarity 60 / 30 / 10 (common / uncommon / rare). Duplicates are allowed, because 12 parts is too
  few to avoid them.
- **Themes in play:** a theme appears only if at least 3 distinct items match it. That leaves Weapon, Fire,
  Tricky, Passive, Triggered and Chariot body.
  - Defence, Ice, Wind, Earth, Electric, Acid, Relics and Stats are out because too few items match them.
  - Attack is out because it is identical to Weapon with today's parts.
  - The rule is data-driven, so a theme comes back on its own once enough parts exist.

### Shop phase (§6)

- **Stage 1** has no screen. Opening the shop credits the fight's reward (5 for a normal fight, 10 for an
  elite) with a pop on the gold label.
- **Stages 2–4** each show 3 option cards:
  - Options 1 and 2 are random themes, never the same as each other and never one from the previous stage.
    Each is a shop or a pack at random.
  - Option 3 is a resource option, one of:
    - **Extra gold:** +4.
    - **Revive health:** +100 max HP for the rest of the run, applied to the player's layout `max_hp` on top
      of the body's HP.
- **Picking an option commits the stage.**
  - **Shop:** shows 3 items with prices. Buy any you can afford, by drag or click. One reroll costs 3 gold.
  - **Pack:** costs 3 to open, then shows 3 items. Take one free. No reroll.
  - **Resource:** granted at once, with a juice-up.
- **Next** leaves the stage, whether or not anything was picked. After stage 4 it reads **Fight**.
- **Buying a body** swaps it in at once with `swap_body`. The old body is gone, not sold. Parts that don't
  fit go to the inventory; if the inventory is full, the overflow is sold automatically, each with a sell
  beat.
- **Inventory full:** a buy or pack pick into a full inventory is refused (no shake, the card glides back).
  Selling makes room.
- Selling works in both views.

### The garage inside the shop screen

- `ChGarage` becomes embeddable. Its pit and its rules stay. These go:
  - the 12-card strip, replaced by the shared inventory bar
  - the body cycle buttons, since bodies are bought now
  - the top bar and its Fight button
- Click behaviour on the pit stays as it is today: click to pick from the bar, click a slot to place, the
  existing flip and lift clicks.
- The tooltip on hover stays (`ChPartTooltip`).
- The toggle button on the centre-left swaps the middle area between the stage content and the pit. The shop
  keeps its state across toggles.

### Starting kit (designer's call)

- The Cutter body, with 2 wheels and a Cutter Chainsaw mounted.
- An empty inventory with capacity 5.
- 20 gold.

## Calls made by the designer (for the user to check)

1. The starting kit is Cutter + 2 wheels + Chainsaw.
2. A 60 s draw ends the run, the same as a loss. A Balatro blind you don't beat ends the run.
3. All of the following:
   - The three modifiers and their numbers.
   - The modifier banner only shows at fight start.
   - Resource amounts: +4 gold, +100 max HP.
   - Reroll costs 3 gold.
4. All of the following:
   - The rarity and tags table.
   - The 60/30/10 roll weights.
   - Duplicates allowed.
   - The theme threshold of 3 or more items, and Attack dropped.
5. A bought body replaces the old one with no refund. Overflow parts are auto-sold when the inventory is full.
6. The cook's HP curve, tuned in the balance runner.
7. Picking an option commits the stage. Next always skips forward.
8. Lifting a branch from the pit (by drag or by click) is refused when its parts don't all fit in the free
   inventory slots. The piece glides back with a refusal shake. Nothing is auto-sold and nothing is lost.
   Today's `_lift_branches` drops the overflow silently, and this fixes it.
9. Only inventory cards can be sold. A mounted part is lifted to the bar first, then sold. The sell zone
   never accepts pit pieces, which follows the user's drag list.
10. Phasing:
    - **Part 1** ships the beat retune and `ChCard`. Today's garage strip cards become `ChCard`s, so the hover,
      tilt and sway can be judged in the game.
    - **Part 2** adds the drag layer, together with the inventory bar and the shop screen it acts on. No
      throwaway drag wiring is built into the old strip.

## Left to the builder

- File layout: whether `ChRun` and the shop screen live in a new `game/run/` and `game/shop/` or in existing
  folders.
- How `ChGarage` is split so it can be embedded: one class with its chrome removed, or a pit view pulled out
  of it.
- The exact spring, juice and tilt constants, tuned by eye against the numbers above.
- How the modifiers hook into the battle: a multiplier in the hit path and `burn_tick`, a tick limit argument
  to `ChBattle.start`, and a filter in `ChEventBus` for player-side listeners.
- Tests: one headless test each for:
  - the run sequence and fight types
  - the stage option rules
  - buy, sell, capacity and reorder
  - the drop-zone accept rules
  - each modifier's effect

  The existing garage tests need updating for the removed strip and body buttons.
