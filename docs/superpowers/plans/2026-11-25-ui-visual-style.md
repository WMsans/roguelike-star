# UI Visual Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle every UI surface (shop, garage, inventory bar, cards, tooltips, battle HUD, result panel) in the
approved Noita-led look, with pixel fonts, a Dusk backdrop and the Celeste colour wash. Layout and motion don't
change.

**Architecture:**
- All colours, fonts and style boxes live in `ChUi` (`game/ui/ch_ui.gd`), and each screen asks it for panels,
  sockets, plaques and pills.
- Two new small nodes draw the decoration, and every screen reuses them:
  - `ChBackdrop` draws the Dusk glow, the grid and the vignette.
  - `ChWash` draws the drifting additive noise wash.
- Capitals come from the header font itself. Silkscreen draws lowercase as capitals, so no string changes.

**Tech Stack:** Godot 4.7 GDScript. The headless test runner is `tests/run_tests.gd`, with assertions from `ChTest`.

**Spec:** `docs/superpowers/specs/2026-11-24-ui-visual-style-design.md`. Read its colour table and "Screen by
screen" section; this plan doesn't repeat them.

Run tests with `godot --headless --path . -s res://tests/run_tests.gd -- <file-name-filter>`. Run the whole suite
with no filter. The output ends with `N passed, M failed`. If the classes are stale ("Could not find type …"), run
`godot --headless --path . --import` once first.

## Global Constraints

- Colours live only in `ChUi`. Keyword colours live in `ChKeywords`. Screens never write a colour literal.
- No layout, size, position or motion changes. `ChCard` feel, `ChJuice`, popups and particles are untouched.
- No new HUD elements or readouts. HP stays "78 / 100" and the gold readout stays "Gold N".
- No scanlines or CRT effect.
- Strings stay as they are. Capitals come from `ChUi.HEAD_FONT` (Silkscreen), which draws lowercase as capitals.
  Existing tests that check "Fight", "You win", "Cutter" and so on must pass unchanged.
- Fonts:
  - Body: Tiny5 (OFL, variable font, default axes).
  - Header: Silkscreen Regular, plus Silkscreen Bold for plaques (OFL).
  - Antialiasing and hinting are off. Sizes are whole multiples of 8 (8, 16, 24).
- Rims are 2px. Panels have square corners.
- Every decorative node (backdrop, wash, plaque, labels) uses `mouse_filter = MOUSE_FILTER_IGNORE`.
- Each task ends with the full suite green: `godot --headless --path . -s res://tests/run_tests.gd`.

## Review Focus

1. **A decorative node eats clicks.** The backdrop, wash and stage panel (which carries the plaque) must let
   clicks reach the garage pit, shelf cards, the toggle and bar cards. Tested in Tasks 2 and 3.
2. **A part name overflows its card at the new font.** Every catalog part's name must wrap into `NAME_LINES` at
   the card's width. Tested in Task 4.
3. **A keyword colour is unreadable as text on the dark panel.** This used to be a solid fill, and is now title
   text. Tested in Task 5.
4. **The longest result title runs off screen as a 24px plaque.** "No fight: the battle could not start" must fit
   inside 1280 px. Tested in Task 7.
5. **The battle wash or vignette draws over the HUD or catches input.** It must sit under the HUD and ignore the
   mouse. Tested in Task 2.

---

### Task 1: Fonts and the `ChUi` style kit

**Files:**
- Create: `game/ui/fonts/Tiny5.ttf`, `game/ui/fonts/Silkscreen-Regular.ttf`,
  `game/ui/fonts/Silkscreen-Bold.ttf`, `game/ui/fonts/OFL-Tiny5.txt`, `game/ui/fonts/OFL-Silkscreen.txt`,
  `CREDITS.md`
- Modify: `game/ui/ch_ui.gd`
- Test: `tests/ui/test_ui_style.gd`

