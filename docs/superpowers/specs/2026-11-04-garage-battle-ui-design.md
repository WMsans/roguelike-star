# Garage and battle: make the slice playable

## Intent

The battle slice works in tests but cannot be played. In the garage, 8px text sits at 320×180, the
parts list runs down the left, the chariot is a few flat rectangles, and you have to hold the mouse
button down to drag a part. In the battle you cannot see either chariot. This pass makes both
screens clear and playable with placeholder art. It does not try to make the game look finished.

## What is wrong today (measured)

- **Battle camera zooms the wrong way.** `ChBattle._camera_at` (`game/battle/ch_battle.gd:354`)
  works out `zoom = box / VIEW` (≥ 1) and treats it as a zoom-out, the way Godot 3 did. In
  Godot 4 a zoom above 1 magnifies. On a real run the player was at x=60, the enemy at x=390, and
  the camera sat at x=225 with zoom 1.27, showing roughly x 100–370. Neither chariot was in the
  shot.
- **Parts are one pixel.** `ChPartDef.size` defaults to `(1,1)` and only `wheel.tres` sets a size,
  so every weapon is a 1×1 body in the fight and a 3px dot in the garage.
- **The screen is not the size the layout assumes.** `project.godot` uses stretch aspect
  `expand`, so the window is not the 320×180 the HUD and the garage lay themselves out in.
- **A fight never ends early.** `ChBattle.start` always runs its full `FIGHT_TICKS` (60 s), even
  after a result. That is why `ChMain` has to hide a fight that is still ticking and then retire
  it later.

## Goals

- **Garage:** the chariot sits in the middle of the screen and the parts run along the bottom in
  a horizontal strip. Click a part to pick it up and it follows the cursor. Click an empty slot on
  the chariot to mount it, or click anywhere else to put it back.
- **Parts in the strip are drawn at the same pixel scale as the chariot.** A part looks identical
  in the strip, in your hand and on the hull, so it goes straight onto the chariot with no
  scaling.
- **UI is sharp.** Buttons, names, numbers and panels render at full window resolution. Only the
  world, the chariots and the part art are chunky pixel art.
- **Battle:** the camera stays close on the two chariots, and both chariots and their parts are
  clearly visible.
- **Battle HUD:** both sides' HP and the player's energy are readable at a glance.
- **End of fight:** the result is clear, and you go back to the garage when you're ready.

## Non-goals

- Real art: no sprites, icons, styled panel art or animation polish. Placeholder colored shapes
  stay.
- A shop, more enemies, more bodies or new parts.
- Rebalancing parts, beyond what giving them real sizes forces.

## Anti-goals (fail even if it works)

- **No labels on the chariots in battle.** No "YOU"/"ENEMY" tags. (User decision.)
- **No event feed or ticker in battle.** The current `caught_fire`-style ticker goes away and
  nothing replaces it. (User decision.)
- **No on-screen hints or instruction lines on either screen.** No "A / D drive" hint in battle,
  no "click a part" line in the garage. (User decision.)
- No paging in the parts strip, and no part shown at a different scale in the strip than on the
  chariot.
- No hold-to-drag in the garage. Placing a part is click, then click.

## Approaches considered

1. **Raise the game resolution and draw the world zoomed (chosen).** The viewport becomes
   1280×720. The pixel world, the chariots and the garage hull draw through a zoom, with
   nearest-neighbour texture filtering (already the project default, `default_texture_filter=0`).
   The UI is ordinary Godot Control nodes, so it is sharp for free. This is the smallest change: the
   battle already draws through a zoomed Camera2D, and the sand rendered correctly at zoom 1.27 in a
   test run. The cost is that while the camera eases between zooms, world pixels can look slightly
   uneven in size. The builder should snap or quantise the zoom to reduce shimmer.
2. **Low-res world SubViewport with a high-res UI on top.** The world renders at 320×180 and is
   scaled up, and the UI draws over it. Every pixel is always exactly the same size, but the camera,
   the garage's mouse-to-slot mapping and the HUD layout all have to convert between two spaces, and
   a close moving camera steps in whole chunky pixels. Rejected as more plumbing with jitterier
   motion.

