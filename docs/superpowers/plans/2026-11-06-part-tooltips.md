# Part Tooltips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the garage's fixed InfoPanel with one Balatro-style part tooltip. It has a main box
of short bullets with coloured, waving keywords, and one coloured box per keyword under it. The
boxes pop in through the feedback system.

**Architecture:** The pieces are:
- `ChKeywords` is a static glossary. It also parses `{key}` / `{key:shown}` tags into richtext2
  BBCode.
- `ChPartDef.description` (a `PackedStringArray` of tagged bullets) replaces `hook_text`.
- `ChPartTooltip` is a self-contained Control. It stacks pooled PanelContainers by hand, without a
  VBox, so each box's `ChJuice` scale and rotation are never reset by a container. It places itself
  beside an anchor rect, clamped to bounds.
- `ChGarage` owns one tooltip. A single `_refresh_tooltip()` decides what it shows: the hovered
  card, the hovered hull part, or nothing while a part is held.

**Tech Stack:** Godot 4.7.2, GDScript, GodotRichTextLabel2 (`addons/richtext2`, `RicherTextLabel`), the existing `Feedback` autoload / `ChJuice`.

**Spec:** `docs/superpowers/specs/2026-11-06-part-tooltips-design.md`

## Global Constraints

- Run tests with `godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]`. Output
  ends with `N passed, M failed`, and every task ends with the whole suite at `0 failed`.
- Tests extend `ChTest`. Every `test_*` method calls `_complete()` last, and nodes it builds go
  through `_track()`.
- No hover in battle. No battle file changes.
- Descriptions describe the game as it is today. Every number in a description must match its
  behaviour script or def. If they disagree, the code wins and the text changes; no behaviour changes.
- Keywords are marked explicitly with tags. There is no automatic word matching.
- The keyword wave uses richtext2's `[sin]` effect. No hand-rolled text animation.
- The tooltip is hidden whenever `ChGarage.held_id != &""`.
- The tooltip never takes mouse input: it and every Control under it use `MOUSE_FILTER_IGNORE`.
- `ChPartTooltip` must not reference `ChGarage`, so the future enemy-build preview can reuse it.
- Colours come from `ChUi` where one exists (`PANEL`, `TEXT`, `ACCENT`).

## Review Focus

- **Pointer goes straight from a hull part onto the strip.** The pit gets no motion event, so
  `hover_path` stays stale, and leaving the card would bring back the old hull tooltip. Expected:
  leaving the pit clears the hull hover. Tested in Task 4
  (`test_tooltip_leaving_pit_clears_hull_hover`).
- **Moving from one card straight to another.** `mouse_exited` of A and `mouse_entered` of B arrive
  in either order. Expected: the tooltip ends on B and is not hidden. Tested in Task 4
  (`test_tooltip_card_to_card`).
- **A card at the far left or right of the strip, or a hull part near an edge.** Expected: the
  tooltip stays fully on screen. Tested in Task 3 (the `place` tests).
- **richtext2's own preparse.** It treats `{...}` as context expressions and `*`, `_`, `~` as
  markdown. Expected: tags are converted before the label sees them, and context and markdown are
  off on tooltip labels, so no stray text appears. Tested in Task 3
  (`test_keyword_bbcode_renders_clean`).
- **A body swap while hovering a hull part.** Expected: the tooltip hides, because the hovered path
  belongs to the old hull. Tested in Task 4 (`test_tooltip_hidden_by_body_swap`).

---

### Task 1: Keyword glossary and tag parser

**Files:**
- Create: `game/ui/ch_keywords.gd`
- Test: `tests/ui/test_keywords.gd`

