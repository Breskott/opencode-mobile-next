# KitSwatch + KitThemePreview — API freeze (wave 0)

Unit: `kit-KitSwatch` (wave 1, tier 1a, kind `kit-part`, model sonnet; title "Build KitSwatch + KitThemePreview"). Spec: kit-v2.md §5 (appearance: "theme swatches, preview") and §9.2 (Surfaces), with cut review C26 (the unit takes `KitThemePreview`) and C36 (`appearance_picker.dart` → kit-KitSwatch as the file→part edge for its wave-2 unit). Owner decision (PLAN §1, STANDARDS §0.2 level 1): the colours are a theme the person can change, from a pack or later their own accent and ground. Rules: LOOK-1, LOOK-6, LOOK-7, LOOK-8, LOOK-14, LOOK-21, LOOK-27, LOOK-39, KIT-9, KIT-12, KIT-25, STATE-8, STATE-9, LAY-2, LAY-9, A11Y-1, A11Y-8.

## Purpose

Choosing colours by looking. This unit freezes three parts:

- **`KitSwatch`:** one theme as a miniature of its own ground, a panel, a line of its text, and its accent and success colours, with the in-use check. `KitSwatch.accent` is the same part for one accent colour in the coming custom theme.
- **`KitSwatchGrid`:** lays swatches out as one single-choice group.
- **`KitThemePreview`:** the app's real kit parts drawn in a candidate theme's roles, so the preview sheet shows what that theme looks like before it is applied.

## Replaces

- **Map elements, 2 on 2 pages** (kit-v2.json `assignment` → `module:appearance`, moved into the kit by K2 §9.2):
  - `appearance-settings#theme-pack-grid` (`kitGap` `KitSwatchTile`; "3-column swatch tiles with a check on the current pack"). This is the private `_ThemePackTile` and its `Wrap` in `lib/ui/screens/settings/personal_settings_screens.dart:85-120, 364-515`:
    - an `InkWell`;
    - `Opacity(.5)` over the whole tile, text included, when unavailable (LOOK-14);
    - `Container`s with radii 14, 6 and 2, and 12 dp dots;
    - the column count from `width / 130` and the card width from `width.clamp(0, 900) − 32 − 10 × (columns − 1) − .5` (G15-style literals);
    - a 2 dp selected border (LOOK-21: 1 physical px).
  - `theme-pack-preview-sheet#theme-preview-card` (`kitGap` `KitThemePreview`; "same generic card for every pack"). This is `ThemeComponentPreview` in `lib/ui/widgets/appearance_picker.dart:230-322`: `Theme` 1, `Material` 1, `DecoratedBox` 1, `FilterChip` 1, `FilledButton` 1, `Text` 5, radii 20 and 10.
