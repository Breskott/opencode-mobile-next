# KitStatusMark and KitTaskMark v2 — API freeze (wave 0)

Unit: `kit-KitStatusMark-v2` (wave 1, tier 1a, kind `kit-change`). Spec: kit-v2.md §2.9, corrected by cut review C05. Rules: STATE-9, MOT-7, MOT-8, LOOK-5, LOOK-6, KIT-43, G37.

## Purpose

The leading state mark of a step row (`KitStatusMark`) and of a task row (`KitTaskMark`). v2 adds a paused mark and gives every mark a word, so no state is shown by colour or shape alone.

## Replaces

- **Map elements:** none. kit-v2.json `changed[KitStatusMark / KitTaskMark].replaces` is empty. The marks are already in use: `local_server_row.dart:189`, `server_plugins_section.dart:608-610`, `team_conversation_view.dart:808-888`, `team_board_card.dart:60-67`.
- **Retires:** the "no state shown by colour alone" item of slice-P9.5 for marks (C41), and the hand-built word switches beside marks in `team_conversation_view.dart:884-888` and `:1018-1027`. Those are migrated in the chat chain, not in this unit.
- **Stale spec item, dropped (C05 verdict):** "read `KitMotion.reduced` instead of `MediaQuery.disableAnimationsOf`" is already done on the VL branch (`kit_status_mark.dart:23`).
- **Widgets retired:** none directly. `KitNeedsYou.mark()` and the checklist, task-card, nav and top-bar units build on this part.

## File

- `lib/ui/kit/kit_status_mark.dart` (`KitStatusMark`, `KitMarkState`)
- `lib/ui/kit/kit_task_mark.dart` (`KitTaskMark`, `KitTaskState`)
- Tests: `test/kit/kit_status_mark_test.dart`
- Gallery: `test/goldens/kit/kit_status_mark_golden_test.dart`

## Public API

```dart
/// Where one step stands. UNCHANGED: no value is added (see "paused" below).
enum KitMarkState { waiting, working, done, failed }

/// A row's leading state mark. States: waiting, working, done, failed,
/// plus the paused modifier.
class KitStatusMark extends StatelessWidget {
  const KitStatusMark({
    super.key,
    required this.state,
    this.paused = false,     // NEW. Only with waiting or working (asserted):
                             //   a heat pause, or a force stop the app can resume
    this.label,              // NEW. The word; null = the kit's default word
    this.showLabel = false,  // NEW. Also draw the word after the mark (outside a KitRow)
  });

  final KitMarkState state;
  final bool paused;
  final String? label;
  final bool showLabel;

  /// NEW. The default word for a state, as a KitRow supporting line starts:
  /// Waiting · Working · Done · Failed · Paused.
  static String wordFor(BuildContext context, KitMarkState state, {bool paused = false});
}

/// Where a task stands. UNCHANGED (no value added).
enum KitTaskState { waiting, working, done, failed, needsYou, stopped }

class KitTaskMark extends StatelessWidget {
  const KitTaskMark({
    super.key,
    required this.state,
    this.paused = false,     // NEW. Only with waiting or working (asserted)
    this.label,              // NEW
    this.showLabel = false,  // NEW
  });

  final KitTaskState state;
  final bool paused;
  final String? label;
  final bool showLabel;

  /// NEW. Waiting · Working · Done · Failed · Needs you · Stopped · Paused.
  static String wordFor(BuildContext context, KitTaskState state, {bool paused = false});
}
```

**Why `paused` is a flag and not a new enum value.** K2 §2.9 asks for `KitMarkState.paused`, and C05 agrees. But adding an enum value breaks two exhaustive `switch`es in the chat library: `lib/ui/screens/chat/team_conversation_view.dart:884` (`String word(KitMarkState mark) => switch (mark) {…}`) and `:1018`. That library has a single owner and no wave-1 unit edits it (AGENTS.md; R03, R11 and KIT-43: additive only). So paused is a modifier on waiting or working, which is also what it means (the step was waiting or working when it paused). This amends K2 §2.9 and §1.12 (`KitStep.paused`, see KitChecklist.md). kit-hygiene (2d) may fold the flag into the enum once the chat chain has replaced those switches with `wordFor`.

- **Semantics.** Every mark is a `Semantics(label: label ?? wordFor(...))`. That is the G37 "status marks need a label" assert, satisfied by default, so no existing caller breaks.
- **`KitTaskMark(state: KitTaskState.needsYou)`** is what `KitNeedsYou.mark()` returns (§2.9), so the two cannot drift.

## States

| State | Mark | Word (default, kit ARB) |
|---|---|---|
| waiting | a hollow ring, 1 physical px stroke | Waiting (`kitMarkWaiting`) |
| working | a small indeterminate ring (`KitTokens.spinnerStroke`, 2 dp, the same arc as a working button); under reduced motion, a still dot | Working (`kitMarkWorking`) |
| done | a check | Done (`kitMarkDone`) |
| failed | the neutral error glyph | Failed (`kitMarkFailed`) |
| paused (waiting or working) | `AppIconography.pause` | Paused (`kitMarkPaused`) |
| task needsYou | `AppIconography.question` | Needs you (`kitTaskNeedsYou`; the same key KitNeedsYou uses) |
| task stopped | `AppIconography.stopCircle` | Stopped (`kitTaskStopped`) |

Loading, empty, error and disabled do not apply: a mark is a state display, not an interactive or data-owning part. KIT-12 doc comment: "States: waiting, working, done, failed, paused (+ task: needsYou, stopped)".

## Tokens

