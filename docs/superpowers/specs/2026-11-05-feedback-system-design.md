# Feedback system design

Date: 2026-11-05. Branch base: `garage-battle-ui`.

## Intent

The battle slice works but is not fun to play. One reason is that parts give almost no feedback: today
the only reaction is a 0.2 s ring around a part the player fires (`ChBattle._draw_markers`). This adds
one central feedback system so that whenever a part acts or is acted on, in the fight, in the garage
and in the UI, the thing itself pops and wobbles, Balatro style, together with pop-up text, pixel
particles and screen shake.

Success: playing the slice, every fire, hit, ignition, freeze and break is readable at a glance, and
moving parts around in the garage and clicking buttons feels bouncy instead of dead.

## Goals

- One feedback manager that any code can ask for a named feedback on a target.
- Feedback on all three surfaces in this pass: battle parts (and the chassis), garage part cards and
  parts placed in the pit, and UI buttons.
- The target itself visibly pops and wobbles (scale and rotation), in battle too.
- A feedback can combine: the wobble, a text pop-up, particles and screen shake.
- Use existing, well-maintained solutions where they exist; do not rebuild them.

## Non-goals

- **No sound.** No sound manager, no audio hooks, no audio fields in the profiles. (User decision.)
- "Passive" feedback (a looping idle effect on parts that react without firing). Ignored for now:
  every feedback is a one-shot trigger. (User decision.)
- Hit-stop (freeze frames). Dropped by the designer, not the user: the fight's physics runs on
  wall-clock physics frames, so pausing the sim and projectiles can change a fight, and a global
  `Engine.time_scale` pause would also freeze the wobble. Revisit after the fight loop steps its
  world from the tick.
- The car flipping too easily. Real problem, separate piece of work after this one.
- Replacing the status markers (`_draw_markers`: blue freeze tint, red burn outline, white X on a
  broken part). Those show state, not events, and stay. The fire pulse ring is replaced by the new
  `fired` feedback.

## Anti-goals

- Feedback must never change the fight. It writes nothing to fight state: no collision shape, mass,
  body position, part or chariot field, energy, or sand cell is touched by feedback code.
  (Designer's call, see below: fights are not frame-rate independent today. `ChBattle.start` ticks
  on process frames while the world and `ChProjectile` move on physics frames, so a same-seed replay
  can already differ. Making fights repeatable is out of scope; the guarantee here is the narrower
  "feedback writes nothing".)
- No sloppy or low-adoption addons. Any third-party addon must be credible, at least dozens of GitHub
  stars and maintained. The user explicitly rejected LabelUpX and Wallop Lite on this ground.
- No twitchy motion. A part that triggers repeatedly should wobble harder, not snap back to a
  restarted animation. This is why springs were chosen over tweens (below).

## Constraints found in the code

- **Battle parts are physics bodies.** Each part and the chassis is a `PixelRigidBody` (Node2D) that
  draws its own texture in `_draw()` (`addons/noita_engine/engine/godot/pixel_rigid_body.cpp:126`).
  The same texture's pixels are the collision hull at join. Bodies are stamped into the sand grid
  only for the duration of a sim tick and unstamped afterwards, so what is on screen is the node's
  own draw, not grid cells. Scaling the body would mean restamping, so it cannot be scaled.
- **World units are cells.** The battle camera zooms 4 to 4.5x (`ChBattle.ZOOM_*`), so a world-space
  Label at font size 20 would be enormous; text sizing must account for that.
- **The bus already carries what feedback needs** (`game/battle/ch_event.gd`): `part_fired`, `hit`
  (`source` = attacking part, `data.target_part` = struck part or null when the hull was hit,
  `data.hp_damage`), `caught_fire`, `frozen`, `thawed`, `part_broken`, `energy_gained`.
- **Pit parts are not nodes.** `ChGarage._draw` paints every placed part in one pass
  (`ch_garage.gd:544`) through `ChPartCard.paint`. The held part is painted on `_held_layer`.
- **Cards and buttons are Controls.** `ChPartCard` extends `Button`; garage top bar buttons (PrevBody,
  NextBody, FightButton) and the result panel's back button are plain `Button`s.
- **Headless tests drive real fights** (`tests/run_tests.gd`, `tests/battle/test_battle.gd`). Anything
  added to the battle scene must run headless and must not slow or change those fights.
- Godot 4.7, Forward Plus. The only addon today is `noita_engine`.

## Approaches considered

**A. A spring component per target (chosen).** Every target owns a small child node holding a
damped spring for scale and rotation. A feedback "kicks" the spring (an impulse) and it rings back
to rest. Kicks add, so rapid triggers stack into a bigger wobble. This is how Balatro's cards move.
Cost: pit parts must become one node each.

**B. Tweens on nodes.** The manager plays an elastic/back Tween on scale and rotation. Simplest, and
closest to the first wording of the request, but a re-trigger must kill and restart the tween, which
on rapid fire reads as twitchy. Also needs the pit split.

**C. Springs without nodes.** The manager keeps a spring per target ID and every draw site reads it.
The pit could keep its one draw pass, but every draw site must opt in, and Controls would still use
node transforms, so there would be two mechanisms.

The user picked **A**.

## The design (decided)

### Feedback manager

- One autoload (working name `ChFeedback`). Public entry: request feedback `kind` on `target`, with
  optional overrides (text, colour, position).
- Each kind is described by a profile: spring kick (scale impulse, rotation impulse, random sign on
  rotation), optional text, optional particles, optional shake amount.
