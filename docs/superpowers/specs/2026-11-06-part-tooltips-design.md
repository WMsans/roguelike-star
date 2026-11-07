# Part tooltips design

Date: 2026-11-06. Branch base: `garage-battle-ui`.

## Intent

Part hints today are inconsistent and mostly empty: the garage's fixed `InfoPanel` (top right of
the pit, `garage.tscn:63`) shows a name, a "Cost · Cooldown" line and `hook_text`, and only 5 of the
12 parts have any `hook_text`. This replaces it with one unified, Balatro-style tooltip that every
part uses:

- A **main box** on the normal panel background: the part's name, its cost/cooldown line, and a
  short description, preferably bullet points.
- Each **keyword** in the description (a concept such as fire, freezing, sparks) is highlighted in
  its own colour.
- Under the main box, **one box per keyword**, with that keyword's colour as its background,
  explaining what the concept does. Example: the Flamethrower's description highlights fire, and a
  fire-coloured box below explains how burning works.
- The tooltip is bouncy and juicy, driven by the existing feedback system (`Feedback`, `ChJuice`).

Success: hovering any part in the garage tells the player what it does and what its concepts mean,
at a glance, and the tooltip feels as alive as the cards and buttons already do.

## Goals

- One tooltip component used for every part, wherever a part can be hovered in the garage: strip
  cards and parts mounted on the hull.
- Descriptions describe what each part does **in the game today** (its behaviour script and def),
  not what `docs/design-doc/parts-list.md` plans. (User decision.)
- One shared keyword glossary, so a concept reads and looks the same on every part.
- The tooltip pops in through the feedback system.
- The component knows nothing about the garage, so the planned pre-fight enemy-build preview can
  reuse it.

## Non-goals

- **No hover in battle.** (User decision.)
- **The pre-fight enemy-build preview phase.** It is planned but out of scope today. (User
  decision.) This design only keeps the tooltip reusable for it.
- Aligning the game's parts with `parts-list.md`. Descriptions are rewritten when parts change.
- Changing any part's behaviour or numbers. In particular, Freeze Charge still freezes directly on
  hit, even though `parts-list.md` now says elemental statuses come only from the sand sim. Its
  description says what it does today.

## Anti-goals

- A tooltip that lies: every number and claim must match the behaviour script and def.
- Accidental highlights: the word "fires" (shoots) must never be highlighted as the fire element.
  This is why keywords are tagged explicitly (below).
- Long prose. Main-box text is a few short bullets. Keyword boxes are one or two sentences.

## Constraints found in the code

- `ChPartDef` (`game/data/ch_part_def.gd`) has `hook_text: String` and nothing else descriptive.
  Defs are `.tres` files in `game/data/parts/`.
- The garage fills the panel through `_fill_info(info: Dictionary)` (`ch_garage.gd:377`).
  - `selected_info(path)` and `_info_of(def)` build the dict.
  - Cards wire `mouse_entered` / `mouse_exited` to `_fill_info` in `_build_strip` (`ch_garage.gd:473`).
  - The hull hover comes from `_follow_pointer` → `_hover_at`.
- `tests/test_garage.gd` asserts on `Pit/InfoPanel` and its `Rows/Name` label (around lines
  610–660). Those tests must move to the new tooltip.
- `RicherTextLabel` (`addons/richtext2`) is installed and already used by `ChPopups`. It supports
  BBCode colour and animated text effects.
- `Feedback.play(kind, target)` kicks a target's `ChJuice` child (`ChJuice.attach`). Profiles are
  `.tres` files in `game/feedback/profiles/`, and a new kind must be added to
  `ChFeedbackManager.KINDS`.
- UI colours come from `ChUi` (`PANEL`, `TEXT`, `ACCENT`…). Base font size is 20, and cards use 12.

## Approaches considered

How keywords are marked in each description:

- **A. Explicit tags (chosen).** The description says which glossary entry each keyword is and
  what word to show: `{burn:catches fire}` shows "catches fire" in burn colour, and plain `{freeze}`
  shows the entry's own name.
  - Handles word forms ("burning", "frozen", "catches fire") with no alias lists.
  - Never highlights by accident.
  - Costs a little markup per description.
- **B. Automatic matching.** Plain text, and any glossary word found is highlighted.
  - Nothing to write.
  - Needs alias lists for every word form, and over-matches "fire" (shoot) against fire (the
    element), which this game's text uses constantly.

The user picked **A**.

## The design (decided)

### Data

- `ChPartDef` gains `description: PackedStringArray`, one entry per bullet, with keyword tags.
  It replaces `hook_text`, which is removed along with its uses.
- **Tag syntax:** `{key}` or `{key:shown text}`. `key` names a glossary entry.
- **One glossary** maps key → display name, colour and explanation text.
- **Keyword boxes:** one per distinct key, in order of first appearance in the description. A key
  tagged twice gets one box.
- **Unknown key:** the text renders plain, no box is added, and a warning is pushed. A test makes
  sure every shipped description resolves.

### Tooltip component

- A self-contained `ChPartTooltip` Control. Its API is roughly "show this def next to this rect"
  and "hide". It does not depend on `ChGarage`.
- It is a vertical stack of panels:
  - **Main box (`ChUi.PANEL` background):** name, then "Cost N · Cooldown Xs" (omitted for
    passives: cooldown 0, cost 0), then the bullets. Keywords are coloured inline.
  - **Keyword boxes:** each has a background in the keyword's colour, its name, and its
    explanation, with text colour chosen for contrast on that background.
