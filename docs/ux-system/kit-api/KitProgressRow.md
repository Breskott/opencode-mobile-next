# KitProgressRow — API freeze (wave 0)

Unit: `kit-KitProgressRow` (wave 1, tier 1b, kind `kit-part`). Spec: kit-v2.md §1.13, with cut review C26 (`KitProgressRow.segments`, taking `session-context-makeup`). Rules: STATE-4, STATE-9, STATE-18, LOOK-4, LOOK-5, LOOK-6, KIT-27.

## Purpose

A row holding a measured amount: a quota window, one item downloading, the context used, a budget. The row has a title, a determinate bar, the amount in words and, when the data is old, its age. `KitProgressRow.segments` shows a stacked bar with a worded legend, for example what fills a conversation's context.

## Replaces

- **Map elements, 6 on 6 pages (kit-v2.json `new[KitProgressRow]`):**
  - `agent-account` (agent-account-limits);
  - `provider-quota` (provider-quota-window);
  - `session-context` (session-context-hero);
  - `usage` (usage-total);
  - `usage-hub` (usage-totals);
  - `voice-model-setup-sheet` (voice-model-setup-sheet-progress).
- **Plus `session-context#session-context-makeup`** (C26; kit-v2.json assigns it to `module:special surface`, and §9 brings it into the kit as `.segments`).
- **Merged gap names:** `KitMetric`, `KitProgressRow`.
- **Code it retires in wave 2, where the unit adopts it:**
  - `Card` + `LinearProgressIndicator` pairs: `agent_account_screen.dart` 5 LPI, `provider_quota_screen.dart` 2, `usage_screen.dart` 2 (G16);
  - the session-context hero card.

## File

- `lib/ui/kit/kit_progress_row.dart` (`KitProgressRow`, `KitProgressSegment`)
- Tests: `test/kit/kit_progress_row_test.dart`
- Gallery: `test/goldens/kit/kit_progress_row_golden_test.dart`

## Public API

```dart
class KitProgressRow extends StatelessWidget {
  const KitProgressRow({
    super.key,
    required this.title,        // "Claude · 5-hour window"
    required this.value,        // 0..1 (clamped); null while unknown: a skeleton bar, never a spinner
    this.valueLabel,            // "62 % · resets in 3 h"
    this.leading,               // a KitRowIcon or KitStatusMark
    this.tone,                  // null = automatic (see States); never AppStatusTone.attention (asserted)
    this.asOf,                  // last-known data: "as of 10:42" (offline or stale)
    this.onTap,                 // opens the detail; adds a KitChevron
    this.titleKey,
    this.valueKey,
  }) : segments = const [];

  /// A stacked bar with a worded legend under it (C26): what fills a
  /// conversation's context, a budget by provider. At most 4 named
  /// segments; the rest are summed into one "Other" segment.
  const KitProgressRow.segments({
    super.key,
    required this.title,
    required List<KitProgressSegment> this.segments,
    this.valueLabel,            // "71 % of 200k tokens"
    this.leading,
    this.asOf,
    this.onTap,
    this.titleKey,
    this.valueKey,
  }) : value = null, tone = null;

  final String title;
  final double? value;
  final String? valueLabel;
  final Widget? leading;
  final AppStatusTone? tone;
  final DateTime? asOf;
  final VoidCallback? onTap;
  final List<KitProgressSegment> segments;
  final Key? titleKey;
  final Key? valueKey;
}

class KitProgressSegment {
  const KitProgressSegment({required this.label, required this.value, this.valueLabel});
  final String label;         // "Conversation"
  final double value;         // share of the whole, 0..1; the segments sum to <= 1
  final String? valueLabel;   // "41k tokens"
}
```

## States

| State | What shows |
|---|---|
| loading (`value == null`) | A skeleton bar, the same shape at `surface3`, with no motion. The value label is hidden. Semantics: "loading". |
| loaded, under 80 % | Bar in `accent`, with the value label. |
| near limit, 80–99 % (automatic) | Bar in `accent`. The value label is followed by the word "Near limit" (`kitProgressRowNearLimit`) in `text1` `label` weight. |
| at limit, 100 % (automatic) | Bar full in `danger`, the word "Limit reached" (`kitProgressRowAtLimit`) in `danger` too (owner polish 2026-09-28: a full or exceeded limit is a failure, not text colour and never amber). |
| stale (`asOf != null`) | "as of 10:42" (`kitProgressRowAsOf`, the time via `intl` for the locale) after the value label, in `text3`. The bar keeps its last value. |
| segments | A stacked bar and a legend of rows (mark swatch, label, value label). The legend always has the words (STATE-9). |
| empty (`segments` empty, or `value == 0` with no label) | The bar track only, and the caller's `valueLabel` (for example "Nothing used yet"). |
| error | Not in this part. The host shows a `KitNotice` error on its section (STATE-20), and the row may keep its last value with `asOf`. |
| disabled | Not in this part: it is not a control. With `onTap: null` it is simply not tappable. |

**Tone and LOOK-4.** K2 §1.13 says "attention from 80 %, failure at 100 %". STANDARDS LOOK-4 reserves the attention roles for "needs you", and LOOK-5 (interim B2) keeps failures out of red. So near and at the limit are carried by the words, and the bar keeps the accent (it is a measured amount), except when full at the limit, where it uses `danger` (owner polish 2026-09-28). An explicit `tone` may be `neutral` (a paused meter, `text3` bar), `progress`, `ok` (`success` bar) or `failure` (`danger` bar, with a word from the caller). `attention` throws an `AssertionError`.