**Interfaces:**
- Produces:
  - `class_name ChKeywords` (RefCounted, static only)
  - `const ENTRIES: Dictionary` mapping key → `{"name": String, "color": Color, "text": String}`
  - `static func has(key: StringName) -> bool`
  - `static func name_of(key: StringName) -> String`
  - `static func color_of(key: StringName) -> Color`
  - `static func text_of(key: StringName) -> String`
  - `static func text_color_on(background: Color) -> Color`: `Color(0.08, 0.08, 0.1)` when the
    background's luminance is above 0.5, else `ChUi.TEXT`.
  - `static func parse(line: String) -> Dictionary`, returning
    `{"bbcode": String, "keys": Array[StringName], "unknown": Array[StringName]}`.
  - `static func keys_of(lines: PackedStringArray) -> Array[StringName]`: known keys only, deduped,
    in order of first appearance.

`ENTRIES` (spec glossary, verbatim text; colours are starting values to tune):

| key | name | color | text |
|---|---|---|---|
| `burn` | Burning | `#d63c2f` | A part touching 3 or more fire or lava cells catches fire. While any of a chariot's parts burn, it loses 5 HP a second. 6 water cells put a part out. |
| `freeze` | Frozen | `#6fb6e8` | Frost and ice build up a part's freeze meter. When it fills, the part stops: it can't fire, and a wheel locks. The meter drains once the cold is gone. |
| `sparks` | Sparks | `#ff8c42` | Hot sparks that fly from cuts. They can set flammable ground alight. |
| `energy` | Energy | `ChUi.ACCENT` | Parts spend energy to fire. Your chariot refills it over time. |
| `charges` | Charges | `#a98be0` | Fires this many times per battle, then stops. |
| `proximity` | Proximity | `#5fbf8f` | Affects your own parts within range. The garage shows the range as a circle while you hover. |
| `extension` | Extension slots | `#9aa0aa` | Parts bolted onto this one. They move with it, and fall off if it breaks. |

Tag rules for `parse`:
- Regex `\{([a-z_]+)(?::([^}]*))?\}`.
- A known key becomes `"[0x%s;sin]%s[]" % [color_of(key).to_html(false), shown]`. `shown` is the
  text after the colon, or `name_of(key)` when there is none. The key goes into `keys`, duplicates
  allowed.
- An unknown key becomes `shown` (or the raw key when there is no colon), as plain text. The key
  goes into `unknown`, with a `push_warning`.
- Text outside tags is copied unchanged.

- [ ] **Step 1: Write the failing tests** in `tests/ui/test_keywords.gd`:

```gdscript
extends ChTest

func _tag(key: StringName, shown: String) -> String:
	return "[0x%s;sin]%s[]" % [ChKeywords.color_of(key).to_html(false), shown]

func test_parse_plain_text_unchanged() -> void:
	var out := ChKeywords.parse("Drives your chariot.")
	assert_eq(out.bbcode, "Drives your chariot.")
	assert_eq(out.keys, [])
	assert_eq(out.unknown, [])
	_complete()

func test_parse_tag_with_shown_text() -> void:
	var out := ChKeywords.parse("Sprays {burn:fire} ahead.")
	assert_eq(out.bbcode, "Sprays %s ahead." % _tag(&"burn", "fire"))
	assert_eq(out.keys, [&"burn"])
	_complete()

func test_parse_bare_tag_uses_entry_name() -> void:
	assert_eq(ChKeywords.parse("{freeze}").bbcode, _tag(&"freeze", "Frozen"))
	_complete()

func test_parse_unknown_key_renders_plain() -> void:
	var out := ChKeywords.parse("a {nope:thing} b {gone}")
	assert_eq(out.bbcode, "a thing b gone")
	assert_eq(out.keys, [])
	assert_eq(out.unknown, [&"nope", &"gone"])
	_complete()

func test_keys_of_dedupes_in_first_order() -> void:
	var lines := PackedStringArray(["{burn:a} then {freeze}", "{burn:b} {nope}", "{energy}"])
	assert_eq(ChKeywords.keys_of(lines), [&"burn", &"freeze", &"energy"])
	_complete()

func test_every_entry_complete() -> void:
	for key in ChKeywords.ENTRIES:
		assert_true(ChKeywords.name_of(key) != "" and ChKeywords.text_of(key) != "", "%s filled" % key)
	assert_eq(ChKeywords.text_color_on(Color.WHITE), Color(0.08, 0.08, 0.1), "dark text on light")
	assert_eq(ChKeywords.text_color_on(Color.BLACK), ChUi.TEXT, "light text on dark")
	_complete()
```