Both rejected and chosen approaches use real Godot UI nodes (buttons, panels, one shared Theme) in
place of the hand-drawn `_draw` UI and hold-to-drag.

## Decisions

### Screen setup

- Viewport 1280×720, stretch mode `canvas_items`, aspect `keep`, so both screens lay out
  identically at any window size (letterboxed rather than expanded).
- **One shared Theme** (`game/ui/` or similar) for every Control: font sizes readable at 720p,
  dark panels, one accent colour. The garage mockup used dark grey panels, an amber accent
  (`#e8c35a`) and an orange Fight button.

### Part sizes (data change)

Every part def gets a real `size`, in cells:

| Part | Size |
|---|---|
| Wheel | 12×12 (unchanged) |
| Ice Cream Mace | 8×4 |
| Cutter Chainsaw | 10×4 |
| Flamethrower | 8×4 |
| Hearth | 6×6 |
| Cutter Rocket | 8×3 |
| Corsair Harpoon | 10×3 |
| Ember Battery | 5×5 |
| Firebolt Launcher | 8×4 |
| Ring of Fire | 6×6 |
| Freeze Charge | 4×4 |
| Strut | 3×8 |

These are the user-approved starting values. They also become the physical bodies in battle (see
the risks below). Slot and extension positions in the body and part `.tres` files **stay as they
are**, so parts at these sizes will overlap each other and the hull. That is handled in the
engine, below, not by moving slots.

### Engine: a chariot's own parts do not collide with each other (user decision)

Today `body_filter` (`addons/noita_engine/engine/core/physics.cpp:24`) puts every body in one
category, with `groupIndex` set only for cell proxies. Box2D therefore skips only pairs that share
a joint: a part and its holder. Sibling parts, and a nested part against the chassis, collide.

Add a per-body **collision group** to `PixelRigidBody`, for example an `int collision_group`
property, with 0 meaning none. Two bodies with the same non-zero group never collide with each
other. Every other collision is unchanged: a body against the other chariot, terrain and
projectiles. `ChChariotBuilder` sets one group per chariot (for example `side + 1`) on the chassis
and on every part.

- **Do not reuse `groupIndex`.** It already carries the positive per-body group that keeps a body
  out of its own cell proxies. A Box2D custom filter callback (`b2World_SetCustomFilterCallback`),
  or another mechanism that leaves the proxy filter alone, is the expected route. The exact
  mechanism is left to the builder.
- **Overlapping pixel stamps.** Bodies stamp their pixels into the world grid. The builder must
  check what happens when two bodies in one group stamp overlapping cells (lost cells, mis-read
  damage, a body pushed out of the grid) and fix it in the same change if it breaks.
- Rebuild the extension with the addon's own `addons/noita_engine/build.sh` / `SConstruct`.
  Add a test in `tests/engine/test_engine_additions.gd` that two same-group bodies placed
  overlapping stay put while a different-group body still collides.

### Garage

Layout, top to bottom:

- **Top bar:** a body switcher `◀ <Body name> ▶` (cycles Cutter → Dozer → Corsair and back, the
  existing `cycle_body`, plus a backwards step), the current body's HP and energy cap as text, and
  a **Fight** button on the right.
- **Middle:** the chariot hull centred, drawn at one integer pixel scale (the garage zoom). Empty
  slots show as dashed boxes. When you're holding a part, the slot under the cursor highlights.
- **Info panel** (top right of the middle area): appears when you hover a strip card or a mounted
  part. It shows name, energy cost, cooldown and hook text. When the hovered part has a proximity
  range, the range circle is drawn on the chariot, as it is today.
- **Bottom strip:** one card per part type, in a single row. Each card shows the part's art at the
  **garage zoom** (the same scale as the hull), its energy cost, and the count carried (`×2`). A
  card whose count is 0 stays in the strip, greyed out and not clickable. The strip scrolls
  sideways if the cards ever stop fitting. No paging.

Interaction:

- **Click a card:** pick that part up. A copy at the garage zoom follows the cursor. Clicking the
  same card again, or clicking anywhere that isn't a free slot, puts it back.
- **Click a free slot while holding:** mount the part there (`drop_part`). Every free slot that
  `_free_slots` lists is valid, including extension slots on a mounted parent, so a part can be
  dropped onto a strut's extension.