**Interfaces:**
- Produces (`ChUi`, all static):
  - Colours, from the spec's table:
    - `INK #0d0709`
    - `PANEL = Color("#140912", 0.84)`
    - `RIM #b8804f`
    - `TEXT #f2e2c2`
    - `LABEL #e0b88a`
    - `ACCENT #ffb53a`: the gold. Keep the name, because tests and `ChKeywords` read it.
    - `SOCKET #8a3445`, `SOCKET_EDGE #2e0f16`, `SOCKET_LINE #b2505f`
    - `SOCKET_EMPTY #4a1e28`, `SOCKET_EMPTY_LINE #6a2a36`
    - `PLAQUE #c0475a`
    - `SELL_RIM #d9465a`, `SELL_TEXT #ff6a7a`
    - `HP_PLAYER #62d64a`, `HP_ENEMY #ff4f5e`
    - `DUSK_CENTRE #7a3446`, `DUSK_EDGE #3a1622`, `GRID = Color(1.0, 0.667, 0.588, 0.10)`
  - Fonts: `BODY_FONT: FontFile` (Tiny5), `HEAD_FONT: FontFile` (Silkscreen), `PLAQUE_FONT: FontFile`
    (Silkscreen Bold).
  - Sizes: `SMALL := 8`, `BODY := 16`, `BIG := 24`. `FONT_SIZE` becomes `BODY`.
  - `static func font(path: String) -> FontFile`: loads the file and sets `antialiasing = NONE`,
    `hinting = NONE`, `subpixel_positioning = DISABLED`. The three font constants are built through it, cached
    the way `theme()` caches.
  - `static func panel(rim := RIM) -> StyleBoxFlat`: `PANEL` fill, 2px `rim`, radius 0, content margin 6.
  - `static func socket(empty := false, hot := false) -> StyleBoxFlat`:
    - Filled: `SOCKET` fill, `SOCKET_EDGE` 2px border.
    - Empty: `SOCKET_EMPTY` fill.
    - Hot: `ACCENT` border, plus a shadow in `ACCENT` at alpha 0.5 with `shadow_size` 4 (the glow).
  - `static func draw_socket(canvas: CanvasItem, rect: Rect2, empty := false, hot := false) -> void`: draws
    `socket()`, then the 1px inner line (`SOCKET_LINE`, or `SOCKET_EMPTY_LINE` when empty) inset by the border.
  - `static func plaque() -> StyleBoxFlat`: `PLAQUE` fill, 2px `TEXT` border, `INK` shadow with `shadow_size` 0
    and `shadow_offset` (3,3), content margin 6/2.
  - `static func draw_pill(canvas: CanvasItem, bottom_centre: Vector2, text: String) -> void`: an `INK` box with
    a 1px `RIM`, `ACCENT` text in `HEAD_FONT` at `SMALL`, centred on `bottom_centre` and hung half below it.
  - `static func draw_plaque(canvas: CanvasItem, centre: Vector2, text: String) -> Rect2`: paints `plaque()`
    sized to `text` in `PLAQUE_FONT` at `BIG` plus margins, centred on `centre`, with an `INK` text shadow at
    (2,2). It returns the rect.
  - `static func draw_group_label(canvas: CanvasItem, bottom_left: Vector2, text: String) -> void`: `text` in
    `HEAD_FONT` at `SMALL`, in `LABEL`.
  - Shop chrome text is painted with these, not with Label nodes. `test_minimal_hud` and the bar's label-count
    test pin the number of Labels.
  - `theme()`:
    - `default_font = BODY_FONT`, `default_font_size = BODY`.
    - Label `font_color` `TEXT`.
    - `PanelContainer` panel = `panel()`.
    - Button uses `HEAD_FONT` with `font_color` `TEXT`. Its styles:
      - normal: `panel()`
      - hover: `panel(ACCENT)`
      - pressed: `panel(ACCENT)`
      - disabled: `panel()` with font colour `TEXT` at alpha 0.4
      - focus: transparent with an `ACCENT` rim
    - Type variation `&"GoButton"` (base `Button`): every state's rim is `ACCENT`, and the font colour is
      `ACCENT`.
    - Type variation `&"Plaque"` (base `Label`): `PLAQUE_FONT`, `BIG`, `TEXT`, `normal` stylebox `plaque()`,
      font shadow `INK` offset (2,2).
  - Keep `flat()` and `BUTTON` alive until Task 8 removes them. Every other task stops using them.
