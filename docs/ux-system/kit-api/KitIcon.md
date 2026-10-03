# KitIcon: API freeze (wave 0)

Unit: `kit-KitIcon` (kind `kit-part`, tier 1a; cut review C02, C23). Spec for `revamp.workflow.js`.

## Purpose

KitIcon is the one way to draw a glyph. It takes a glyph from the app's named Phosphor set (`AppIconography`, with verbs in `AppIcons`) and draws it:
- at one of three designed sizes, 20, 22 or 24 logical px (VL §7, C02: s/m/l);
- in an opaque colour role;
- aligned to whole physical pixels;
- decorative by default.

It replaces every `Icon(` and `AppGlyph(` outside the kit, so there is one icon vocabulary and one size scale.

## Replaces

- **G16 baseline** (`test/kit_ratchet_baseline.json`): `Icon` 726 in 143 files. The largest are:
  - `chat/composer.dart` 29;
  - `chat/message_view.dart` 27;
  - `workspace_screen.dart` 23;
  - `files_screen.dart` 21;
  - `activity_screen.dart` 20;
  - `chat_screen.dart` 20;
  - `review_workspace.dart` 20;
  - `tool_card.dart` 17.
- **`lib/ui/app_iconography.dart`** is in this unit's write set (C23). Its G16 counts are `{Icon 2, Opacity 1}`, and after this unit they are zero:
  - The classes `AppGlyph` and `AppBrandMark` move into `lib/ui/kit/kit_icon.dart` unchanged (R12: moved, not duplicated). `app_iconography.dart` re-exports them, so every import keeps compiling.
  - Both are marked `/// Retired by kit-KitIcon: use KitIcon` / `KitBrandMark` (KIT-43; no `@Deprecated`).
  - `AppGlyph(` and `AppBrandMark(` become G2 ratchet patterns (7 and 1 call sites).
  - The `AppIconography` IconData constants (187 glyphs) stay in `app_iconography.dart` as data.