- [ ] **Step 2: Run** `godot --headless --path . --script res://tests/run_tests.gd -- keywords`. Expected: FAIL (`ChKeywords` not found).
- [ ] **Step 3: Implement** `game/ui/ch_keywords.gd` with the interfaces and table above. `ENTRIES` keys are StringNames (`&"burn"`). Compile the regex once in a `static var`.
- [ ] **Step 4: Run** the same command. Expected: `6 passed, 0 failed`. Then the full suite: `0 failed`.
- [ ] **Step 5: Commit** `git add game/ui/ch_keywords.gd* tests/ui && git commit -m "feat(ui): keyword glossary and tag parser"`

---

### Task 2: Part descriptions

**Files:**
- Modify: `game/data/ch_part_def.gd` (add `var description: PackedStringArray = []` next to `hook_text`; `hook_text` is removed in Task 4)
- Modify: all 12 `game/data/parts/*.tres` (add `description = PackedStringArray(...)`)
- Test: `tests/data/test_catalog.gd`

**Interfaces:**
- Consumes: `ChKeywords.parse`, `ChKeywords.keys_of` (Task 1).
- Produces: `ChPartDef.description: PackedStringArray`, with one tagged bullet per entry and no
  leading "•".

Bullets (spec table, one array entry per bullet):

| file | description |
|---|---|
| flamethrower | `Sprays a 1 s burst of {burn:fire} ahead.` / `45 damage over the burst.` |
| firebolt_launcher | `Lobs a bolt that bursts into a pool of {burn:fire}.` / `25 damage.` / `5 {charges}.` |
| ring_of_fire | `A ring of {burn:fire} grows 24 cells out over 1 s.` / `10 damage to every part it crosses, yours too.` |
| hearth | `Charges for 1 s, then rings your chariot with {burn:fire} for 2.25 s.` / `45 damage to enemies inside.` / `Can set your own parts {burn:alight}.` |
| cutter_chainsaw | `Cuts anything within 14 cells: 20 damage.` / `Every cut throws {sparks}.` |
| cutter_rocket | `Fires straight ahead: 30 damage, digs the ground it hits.` / `When anything {burn:catches fire}, its next shot charges twice as fast.` |
| ember_battery | `When anything {burn:catches fire}, on either chariot, gain 3 {energy}.` |
| freeze_charge | `Weapons within 24 cells ({proximity}) also {freeze} what they hit.` / `Two hits freeze a part.` |
| ice_cream_mace | `Swings at anything within 6 cells: 20 damage.` / `Hits on a {freeze:frozen} part deal ×3 and thaw it.` |
| corsair_harpoon | `Fires a line up to 120 cells ahead.` / `Hooks the enemy hull and reels both chariots together for 1.5 s.` / `5 damage.` |
| strut | `Holds 2 more parts ({extension}).` |
| wheel | `Drives your chariot.` |

- [ ] **Step 1: Write the failing test** in `tests/data/test_catalog.gd`:

```gdscript
func test_every_part_described() -> void:
	var catalog := ChCatalog.load_default()
	assert_eq(catalog.parts.size(), 12, "the slice's 12 parts")
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		assert_true(def.description.size() > 0, "%s has a description" % id)
		for line in def.description:
			assert_eq(ChKeywords.parse(line).unknown, [], "%s: every tag resolves" % id)
			assert_true(not line.begins_with("•"), "%s: the tooltip adds the bullet" % id)
	assert_eq(ChKeywords.keys_of(catalog.part(&"flamethrower").description), [&"burn"])
	assert_eq(ChKeywords.keys_of(catalog.part(&"freeze_charge").description), [&"proximity", &"freeze"])
	assert_eq(ChKeywords.keys_of(catalog.part(&"ember_battery").description), [&"burn", &"energy"])
	_complete()
```

