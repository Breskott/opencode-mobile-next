# revamp-kit-KitUndo: Build KitUndo (2026-09-26)

## 1. Scope

- Unit: `kit-KitUndo` (wave 1, tier 1a leaf, kit-part). Finish line: `KitUndo`
  exists in `lib/ui/kit/kit_undo.dart`, exports `showKitUndo`, `KitUndo` and
  `KitClearance`/`KitBottomInset` (`lib/ui/kit/kit_bottom_inset.dart`), with
  its frozen API, its four declared states, its galleries and its behaviour
  tests (KitUndo.md, KitBottomInset.md). Non-goal: no call site migrated off
  the framework `SnackBar`; no screen changed; `kit.dart`'s export row and
  doc table are the integrator's (R06).
- Files changed: `lib/ui/kit/kit_undo.dart`, `lib/ui/kit/kit_bottom_inset.dart`
  (new), `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`,
  `test/kit/kit_undo_test.dart`, `test/goldens/kit/kit_undo_golden_test.dart`
  and its 26 PNGs, this QA record. The review-fix round (2026-09-27) added
  one copy key, `kitUndoWorking` ("Undoing" / "جارٍ التراجع"), spoken on the
  action while an undo runs. (`lib/l10n/app_localizations*.dart` were
  regenerated locally to run the tests but are not committed — PROC-13, units
  never commit them.)
- Pages (map ids): none — KitUndo.md and KitBottomInset.md both say "No map
  element" (K2 §2.12; the seam K2 asks for). This is a kit-part unit with no
  `pages`.
- Specs followed: STANDARDS.md KIT-11, KIT-34, DATA-11, MOT-1, MOT-11,
  A11Y-3, A11Y-8, LAY-6, LAY-8, LAY-9, LAY-10, LOOK-20, LOOK-27, COPY-3,
  COPY-25, COPY-30; kit-v2 §1.17, §2.12, §4.1, §4.8, §8.2, §8.4;
  docs/ux-system/kit-api/KitUndo.md and KitBottomInset.md (frozen, wave 0,
  2026-09-26).
- Contract problems (PROC-20):
  - KIT-12's declared-state vocabulary (`{loading, empty, error, disabled,
    working, answered}`) has no word for KitUndo.md's own "default" state or
    its accessible-navigation variant. Followed KitUndo.md's own four states
    verbatim (default, working, error, the accessible variant) since it is
    the frozen spec for this exact part; the doc comment on `KitUndo` in
    `kit_undo.dart` records the mismatch. Proposed text: KIT-12's vocabulary
    gains "default" (the base state every part has, whether or not it is
    named) so a part's doc comment can cite it without inventing a fifth
    word.
  - KitUndo.md's Galleries section asks for the bar "shown over a KitNav
    dock scene" and lists 915×412 among the sizes. KitNav has not merged
    (C25: this unit is a leaf with no unit dependency), and `kitGallerySizes`
    (`test/goldens/kit/kit_gallery.dart`, shared, PROC-13) does not carry
    915×412. Stood in for both: a plain bottom bar publishes the same
    clearance a real dock will through `KitBottomInset`, and 915×412 is
    rendered as one extra shot outside the shared size list. Recorded under
    NOT proven below.
  - The Undo/Try-again action's `working` state reuses `KitButton`'s shared
    spinner (`_Spinner`, `kit_buttons.dart`, not this unit's file), a bare
    `CircularProgressIndicator` that keeps a ticker running under
    `disableAnimations`/Effects Off. This is a pre-existing gap already
    baselined for `KitButton`, `KitConfirmSheet`, `KitActionBlock` and
    `KitStateView` (`test/kit_motion_baseline.json`), but G8x's own rule is
    that a part added after the gate is never added to that baseline, so
    this unit does not register a "working" G8x sample and instead records
    the gap here for the coordinator to fix at the shared `_Spinner`.
- New kit parts (KIT-3): `KitUndo` and `KitBottomInset`/`KitClearance` — both
  named by the unit's own contract (`work-units.json`), not discovered ad
  hoc.
- Map items (EVID-11): n/a — no `pages`, no map record.
- States per page (STATE-20): n/a — no `pages`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitUndo`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2` at the time this worktree was created; the branch
  has since moved on with other units' work, not rebased onto here), code
  head `c1f22864` (`c1f2286461121abb4d031c1044b47d9fe5105922`) for the
  first build; the review-fix round is the commit after `b453b60b` on the
  same branch (`git log -1 revamp/kit-KitUndo`).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at
the wave checkpoint (R19/R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_undo_test.dart` (KitUndo's 14 behaviour contracts plus the review-fix tests 9b, 11b, 11c, 12c, 12d, 13c and the stacking group; KitBottomInset's 6; the `kitMotionStillTests` registration) | passes | 43 passed | PASS |
| 2 | `test/goldens/kit/kit_undo_golden_test.dart` (the 26 required images plus 27 non-image G5/G6 runs: working, error, accessible × the other §8.4 sizes, 915×412, text 2.0, Arabic) | passes, goldens looked at | 53 passed | PASS |
| 3 | `test/kit_ratchet_test.dart` + `test/l10n_coverage_test.dart` | passes | 34 passed | PASS |
| 4 | `test/kit_motion_test.dart` (G8x manifest + samples) + `test/design_standard_test.dart` | passes | 194 passed | PASS |
| 7 | `flutter analyze lib test` | no errors, no new issues | no issues found | PASS |
| 8 | `dart format --language-version=3.10` on every changed Dart file | no diff | no diff | PASS |