- Header comment: replace the "flat placeholder art, no textures" line with one sentence pointing at this spec.

- [ ] **Step 1: Copy the fonts in.**
  - Download from `https://raw.githubusercontent.com/google/fonts/main/ofl/`:
    - `silkscreen/Silkscreen-Regular.ttf`
    - `silkscreen/Silkscreen-Bold.ttf`
    - `silkscreen/OFL.txt` → `OFL-Silkscreen.txt`
    - `tiny5/Tiny5%5BBLED,JITT,ROND,wdth,wght%5D.ttf` → `Tiny5.ttf`
    - `tiny5/OFL.txt` → `OFL-Tiny5.txt`
  - Write `CREDITS.md`, one line per font: name, author from its OFL.txt, licence "SIL Open Font License 1.1".
  - Run `godot --headless --path . --import`.

- [ ] **Step 2: Write the failing test** `tests/ui/test_ui_style.gd`:

```gdscript
extends ChTest

func test_fonts_are_crisp() -> void:
	for f in [ChUi.BODY_FONT, ChUi.HEAD_FONT, ChUi.PLAQUE_FONT]:
		assert_eq(f.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "pixel fonts draw unsmoothed")
		assert_eq(f.hinting, TextServer.HINTING_NONE)
	assert_eq(ChUi.theme().default_font, ChUi.BODY_FONT, "body text is Tiny5")
	assert_eq(ChUi.theme().get_font(&"font", &"Button"), ChUi.HEAD_FONT, "buttons read in capitals")
	_complete()

func test_socket_states() -> void:
	assert_eq(ChUi.socket().bg_color, ChUi.SOCKET, "a filled socket")
	assert_eq(ChUi.socket(true).bg_color, ChUi.SOCKET_EMPTY, "an empty one is darker")
	assert_eq(ChUi.socket(false, true).border_color, ChUi.ACCENT, "hot gets the gold rim")
	assert_true(ChUi.socket(false, true).shadow_size > 0, "and the glow")
	assert_eq(ChUi.socket().shadow_size, 0, "a cold socket has no glow")
	_complete()
```