- [ ] **Step 2: Run** `godot --headless --path . --script res://tests/run_tests.gd -- catalog`. Expected: FAIL (empty descriptions).
- [ ] **Step 3: Add the field and the 12 descriptions** from the table. Before writing each one, check its numbers against the part's behaviour script (`game/battle/behaviours/`), `ChPartRuntime` and `ChDamage`. If one is wrong, change the text and note it in the commit message.
- [ ] **Step 4: Run** the same command, then the full suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `git add game/data && git add tests/data && git commit -m "feat(data): tagged part descriptions"`

---

### Task 3: The tooltip component

**Files:**
- Create: `game/ui/ch_part_tooltip.gd`
- Create: `game/feedback/profiles/tooltip.tres` (`scale_kick = 3.0`, `rotation_kick_deg = 3.0`, everything else at the defaults; copy `hover.tres` as the template)
- Modify: `game/feedback/ch_feedback_manager.gd:10` (add `&"tooltip"` to `KINDS`)
- Test: `tests/ui/test_part_tooltip.gd`

**Interfaces:**
- Consumes: `ChKeywords.*` (Task 1), `ChPartDef.description` (Task 2), `ChJuice.attach/of`,
  `Feedback.play`, `ChUi.flat(fill, rim)`, `ChUi.PANEL/TEXT`.
- Produces:
  - `class_name ChPartTooltip extends Control`
  - `enum Side { ABOVE, RIGHT }`
  - `const WIDTH := 300.0`, `GAP := 8.0`, `EDGE := 8.0`, `POP_FROM := 0.5`, `STAGGER := 0.04`
  - `var def: ChPartDef`, which is null while hidden
  - `func show_part(def_in: ChPartDef, anchor: Rect2, side: Side, bounds: Rect2) -> void`. `anchor`
    and `bounds` are in the tooltip parent's local pixels.
  - `func hide_tooltip() -> void`, which sets `visible = false` and `def = null`
  - `func boxes() -> Array[PanelContainer]`: the main box first, then the visible keyword boxes in
    order
  - `func keyword_keys() -> Array[StringName]`
  - `func name_label() -> Label`, `func line_label() -> Label`, `func bullets_label() -> RicherTextLabel`
  - `static func place(anchor: Rect2, size: Vector2, bounds: Rect2, side: Side) -> Vector2`
  - `func restack() -> void`

Design decisions the implementer cannot infer:
- **Node layout.**
  - Root: `ChPartTooltip`, `mouse_filter = IGNORE`, `z_index = 10`. It starts hidden
    (`visible = false`, `def = null`) and builds its main box in `_init`.
  - Boxes are direct children of the root, not inside any Container, so their Juice scale and
    rotation survive.
  - Each box is a `PanelContainer` with `custom_minimum_size.x = WIDTH` and a VBox inside for its
    labels.
  - The main box uses `ChUi.flat(ChUi.PANEL)`. A keyword box uses `ChUi.flat(color_of(key))`.
- **Main box content:**
  - Name: Label, font size 20, `ChUi.TEXT`.
  - Line: Label, font size 14, `ChUi.TEXT.darkened(0.25)`. Its text is `"Cost %d · Cooldown %.1fs"`.
    It is hidden when `energy_cost == 0 and cooldown == 0.0`.
  - Bullets: `RicherTextLabel`, font size 16. Its bbcode is the parsed lines, each prefixed with
    `"• "` and joined with `"\n"`.
  - Set these on the RicherTextLabel after `add_child`, the order `ChPopups` uses: `context_enabled
    = false`, `markdown_enabled = false`, `autostyle_emojis = false`, `autostyle_numbers = true`,
    `autostyle_numbers_tag = "[0x%s]%%s[]" % ChUi.ACCENT.to_html(false)`,
    `autostyle_numbers_pad_decimals = false`, `fit_content = true`,
    `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`.
