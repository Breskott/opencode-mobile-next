# KitProgress v2 — API freeze (wave 0)

Unit: `kit-KitProgress-v2` (wave 1, tier 1a, kind `kit-change`). Spec: kit-v2.md §2.8, §4.9; design standard §4. Rules: STATE-4, STATE-6, STATE-7, LOOK-6, KIT-43, MOT-5.

## Purpose

The value that describes progress inside a `KitStateView` (and inside `KitChecklist` and `KitProgressRow`), plus its renderer `KitProgressView`. v2 adds stages and a time estimate, so a job that takes more than 30 s says where it is and how long is left, in words.

## Replaces

- **Map elements:** `project-folder-open-dialog#project-folder-open-dialog-progress` (1, kit-v2.json `changed[KitProgress]`).
- **Code reach, adopted in wave 2 and not by this unit:** the hand-built `LinearProgressIndicator` sites in G16 (41 in 29 files: `agent_account_screen.dart` 5, `usage_screen.dart` 2, `provider_quota_screen.dart` 2, `local_agent_onboarding.dart` 2, …) that show a job's progress. They are shared with `KitLoadingBar` (screen loading) and `KitProgressRow` (measured amounts).
- **Absorbs:** SetupProgressView's head bar and its "18 of 30 MB · about 1 min left" line. The unit is `kit-KitChecklist`; this part provides the value it renders.

## File

- `lib/ui/kit/kit_progress.dart` (`KitProgress`, `KitProgressView`; `KitLoadingBar` and `KitSkeletonRows` stay in the file unchanged)
- Tests: `test/kit/kit_progress_test.dart`
- Gallery: `test/goldens/kit/kit_progress_golden_test.dart`

## Public API

```dart
class KitProgress {
  // UNCHANGED
  const KitProgress.waiting({this.caption, this.key, this.tone, this.semanticsLabel});

  // CHANGED (additive): optional eta
  const KitProgress.known(
    double this.value, {
    this.caption,         // "29 of 30 MB"
    this.eta,             // NEW: appended as "· about 1 min left"
    this.key,
    this.tone,
    this.semanticsLabel,
  });

  /// NEW. A job made of stages: "Step 3 of 5 · Installing · about 2 min left".
  /// The bar is determinate at (step - 1 + (stepValue ?? 0)) / of.
  const KitProgress.staged({
    required int this.step,     // 1-based; 1 <= step <= of (asserted)
    required int this.of,       // >= 1
    required String this.label, // what this stage does, in words: "Installing"
    this.stepValue,             // 0..1 within the current stage, when measured
    this.eta,                   // time left for the whole job, when known
    this.caption,               // an extra measured line: "29 of 30 MB"
    this.key,
    this.tone,
    this.semanticsLabel,
  });

  final double? value;          // 0..1, or null while unknown (computed for staged)
  final String? caption;
  final Duration? eta;          // NEW
  final int? step;              // NEW, staged only
  final int? of;                // NEW, staged only
  final String? label;          // NEW, staged only
  final double? stepValue;      // NEW, staged only
  final Key? key;
  final AppStatusTone? tone;    // null = accent; neutral = stopped; failure = failed
  final String? semanticsLabel;

  bool get isStaged;            // NEW

  /// NEW. The one line under the bar, joined with " · ":
  /// staged: "Step 3 of 5 · Installing[ · caption][ · about 2 min left]";
  /// known: "caption[ · about 1 min left]".
  String line(BuildContext context);
}

class KitProgressView extends StatelessWidget {
  const KitProgressView({super.key, required this.progress}); // UNCHANGED
}
```

- **The eta words**, from kit ARB with ICU plurals (COPY-3):
  - `kitProgressEtaSeconds` "about {n} s left";
  - `kitProgressEtaMinutes` "about {n} min left";
  - `kitProgressEtaHours` "about {n} h left";
  - `kitProgressStep` "Step {step} of {of}".

  Rounding: under 60 s, round up to 10 s; under 1 h, whole minutes rounded up; beyond that, hours with one decimal dropped. An `eta` of zero or less is not shown.
- **`value` for `staged`** is derived. `known` keeps its given value.
- **Spec note:** the K2 §2.8 signature `staged({step, of, label, eta})` is kept exactly. `stepValue` and `caption` are optional additions, so SetupProgressView's "29 of 30 MB" line survives the move into KitChecklist.

## States

- **waiting:** an indeterminate bar with an optional caption. Its 8 s escalation is shown by the host (`KitStateView.since`, `KitChecklist.since`), never by the bar (K2 §2.8).
- **known:** a determinate bar and one line.
- **staged:** a determinate bar and the stage line.
- **stopped** (`tone: neutral`): a `text3` bar that holds its value. The host says "Stopped".
- **failed** (`tone: failure`): the bar holds its value in `text1` (LOOK-5 interim). The host's title says what failed.

Loading, empty and disabled do not apply: it is a value object and a renderer. KIT-12 doc comment: "States: waiting, known, staged, stopped, failed".