Fixes made during the build, each with a failing-first check by reverting the
specific line and rerunning the named test (TEST-2; not saved as separate
`.txt` files — the unit's own iterative test output above already shows each
fix's before/after; see "How to reproduce" to redo any of them):

- `kit_undo.dart`'s `_stacks` helper was named `chrome`; G21's LOOK-32
  metal/chrome ban flagged it. Renamed to `reserved`, and its bare `48`
  (Dismiss's width) replaced with `KitTokens.minTarget`. Reverting the
  rename reproduces the `test/kit_ratchet_test.dart` "G21 look and motion"
  failure.
- `_KitUndoHost._handleKey`'s "no text field focused" check compared
  `primaryFocus.context.widget` to `EditableText`, but `EditableText` wraps
  its focus node in an inner `Focus` widget (`debugLabel: 'EditableText'`),
  so the check never matched. Changed to
  `context.findAncestorWidgetOfExactType<EditableText>()`. Reverting this
  reproduces `test/kit/kit_undo_test.dart`'s Ctrl+Z tests failing to block
  while a text field is focused.
- The Ctrl+Z `HardwareKeyboard` handler was added once behind a boolean
  guard; `HardwareKeyboard.clearState()` (called by the test harness between
  every test, for hermeticity — also true of any future host lifecycle
  event that clears handlers) silently dropped it after the first test that
  showed a bar, so a later test's Ctrl+Z never reached the handler. Now
  re-armed (remove then add) on every `show()`. Reverting this reproduces
  `test/kit/kit_undo_test.dart` "12b" failing only when run as part of the
  full file, not in isolation — the original symptom this fix was written
  for.
- `showKitUndo` started the 8 s timer unconditionally; accessible navigation
  must never time out (item 6). Now gated on
  `MediaQuery.accessibleNavigationOf(context)` read at show time. Reverting
  this reproduces test "6" committing at 60 s instead of staying open.
- `attemptUndo`'s `onUndoFailed` branch disposed the pending request right
  after handing off, but the caller's `tryAgain` closure can run later on
  that same object; also left `working` at `true` after the failed attempt,
  so a second `attemptUndo` (via `tryAgain`) returned immediately without
  re-running `onUndo`. Now resets `working` to `false` and does not dispose.
  Reverting this reproduces test "7"'s `tryAgain` never re-running `onUndo`.
- The Arabic galleries showed tofu: the plain `AppTheme.dark()`/`.light()`
  theme has no Arabic-capable font declared. Wrapped with
  `AppTheme.forLocale`, plus a local copy of `kit_gallery.dart`'s own
  button-text-style fallback (a button's `textStyle` is explicit on the app
  theme and bypasses `forLocale`'s type-role fix). Reverting this reproduces
  tofu in `kit_undo_default_ar_*.png`.

Review fixes (2026-09-27, seven findings). Findings 1 and 2 were checked
failing-first (fix reverted, named test rerun, failure seen, fix restored);
the others are covered by the new tests named below:

1. DATA-11 (Undo taken): `_commit` now treats a request whose async
   `onUndo` is in flight as Undo taken — any commit trigger (a new bar, the
   owning route popping, `AppLifecycleState.paused`, `commitPending()`,
   Dismiss) only closes the bar and never runs `onCommit`; `attemptUndo`
   keeps the outcome. `_PendingUndo.dispose` is idempotent (`_disposed`) and
   `setWorking`/`setError` do nothing after it, so no second dispose and no
   notify on a disposed notifier. If that closed undo then fails, the
   failure form takes the slot back (never silent, item 4), committing the
   newer bar first exactly as a new bar would (item 1). Tests "9b" (six
   cases). Reverting the `pending.working` guard fails all six.
2. Stacking measured in the theme's face: `_stacks` measures the message
   with `KitText.styleOf(context, body)` and the action with the theme's
   `textButtonTheme` text style (the face `KitButton` renders with), plus
   the working spinner's room and the 48 dp minimum. At 412×915 text 1.0
   the default bar is now one row (the old goldens had "Undo" on a second
   line). Test "stacking … a short message and Undo share one row at 412
   wide" (real fonts loaded); reverting to `KitText.styleFor` fails it.
   14 PNGs re-rendered and looked at: `default`, `default_ar`,
   `default_360x800`, `default_ar_1280x800`, `default_text2_1280x800`,
   `working`, `accessible`, dark and light. `error` still stacks at 412 wide
   (the failure message, Try again and Dismiss do not fit) — correct.
3. Motion: one `CurvedAnimation` made in `initState` and disposed; opacity
   reads its value (`KitMotion.enter` in, `KitMotion.exit` out); the
   `space2` slide applies only while the controller runs forward, so the
   exit is a fade. Test "13c".
4. A11Y-3: the live-region node's own label is the message (the visible
   text is excluded so it is not read twice), so the platform bridges
   announce the failure form when the label changes. Test "11b" records the
   label sequence: the message, then once the failure text.
5. Galleries: G5/G6 (no images) for working, error and accessible at every
   other size (test 2 above).
6. Ctrl+Z: Shift or Alt with it is not Undo. It is bound as a
   `FocusManager` late key handler, so a focused widget that handles Ctrl+Z
   itself (a terminal) keeps it; a `HardwareKeyboard` handler covers only
   the no-primary-focus case. Text fields keep it as before. Tests "12c",
   "12d".
7. While working the action's node is not enabled, has no tap action and
   carries the value "Undoing" (`kitUndoWorking`). Test "11c".

## 5. Evidence

- `run-unit-tests.txt`: `test/kit/kit_undo_test.dart` +
  `test/goldens/kit/kit_undo_golden_test.dart`, 56 passed.
- `run-shared-gates.txt`: the four shared gates above, 228 passed.
- `run-analyze.txt`: `flutter analyze lib test`, no issues.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-11 | `test/kit/kit_undo_test.dart` "1. shows the message and Undo" | `run-unit-tests.txt` |
  | KIT-34 | `test/kit/kit_undo_test.dart` "4. one at a time" | `run-unit-tests.txt` |
  | DATA-11 | `test/kit/kit_undo_test.dart` "5a/5b/5c", "7", "8", "9b" group | `run-unit-tests.txt` |
  | MOT-1, MOT-2 | `test/kit/kit_undo_test.dart` "13a"/"13b"/"13c" | `run-unit-tests.txt` |
  | MOT-11 | `test/kit/kit_undo_test.dart` "14. no HapticFeedback" | `run-unit-tests.txt` |
  | A11Y-3 | `test/kit/kit_undo_test.dart` "11", "11b", "11c" | `run-unit-tests.txt` |
  | A11Y-8 | `test/kit/kit_undo_test.dart` "stacking (A11Y-8) in the theme's own face" group | `run-unit-tests.txt` |
  | LAY-8, LAY-9 | `test/kit/kit_undo_test.dart` "10. placement" group | `run-unit-tests.txt` |
  | LAY-10 | `test/kit/kit_undo_test.dart` "12a"/"12b"/"12c"/"12d" | `run-unit-tests.txt` |
  | KitBottomInset invariants | `test/kit/kit_undo_test.dart` `KitBottomInset` group (6 tests) | `run-unit-tests.txt` |
  | TEST-9, G23, TEST-20, G5, G6 | `test/goldens/kit/kit_undo_golden_test.dart` (images + "G5/G6 only" runs) | `run-unit-tests.txt`, the 26 PNGs |
  | KIT-9, LOOK-32 (G21) | `test/kit_ratchet_test.dart` | `run-shared-gates.txt` |
  | G8x manifest | `test/kit_motion_test.dart` | `run-shared-gates.txt` |

- Changed test expectations (TEST-19): none — the review-fix round only
  added tests; no existing expectation was edited.
- Goldens changed (each opened and looked at before committing): the
  review-fix round re-rendered 14 (finding 2 above); all 26 are
  new (`test/goldens/kit/kit_undo_*.png`), listed in the commit. No approved
  VL canvas render exists for KitUndo yet, so EVID-12 is "no approved
  render" for every one of them.
- Before and after (EVID-10): n/a — no existing page or golden this replaces
  (KitUndo has no map element; the framework `SnackBar` call sites it will
  eventually replace are unmigrated wave-2 work, not this unit's).
- Accessibility: labels — Undo/Try again carry a composed semantic label
  ("{action}, {message}"); Dismiss carries `kitSheetDismiss`. Targets — the
  action and Dismiss are both ≥48×48 dp (asserted in test "11"; the tertiary
  button's `KitTokens.minTarget` square, `KitIconButton`'s own 48 dp
  constraint). 200% text: the message/action stack instead of overflowing
  (`_stacks`, asserted implicitly by every gallery rendering without
  exception at `text2`). Arabic: RTL placement and the button's own label
  verified in the `_ar_` galleries (bar hugs the end/right, action at the
  visual end).
- Privacy and security: n/a — no credentials, stored data, external links or
  notifications are touched. `message`/`undoLabel` are caller-supplied
  strings shown as given (COPY-2 territory belongs to the call site, not
  this leaf part).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_undo_test.dart test/goldens/kit/kit_undo_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/kit_motion_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F analyze lib test
```

## 7. NOT proven

- The failure-form announcement is proven through the semantics tree (the
  live-region label changes once); no TalkBack/VoiceOver pass heard it.
- A failed undo whose bar was closed meanwhile comes back and commits
  whatever newer bar held the slot. KitUndo.md does not name this case;
  this follows items 1 and 4 together. If the owning route had popped, the
  failure form now shows over whatever route is on top.
- The working spinner widens the action by its room, so a bar that only just
  fitted on one row can move to two rows when Undo is tapped.

- Not run on a device or emulator (R19/R20: coordinator work at the wave
  checkpoint).
- "Shown over a KitNav dock scene" is stood in for by a plain bottom bar
  publishing the same `KitBottomInset` clearance a real dock will; the
  gallery should be re-rendered against the real `KitNav` once kit-KitNav
  merges.
- Ctrl+Z has no visible shortcut hint (`KitAction.shortcut`): KitAction v2
  had not merged when this unit was built (checked: no `shortcut` field on
  `KitAction`/`kit_buttons.dart` at this branch's base), so the binding
  works but is undiscoverable without a keyboard reference. Per KitUndo.md
  item 7, kit-hygiene adds the hint once KitAction v2 lands.
- The "working" state's spinner is not covered by the G8x reduced-motion
  gate for this unit (see the Contract problems entry above); its own
  `kit_undo_test.dart` behaviour tests ("9", "13a", "13b") do exercise
  working/reduced-motion but never through the ticking `CircularProgressIndicator`
  path together (test 9 uses real-time `await tester.pump()` without
  asserting stillness; 13a/13b never tap Undo).
- No live-server or on-device Arabic/RTL screen-reader pass — the `_ar_`
  goldens and the semantics assertions in test "11" are the only Arabic/a11y
  evidence.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitUndo` |
| Enabled | Yes — `showKitUndo`/`KitBottomInset` are usable now; no call site wired yet (wave-2 work, per KitUndo.md "Replaces") | `lib/ui/kit/kit_undo.dart`, `lib/ui/kit/kit_bottom_inset.dart` |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `c1f22864` |
| Deployed | No | |
| Released | No | |