- In battle it subscribes to the fight's `ChEventBus` (one listener key, like the HUD's
  `hud_listener`) and turns events into feedback, so no behaviour script changes.
- Garage and UI call it directly.

### Splitting look from collision (battle)

- Each part body and the chassis keeps its texture (so the hull, mass and collision are untouched),
  but its own draw is hidden with `self_modulate.a = 0`, which hides only the node's own draw and not
  its children.
- A child visual node with the same art follows the body for free (it is a child) and carries the
  spring. All wobble happens on the child, so physics never sees it.
- The visual may poke past the collision box for a few frames while scaled up. That is accepted; the
  overshoot is part of the feel.

### Feedback kinds (all one-shot "trigger" for now; names are not important to the user)

Battle, from the bus:

| Event | Who reacts | Feedback |
|---|---|---|
| `part_fired` | the firing part | `fired`: punchy pop |
| `hit` | the attacking part | `landed`: pop on the weapon |
| `hit` | `target_part`, or the hit chassis when null | `struck`: recoil wobble, damage number, sparks, small shake |
| `caught_fire` | the part | `caught_fire`: wobble, fire-coloured particles, text |
| `frozen` | the part | `frozen`: stiff squash, frost-coloured particles, text |
| `thawed` | the part | `thawed`: small release wobble |
| `part_broken` | the part | `broken`: big pop, debris particles, bigger shake |
| `energy_gained` | the source part | `energy`: small pop, "+N" text |

Weapon firing and a part catching fire are separate feedbacks (user requirement).

Garage:

| Moment | Target | Feedback |
|---|---|---|
| card pressed (`pick_part`) | the card | `activate` |
| card hovered | the card | `hover`: small kick |
| part dropped into a slot (`drop_part`) | the new pit part node | `placed`: big settle bounce |
| part lifted (`lift`) | the card it returns to | `activate` |
| body cycled (`cycle_body`) | the hull | `placed` |

UI: every Button (top bar, Fight, result panel back) gets `activate` on press and `hover` on hover.

### Garage pit split

The placed parts become one node each (with a spring child), positioned from the existing
`screen_of(path)` / `_box_at` maths and painted with `ChPartCard.paint`, so the art rule stays in one
place. The hull likewise becomes a node so it can wobble. Slot markers, the hover range circle and
the held part can stay in the immediate-mode draw.

### Existing solutions to use

- **Screen shake: [Phantom Camera](https://github.com/ramokz/phantom-camera)** (MIT, about 3.6k stars,
  active). Shake via its `PhantomCameraNoiseEmitter2D`. It expects a `PhantomCameraHost` on the
  `Camera2D` and an active `PhantomCamera2D`; the battle's framing maths (`camera_frame`,
  `camera_eased`, kept as is) should drive the `PhantomCamera2D` instead of the `Camera2D`. The garage
  also needs a camera (or a shake on its root Control) for a garage shake; see "left to the builder".
- **Wobbly text: [GodotRichTextLabel2](https://github.com/chairfull/GodotRichTextLabel2)** (MIT, about
  290 stars, Godot 4). Gives pop-up text bouncy and wavy animation inside a `RichTextLabel`.
- **Pop-up motion: our own,** about 30 lines with Tween + pooled labels. No floating-text addon has
  more than a handful of stars, so this is the one deliberate exception to "don't build from scratch".
- **Particles in battle: the engine's `PixelWorld.spawn_visual_particles(color, position, velocity,
  count, spread, lifetime, gravity_scale, collides)`** (`pixel_world.cpp:102`): pixel-sized sparks
  that match the art. They are visual only and vanish at end of life or on contact; they never become
  sand cells (`particles.cpp:125`), which is what keeps them out of fight state. Never use
  `spawn_particles` (material) for feedback. They share one pool with the fight's real particles
  (cap 20,000, `particles.h:59`), and a full pool makes Flamethrower/Chainsaw drop cells, so: a hard
  cap per feedback (designer's proposal: 24 particles) and a global budget (proposal: feedback skips
  its particles when the pool is above 75% full). No VFX pack.
- **Particles in garage/UI: Godot's built-in `CPUParticles2D`.**

Both addons must be checked to load and work on 4.7 (and headless) before anything is built on them.
If either fails, stop and bring it back to the user rather than swapping in a lesser addon.

## Left to the builder

- Spring constants, kick sizes, colours, text wording and particle counts per kind. Tune by playing;
  Balatro's cards are the reference.
- Whether profiles are `.tres` resources or a const table. (Proposal: resources, so they tune in the
  editor.)
- How pop-up text is placed in battle: a screen-space layer at the projected world point, or a
  world-space label scaled by the inverse zoom.
- Pooling sizes for labels and particle nodes.
- How the spring child finds the art to draw: share the body's texture, or draw through
  `ChPartCard.paint` / `ChTextures`.
- How Phantom Camera is wired into the battle and garage scenes, as long as current framing behaviour
  is kept.
- Whether to keep the HUD energy pips and HP bars static or give them `hover`/`activate` wobble.
  (Proposal: an HP bar gets a small kick on its side's `struck`.)
- Tests: at minimum, the spring maths; that feedback writes no fight state (e.g. a fight with
  feedback on leaves every part/chariot field and body transform exactly as the bus and physics set
  them, and the visual child's transform is the only thing that moves); the particle cap and budget;
  and that the pit nodes land where the old draw put the parts. Feedback runs in headless tests too
  (it is cheap and has no hit-stop); existing frame budgets such as `CHAIN_FRAMES` must still pass.