- **Material `Icons.*` glyphs outside the kit** (for example `Icons.add_comment_outlined` ×6, `search_off_rounded` ×5, `sync_problem_rounded` ×4) are rejected by KitIcon's debug assert. Their call sites map them to `AppIconography` glyphs when they migrate.
- **Kit-internal off-scale sizes retire in their owning units:**
  - 18: `kit_panel.dart:80` (this is kit-KitSurface's), `kit_notice.dart`, `kit_status_line.dart`, `kit_ask_line.dart`, `kit_state_view.dart`;
  - 19: `kit_buttons.dart`, `kit_state_view.dart`.
  Status-mark dots (`kit_status_mark.dart` 12) are marks, not glyphs, and stay with KitStatusMark.
- **kit-v2.json `assignment`:** no element is assigned.

## File

`lib/ui/kit/kit_icon.dart` (new), and `lib/ui/app_iconography.dart`, which keeps the glyph data and re-exports the moved classes. The write set is those two files, `test/kit/kit_icon_test.dart` and `test/goldens/kit/kit_icon_golden_test.dart`.

## Public API

```dart
/// The three designed sizes (VL §7, LOOK-33; s/m/l per cut review C02).
enum KitIconSize {
  small,  // 20: inline beside secondary text, a row's tile, a fold chevron
  medium, // 22: a confirmation's mark, a card header
  large;  // 24: an icon-only control, navigation (AppIconography.actionSize)

  double get logical; // 20, 22, 24
}

class KitIcon extends StatelessWidget {
  /// [icon] must come from the app's set: an `AppIconography` glyph or an
  /// `AppIcons` verb. A debug assert rejects any other font family, for
  /// example Material's `Icons.*`.
  const KitIcon(
    IconData icon, {
    Key? key,
    KitIconSize size = KitIconSize.large,
    KitTextTone? tone,          // null: the ambient icon colour the enclosing kit part set, else text1
    bool growsWithText = false, // leading and state icons only (LOOK-33): see below
    String? semanticsLabel,      // null: decorative, excluded from semantics
  });

  /// An icon that says a status, in the tone for [status]: the kit's one
  /// tone map, KitTokens.toneFor (README.md decision D12): neutral →
  /// secondary, progress → accent, ok → success, attention → primary,
  /// failure → primary. Attention's amber belongs only to the needs-you
  /// parts (LOOK-4, LOOK-24); a failure is said in words and a neutral
  /// error glyph, not in red (LOOK-5, B2 interim). The glyph is the
  /// status's own, KitTokens.glyphFor: neutral radioEmpty, progress sync,
  /// ok check, attention warning, failure error (KitStatusMark reads the
  /// same map). [icon] overrides the glyph only where a condition has its
  /// own (a status line's cloudOff); the tone still comes from [status].
  const KitIcon.status(
    AppStatusTone status, {
    IconData? icon,
    Key? key,
    KitIconSize size = KitIconSize.small,
    bool growsWithText = true,
    String? semanticsLabel,
  });

  // No KitIcon.toneFor: the one tone map is KitTokens.toneFor (README.md,
  // decisions D8 and D12). Words beside the icon read the same map there.
}

/// The open-portal mark (the retired AppBrandMark's job). Decorative unless
/// labelled. It is drawn from `assets/branding/open-portal/mark.svg` in the
/// accent.
enum KitBrandMarkSize { tile, mark } // KitTokens.iconTileSize (30) · KitTokens.markSize (44)

class KitBrandMark extends StatelessWidget {
  const KitBrandMark({Key? key, KitBrandMarkSize size = KitBrandMarkSize.tile, String? semanticsLabel});
}

// Moved here unchanged and re-exported from app_iconography.dart (retired):
// class AppGlyph extends StatelessWidget { const AppGlyph(IconData icon, {Key? key, double? size, Color? color, String? semanticLabel, TextDirection? textDirection}); }
// class AppBrandMark extends StatelessWidget { const AppBrandMark({Key? key, double size = 32, String? semanticLabel}); }
```

- **Growing with text (LOOK-33, B16 interim).** With `growsWithText: true`, the size is `KitTokens.iconSize(context, size.logical)`, which scales with the person's text size up to `KitTokens.maxIconScale` (1.5). The result is then rounded to a whole physical pixel: `(s * dpr).round() / dpr`. Without it, the size is exactly 20, 22 or 24.
- **Duotone glyphs** (the `…Selected` navigation glyphs) draw their background glyph at `KitTokens.duotoneWash` (new token, see Tokens). Under high contrast they fall back to the regular glyph. LOOK-33 allows duotone only on the dock's or rail's selected destination (`kit-KitNav`), and the G21 pattern `AppPhosphorDuotone|Selected\b` outside `kit_nav.dart` enforces it.
- **Direction.** `matchTextDirection` is taken from the glyph (directional glyphs mirror under RTL, LAY-8). Inside a `KitLtr` region (KitText.md) a technical mark keeps its orientation.

## States

- KitIcon has no loading, empty, error or working state; those belong to the host.
- **Disabled:** the host passes `tone: KitTextTone.tertiary`. There is no opacity (LOOK-14 applies to marks read with their word).
- **Status:** `KitIcon.status` covers neutral, progress, ok, attention and failure.
- **Selected:** a duotone glyph, on the dock or rail only.

## Tokens

- **ThemeRoles:** `text1`, `text2`, `text3`, `accent`, `onAccent`, `attention`, `danger`, `success` (via `KitText.toneColor`).
- **KitTokens:** `iconSize(context, size)`, `maxIconScale` (1.5), `iconTileSize` (30) and `markSize` (44) for `KitBrandMark`.
- **New token (pre-wave `kit_tokens.dart`, `_new-tokens.md`):** `KitTokens.duotoneWash` (double, 0.2): the alpha of a duotone glyph's background. It is not in this unit's write set, so the coordinator adds it before wave 1. Otherwise the duotone path keeps `AppGlyph`'s literal inside the moved retired class and `KitIcon` draws the regular glyph only (PROC-20).

## Adaptive

- The sizes are identical on compact, medium, expanded and large (§8.3: density never shrinks anything).
- KitIcon is not a control. Hover, focus and tooltips belong to `KitIconButton`, `KitTappable` and `KitTerm` (R23).

## Accessibility

- **Decorative by default** (`ExcludeSemantics`), because the control or row beside it carries the words (A11Y-1).
- With `semanticsLabel`, it is an image node with that label. Use this only for a standalone informative glyph.
- **Contrast:** icon colours meet 3:1 on ground and surface1–3 (LOOK-8).
- **200 % text:** a fixed icon stays at 20, 22 or 24, and a growing icon reaches at most 1.5×, rounded to whole physical pixels.
- **48 dp** does not apply: it is not a target.

## RTL

- Directional glyphs mirror through the glyph's `matchTextDirection`: back, forward, chevrons, reply, undo and redo, send, indent.
- Play and media, check, clock, search, brand logos and key or code glyphs do not mirror (LAY-8). That flag is part of `AppIconography`'s data. Changing a glyph's flag is this unit's job only when the LAY-8 list says so.
- No insets.

## Motion and haptics

- None. A rotating chevron is `KitSpin.chevron` (KitMotionParts), and a swap of glyphs is `KitSwap`.
- No `KitHaptics`.

## Data safety and honest state

- A state is never shown by colour alone. `KitIcon.status` sits beside the state's word (STATE-9), and the host provides that word.
- Failure uses the neutral tone (LOOK-5), so red keeps meaning only destroy or stop.
- `KitBrandMark` is never used as a status.

## Depends on

- The VL merge (`KitText.toneColor`, `ThemeRoles`, `KitTokens`).
- The pre-wave token `duotoneWash`.
- No wave-1 part. Later parts use KitIcon: kit-KitNav, kit-KitTopBar (C25) and the hygiene swap in kit parts.

## Tests required

`test/kit/kit_icon_test.dart`:

1. Each `KitIconSize` renders at exactly 20, 22 and 24 logical px at text scale 1.0 and 2.0 when `growsWithText` is false.
2. With `growsWithText` at 2.0 text, it renders at `min(size × 2, size × 1.5)` rounded to a whole physical pixel at DPR 2.625 and 3.0. A test on `(renderedSize * dpr) % 1 == 0`.
3. The debug assert fires for `Icons.add` and passes for `AppIconography.add` and `AppIcons.copy`.
4. With no label it has no semantics node. `semanticsLabel: 'Offline'` gives one image node with that label.
5. `KitIcon.status` maps each `AppStatusTone` to the tone listed above (equal to `KitTokens.toneFor`); failure is not `danger` and attention is not `attention`.
6. Under RTL, `AppIconography.back` is mirrored and `AppIconography.check` is not.
7. A duotone glyph draws two layers, or one under `MediaQuery.highContrast`.
8. Every tone colour has alpha 255.
9. `AppGlyph` and `AppBrandMark` still build from `package:opencode_mobile/ui/app_iconography.dart` (re-export) with their old parameters.
10. `app_iconography.dart` has G16 count zero. This is asserted by the ratchet test, which the integrator re-baselines (R05).
11. Reduced motion: no ticker.

## Galleries required

`test/goldens/kit/kit_icon_golden_test.dart`, at DPR 3, Android:

- **States:** `sizes` (one glyph at 20/22/24 in each tone), `status` (the five statuses beside their words) and `duotone` (a selected nav glyph and its high-contrast fallback). Each in dark and light at 412×915.
- **Default state (`sizes`):** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **`_text2` and `_ar`:** `sizes` and `status` at 412×915 and 1280×800. The Arabic shot shows mirrored directional glyphs.
- **G6 overflow matrix** without images.
- The gallery checks the goldens for pixel alignment: no half-pixel edges (VL §7).

## Non-goals

- No new glyphs. Adding one goes through `AppIconography` in a unit that owns the page.
- No icon buttons (`KitIconButton`), no tooltips, no tap handling.
- No custom colours: tones only.
- No sizes other than 20, 22 and 24.
- No SVG icons other than the brand mark.
- No call-site migration.

## Open questions

None. `KitTokens.duotoneWash` and `KitTokens.toneFor` are pre-wave (`_new-tokens.md`); the coordinator adds them with the other seams. The fallback for a missing `duotoneWash` is above.