- **Placement:** anchored to the hovered thing, not the cursor, the way Balatro anchors to a card.
  - For a strip card: above the card.
  - For a hull part: beside the part's drawn box.
  - In both cases, clamped to stay fully on screen.
- It ignores the mouse (`MOUSE_FILTER_IGNORE`), so it never steals hover from what is under it.
- **Hidden while a part is held** (`held_id` set), for both cards and hull parts. Picking a part
  up hides it, and dropping or cancelling lets hover show it again. (User decision: placing stays
  clean, the way Balatro hides tooltips while a card is dragged.) So the wiring checks held state
  in `_follow_pointer`, `pick_part`, `cancel_hold` and `drop_part`.
- The garage's `InfoPanel` is removed. Card and hull hovers show and hide the tooltip instead of
  calling `_fill_info`.

### Juice

- Every box (main and each keyword box) gets its own `ChJuice`, on a child that holds the box's
  content rather than on the container-managed panel itself, so the juice's scale and rotation
  don't fight the VBox layout. (Designer's call.)
- The stagger needs no change to the shared feedback code: each box's spring can start below 1.0
  (or its kick can wait a few hundredths of a second) before `Feedback.play`. (Designer's call.)
- On show, the boxes pop in top to bottom, slightly staggered, through `Feedback.play` with a new
  `tooltip` profile, so the stack bounces in like a Balatro card.
- Moving straight from one part to another re-kicks rather than rebuilding from rest. The springs
  add, consistent with the feedback design's "no twitchy restarts".
- Keyword words in the main box use a gentle RicherTextLabel effect (for example a small wave), so
  they read as interactive concepts.

### Glossary and descriptions (draft wording)

All wording below is a draft. The builder checks every number against the behaviour scripts and
defs. If the code disagrees, the code wins and the text changes.

Glossary:

| Key | Name | Explanation |
|---|---|---|
| `burn` | Burning | A part touching 3 or more fire or lava cells catches fire. While any of a chariot's parts burn, it loses 5 HP a second. 6 water cells put a part out. |
| `freeze` | Frozen | Frost and ice build up a part's freeze meter. When it fills, the part stops: it can't fire, and a wheel locks. The meter drains once the cold is gone. |
| `sparks` | Sparks | Hot sparks that fly from cuts. They can set flammable ground alight. |
| `energy` | Energy | Parts spend energy to fire. Your chariot refills it over time. |
| `charges` | Charges | Fires this many times per battle, then stops. |
| `proximity` | Proximity | Affects your own parts within range. The garage shows the range as a circle while you hover. |
| `extension` | Extension slots | Parts bolted onto this one. They move with it, and fall off if it breaks. |

Descriptions:

| Part | Bullets |
|---|---|
| Flamethrower | Sprays a 1 s burst of {burn:fire} ahead. · 45 damage over the burst. |
| Firebolt Launcher | Lobs a bolt that bursts into a pool of {burn:fire}. · 25 damage. · 5 {charges}. |
| Ring of Fire | A ring of {burn:fire} grows 24 cells out over 1 s. · 10 damage to every part it crosses, yours too. |
| Hearth | Charges for 1 s, then rings your chariot with {burn:fire} for 2.25 s. · 45 damage to enemies inside. · Can set your own parts {burn:alight}. |
| Cutter Chainsaw | Cuts anything within 14 cells: 20 damage. · Every cut throws {sparks}. |
| Cutter Rocket | Fires straight ahead: 30 damage, digs the ground it hits. · When anything {burn:catches fire}, its next shot charges twice as fast. |
| Ember Battery | When anything {burn:catches fire}, on either chariot, gain 3 {energy}. |
| Freeze Charge | Weapons within 24 cells ({proximity}) also {freeze} what they hit. · Two hits freeze a part. |
| Ice Cream Mace | Swings at anything within 6 cells: 20 damage. · Hits on a {freeze:frozen} part deal ×3 and thaw it. |
| Corsair Harpoon | Fires a line up to 120 cells ahead. · Hooks the enemy hull and reels both chariots together for 1.5 s. · 5 damage. |
| Strut | Holds 2 more parts ({extension}). |
| Wheel | Drives your chariot. |

## Left to the builder

- Keyword colours, box padding, font sizes, stagger timing and the `tooltip` profile's kick values.
  Tune by eye; Balatro is the reference.
- Whether the glossary is a const table in one script or a `.tres` per entry (like feedback
  profiles).
- How the tooltip hides: instantly, or a quick shrink.
- Whether numbers in bullets get an accent colour (Balatro-style), as long as they get no boxes.
- Where the tooltip node lives in the garage scene, as long as it draws above the pit, strip and
  held layer.
- Tests, at minimum:
  - tag parsing (plain text, `{key}`, `{key:text}`, an unknown key);
  - keyword boxes deduplicated and in first-appearance order;
  - every shipped part has a description whose keys all resolve;
  - hovering a card or a hull part shows the tooltip with that part's name, and moving off hides it;
  - picking a part up hides the tooltip and keeps it hidden while held; after a drop or a cancel,
    hover shows it again;
  - the tooltip stays on screen at the screen edges;
  - the existing `InfoPanel` assertions in `tests/test_garage.gd` are replaced.
