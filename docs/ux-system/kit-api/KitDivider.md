# KitDivider: API freeze (wave 0)

Unit: `kit-KitDivider` (kind `kit-part`, tier 1a). Spec for `revamp.workflow.js`.

## Purpose

KitDivider is the one separator. It is a `hairline` line exactly one physical pixel thick, snapped to the pixel grid (VL §7, LOOK-21), and optionally inset to where a row's words start (VL §4). It replaces `Divider` and `VerticalDivider`, so no separator is ever doubled, soft or a different grey.

## Replaces

- **G16 baseline:** 70 in 43 files:
  - `Divider` 65 in 42 files;
  - `VerticalDivider` 5 in 3.

  The largest are `review_workspace.dart` 5, `tools_screen.dart` 5, `chat/command_launcher.dart` 4, `files_screen.dart` 4, `termux_setup_screen.dart` 3, `about_screen.dart` 2, `active_context_screen.dart` 2 and `app_diagnostics_screen.dart` 2.
- **Not here:**
  - `PopupMenuDivider` 2 is `KitMenu`'s group divider.
  - The hairlines drawn inside kit parts (`KitRowGroup` at `kit_row.dart:278`, the confirm sheet's consequences at `kit_confirm_sheet.dart:633`) move to KitDivider in their own units (kit-KitRow-v2, kit-KitConfirmSheet/DetailsFold).
- **kit-v2.json `assignment`:** no element is assigned.

## File

`lib/ui/kit/kit_divider.dart` (new). The write set is that file, `test/kit/kit_divider_test.dart` and `test/goldens/kit/kit_divider_golden_test.dart`.

## Public API

```dart
/// Where a horizontal separator starts (VL §4: "separators are inset to the text start").
enum KitDividerInset {
  none,   // edge to edge: between sections, under a header
  gutter, // from KitTokens.space4 (16): rows with no leading icon
  text,   // from space4 + iconTileSize + space3 (16 + 30 + 12): rows with an icon tile
}

class KitDivider extends StatelessWidget {
  /// A horizontal hairline. Its layout extent is exactly one physical pixel;
  /// spacing around it is the host's, from tokens.
  const KitDivider({Key? key, KitDividerInset inset = KitDividerInset.none});

  /// A vertical hairline between items in a row, such as a toolbar's groups.
  /// It is as tall as its parent allows.
  const KitDivider.vertical({Key? key});
}
```

**Paint, frozen.**
- The line is a filled rectangle `1 / devicePixelRatio` thick, not a stroke.
- Its position is rounded to the physical pixel grid at paint time: the paint offset is rounded in device pixels. So at DPR 2.625 or 3.0 it covers exactly one device-pixel row or column and is never smeared over two (VL §7: "a doubled hairline or a half-pixel offset is a bug").
- The inset is directional: from the start edge.

## States

- None. A separator has no loading, empty, error, disabled, working or answered state.
- Under high contrast it keeps `hairline`. A stronger separator would need a new role, which is out of scope.

## Tokens

- **ThemeRoles:** `hairline` (never passed through `withValues(alpha:)`, LOOK-3).
- **KitTokens:** `space3`, `space4`, `iconTileSize`, and `hairlineWidth(context)` (pre-wave §0.5 step 2).
- **New tokens:** none.

## Adaptive

- The same line on compact, medium, expanded and large.
- The `text` inset is the same on every window, because the row anatomy does not change (VL §4).
- **Pointer and keyboard:** not interactive, not focusable.

## Accessibility

- Decorative: it is excluded from semantics (`ExcludeSemantics`), so screen readers never announce "divider" between rows.
- Grouping is carried by the panel and the section label.
- **200 % text:** unaffected (one physical pixel).
- **Contrast:** `hairline` is a separator, not information. Information is never carried by a divider alone.

## RTL

- The inset uses `EdgeInsetsDirectional.only(start:)`, so under Arabic the line starts at the right, under the words.
- The vertical divider has no direction.

## Motion and haptics

- None.

## Data safety and honest state

- Not applicable. A divider never stands for a state. For example, "destructive rows sit last after a divider" (K2 §2.5) is the host's ordering; the divider only separates.

## Depends on

- The VL merge (`ThemeRoles.hairline`, `KitTokens`).
- The pre-wave `KitTokens.hairlineWidth(context)`.
- No wave-1 part.

## Tests required

`test/kit/kit_divider_test.dart`:

1. The layout height of the horizontal divider is `1 / dpr` at DPR 1.0, 2.625 and 3.0. The vertical divider's width likewise.
2. Placed at a fractional logical offset (for example y = 10.3 at DPR 2.625), the rendered line covers exactly one device-pixel row. This is a pixel probe on an image of the layer: one row painted, none half-painted.
3. The insets are `none` 0, `gutter` 16 and `text` 58 from the start. Under RTL they are measured from the right.
4. The colour equals `ThemeRoles.hairline` exactly (alpha unchanged) in dark and light.
5. There is no semantics node.
6. At `TextScaler.linear(2)` the thickness is unchanged.
7. Reduced motion: no ticker.

## Galleries required

`test/goldens/kit/kit_divider_golden_test.dart`, at DPR 3, Android:

- **States:** `insets` (a row group with `none`, `gutter` and `text` dividers between 54 dp rows) and `vertical` (a toolbar with two groups). Each in dark and light at 412×915.
- **Default state (`insets`):** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **`_text2` and `_ar`:** `insets` at 412×915 and 1280×800. The Arabic shot shows the inset from the right.
- **Crispness:** a review item on the 412×915 shot at DPR 3: one device-pixel row, no doubled or soft line.

## Non-goals

- No thickness, colour or indent parameters: the look comes from tokens.
- No section spacing: that comes from `KitTokens.sectionGap` in the host.
- No menu dividers (KitMenu).
- No list separators built into lists: `KitRowGroup` places them.
- No call-site migration.

## Open questions

None.
