# UI visual style design

Date: 2026-11-24. Branch base: `garage-battle-ui`.

## Intent

The UI is "lame as hell" (user's words). The battle world is rich, bright pixel art, but every screen on top of
it is flat grey boxes on black in Godot's default font. This pass gives the UI a **new visual style**. It is not a
new layout and not new motion. The user said outright that the work is "mainly a new visual style".

References the user gave, and what each one contributes:

- **Noita (leads):** dark, see-through panels with thin warm rims, parts sitting in dull rose sockets, small crisp
  pixel text, small all-caps labels above each group, a gold rim on the selected thing, and a HUD of thin bars and
  icons with no slabs behind them. It is quiet, so the world stays the star.
- **Gambonanza (accents):** a rose/cream/ink palette, a raised plaque for the one main header, and price pills
  hanging under items.
- **Balatro and Witch's Night Market:** named at the start. Neither survived the mockup round as a direction.
- **Celeste foreground (`/Users/jeremyzhao/Development/godot/AllKindsOfRendering/celeste-background-rendering`):**
  its drifting colour wash layer goes over the screens.

Success: the shop, garage, battle and result screens all read as one designed game in the style below. The
battle's world art still reads as the brightest, busiest thing on screen. Every existing interaction still works.

## Decided by the user

- **A new visual style, not a new layout.** Screen layouts, sizes and positions stay as they are.
- **Noita leads, with Gambonanza's accents.** It is slightly more saturated than Noita.
- **No scanlines.**
- **The shop/garage backdrop is "Dusk":** a mid wine glow with a faint grid, brighter than near-black, but the
  panels on it still read as darker. The brighter Gambonanza rose was rejected.
- **The Celeste foreground is added.** It is the colour wash only (see the call below).
- **Approach A:** everything is drawn in code by extending `ChUi`. There are no texture frames, and the window
  scaling setting is not changed.

### Calls made in the conversation (the user confirmed the playback)

- **No stage label.** The mockups showed "STAGE 2 / 4", but the shop spec's "no HUD creep" rule holds.
- **Energy stays as pips, restyled.** It does not become a bar, because the pips show which energy a press would
  spend (`VOLLEY`) and what the pool lacks (`SHORT`).
- **Every UI surface gets the style:** shop, garage, inventory bar, cards, part tooltips with their keyword boxes,
  battle HUD, the elite/boss banner and countdown, and the result panel.
- **The font is a free pixel font with smoothing off.** The candidates are m5x7 for body text and m6x11 for
  headers (Daniel Linssen). See "Left to the builder" for the licence check.
  - Used: Tiny5 for body text (`BODY_FONT`), Silkscreen Regular for headers, buttons and labels (`HEAD_FONT`)
    and Silkscreen Bold for plaques (`PLAQUE_FONT`), all OFL, in `game/ui/fonts/`.
- **Motion stays as it is.** Card hover, tilt, sway, drag, juice beats and popups don't change.
- **Foreground:** Claude proposed bringing only the colour wash over, on both the battle (above the world, under
  the HUD) and the shop/garage backdrop, with the two mist layers left off (they are `visible = false` in the
  source project too). The user did not object.

## Goals

- One look across every screen, defined in one place (`game/ui/ch_ui.gd`), which is where colours live today.
- A pixel font on every Control and every `draw_string`.
- The Dusk backdrop behind the shop and garage, in place of flat black.
- The colour wash drifting over the battle and the shop/garage.
- The battle HUD restyled to thin bars and icons with no black slabs. The result panel becomes a plaque banner.

## Non-goals

- Layout changes, new HUD elements, new readouts.
- New or changed motion (`ChCard` feel, `ChJuice`, popups, particles, screen shake).
- Hand-drawn pixel frames (nine-slice textures), approach B. This may come later piece by piece.
- Whole-number window scaling (approach C). The user picked A only.
- The Celeste mist layers.
- Sound. Battle world art, sprites and VFX.

## Anti-goals

- **No scanlines or CRT effect.**
- **The UI must not compete with the battle.** If the HUD or wash makes the fight harder to read, it is wrong
  even if it matches the mockup.
- **No HUD creep** (carried over from the run-shop spec).
- **Nothing breaks.** Drag, drop, click, hover, tooltips and the sell zone behave exactly as before, and the
  headless suite passes.

## Constraints found in the code

- `game/ui/ch_ui.gd` builds the shared Theme in code: `ACCENT`, `GO`, `HP_PLAYER`, `HP_ENEMY`, `PANEL`,
  `BUTTON`, `TEXT`, `FONT_SIZE` = 20, and `flat(fill, rim)`, which is a `StyleBoxFlat` with a 1px rim and a 3px
  corner. Its header comment says "flat placeholder art, no textures (spec: …)". This spec replaces that rule
  for UI chrome. Panels stay code-drawn, but the placeholder framing goes.
- Nine files read `ChUi`: `ch_battle_hud.gd`, `ch_garage.gd`, `ch_part_card.gd`, `ch_inventory_bar.gd`,
  `ch_shop_screen.gd`, `ch_card.gd`, `ch_keywords.gd`, `ch_part_tooltip.gd` and `ch_result_panel.gd`.
- Several of these draw their own faces in `_draw()` and do not use the Theme:
  - `ChCard`'s face and `ChShopScreen`'s inner card classes: an option card, a body card, and an item card that
    shows a price.
  - `ChPartCard._paint_face`: name, cost, count, and the part art on a `PANEL` slab.
  - `ChInventoryBar._draw_bar`: slots and the sell zone, with an `ACCENT` rim while highlighted.
  - `ChGarage`'s slot markers and hover box (`MARK_COLOR`, `HOVER_COLOR`).
  - `ChShopScreen._draw`, which fills the whole screen with `PANEL`. This is the black backdrop.
- `ChPartTooltip` fills each keyword box with the keyword's saturated colour, for example a solid orange
  "Press" box. `ChKeywords.text_color_on` picks dark or light text by luminance.
- `ChBattleHud` uses two `PanelContainer` blocks (name, HP text, a 320×20 `ProgressBar`, energy pips of 10×12),
  a banner `Label` and a countdown `Label`. The pip colours are `ChUi.ACCENT`, `VOLLEY`, `SHORT` and `PIP_OFF`.
- Battle layers: `ChBackground` is a `CanvasLayer` at `layer = -10`. The world is a Node2D under the camera. The
  HUD sits under the `$HUD` CanvasLayer. `ChResultPanel` sits on its own CanvasLayer (`ChMain._init`).
- The display is a 1280×720 canvas with `stretch/mode = canvas_items` in a maximized window, so it scales by
  about 1.9× on the user's screen. `default_texture_filter = 0` (nearest). Pixel fonts and 1–2px rims will
  land on uneven screen pixels. This is accepted under approach A. Use 2px rims rather than 1px so they don't
  vanish or shimmer.
- **The Celeste wash** (`scenes/main.tscn` node `Fg/Wash`, script `scripts/fg_layer.gd`):
  - A `Sprite2D` with a seamless `NoiseTexture2D` 512×288 (`FastNoiseLite`, seed 7, frequency 0.004, 2 octaves).
  - Its colour ramp runs `(0.45,0.25,0.8)` → `(0.9,0.3,0.55)` → `(1,0.6,0.25)`.
  - It uses additive blend (`CanvasItemMaterial.blend_mode = 1`) at `modulate.a = 0.15`, with `scroll_scale`
    0.5 and drift `speed` (4,4) art px/s, snapped to whole texels.
  - That project's `FgLayer` reads `Camera2D` for its scroll. The shop has no camera, so drift alone must drive
    it there.
- Tests that pin current colours: `tests/ui/test_keywords.gd:38-39` (`text_color_on`) and
  `tests/battle/test_battle_hud.gd:54-67` (pip colours by name: `ChUi.ACCENT`, `ChBattleHud.VOLLEY`,
  `PIP_OFF`). They compare by constant, so renaming or changing values is fine as long as the constants still
  exist and the logic holds.
- `tools/screenshot.gd` captures `garage.png`, `tooltip_hull.png`, `battle.png` and `result.png` from the real
  game. It needs a window, so run it without `--headless`. If it reports "Could not find type ChRun", run
  `godot --headless --path . --import` once first.

## Approaches considered

- **A. Code-drawn, extending `ChUi` (chosen).** Panels, rims, sockets, the plaque and pills are `StyleBoxFlat`s
  plus a few shared draw helpers on `ChUi`. Two `.ttf` pixel fonts are added. The backdrop and wash are a small
  shader or noise-texture layer reused by both screens. It is the fastest option, needs no hand-drawn art, and
  keeps colours in one file. The cost is clean flat rims without Noita's hand-pixelled bevels.
- **B. Nine-slice pixel-art frames (`StyleBoxTexture`).** This is the most authentically crunchy option, but every
  piece needs art drawn and tuned, and it still blurs at 1.9×. It is deferred.
- **C. A plus whole-number window scaling.** This gives crisp pixels everywhere, at the cost of letterbox bars.
  Claude suggested trying it as a one-line test. The user chose A only, so scaling is untouched.

## The style

The colours below come from the approved mockup (Noita-led, more saturated, Dusk backdrop). They are starting
values, and the builder tunes them against real screenshots.

The approved mockups are in `.superpowers/brainstorm/72935-1795585046/content/`, which is git-ignored and local
only:
- `visual-style-v3.html` shows the shop and the battle HUD with the result banner.
- `shop-bg-brightness.html` shows the Dusk backdrop, option 1.

Use them for placement details the table doesn't give, such as where the plaque and pills sit.

Calls Claude made after the builder check (the user can overrule any of them):

- **The vignette goes on both screens,** because the user saw it on both mockups and removed only the scanlines.
  - On the battle it is lighter than on the shop. It sits above the wash and below the HUD and the result layer.
  - If it dims the world where the HUD text sits, lighten it further or drop it from the battle. The anti-goal
    "must not compete with the battle" wins.
- **Capitals for chrome, mixed case for reading text.** Noita does the same.
  - Capitals: group labels, plaques, buttons (GARAGE, NEXT, CONTINUE, SELL, Reroll), the HUD names, the banner
    and the result title.
  - Mixed case: card part names, tooltip names, tooltip and keyword prose.
  - Capitals are applied at display time through `HEAD_FONT` (Silkscreen draws lowercase as capitals),
    never in the data, so tests that check "You win", "Cutter" and so on still hold.
- **The HP readout stays "78 / 100".** The mockup's "✚ 84" was shorthand. The non-goals rule out changed
  readouts.

| Role | Value | Notes |
|---|---|---|
| Ink (darkest, outlines, shadows) | `#0d0709` | |
| Panel fill | `#140912` at ~84% alpha | near-black wine, see-through |
| Panel rim | `#b8804f`, 2px | warm tan; no corner radius (square, Noita) |
| Text | `#f2e2c2` | cream |
| Group label | `#e0b88a`, small caps, letter-spaced | e.g. "PARTS" above the inventory bar |
| Gold (accent, money, hover/selected, go buttons) | `#ffb53a` | replaces `ACCENT #e8c35a`. Hovered/selected gets a gold rim plus a soft glow |
| Socket (filled) | `#8a3445` fill, `#2e0f16` 2px border, `#b2505f` 1px inner line | where part art sits |
| Socket (empty) | `#4a1e28` fill, `#6a2a36` inner line | |
| Plaque (one main header per screen) | `#c0475a` fill, 2px cream border, 2px ink outline, 3px hard ink drop shadow, bold header font, ink text shadow | "SHOP"; the result's "YOU WIN" / "YOU LOSE" |
| Price pill | ink fill, 1px tan rim, gold text, hung off the bottom edge of the item | shop items with a price |
| Sell zone | panel, rim `#d9465a`, text `#ff6a7a` | |
| HP player / enemy | `#62d64a` / `#ff4f5e` | thin bars, 1px ink outline |
| Dusk backdrop | radial glow `#7a3446` centre → `#3a1622` edge, 40px grid lines at `rgba(255,170,150,.10)` | shop and garage only |
| Vignette | soft dark inset at the screen edges | kept. The user removed scanlines, not the vignette |

Screen by screen:

- **Shop and garage:** the Dusk backdrop, then the wash, then the panels.
  - The shop stage row sits on one panel with the "SHOP" plaque on its top edge.
  - Items and options are cards. Shop items carry price pills.
  - The Garage/Shop toggle, Next and Reroll are panel buttons. Next (the go action) has a gold rim and gold text.
  - The inventory bar's slots are sockets, with the "PARTS" label above.
  - The gold readout is gold text, top right, with no slab.
  - In the garage, slot markers and the hover box take gold/tan from the palette in place of the current pale
    yellow.
- **Cards** (`ChCard`, `ChPartCard`, the shop's inner cards): the face is a panel. The part-art area is a
  socket. The name and cost use the body font. Hover and selection add the gold rim and glow. Sizes don't
  change.
- **Part tooltip:** a dark panel with a tan rim and cream text. Numbers stay gold. Each keyword box becomes a
  dark panel whose title is in the keyword's colour, with a coloured left stripe or rim, in place of a solid
  saturated fill.
- **Battle HUD:** no `PanelContainer` slabs. Each side shows its name, a thin HP bar with a ✚-style icon and the
  number, and the energy pips restyled as small sockets (lit gold, `VOLLEY` brighter gold, `SHORT` dark red,
  unlit as empty sockets). Text gets a 1px ink outline or shadow so it reads over the bright sky. The elite/boss
  banner uses the plaque. The countdown uses the header font.
- **Result panel:** a plaque reading "YOU WIN" / "YOU LOSE" etc. (whatever `ROWS` holds today) and a gold-rimmed
  Continue button, over the fight.
- **Foreground wash:** the same noise, colour ramp, additive blend and ~15% alpha as the Celeste `Wash`, drifting
  slowly.
  - In battle it draws above the world and below the HUD.
  - On the shop/garage it draws above the backdrop and below the panels.
  - It must not catch mouse input.
  - In battle, scroll may follow the camera as in `FgLayer`. On the shop it is drift only.

## Left to the builder

- **Fonts.** Pick the files and confirm their licence allows shipping them in the repo. m5x7 and m6x11 by Daniel
  Linssen are the starting candidates. If either licence is unclear, use an OFL pixel font such as Silkscreen
  or Pixelify Sans. Add a credits note wherever the project keeps one (or a `CREDITS.md`).
  - Set sizes at whole multiples of each font's native pixel height, with antialiasing and hinting off.
  - The current sizes (20 theme, 12/14/16 in cards and tooltips) will change, and text must still fit the
    existing card and tooltip sizes.
- **How `ChUi` exposes the style.** Its shape is the builder's call: new constants, a `panel()`/`socket()`/
  `plaque()`/`pill()` helper set, Theme type variations. The rule is that colours live only in `ChUi` (and
  keyword colours in `ChKeywords`).
- **Backdrop and wash.** Choose a shader or `NoiseTexture2D` + `Sprite2D`, and whether the two screens share one
  scene or helper. Choose the exact wash alpha (start at the source's 0.15, and lower it if it washes out the
  battle).
- **Keyword colours.** Nudge them in saturation if they read poorly as text on dark panels.
- **Tests.** Update existing tests where constants are renamed. Add a check only where a new branch of logic
  appears (for example, a helper that picks socket vs empty-socket style). No tests for colours themselves.
- **Verification.** Run `tools/screenshot.gd` and compare the four shots against this spec, and run the headless
  suite (`tests/run_tests.gd`).