- **Keyword box content:**
  - Name: Label, font size 16.
  - Text: Label, font size 14, autowrap.
  - Both labels use `text_color_on(color)`.
  - Keyword boxes are pooled: reuse by index and hide the extras, so a box keeps its `ChJuice`
    across shows.
- **`restack()`:**
  - Sets each visible box's `size = Vector2(WIDTH, 0)` (a Control clamps that up to its minimum
    height) and stacks them top to bottom with a 4 px gap.
  - Sets the root `size` to the stack's bounding size.
  - Sets `position = place(_anchor, size, _bounds, _side)`.
  - Called from `_process` while visible, because the RicherTextLabel parses and fits one frame
    late, and from `show_part`.
- **`place`:** EDGE is the screen margin.
  - ABOVE: `x = anchor.get_center().x - size.x / 2` and `y = anchor.position.y - GAP - size.y`. If
    `y < bounds.position.y + EDGE`, use `y = anchor.end.y + GAP` instead.
  - RIGHT: `x = anchor.end.x + GAP` and `y = anchor.get_center().y - size.y / 2`. If
    `x + size.x > bounds.end.x - EDGE`, use `x = anchor.position.x - GAP - size.x` instead.
  - Finally clamp x to `[bounds.position.x + EDGE, bounds.end.x - EDGE - size.x]` and y likewise.
- **Pop-in.** Every box has `ChJuice.attach(box)`.
  - When `show_part` runs while the tooltip was hidden: set each visible box's
    `scale_spring.value = POP_FROM` and `velocity = 0`. Play `Feedback.play(&"tooltip", box)` on
    box 0 now, and on box `i` after `i * STAGGER` seconds via
    `get_tree().create_timer(i * STAGGER).timeout`.
  - When it was already visible (a new def or a new anchor): no reset, just
    `Feedback.play(&"tooltip", box)` on each box at once. The springs add up, so there are no
    twitchy restarts.
- After building any child, set `mouse_filter = MOUSE_FILTER_IGNORE` on it.

- [ ] **Step 1: Write the failing tests** in `tests/ui/test_part_tooltip.gd`:

```gdscript
extends ChTest

const BOUNDS := Rect2(0, 0, 1280, 720)

func _tooltip() -> ChPartTooltip:
	var holder := Control.new()
	holder.size = BOUNDS.size
	Engine.get_main_loop().get_root().add_child(_track(holder))
	var tip := ChPartTooltip.new()
	holder.add_child(tip)
	return tip

func _def(id: StringName) -> ChPartDef:
	return ChCatalog.load_default().part(id)

func _frames(n := 2) -> void:
	for i in n:
		await Engine.get_main_loop().process_frame

func test_place_above_centres() -> void:
	assert_eq(ChPartTooltip.place(Rect2(600, 600, 88, 132), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.ABOVE), Vector2(494, 392))
	_complete()

func test_place_above_clamps_left_edge() -> void:
	assert_eq(ChPartTooltip.place(Rect2(0, 600, 88, 132), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.ABOVE).x, 8.0)
	_complete()

func test_place_above_flips_below_at_top() -> void:
	assert_eq(ChPartTooltip.place(Rect2(600, 20, 88, 40), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.ABOVE).y, 68.0)
	_complete()

func test_place_right_and_flip_left() -> void:
	assert_eq(ChPartTooltip.place(Rect2(600, 280, 48, 24), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.RIGHT), Vector2(656, 192))
	assert_eq(ChPartTooltip.place(Rect2(1200, 280, 48, 24), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.RIGHT).x, 892.0)
	assert_eq(ChPartTooltip.place(Rect2(600, 10, 48, 24), Vector2(300, 400), BOUNDS,
		ChPartTooltip.Side.RIGHT).y, 8.0)
	_complete()

func test_show_builds_main_and_keyword_boxes() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"flamethrower"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames()
	assert_true(tip.visible)
	assert_eq(tip.name_label().text, "Flamethrower")
	assert_eq(tip.line_label().text, "Cost 2 · Cooldown 3.0s")
	assert_eq(tip.keyword_keys(), [&"burn"])
	assert_eq(tip.boxes().size(), 2, "main + Burning")
	var style := tip.boxes()[1].get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, ChKeywords.color_of(&"burn"), "the keyword box wears its colour")
	_complete()

func test_passive_hides_cost_line() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ember_battery"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames()
	assert_true(not tip.line_label().visible)
	assert_eq(tip.keyword_keys(), [&"burn", &"energy"])
	_complete()

func test_switch_def_reuses_boxes_and_hide() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ember_battery"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	var first_kw := tip.boxes()[1]
	tip.show_part(_def(&"freeze_charge"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(tip.keyword_keys(), [&"proximity", &"freeze"])
	assert_eq(tip.boxes()[1], first_kw, "pooled box reused")
	tip.show_part(_def(&"wheel"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(tip.boxes().size(), 1, "extra keyword boxes hidden")
	tip.hide_tooltip()
	assert_true(not tip.visible and tip.def == null)
	_complete()

func test_pop_in_from_hidden_but_not_on_switch() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"flamethrower"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	var juice := ChJuice.of(tip.boxes()[0])
	assert_true(juice != null, "every box carries a Juice")
	assert_true(juice.scale_spring.value < 1.0, "a fresh show pops in from small")
	juice.scale_spring.value = 1.0
	juice.scale_spring.velocity = 0.0
	tip.show_part(_def(&"hearth"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(juice.scale_spring.value, 1.0, "a switch does not reset the spring")
	assert_true(juice.scale_spring.velocity != 0.0, "it kicks instead")
	_complete()

func test_boxes_stack_without_overlap() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ember_battery"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames(3)
	var boxes := tip.boxes()
	for i in boxes.size() - 1:
		assert_true(boxes[i + 1].position.y >= boxes[i].position.y + boxes[i].size.y)
	assert_true(Rect2(tip.position, tip.size).end.y <= 600.0 - ChPartTooltip.GAP + 0.5, "above the card")
	_complete()

func test_ignores_mouse_everywhere() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"freeze_charge"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(tip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node in tip.find_children("*", "Control", true, false):
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % node.name)
	_complete()

func test_keyword_bbcode_renders_clean() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ice_cream_mace"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames()
	var shown := tip.bullets_label().get_parsed_text()
	assert_true(shown.contains("frozen"), "the keyword's word shows")
	assert_true(shown.contains("×3"), "the multiplier survives")
	for junk in ["0x", "sin", "{", "}", "[", "]"]:
		assert_true(not shown.contains(junk), "no %s leaks into the text" % junk)
	_complete()

func test_tooltip_profile_loads() -> void:
	assert_true(Feedback.profile(&"tooltip") != null)
	_complete()
```

- [ ] **Step 2: Run** `godot --headless --path . --script res://tests/run_tests.gd -- tooltip`. Expected: FAIL (`ChPartTooltip` not found).
- [ ] **Step 3: Implement** `ChPartTooltip`, `tooltip.tres` and the `KINDS` entry with the interfaces and decisions above. If `[0x…;sin]` doesn't render as colour plus wave in richtext2, find the addon's working combined form in `_parse_tags` and use it in `ChKeywords.parse`. Update Task 1's `_tag` helper to match. Don't drop the wave.
- [ ] **Step 4: Run** the same command, then the full suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `git add game/ui game/feedback tests/ui && git commit -m "feat(ui): Balatro-style part tooltip"`

---

### Task 4: Wire the tooltip into the garage, remove InfoPanel and hook_text