- [ ] **Step 3: Run it to make sure it fails.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- ui_style`
  - Expected: FAIL (`BODY_FONT` and `socket` are not declared).

- [ ] **Step 4: Implement the interfaces above** in `game/ui/ch_ui.gd`.

- [ ] **Step 5: Run the filter, then the whole suite.** Both should pass.
  - The whole suite may fail on the HUD pip tests only if `ACCENT` changed name. It must not change name.

- [ ] **Step 6: Commit.**
  - `git add game/ui CREDITS.md tests/ui/test_ui_style.gd && git commit -m "feat(ui): pixel fonts and the Noita-led style kit"`

---

### Task 2: Backdrop and colour wash, on the shop and the battle

**Files:**
- Create: `game/ui/ch_backdrop.gd`, `game/ui/ch_wash.gd`
- Modify: `game/shop/ch_shop_screen.gd` (`_init`, `_draw`), `game/battle/ch_battle.gd` (`_build_hud`)
- Test: `tests/ui/test_backdrop.gd`

**Interfaces:**
- Consumes: `ChUi.DUSK_CENTRE`, `DUSK_EDGE`, `GRID`, `INK`.
- Produces:
  - `class_name ChBackdrop extends Control`:
    - `var dusk := true`. When true it draws the radial `DUSK_CENTRE`→`DUSK_EDGE` glow and the 40px `GRID`
      lines. When false it draws only the vignette (the battle).
    - `var vignette_alpha := 0.7` (the battle sets 0.35).
    - Full-rect anchors, `MOUSE_FILTER_IGNORE`, redraws on `resized`.
    - Draw the glow with a `GradientTexture2D` (fill `RADIAL`) built once. Draw the vignette as a second radial
      gradient, transparent centre → `INK` at `vignette_alpha` at the edge.
  - `class_name ChWash extends TextureRect`:
    - A `NoiseTexture2D` 512×288, `seamless`, with `FastNoiseLite` seed 7, frequency 0.004, 2 octaves.
    - Colour ramp `(0.45,0.25,0.8)`@0, `(0.9,0.3,0.55)`@0.5, `(1,0.6,0.25)`@1.
    - `CanvasItemMaterial` `BLEND_MODE_ADD`, `modulate.a = ALPHA`, with `const ALPHA := 0.15`.
    - `stretch_mode = STRETCH_TILE`, full rect, `MOUSE_FILTER_IGNORE`, `texture_repeat` enabled.
    - `const SPEED := Vector2(4, 4)`, in art px per second.
    - `static func drift_at(seconds: float) -> Vector2`, which returns `(SPEED * seconds).floor()`. `_process`
      applies it as a negative `position` offset wrapped modulo the texture size, with the rect grown by one
      texture size so no edge shows.
  - Shop: `ChShopScreen._init` adds a `ChBackdrop` then a `ChWash` as its first two children, before
    `gold_label`. `_draw` and the `resized.connect(queue_redraw)` line go. The comment about the screen being
    opaque moves to the backdrop add, since the backdrop is what keeps the ended battle from showing through.
  - Battle: `ChBattle._build_hud` adds a `ChWash` then a `ChBackdrop` (`dusk = false`, `vignette_alpha = 0.35`)
    to `$HUD` before `hud`, so both draw above the world and under the HUD.

- [ ] **Step 1: Write the failing test** `tests/ui/test_backdrop.gd`:

```gdscript
extends ChTest

func test_wash_drifts_in_whole_texels() -> void:
	assert_eq(ChWash.drift_at(0.0), Vector2.ZERO)
	assert_eq(ChWash.drift_at(0.6), Vector2(2, 2), "4 px/s for 0.6 s is 2.4, floored")
	_complete()