## Tokens

- **ThemeRoles:**
  - bar track `surface3`;
  - bar value `accent` (LOOK-6: loading and progress bars);
  - stopped `text3`;
  - failed `text1`;
  - the line in `text2`.
- **KitText:** `secondary` for the line. Numbers use tabular figures within that role (LOOK-18).
- **KitTokens:** `space2` (bar to line).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.progressBarHeight` = 4 and `KitTokens.loadingBarHeight` = 2, replacing the literals `minHeight: 4` and `height: 2` in `kit_progress.dart` (G21 inside the kit);
  - `KitTokens.progressBarRadius` = 2.

  Also the shared tone map `KitTokens.toneFor` / `toneColor` (README.md decision D12).

## Adaptive

- **compact / medium / expanded / large:** the bar fills its host's width. The host caps it: KitStateView at its state width, KitChecklist at `KitLayout.readingWidth`. At no size does the bar sit beside the line. The line always sits under the bar and wraps.
- **Pointer and keyboard:** not focusable. No hover.

## Accessibility

- The bar is one semantics node. Its label is `semanticsLabel` or the host's title. Its value is the line ("Step 3 of 5, Installing, about 2 minutes left"), and for `known` it is also given as a percentage ("62 percent").
- The line wraps at 200 % text and is never truncated. The bar height does not scale.
- It is not a live region. The host's live region announces a stage change once (A11Y-3). A caption that only changes its numbers ("29 of 30 MB") is not re-announced. The host announces only when `step` or `label` changes.

## RTL

- The bar fills from the start edge: the framework's `LinearProgressIndicator` follows `Directionality`. It is a progress direction, so it mirrors (LAY-8).
- Byte counts and sizes in `caption` are wrapped by the caller with `KitBidi.ltr` (COPY-30). The kit's own "Step 3 of 5" uses `intl` digits for the locale.

## Motion and haptics

- A determinate value animates to its new value on `KitMotion.standard` / `enter` (paint only). Under reduced motion it jumps.
- The indeterminate bar is the framework's. Under reduced motion it is shown as a static 30 % track segment at the start. This is new: today it keeps moving. G8 requires a still frame.
- **Haptics:** none. `KitHaptics.done` belongs to the host (KitStateView progress → ok; KitChecklist all done).

## Data safety and honest state

- **STATE-6:** a job longer than 30 s uses `staged`, or `known` with a caption. This is a reviewer rule; the part cannot know the duration.
- A `staged` step never exceeds `of`, and the value never goes backwards within a job unless the step goes back. This is asserted in debug, because a bar that shrinks reads as a lie.
- `eta` is shown only when the caller has one from a measurement or a component estimate, never an invented one. SetupProgressView's rule, "never an estimate dressed up as a measurement", moves here: an estimate before the start is `KitChecklist.estimate` (words), not `eta`.
- The line never says "Done". The host title does.

## Depends on

None (tier 1a). Pre-wave: the tokens above (`_new-tokens.md`).

Depended on by: KitProgressRow, KitChecklist (C25), and KitStateView (already uses `KitProgressView`).

## Tests required

In `test/kit/kit_progress_test.dart`:

1. `staged(step: 3, of: 5, label: 'Installing', eta: 2 min).line` is "Step 3 of 5 · Installing · about 2 min left". Arabic uses the locale's plural forms.
2. The staged value equals `(step - 1 + stepValue) / of`. With no `stepValue` it equals `(step - 1) / of`.
3. `step` greater than `of`, `step` less than 1, or `of` less than 1 throws an `AssertionError`.
4. `known(0.62, caption: '29 of 30 MB', eta: 50 s)` renders "29 of 30 MB · about 50 s left". An `eta` of 0 or negative is omitted.
5. The semantics value carries the full line, and "62 percent" for `known`.
6. Under reduced motion, an indeterminate bar settles after one `pump()` with no ticker (G8). A determinate change applies immediately.
7. Existing `KitProgress.waiting` and `KitProgress.known` calls compile and render as today, apart from the look.

## Galleries required

`test/goldens/kit/kit_progress_golden_test.dart` renders `KitProgressView` inside an inline `KitStateView`-sized host. DPR 3, Android platform.

- **Declared states × dark and light at 412×915:**
  - waiting (reduced motion frame);
  - known with caption and eta;
  - staged 3 of 5 with eta;
  - staged with a measured stepValue and caption;
  - stopped;
  - failed.
- **Default (staged)** × dark and light at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Text 2.0 and Arabic** (staged) at 412×915 and 1280×800.
- **Names:** `kit_progress_<state>…png`.

## Non-goals

- No change to `KitLoadingBar` or `KitSkeletonRows`, apart from moving their literals to the flagged tokens if the builder chooses to.
- No per-host placement rules: those are KitStateView, KitChecklist and KitProgressRow.
- No computing of estimates. The caller supplies `eta`.

## Open questions

None.