## Tokens

- **ThemeRoles:**
  - `accent` (bar, LOOK-6);
  - `surface3` (track and skeleton);
  - `text1` (title, at-limit bar, limit words);
  - `text2` (value label);
  - `text3` (as-of);
  - `success` (ok tone);
  - `surface1` (the panel the row sits on).
- **KitText:** `rowTitle` (title), `secondary` (value label and legend), `label` (limit words), `caption` (as-of). Tabular figures for numbers (LOOK-18).
- **KitTokens:** `rowHeightTwoLine`, `gutter` (row inset), `space2` and `space3`, `iconTileSize` (leading), `minTarget`.
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.progressBarHeight` (4) and `progressBarRadius` (2): shared with KitProgress, same names;
  - `KitTokens.segmentFills`, the 4 stacked-bar fills, derived from existing roles and never hard-coded: `accent`, `text2`, `text3`, and `surface3` with a 1 physical px `hairline` edge; "Other" uses `surface3`. No new colour role is created.

## Adaptive

- **compact:** a full-width `KitRow` layout inside a `surface1` panel. The value label sits under the title, and the bar under both. The segments legend is one row per segment.
- **medium:** the same. The panel is capped by `KitScreen` at `readingWidth`.
- **expanded / large:** the value label moves to the trailing end on the title's line when both fit at the current text scale (it is measured the way `KitStatusLine._stacks` measures). The legend flows in two columns when there are 3 or more segments and the width is at least `KitLayout.readingWidth / 2` per column.
- **Pointer:** with `onTap`, hover shows the kit row highlight and the focus ring (`focusRingWidth`, pre-wave). Enter activates. Without `onTap` it is not focusable.

## Accessibility

- **One merged semantics node:** "{title}, {percent} percent, {valueLabel}[, near limit][, as of 10:42]" (K2: "62 percent, resets in 3 hours"). For segments: "{title}, {valueLabel}; {label} {valueLabel}; …".
- With `onTap`: button semantics with a 48 dp minimum target (`minTarget`).
- It is not a live region. A crossing into near limit or at limit is announced by the host once, if at all.
- At 200 % text the title and value label wrap (the title to 2 lines, the value label never truncated), and the bar stays full width. At 1.3× and above, the trailing-value layout falls back to stacked.

## RTL

- The bar fills from the start (it mirrors). The segments stack from the start in list order.
- Numbers and units in labels come from the caller already formatted by `intl`. Units with Latin symbols are wrapped by the caller with `KitBidi.ltr` (COPY-30).
- Directional padding only (G7).

## Motion and haptics

- A value change animates the bar on `KitMotion.standard` / `enter` (paint only, MOT-5). A newly crossed limit word cross-fades on `KitMotion.quick`.
- Instant under reduced motion. No loops, and the skeleton does not shimmer.
- **Haptics:** none.

## Data safety and honest state

- Last-known values carry their age (`asOf`, STATE-18, the reliability vertical). A row without `asOf` must be live data, and that is the caller's contract.
- A near or at limit state always has its word, never colour alone (STATE-9).
- `value` is clamped to 0..1 for drawing. The value label shows the real number (for example "112 %").
- Segments that sum to more than 1 throw an `AssertionError` in debug and are scaled to fit in release, never drawn past the track.

## Depends on

- **kit-KitProgress-v2** (its bar renderer and tokens, C25).
- Existing parts: `KitRow` geometry (v1 is enough), `KitChevron`, `KitRowIcon`.

## Tests required

In `test/kit/kit_progress_row_test.dart`:

1. `value: null` shows the skeleton bar and no percentage. Semantics say "loading".
2. 0.62 with a value label renders both. Semantics are "…, 62 percent, …".
3. The automatic tone: at 0.80 "Near limit" appears; at 1.0 "Limit reached" appears; at 0.79 neither.
4. `tone: AppStatusTone.attention` throws an `AssertionError` (LOOK-4).
5. `asOf` renders "as of HH:mm" in the locale's format. Pumped in Arabic, the digits follow `intl`.
6. Segments: the legend lists every label with its value label. A fifth segment folds into "Other". Segments summing over 1 assert.
7. `onTap`: the whole row is one 48 dp target, and tapping calls it once. Without `onTap`, no button semantics.
8. Under reduced motion a value change settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_progress_row_golden_test.dart`: rows in a `surface1` panel, DPR 3, Android platform.

- **Declared states × dark and light at 412×915:**
  - loading;
  - loaded (62 %);
  - near limit (85 %);
  - at limit (100 %);
  - stale (as of);
  - segments (4 + Other);
  - empty.
- **Default (loaded)** × dark and light at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Text 2.0 and Arabic** (loaded and segments) at 412×915 and 1280×800.
- **Names:** `kit_progress_row_<state>…png`. Keep the set under 60 PNGs.

## Non-goals

- No charts beyond one stacked bar: no history, no sparkline (the dataviz work is not in wave 1).
- No fetching or refreshing. The host owns data, loading and errors.
- No screen adoption (kit-part non-goal).

## Open questions

None. `KitTokens.segmentFills` is frozen above as a list derived from existing roles (`_new-tokens.md`); it adds no role to `ThemeRoles`.