- **Adopters in wave 2** (not this unit's files):
  - the settings unit owning `personal_settings_screens.dart` (the grid; its `theme-pack-<id>` keys are passed as `swatchKey`);
  - the one owning `appearance_picker.dart` (the preview sheet on `showKitSheet`).
  - Their G16 counts for these widgets (`Opacity` 1, `InkWell` 1, `Theme` 1, `Material` 1, `FilterChip` 1) go to zero there.
- **Future (named now so there is one part):** the custom theme's accent picker (LOOK-7, LOOK-39) uses `KitSwatch.accent` in a `KitSwatchGrid`.

## File

- `lib/ui/kit/kit_swatch.dart` (new): `KitSwatch`, `KitSwatchGrid`, `KitThemePreview`.
- Tests: `test/kit/kit_swatch_test.dart`.
- Gallery: `test/goldens/kit/kit_swatch_golden_test.dart`.

## Public API

```dart
/// One theme, or one accent, to choose. States: default, selected (in
/// use), disabled with reason (unavailable).
class KitSwatch extends StatelessWidget {
  /// A theme: a miniature in [roles] — its ground, a surface1 panel with a
  /// line of its text1, its accent and success — and the label under it.
  const KitSwatch({
    super.key,
    required this.roles,          // ThemeRoles? of the brightness in use; null: no palette (unavailable)
    required this.label,          // "Graphite" (a pack's name, shown as written)
    required this.selected,       // in use now: a check and selected semantics
    required this.onPressed,      // VoidCallback? the host opens its preview sheet; null = unavailable
    this.disabledReason,          // required when onPressed == null (asserted): "Needs Android 12 or later"
    this.swatchKey,               // e.g. ValueKey('theme-pack-${id.name}') (kept by the host)
  }) : color = null;

  /// One accent for the custom theme: a circle of [color], a check in its
  /// own on-colour when selected.
  const KitSwatch.accent({
    super.key,
    required Color this.color,    // a guarded accent (LOOK-39: deriveRoles moved it out of the
                                  //   attention/danger band, and it reads on the ground)
    required this.label,          // "Blue": the colour's name is its semantic label
    required this.selected,
    required this.onPressed,      // selects at once (a single choice acts on tap, KIT-25)
    this.disabledReason,
    this.swatchKey,
  }) : roles = null;

  final ThemeRoles? roles;
  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final Key? swatchKey;
}

/// A single-choice group of swatches: columns from the space it has,
/// start-aligned, arrow keys move within it.
class KitSwatchGrid extends StatelessWidget {
  const KitSwatchGrid({
    super.key,
    required this.label,          // the group's name for semantics: "Theme", "Accent colour"
    required this.children,       // KitSwatch widgets (all theme or all accent; asserted)
    this.gridKey,
  });
}

/// The app's own parts in [roles]: a panel with a row (icon tile, title,
/// "Working · 2 min" with the working mark), a code line, the needs-you
/// word, a selected segment's check, a primary and a secondary button.
/// A picture of the theme: one semantics node, not interactive.
class KitThemePreview extends StatelessWidget {
  const KitThemePreview({
    super.key,
    required this.roles,
    required this.label,          // "Preview of Graphite" (semantic label of the picture)
    this.previewKey,              // e.g. ValueKey('theme-component-preview') (kept by the host)
  });
}
```

Notes:

- **The colours drawn are data.** A swatch paints its own `ThemeRoles` instance (or `color`), not the current theme's, and that is still "every colour comes from a `ThemeRoles` role" (LOOK-1). The frame around it (label, check, border) uses the current theme.
- **One `Theme` override, inside the kit.** `KitThemePreview` wraps its sample in `Theme(data: AppTheme.forLocale(AppTheme.fromRoles(roles), locale))`, so the real kit parts pick up the candidate roles. K2 §9.1 moves `Theme` overrides into the kit. R23 ("only in `app_theme.dart`") is read as applying outside the kit, and the gate allowlists this one file with that reason (KIT-5).
- **Kit copy** (ARB, `kit` prefix, en and ar):
  - `kitSwatchInUse` "In use" (semantic value of a selected swatch);
  - `kitThemePreviewTitle` "Fix the login bug" (the sample row's title);
  - `kitThemePreviewWorking` "Working · 2 min";
  - `kitThemePreviewNeedsYou` "Needs you";
  - `kitThemePreviewPrimary` "Send";
  - `kitThemePreviewSecondary` "Attach";
  - `kitThemePreviewSegment` "On";
  - `kitThemePreviewCode` "final ready = true;" (`@description` starting "Technical:", not translated; COPY-11);
  - `kitThemePreviewLabel` "Preview of {theme}".

## States

| State | KitSwatch | KitSwatch.accent |
|---|---|---|
| default | miniature, label in `text1`, a 1-physical-px `hairline` border | the colour circle with a 1 px `hairline` ring |
| selected (in use) | a 1 px `accent` border, a 20 dp check in `accent` after the label, selected semantics with the value "In use" | the check inside the circle in `onColor(color)` and a 1 px `text1` ring outside it |
| disabled with reason | the miniature replaced by a `surface3` field with the sparkle glyph in `text3`; the label in `text3` and `disabledReason` under it in `text2`, visible (STATE-8); not focusable, but still in semantics with the reason | the circle drawn in `surface3` with the reason as the hint (not expected in the picker, which offers only valid accents) |
| focused (keyboard) | a 2-physical-px `accent` focus ring outside the border | the same |

`KitThemePreview` has one state: it draws what it is given. Loading and error do not apply: roles are local. The host's save failure is a `KitNotice` in its sheet. KIT-12 doc comment: "States: default, selected, disabled with reason".

## Tokens

- **ThemeRoles** (the current theme, for the frame):
  - `hairline` (borders);
  - `accent` (the selected border, check and focus ring; LOOK-6: the current-selection mark and the focus ring);
  - `text1`, `text2`, `text3` (label, reason, disabled);
  - `surface1` (the tile);
  - `surface3` (unavailable).
- **ThemeRoles** (the swatch's own): `ground`, `surface1`, `text1`, `accent`, `success`.
- **KitText:** `label` (13/18 w600: the swatch label), `secondary` (the reason). The preview uses the parts' own roles.
- **KitTokens:**
  - `panelCornerRadius` (18: tile and preview frame);
  - `iconTileRadius` (9: the miniature's inner panel);
  - `space1`, `space2`, `space3` (miniature padding, dot gaps, grid spacing);
  - `markSize` (44: the accent circle), inside a 48 dp target (`minTarget`);
  - `smallIconSize` (20: the check);
  - `hairlineWidth(context)` / `focusRingWidth(context)` (LOOK-21).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.swatchMinWidth` = 112: the narrowest tile. Columns are `clamp(floor(width / swatchMinWidth), 2, 6)`, replacing `/ 130` and the other literals;
  - `KitTokens.swatchPreviewHeight` = 56: the miniature's height;
  - `KitTokens.swatchDot` = 12: the accent and success dots.

## Adaptive

| Window | KitSwatchGrid | KitThemePreview |
|---|---|---|
| compact | 3 columns at 360–599 dp (2 below 348 dp of content), the host's rails | full width of the sheet's content |
| medium | 4 or 5 columns (by the width it is given), capped with its host at `KitLayout.readingWidth` | the same, inside the sheet capped at 640 |
| expanded / large | up to 6 columns in the Settings detail pane or reading width | inside the 560 dp dialog panel the sheet becomes |

- **Pointer:** a hover fill on the tile (`KitTappable`-style, no ripple) and a click cursor. The tooltip repeats a truncated label.
- **Keyboard (LAY-10):** the grid is one Tab stop. The arrow keys move within it (reading order; ↑ and ↓ move by a row), Enter or Space presses the focused swatch, and Home and End jump to the first and last. The same group rule as KitChoiceList (§8.2).

## Accessibility

- **Each swatch** is a button in a group named `label` (`inMutuallyExclusiveGroup`), labelled with its name. `selected` maps to selected semantics with the value "In use", so the choice is never colour alone (STATE-9). A disabled swatch reads its reason as the hint.
- **Targets:** every tile is at least 48 × 48 dp. Accent circles are 44 dp drawn inside 48 dp targets, 8 dp apart (LAY-9).
- **The preview** is one image node labelled `kitThemePreviewLabel` ("Preview of Catppuccin"). Its sample buttons are not announced as buttons (they do nothing).
- **200 % text:**
  - labels wrap to two lines, and from 1.3× the grid drops a column so the label keeps at least 8 characters per line;
  - the reason wraps and is never cut;
  - the preview's words wrap and it grows taller;
  - no overflow at 320 dp.
- **Contrast:**
  - the frame meets LOOK-8 in every pack;
  - the miniature's own colours are the theme's and are shown as they are;
  - the check inside an accent circle uses `onColor(color)` (≥ 4.5:1, the `theme_roles.dart` helper).

## RTL

- The grid fills from the start edge (right in Arabic), and arrow keys follow the reading direction.
- Inside the miniature the text line sits at the start and the dots at the end.
- Pack names are shown as written, isolated with `KitBidi.auto`.
- The preview mirrors like any screen, and its code line is an LTR island aligned left (COPY-30).

## Motion and haptics

- **Selection changes at once:** the check and border swap with no animation, as a choice row does.
- **A theme being applied** is animated by the app's theme change (`MaterialApp`'s own), not by this part.
- **No haptics:** a choice is local (MOT-11).
- **Reduced motion:** nothing to reduce; settles after one `pump()` (G8).

## Data safety and honest state

- **The part never applies or saves a theme.** `onPressed` is the host's (open the preview sheet, or select an accent). The host keeps the "Apply / In use" and save-failure states (the sheet's `KitNotice`).
- **Selected means in use now.** A swatch previewed in the sheet is not shown selected in the grid until it is applied.
- **Unavailable is said, not faded:** the reason is visible text (STATE-8), and there is no `Opacity` over words (LOOK-14).
- **Only guarded accents.** `KitSwatch.accent` asserts in debug that `color` keeps LOOK-39's distance from the current theme's `attention` and `danger` (hue ≥ 30°, ΔE2000 ≥ 20). It uses the same check `deriveRoles` uses, so the picker cannot offer an accent that reads as "needs you" or "danger".

## Depends on

- **Existing:**
  - `ThemeRoles` and `onColor` (`theme_roles.dart`);
  - `AppTheme.fromRoles` and `AppTheme.forLocale` (`app_theme.dart`, VL);
  - `KitTokens`, `KitText`;
  - for the preview's sample: `KitButton` (primary, secondary), `KitRow`/`KitPanel`, `KitTaskMark`/`KitStatusMark`, `KitTechnicalValue`-style mono line.
- **Pre-wave seams:** `KitTokens.hairlineWidth`/`focusRingWidth`, `KitBidi`.
- **No wave-1 dependency** (tier 1a). The preview uses today's parts. When the v2 parts merge, the preview picks up their look automatically, because it renders them rather than copying them.
- **Pre-wave (`_new-tokens.md`):** the LOOK-39 distance check must be a public function in `theme_roles.dart` (for example `bool accentKeepsMeaning(Color accent, ThemeRoles roles)`). The VL branch has only the private `_guardAccent`. This is the §0.5 step 1 theme work, not this unit's.

Depended on by: the settings unit (Appearance grid), the unit owning `appearance_picker.dart` (preview sheet), and the future custom-theme slice.

## Tests required

In `test/kit/kit_swatch_test.dart`:

1. **Press:** tapping a swatch calls `onPressed` once. Enter or Space on the focused swatch does too (G14).
2. **Selected:** `selected: true` gives selected semantics with the value "In use" and shows the check. The border is 1 physical px in `accent` (no 2 dp border).
3. **Disabled with reason:** `onPressed: null` without `disabledReason` asserts. With it, the reason is a visible `KitText` (found by text), the tile is skipped by Tab, and no `Opacity` wraps any text (a painted text alpha scan is 255).
4. **Miniature colours:** a swatch for `graphiteLight` paints `graphiteLight.ground`, `.surface1`, `.text1`, `.accent` and `.success` in the miniature, even when the app theme is dark.
5. **Accent swatch:** the check paints in `onColor(color)`. A `color` inside the attention band (for example #FFB547 on Graphite) asserts in debug (LOOK-39).
6. **Grid columns:** 3 columns at 412 dp, 2 at 320 dp, 6 at 900 dp of content, and one fewer from text 1.3.
7. **Keyboard:** Tab enters the grid once; → moves to the next swatch (← under RTL); ↓ moves one row.
8. **Preview:** `KitThemePreview(roles: graphiteLight)` inside a dark app paints the sample primary button in `graphiteLight.accent`. It exposes one semantics node labelled "Preview of …" and no button nodes.
9. **Overflow and motion:** no overflow at 320, 412, 600, 840 and 1280 at text 1.0, 1.3 and 2.0, LTR and RTL (G6); settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_swatch_golden_test.dart`, DPR 3, Android. The scenes are:

- a grid of 8 packs (Graphite selected, Material You unavailable);
- a grid of the 3 guarded Graphite accents;
- `KitThemePreview` for Graphite and for Catppuccin.

- **Declared states × dark and light at 412×915:**
  - `grid` (default, selected and unavailable together);
  - `grid_focused`;
  - `accent` (one selected);
  - `preview_graphite`;
  - `preview_catppuccin`.

  That is 10 PNGs.
- **Default (`grid`) × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Text 2.0 and Arabic** (`grid`, `preview_graphite`) at 412×915 and 1280×800, dark: 8 PNGs.
- **Names:** `kit_swatch_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 28 PNGs.

## Non-goals

- **No custom-theme editor:** no ground picker and no contrast warnings. That is a later programme slice; this unit only gives it its swatch.
- **No preview sheet, Apply button or save:** that is `appearance_picker.dart`'s wave-2 unit, on `showKitSheet`.
- **No Effects preview or glass sample** (LOOK-27: Effects previews glass through the real navigation layer).
- **No change to theme packs or `deriveRoles`.**

## Open questions

None. C26's "accent-only packs after VL" is superseded by STANDARDS Appendix A #29 (a pack may set every role's value, never its meaning), so the swatch shows each pack's own ground and surface, not only its accent.