- **Click a mounted part while holding nothing:** send it and everything mounted on it back to the
  strip (`lift`).
- **Right-click a mounted part:** flip it (`click_part` / `toggle_flip`). This moves off left-click,
  because left-click now means "send it back".
- **No hint lines** anywhere in the garage. The mockup's "Click a part to pick it up" line is
  dropped. (User decision.)

The mockup that was approved is in
`.superpowers/brainstorm/32931-1793838930/content/garage-v2.html`, **minus** its hint line.

### Battle

- **Camera:** fix the zoom so it frames both chassis plus a margin, using Godot 4's semantics
  (visible size = viewport / zoom). It tightens as the chariots close in and widens as they
  separate, clamped between a closest and a widest zoom, and kept inside the arena. It eases toward
  the target rather than snapping.
- **Spawn distance:** move the spawns from x=60/420 (360 apart) to roughly 120–150 cells apart
  around the arena centre, so the first frame is already a close shot. The wood/water patches may
  then sit between or under the spawns. That is acceptable as long as a chariot still starts on
  ground it can drive off.
- **HUD (sharp Control nodes):**
  - Player HP bar top left and enemy HP bar top right, each with the body or enemy name and
    `current / max`.
  - Player energy under the player HP bar as pips (one per energy unit, filled vs. empty), plus a
    "N parts waiting" note when the energy queue is non-empty.
  - **Remove** the event ticker. Add no chariot tags and no control hints.
  - Keep the part status markers (frozen tint, burning outline, broken X) and the fire pulse. They
    are drawn in the world and read on the parts themselves.
- **End of fight:** when either chassis reaches 0 HP, the fight **stops**. A centred panel shows
  **You win** or **You lose** with a **Back to garage** button, and the garage returns only on that
  click. A fight that runs out its time limit shows the same panel with a draw message, and a fight
  that could not start shows the panel with its message. *(The draw and could-not-start wording is
  the designer's call.)* Behind the panel, the world freezes (`world.simulating = false`), so
  nothing moves or takes damage after the result. *(Designer's call.)*
- **Fight stopping:** `ChBattle` gains a real end: the tick loop exits on a result (or on its time
  limit). That should let `ChMain` drop its hide-and-retire machinery (`retiring`,
  `_retire_current`, `_release_retiring`, the 2-second `RESULT_SECONDS` window), since a fight is
  always over by the time the result panel shows.

The approved battle mockup is `.superpowers/brainstorm/32931-1793838930/content/battle-hud.html`,
**minus** its YOU/ENEMY tags, its feed and its A/D hint.

## Constraints

- Godot 4.7 with the `noita_engine` PixelWorld addon. Chariots are `PixelRigidBody` parts joined to
  a chassis.
- The headless test suite (`tests/run_tests.gd`) must stay green. `tests/test_garage.gd` drives the
  garage's logic methods (`drop_part`, `lift`, `click_part`, `cycle_body`, `request_fight`) and
  `ChMain`'s loop. Keep those methods working. Tests of `ChMain`'s result window and fight
  retirement will change along with that behaviour.
- The garage's logic must stay in methods the tests can call directly. The UI calls the same
  methods.

## Risks for the builder

- **Real part sizes change the physics.** A part becomes a body many cells across, jointed onto
  the hull at its anchor. Even with the collision group, part-vs-terrain contact and anything that
  samples a part's footprint (`ChPartRuntime.sample_rect`, proximity checks, the flamethrower's
  margin pin, the AI's reach from part edges) may behave differently. Expect test expectations in
  `tests/battle/` to shift, and check that every starter build and `dozer_cook` still spawns, drives
  and fights.
- Moving the spawns touches `ChArenaBuilder` and `tests/battle/test_arena.gd`'s spawn checks.
- The garage zoom has to fit the largest hull (Corsair, 48×10) plus parts hanging off it in the
  middle area, and the largest card art (Wheel 12×12, Chainsaw/Harpoon 10 wide) in the strip.

## Left to the builder

- Exact pixel zooms, panel sizes, font sizes and colours within the approved look.
- The closest/widest camera zoom, the easing rate, and the zoom-snapping method.
- How the Theme and UI scenes are organised.
- Exact spawn x positions within the stated range.