- **ThemeRoles** (the tone table shared by the states group, LOOK-4/5/6):
  - waiting ring: `text3`;
  - working: `accent` (LOOK-6, working marks);
  - done: `success` (never `accent`; LOOK-6, STATE-9);
  - failed: `text1` with the neutral error glyph, never `danger` (LOOK-5, interim B2);
  - paused and stopped: `text2`;
  - needsYou: `attention` (allowed: this is the needs-you mark, LOOK-4).
- **KitText:** `secondary` for the visible word when `showLabel`.
- **KitTokens:** `smallIconSize` (20; the glyph), `markSize` is not used (that is the 44 dp tile). The 32 dp slot is today a literal.
- **Pre-wave seam:** `KitTokens.hairlineWidth(context)` for the ring stroke (LOOK-21).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.markSlotSize` = 32 (the leading slot, today the literal `32`);
  - `KitTokens.markRingSize` = 10 (the waiting ring) and `KitTokens.markDotSize` = 12 (the still working dot under reduced motion);
  - `KitTokens.toneFor` / `toneColor(AppStatusTone)`: the kit's one `AppStatusTone` map, used by every part in the states group (README.md decision D12). G21 forbids numeric literals and ad-hoc colour picks inside the kit. `KitTaskState.needsYou` is the only mark in `attention`; it is a task state, not an `AppStatusTone`.

## Adaptive

- **All window classes:** the same 32 dp slot and 20 dp glyph. The glyph grows with text only within `KitTokens.maxIconScale` (LOOK-33, A11Y-8), rounded to whole physical pixels.
- **Pointer and keyboard:** not focusable (not a control). Hover adds nothing: the word is already in the semantics and the row.

## Accessibility

- Every mark carries its word in semantics (STATE-9, A11Y-1). The row's supporting line still starts with the word (DS §6).
- Not a live region. The host announces changes (A11Y-3).
- At 200 % text the glyph grows at most 1.5×. `showLabel` text wraps, never truncates.
- Contrast: glyphs ≥ 3:1 on `ground` and `surface1–3` (LOOK-8). `text3` for the waiting ring must meet 3:1; if a pack fails that, the ring uses `text2`.

## RTL

- The mark is symmetric. With `showLabel`, the word follows the mark in reading order (`Row` with directional padding).
- The check and pause glyphs do not mirror (LAY-8).

## Motion and haptics

- **Working:** the platform ring. Under `KitMotion.reduced(context)` (the only reduced-motion source, MOT-8) it is a still dot.
- **State change:** the glyph cross-fades on `KitMotion.quick`, and swaps instantly under reduced motion.
- **Haptics:** none (MOT-11).
- **G8:** settles after one `pump()` under `disableAnimations` and under Effects Off. G8x (manifest) covers it once the part is exported.

## Data safety and honest state

- The mark shows only the state it is given, never an inferred one (STATE-11). Paused is refused (assert) with done or failed, because a finished step cannot be paused.
- `failed` never uses red (LOOK-5 interim) and `done` never uses the accent (LOOK-6).

## Depends on

None in wave 1 (tier 1a). Pre-wave seams: `KitTokens.hairlineWidth`, and the new tokens above.

Depended on by: KitNeedsYou, KitChecklist, KitTopBar, KitNav, KitTaskCard, KitWorkGraph, KitAgentStrip, KitToolRow (C25).

## Tests required

In `test/kit/kit_status_mark_test.dart`:

1. Each `KitMarkState` and `KitTaskState` exposes its default word as its semantics label (English and Arabic locales).
2. `label:` overrides the word. `showLabel: true` renders the word as visible text beside the mark.
3. `paused: true` with waiting or working shows the pause glyph and the word "Paused". With done or failed it throws an `AssertionError` (G37).
4. Under `MediaQuery(disableAnimations: true)`, and separately under `KitEffects` motion Off, `working` shows the still dot and `pump()` leaves no running ticker (G8).
5. Colour-role mapping: done paints `success`, failed paints `text1`, working paints `accent`, needsYou paints `attention` (a golden plus one finder-level check on the `Icon.color` against `ThemeRoles`).
6. `KitNeedsYou.mark()` and `KitTaskMark(state: needsYou)` produce the same widget configuration. This test lives in KitNeedsYou's unit and is listed here so it is not duplicated.
7. Existing callers compile unchanged: `KitStatusMark(state: …)` and `KitTaskMark(state: …)` with no new arguments. This is checked by `flutter analyze` on the whole tree.

## Galleries required

`test/goldens/kit/kit_status_mark_golden_test.dart`, at DPR 3 through `kitGalleryShot` (TEST-9, G23). Scenes use `debugDefaultTargetPlatformOverride = TargetPlatform.android`.

- **One sheet of all states in rows**, as each would sit in a `KitRow` with its supporting word: waiting, working (reduced motion, so a still frame), done, failed, paused-working, task needsYou, task stopped. Plus one row with `showLabel`.
- **Declared states × dark and light at 412×915:**
  - `kit_status_mark_all_{dark,light}.png`;
  - `kit_status_mark_labelled_{dark,light}.png`.
- **The default sheet × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Text 2.0 and Arabic RTL** at 412×915 and 1280×800 (`_text2_`, `_ar_`).
- **Names:** `kit_status_mark_<state>[_ar][_text2][_<W>x<H>]_<dark|light>.png` (TEST-20). The total stays under 60 PNGs.

## Non-goals

- No new enum values (see above).
- No change to callers outside the kit. The chat library's word switches move to `wordFor` in the chat chain.
- No progress display: the screen's bar says how far (DS §6).

## Open questions

None. The paused-as-flag decision follows from R11/KIT-43 with the evidence above; the coordinator should amend K2 §2.9 and §1.12 to match.
