# revamp-kit-KitWorkLine: KitWorkLine (2026-09-27)

## 1. Scope

- Unit: `kit-KitWorkLine` (wave 1, tier 2, kit part). Finish line: `KitWorkLine` exists in `lib/ui/kit/chat/kit_work_line.dart` with the frozen API of `docs/ux-system/kit-api/KitWorkLine.md`, behaviour tests and galleries. Non-goal: migrating `message_view.dart` / `team_conversation_view.dart` (chat-1, chat-4) and exporting from `kit.dart` (integrator, R06).
- Files changed: `lib/ui/kit/chat/kit_work_line.dart` (new), `lib/l10n/app_en.arb` (+16 `kitWork*` keys), generated `lib/l10n/app_localizations*.dart`, `test/kit/kit_work_line_test.dart` (new), `test/goldens/kit/kit_work_line_golden_test.dart` (new) and 18 PNGs.
- Pages (map ids): `embedded-message-view#embedded-message-view-tool-group-toggle` (kitGap KitWorkLine); consumers migrate in chat-1.
- Specs followed: KitWorkLine.md (frozen); STANDARDS.md STATE-15, STATE-16, KIT-41, AUTO-15, LOOK-5 (B2 interim), MOT-5, PERF-2, TEST-9 (as reduced by the owner decision of 2026-09-27), TEST-20; visual language §5.
- Contract problems (PROC-20):
  1. **Stopped hides its word.** KitWorkLine.md table: stopped label = `summaryOf` + " · Stopped"; KitChip.summary is one line with an end ellipsis. At 412 dp with three segments the chip reads "Read 3 files · edited 1 file · ran 2 commands · Stopp…" (`after-kit_work_line-stopped.png`), so a stopped turn looks done by sight, against the spec's own "a stopped turn is never shown as done". Semantics and the truncation tooltip carry the full words. Proposed text: "stopped: chip label `Stopped · {summary}`" (word first, like the semantics label). Blocks: nothing; built as frozen.
  2. **Two-line chip from 1.3× text.** KitWorkLine.md Adaptive says the label wraps to two lines from 1.3× text; KitChip (`_ChipFrame`) is `maxLines: 1` always. Needs a KitChip change (kit-KitChip owner). The 2.0 text galleries show the ellipsis.
  3. **Chip semantics label.** KitChip.summary has no semantics-label parameter, so the per-state spoken labels ("Working, …", "Didn't finish, …") are given by a `Semantics(excludeSemantics: true)` around the chip. Proposed: an optional `semanticsLabel` on `KitChip.summary` (additive).
  4. **Manifest vs spec states.** `test/kit/kit_manifest_test.dart` knows only loading/empty/error/disabled/working/answered and infers "disabled" from the nullable `onExpansionChanged`; the frozen API's states are work states and the chip is never disabled. The doc comment says `States: none — …` and names the work states on the next lines; the manifest still reports `states · KitWorkLine: declares none but needs disabled`.
  5. **Arabic and galleries.** KitWorkLine.md asks for Arabic plural tests, `ar` ARB entries, Arabic RTL galleries and five extra sizes; the owner decision of 2026-09-27 (later, wins) dropped them. The manifest's `gallery` check still asks for `kitGallerySizes` and `_ar_` goldens (same as KitChip).
- New kit parts (KIT-3): `KitWorkLine` (planned, this unit), with `KitWorkState` and `KitWorkCounts`.
- Map items (EVID-11): tool-group-toggle "expanded work group repeats its own summary line" → done: `kit_work_line_test.dart` "opened: steps in order under stepsKey, summary not repeated (5)"; "waiting-for-you turn still shows 'Running tools'" → done: "waitingForYou: the words, no mark, no progress anywhere (AUTO-15)". Host adoption deferred to chat-1.
- States per page (STATE-20): n/a (kit part). Part states: running, waitingForYou, done, endedFailed, stopped × folded/expanded → goldens `kit_work_line_<state>` and tests group "states (2, 3)".
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitWorkLine`, base `dcf05c5e`, code head `81a5b764`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part, fixes nothing | n/a | PASS |
| 2 | `test/kit/kit_work_line_test.dart` | passes | 34 passed (`run-2.txt`) | PASS |
| 3 | `test/goldens/kit/kit_work_line_golden_test.dart` | passes, G5 checks in both themes | 18 passed | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart` | pass | 35 passed | PASS |
| 5 | `test/golden_harness_test.dart` | no new violation from this unit | one failure, `arabicFont: kit_page_route_golden_test.dart`, present on the base, not this unit's | PASS (for this unit) |
| 6 | `test/kit/kit_manifest_test.dart` | only integrator items and contract problem 4/5 for KitWorkLine | exported, docRow (integrator), states, gallery (above) | see §1 |
| 7 | `flutter analyze lib/ui/kit lib/l10n` + the two new test files | no new issues | one pre-existing info in `kit_since.dart` | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | AUTO-15 | `test/kit/kit_work_line_test.dart` "waitingForYou: the words, no mark, no progress anywhere" | `run-2.txt` |
  | STATE-15, LOOK-5 | "endedFailed: failed mark with its word, open on first build, no danger colour" | `run-2.txt` |
  | PERF-2 | "30 steps: 25 built, \"Show 5 earlier steps\" reveals the rest in place and focus moves to the first (6)" | `run-2.txt` |
  | MOT-5, G8x | group "motion (7, G8x)" | `run-2.txt` |
  | A11Y (button, expanded, 48 dp, not live) | group "semantics (8)" | `run-2.txt` |
  | G14 | "desktop: Tab reaches the chip, Enter toggles, the focus ring shows (9)" | `run-2.txt` |
  | G6 | group "200 % text at 320 dp (10, G6)", every state, LTR and RTL | `run-2.txt` |

- Changed test expectations (TEST-19): none.
- Goldens added (each opened and looked at): `kit_work_line_{running,waiting_for_you,done,done_expanded,ended_failed,stopped}_{dark,light}`, `kit_work_line_default_1280x800_{dark,light}`, `kit_work_line_default_text2[_1280x800]_{dark,light}` (18 PNGs). The failed state puts "Didn't finish" above the chip when both do not fit one line (a Wrap, so 2.0 text never overflows). No approved VL canvas render for this part (EVID-12: none).
- Before and after: no before render (new part). After: `after-kit_work_line-done_expanded.png`, `after-kit_work_line-stopped.png`.
- Accessibility: one button node per line with expanded state and the per-state label; leading mark excluded; not a live region; ≥ 48×48; the earlier-steps button moves focus to the first revealed step; 200 % text at 320 dp without overflow.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_work_line_test.dart test/goldens/kit/kit_work_line_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart
$F analyze lib/ui/kit lib/l10n test/kit/kit_work_line_test.dart test/goldens/kit/kit_work_line_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Not used by any screen yet (chat-1 migrates `_WorkGroup`, `_FoldLine`, `_FoldSteps`); not exported from `kit.dart`.
- Steps in the galleries are plain mono text standing in for KitToolRow (not merged).
- No Arabic copy or RTL gallery (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitWorkLine` |
| Enabled | No: not yet used by a screen | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `81a5b764` |
| Deployed | No | |
| Released | No | |