**Files:**
- Modify: `game/garage/ch_garage.gd`:
  - remove `_info_panel/_info_name/_info_line/_info_hook` (lines 50–53), `selected_info`,
    `_info_of`, `_fill_info` (lines 257–283 and 377–387), and their calls at lines 211, 373,
    435–438, 473–474;
  - add the tooltip;
  - change the `_enter_tree` guard (line 423) to `if tooltip != null: return`.
- Modify: `game/garage/garage.tscn` (delete the `InfoPanel` node and its `Rows/Name/Line/Hook`
  children, lines 63–96).
- Modify: `game/data/ch_part_def.gd` and the 5 `.tres` files that set it (delete `hook_text`).
- Modify: `game/garage/ch_part_card.gd:33` (that comment mentions the InfoPanel; it now says the
  tooltip).
- Test: `tests/test_garage.gd` (lines 610–620 and 650–657 change; new tests are added).

**Interfaces:**
- Consumes: `ChPartTooltip.show_part/hide_tooltip/def`, `ChPartTooltip.Side` (Task 3).
- Produces (on `ChGarage`):
  - `var tooltip: ChPartTooltip`, created in `_enter_tree` and added as the garage's last child so
    it draws above the pit, the strip and the held layer
  - `func _refresh_tooltip() -> void`
  - `var _hover_card: ChPartCard = null`

`_refresh_tooltip()` is the only place the tooltip is shown or hidden:
1. If `tooltip == null`, return.
2. If `held_id != &""`, hide.
3. If `_hover_card != null`, call `show_part(_hover_card.def, <card's rect in garage-local
   pixels: Rect2(card.global_position - global_position, card.size)>, Side.ABOVE,
   Rect2(Vector2.ZERO, size))`.
4. If `hover_path` is not empty and the def resolves, call `show_part(def,
   _box_at(screen_of(hover_path), def), Side.RIGHT, Rect2(Vector2.ZERO, size))`.
5. Otherwise, hide.