func test_decoration_ignores_the_mouse() -> void:
	var screen := ChShopScreen.new()
	_track(screen)
	assert_true(screen.get_child(0) is ChBackdrop, "the backdrop is the bottom layer")
	assert_true(screen.get_child(1) is ChWash, "the wash is over it")
	for i in 2:
		assert_eq((screen.get_child(i) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"a click goes through to the pit and the cards")
	_complete()
```

  - Add `test_battle_wash_sits_under_the_hud` to the same file. Instantiate `res://game/battle/battle.tscn`, add
    it to the root and `_track` it. Call `battle._build_hud()` directly; there's no need to start a fight. Then
    assert:
    - `$HUD`'s children in order are `ChWash`, `ChBackdrop`, `ChBattleHud`.
    - The first two are `MOUSE_FILTER_IGNORE`.

- [ ] **Step 2: Run it to make sure it fails.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- backdrop`
  - Expected: FAIL (`ChWash` not declared).

- [ ] **Step 3: Implement `ChBackdrop`, `ChWash` and the two hooks** as above.

- [ ] **Step 4: Run the filter, then the whole suite.** Both should pass.
  - `tests/shop/test_shop_screen.gd` reads children by name, not index. If any test reads `get_child(0)` on the
    screen, update it to look the node up by name.

- [ ] **Step 5: Commit.**
  - `git commit -m "feat(ui): dusk backdrop, vignette and the Celeste colour wash"`

---

### Task 3: Shop, inventory bar and garage chrome

**Files:**
- Modify: `game/shop/ch_shop_screen.gd`, `game/shop/ch_inventory_bar.gd`, `game/garage/ch_garage.gd`
- Test: `tests/shop/test_shop_screen.gd`, `tests/shop/test_inventory_bar.gd` (append)

**Interfaces:**
- Consumes: Task 1's `theme()` variations, `draw_socket`, `panel`, `ACCENT`, `SELL_RIM`, `SELL_TEXT`, `RIM`.
- Produces (fields later tasks and tests read):
  - `ChShopScreen.stage_panel: Control`:
    - A child of `stage_view`, added first, so the garage view hides it with the shop. `MOUSE_FILTER_IGNORE`.
    - Its `draw` paints `ChUi.panel()` over `stage_rect`, then `ChUi.draw_plaque` "SHOP" centred on that
      rect's top edge.
    - `var stage_rect: Rect2` is set in `_place_row` to the row's span plus 24 px on every side, then
      `queue_redraw()`.
  - `next_button.theme_type_variation = &"GoButton"`.
  - `gold_label` font colour `ACCENT`, font `HEAD_FONT`. The text stays "Gold N".
  - `ChInventoryBar._draw_bar` paints `ChUi.draw_group_label(_layer, _slots[0].position - Vector2(0, 6), "PARTS")`.
    This is not a Label, so the bar's one-label test holds.
  - `ChInventoryBar._draw_bar`:
    - Each slot is `ChUi.draw_socket(_layer, rect, true, _highlighted)`.
    - The sell zone is `panel(SELL_RIM)`, or `panel(ACCENT)` while highlighted and sellable.
    - `sell_label` font colour is `SELL_TEXT`.
    - The bar's own `PanelContainer` background becomes transparent (a `StyleBoxEmpty` override), so the bar
      floats on the backdrop as in the mockup.
  - `ChGarage`: `MARK_COLOR` becomes `ChUi.RIM`, the near-slot fill `Color(ChUi.ACCENT, 0.2)` stays, and
    `HOVER_COLOR` becomes `ChUi.ACCENT`. Both stay `const` and are defined from `ChUi`.

- [ ] **Step 1: Write the failing tests.**
  - Append to `tests/shop/test_shop_screen.gd`, after setting the screen up the way its existing tests do:

```gdscript
func test_shop_chrome_lets_clicks_through() -> void:
	var screen := _screen()
	assert_eq(screen.stage_panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks reach the shelf")
	assert_true(screen.stage_panel.stage_rect.size.x > 0.0, "the panel spans the stage row")
	assert_eq(screen.next_button.theme_type_variation, &"GoButton")
	screen._on_toggle()
	assert_true(not screen.stage_panel.is_visible_in_tree(), "the panel and plaque go with the shop view")
	_complete()
```

  - The existing `test_minimal_hud` (exactly two chrome Labels) and the bar's one-label test must still pass
    unchanged. They are the guard against painting SHOP or PARTS as Labels.

- [ ] **Step 2: Run it to make sure it fails.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- shop_screen`
  - Expected: FAIL (`stage_panel` doesn't exist).

- [ ] **Step 3: Implement the interfaces above.**

- [ ] **Step 4: Run `-- shop_screen`, `-- inventory_bar`, then the whole suite.** All should pass.

- [ ] **Step 5: Commit.**
  - `git commit -m "feat(ui): shop plaque, stage panel, socket slots and gold go button"`

---

### Task 4: Card faces and price pills

**Files:**
- Modify: `game/ui/ch_card.gd` (`_paint_face`), `game/garage/ch_part_card.gd` (`FONT`, `LINE`, `_paint_face`),
  `game/shop/ch_shop_screen.gd` (`OptionCard`, `BodyItemCard`, `PackItemCard`)
- Test: `tests/ui/test_card.gd` (append)

**Interfaces:**
- Consumes: `ChUi.panel`, `draw_socket`, `draw_pill`, `BODY_FONT`, `BODY`.
- Produces:
  - `ChCard._paint_face()` draws `ChUi.panel(ChUi.ACCENT if hovered else ChUi.RIM)` over the whole face. For
    hover, also draw `ChUi.socket(false, true)`'s glow, or a 4px `ACCENT` alpha-0.3 rect behind the face. The
    builder picks whichever reads better.
  - `ChPartCard`:
    - `FONT := ChUi.BODY` (16). `LINE` is set from `ChUi.BODY_FONT.get_height(FONT)`, so it is 18.
    - The text is drawn with `ChUi.BODY_FONT`, not `get_theme_default_font()`.
    - The part-art slab becomes `ChUi.draw_socket(self, art_rect)`, where `art_rect` is the old slab rect.
    - When `price >= 0`, the cost row is not drawn. Instead `ChUi.draw_pill(self, Vector2(size.x * 0.5,
      size.y), "%d$" % price)`.
    - The `×n` count stays in `ACCENT`.
  - `OptionCard` and `BodyItemCard`:
    - The face is `super()`.
    - Option text is in `ChUi.HEAD_FONT` at `ChUi.BODY`.
    - The body name is in `BODY_FONT` at `BODY`.
    - The body price moves to `draw_pill` at the bottom centre.
    - The hull draws on a `draw_socket` rect.
  - `PackItemCard`: draws through `super()`. Its own slab and rim copy go.

- [ ] **Step 1: Write the failing test.** Append to `tests/ui/test_card.gd`:

```gdscript
func test_every_part_name_fits_its_card() -> void:
	var catalog := ChCatalog.load_default()
	for def: ChPartDef in catalog.parts.values():
		var card := ChPartCard.new(def, func() -> void: pass)
		_track(card)
		var inner := card.custom_minimum_size.x - ChPartCard.PAD * 2.0
		var lines := card._wrap(ChUi.BODY_FONT, def.display_name, inner)
		assert_true(lines.size() <= ChPartCard.NAME_LINES, "%s wraps into the card" % def.id)
		for line in lines:
			assert_true(ChUi.BODY_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				ChPartCard.FONT).x <= inner, "%s: '%s' fits the width" % [def.id, line])
	_complete()
```

- [ ] **Step 2: Run it to make sure it fails.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- test_card`
  - Expected: FAIL (`ChUi.BODY_FONT` is not used by the card yet; the size assertion fails at `FONT` 12 vs the
    measured width, or `_wrap` cuts).
  - If it passes already, `_wrap` was cutting silently. Check that `_wrap` cuts at `NAME_LINES` and doesn't
    measure with a different font.

- [ ] **Step 3: Implement the interfaces above.** If a real part name still overflows at 16, set `FONT` to 8 and
  keep `LINE` from the font. Don't widen the card.

- [ ] **Step 4: Run the filter, then the whole suite.** Both should pass.

- [ ] **Step 5: Commit.**
  - `git commit -m "feat(ui): card faces on panels with sockets and price pills"`

---

### Task 5: Part tooltip and keyword boxes

**Files:**
- Modify: `game/ui/ch_part_tooltip.gd` (`_init`, `_fill_keyword`, `_box`, `_label`), `game/ui/ch_keywords.gd`
  (colours only, if needed)
- Test: `tests/ui/test_part_tooltip.gd`, `tests/ui/test_keywords.gd` (append)

**Interfaces:**
- Consumes: `ChUi.panel`, `BODY_FONT`, `BODY`, `BIG`, `TEXT`, `LABEL`.
- Produces:
  - The main box is `panel()`. The name is `BODY_FONT` at `BIG` in `TEXT`. The cost line is `BODY` in `LABEL`.
    Bullets are `BODY` in `TEXT` with numbers in `ACCENT`, as now.
  - Keyword boxes are `panel(ChKeywords.color_of(key))`, so the rim takes the keyword's colour. The title is in
    `HEAD_FONT` at `BODY` in the keyword's colour. The body is `BODY` in `TEXT`.
  - `ChKeywords.text_color_on` stays, because its test pins it, but the tooltip no longer calls it.

- [ ] **Step 1: Write the failing tests.**
  - Append to `tests/ui/test_keywords.gd`:

```gdscript
func test_keyword_colours_read_on_the_panel() -> void:
	for key in ChKeywords.ENTRIES:
		var c := ChKeywords.color_of(key)
		assert_true(c.get_luminance() - ChUi.PANEL.get_luminance() >= 0.35,
			"%s reads as text on the dark panel" % key)
	_complete()
```

  - Append to `tests/ui/test_part_tooltip.gd`: after `show_part` with a def that has a keyword (reuse the file's
    existing setup), assert:
    - the keyword box's `panel` stylebox `border_color` equals `ChKeywords.color_of(key)`;
    - its title label's `font_color` override equals the same colour.

- [ ] **Step 2: Run them to make sure they fail.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- keywords`, then `-- part_tooltip`.
  - Expected: the tooltip test FAILS (the box is still a solid fill).
  - The luminance test may fail for `passive` or `extension` (`#9aa0aa`). If so, that is the nudge the spec
    allows.

- [ ] **Step 3: Implement the interfaces above.** Raise any keyword colour that fails the luminance check, keeping
  its hue.

- [ ] **Step 4: Run both filters, then the whole suite.** All should pass.

- [ ] **Step 5: Commit.**
  - `git commit -m "feat(ui): dark tooltip with keyword-coloured rims and titles"`

---

### Task 6: Battle HUD without slabs

**Files:**
- Modify: `game/battle/ch_battle_hud.gd`
- Test: `tests/battle/test_battle_hud.gd`, `tests/battle/test_fight_rules.gd` (existing tests must still pass;
  append one)

**Interfaces:**
- Consumes: `ChUi.HEAD_FONT`, `BODY`, `BIG`, `HP_PLAYER`, `HP_ENEMY`, `INK`, `ACCENT`, `SOCKET_EMPTY`, and the
  `&"Plaque"` variation.
- Produces:
  - `_player_block()` and `_enemy_block()` still return a `PanelContainer`, so the layout is unchanged. Each gets
    a `StyleBoxEmpty` `panel` override, so there is no slab.
  - `player_name` and `enemy_name` use `HEAD_FONT` at `BODY`.
  - `player_hp` and `enemy_hp` read "✚ 78 / 100". The ✚ is a separate `TextureRect` or `Label` in front of the
    HP label, so `player_hp.text` stays "78 / 100".
  - Every HUD label gets `outline_size` 2 with `font_outline_color` `INK`, so it reads over the bright sky.
  - The bars:
    - `BAR := Vector2(220, 6)`. Thin is a style change, not a layout one, so the block shrinks with it.
    - Background is `INK`, fill is the HP colour, both `StyleBoxFlat` with no radius.
  - The pips:
    - `PIP := Vector2(8, 8)`.
    - `PIP_OFF := ChUi.SOCKET_EMPTY`.
    - `VOLLEY := Color("#ffe08a")`, a brighter gold than `ACCENT`.
    - `SHORT` stays `#7a2e2e`.
    - Lit pips stay `ChUi.ACCENT`.
  - `show_banner` uses `theme_type_variation = &"Plaque"` on the banner label.
  - `show_countdown`'s label uses `HEAD_FONT` at `BIG` with the ink outline.

- [ ] **Step 1: Write the failing test.** Append to `tests/battle/test_battle_hud.gd`:

```gdscript
func test_hud_has_no_slabs() -> void:
	var hud := _hud()
	hud.show_state(_chariot(_body("Cutter", 100), 78, 20.0, 20.0), _chariot(_body("Dozer", 200), 30))
	for block in [hud.player_name.get_parent().get_parent(), hud.enemy_name.get_parent().get_parent()]:
		assert_true((block as PanelContainer).get_theme_stylebox(&"panel") is StyleBoxEmpty,
			"the world shows behind the HUD")
	assert_eq(hud.player_hp.text, "78 / 100", "the readout is unchanged")
	assert_true(hud.player_name.get_theme_constant(&"outline_size") >= 2, "names read over the sky")
	_complete()
```

- [ ] **Step 2: Run it to make sure it fails.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- battle_hud`
  - Expected: FAIL (the panel is the theme's `panel()`).

- [ ] **Step 3: Implement the interfaces above.**

- [ ] **Step 4: Run `-- battle_hud`, `-- fight_rules`, then the whole suite.** All should pass. The pip tests
  compare against the constants, so they hold.

- [ ] **Step 5: Commit.**
  - `git commit -m "feat(battle): slab-free HUD, thin bars, socket pips, plaque banner"`

---

### Task 7: Result panel as a plaque

**Files:**
- Modify: `game/ui/ch_result_panel.gd`
- Test: `tests/ui/test_result_panel.gd` (append)

**Interfaces:**
- Consumes: the `&"Plaque"` and `&"GoButton"` variations.
- Produces:
  - The panel's own `panel` stylebox is `StyleBoxEmpty`, so there is no box behind the pair.
  - `title.theme_type_variation = &"Plaque"`.
  - `back.theme_type_variation = &"GoButton"`.
  - `ROW_GAP` stays.
  - Text and `ROWS` are unchanged.

- [ ] **Step 1: Write the failing test.** Append to `tests/ui/test_result_panel.gd`:

```gdscript
func test_longest_title_fits_the_screen() -> void:
	var panel := _panel(&"aborted")
	assert_eq(panel.title.theme_type_variation, &"Plaque")
	var width := ChUi.PLAQUE_FONT.get_string_size(panel.title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		ChUi.BIG).x + 12.0
	assert_true(width <= 1280.0 - 2.0 * 20.0, "the aborted title fits inside the canvas margins")
	_complete()
```

- [ ] **Step 2: Run it to make sure it fails.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd -- result_panel`
  - Expected: FAIL on the variation.

- [ ] **Step 3: Implement the interfaces above.**

- [ ] **Step 4: Run the filter, then the whole suite.** Both should pass.

- [ ] **Step 5: Commit.**
  - `git commit -m "feat(ui): result panel as plaque and gold continue"`

---

### Task 8: Remove the old style and check it in the real game

**Files:**
- Modify: `game/ui/ch_ui.gd` (delete `flat()`, `BUTTON`, `GO` if `grep` shows no reader), any straggler caller
- Modify: `docs/superpowers/specs/2026-11-24-ui-visual-style-design.md`. In the capitals call, replace
  "(`uppercase` on the Label or Button, or `.to_upper()` in `draw_string`)" with "through `HEAD_FONT`
  (Silkscreen draws lowercase as capitals)", and name the fonts actually used.

- [ ] **Step 1: Find any remaining reader of the old style.**
  - Run: `grep -rn "ChUi\.\(flat\|BUTTON\|GO\b\)\|get_theme_default_font" game tests`
  - Expected: no hits outside `ch_ui.gd`. Fix any hit to use the Task 1 kit, then delete the dead members.

- [ ] **Step 2: Run the whole suite.**
  - Run: `godot --headless --path . -s res://tests/run_tests.gd`
  - Expected: `… passed, 0 failed`.

- [ ] **Step 3: Take the real-game shots.**
  - Run: `godot --path . --windowed --always-on-top --resolution 1280x720 -s res://tools/screenshot.gd -- <scratch dir>`
  - Open `garage.png`, `tooltip_hull.png`, `battle.png` and `result.png`. Check them against the spec's "Screen
    by screen" section and the anti-goals:
    - no scanlines;
    - the battle world is still the brightest thing on screen;
    - HUD text is readable over the sky;
    - the battle vignette doesn't dim the HUD corners. If it does, lower `vignette_alpha` or drop it, per the
      spec's call.
  - Tune colours and the wash alpha in `ChUi` and `ChWash` only.

- [ ] **Step 4: Commit.**
  - `git commit -m "refactor(ui): drop the placeholder style; spec notes the fonts used"`