Call it from:
- card `mouse_entered` (set `_hover_card = card` first);
- card `mouse_exited` (clear `_hover_card` only if it is that card, so the card-to-card order
  doesn't matter);
- `_follow_pointer` when `hover_path` changes;
- `pick_part`, `cancel_hold`, `drop_part`;
- `cycle_body`, after `hover_path = []`;
- a new `_pit.mouse_exited` handler that sets `hover_path = []` first.

- [ ] **Step 1: Write the failing tests** in `tests/test_garage.gd`, and change the existing ones:
  - In `test_no_hint_labels`, replace the InfoPanel assertion with
    `assert_true(not garage.tooltip.visible, "the tooltip is away until something is hovered")`.
  - In `test_mouse_chain_plays_a_round_trip`, replace `panel` with `garage.tooltip`. Replace the
    Name assertion with `assert_eq(garage.tooltip.def.id, &"wheel", "naming the part")`.
  - Add these tests (they use the file's existing `_garage_scene`, `_card_of`, `_move`,
    `_inventory`, `_layout`, `_catalog`):

```gdscript
func _ready_garage(ids: Array) -> ChGarage:
	var garage := _garage_scene(_inventory(ids), _layout(&"cutter"), _catalog())
	for i in 2:
		await Engine.get_main_loop().process_frame
	return garage

func test_tooltip_follows_card_hover() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"flamethrower"])
	var card := _card_of(garage, &"flamethrower")
	card.mouse_entered.emit()
	assert_true(garage.tooltip.visible)
	assert_eq(garage.tooltip.def.id, &"flamethrower")
	card.mouse_exited.emit()
	assert_true(not garage.tooltip.visible)
	_complete()

func test_tooltip_card_to_card() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"flamethrower"])
	var a := _card_of(garage, &"wheel")
	var b := _card_of(garage, &"flamethrower")
	a.mouse_entered.emit()
	b.mouse_entered.emit()
	a.mouse_exited.emit()
	assert_true(garage.tooltip.visible, "a late exit from A does not hide B's tooltip")
	assert_eq(garage.tooltip.def.id, &"flamethrower")
	_complete()

func test_tooltip_hidden_while_held() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"wheel"])
	var card := _card_of(garage, &"wheel")
	card.mouse_entered.emit()
	assert_true(garage.pick_part(&"wheel"))
	assert_true(not garage.tooltip.visible, "picking up hides it")
	_move(garage.get_global_position() + garage.screen_of([0]))
	assert_true(not garage.tooltip.visible, "and it stays hidden while held")
	garage.cancel_hold()
	assert_true(garage.tooltip.visible, "putting it back lets hover show it again")
	assert_true(garage.pick_part(&"wheel"))
	assert_true(garage.drop_part(&"wheel", [0]))
	garage.cancel_hold()
	assert_true(garage.tooltip.visible, "after a drop, hover shows it again")
	_complete()

func test_tooltip_on_hull_part() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	var at := garage.get_global_position() + garage.screen_of([0])
	_move(at)
	assert_true(garage.tooltip.visible)
	assert_eq(garage.tooltip.def.id, &"wheel")
	_move(Vector2(100, 500))
	assert_true(not garage.tooltip.visible, "moving off the hull hides it")
	_complete()

func test_tooltip_leaving_pit_clears_hull_hover() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	_move(garage.get_global_position() + garage.screen_of([0]))
	garage.get_node("Pit").mouse_exited.emit()
	assert_true(not garage.tooltip.visible, "leaving the pit drops the hull hover")
	var card := _card_of(garage, &"wheel")
	card.mouse_entered.emit()
	card.mouse_exited.emit()
	assert_true(not garage.tooltip.visible, "no stale hull tooltip comes back")
	_complete()

func test_tooltip_hidden_by_body_swap() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	_move(garage.get_global_position() + garage.screen_of([0]))
	garage.cycle_body(1)
	assert_true(not garage.tooltip.visible)
	_complete()

func test_no_info_panel_left() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.get_node_or_null("Pit/InfoPanel") == null)
	assert_true(not "hook_text" in ChPartDef.new(), "hook_text is gone")
	_complete()
```

- [ ] **Step 2: Run** `godot --headless --path . --script res://tests/run_tests.gd -- garage`. Expected: FAIL (`tooltip` missing).
- [ ] **Step 3: Implement** the wiring, the removals and `_refresh_tooltip` as specified above.
- [ ] **Step 4: Run** `-- garage`, then the full suite. Expected: `0 failed`. Also run `grep -rn "hook_text\|InfoPanel\|_fill_info\|selected_info" game tests tools`. Expected: no matches.
- [ ] **Step 5: Commit** `git add game tests && git commit -m "feat(garage): part tooltip replaces InfoPanel"`

---

### Task 5: Look at it

**Files:** none changed unless tuning is needed (`ch_keywords.gd` colours,
`ch_part_tooltip.gd` constants, `tooltip.tres`).

- [ ] **Step 1: Shoot the garage.** Run `godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- /tmp/claude-1000/-mnt-windows-Godot-roguelike-star/906f2e20-a098-4e64-935f-67ed5bc01f32/scratchpad/shots`, with a window server and no `--headless`. If the script doesn't hover a card, add one hover step to it: emit `mouse_entered` on the Flamethrower card and on a mounted part, then capture after about 0.3 s.
- [ ] **Step 2: Check each shot.**
  - The tooltip is fully on screen.
  - The keyword words are coloured and readable on `ChUi.PANEL`.
  - Each keyword box's text is readable on its colour.
  - Boxes don't overlap.
  - Numbers are accent-coloured.
  - Use the `mcp__plugin_antislop_antislop-contrast__check_contrast` tool on each keyword colour,
    both against `ChUi.PANEL` (inline word) and against its own text colour (box). Aim for at least
    4.5:1. If a colour fails, adjust it in `ENTRIES`.
- [ ] **Step 3: Run** the full suite. Expected: `0 failed`. Commit any tuning: `git commit -am "tune(ui): tooltip colours and pop"`.
