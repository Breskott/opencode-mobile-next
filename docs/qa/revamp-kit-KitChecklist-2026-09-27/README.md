# revamp-kit-KitChecklist: KitChecklist and the SetupProgressView adapter (2026-09-27)

## 1. Scope

- Unit: `kit-KitChecklist` (wave 1, tier 4, kit-part). Finish line: `KitChecklist`/`KitStep` exist as frozen in `docs/ux-system/kit-api/KitChecklist.md`, and `SetupProgressView` is a thin adapter over `KitStateView` + `KitChecklist` that keeps its constructor, statics and keys. Non-goal: no screen adoption beyond the adapter, no engine logic, no `kit.dart` export (integrator, R06).
- Files changed: `lib/ui/kit/kit_checklist.dart` (new), `lib/ui/widgets/setup_progress_view.dart` (adapter), `lib/l10n/app_en.arb` (+4 keys) and generated l10n output, `test/kit/kit_checklist_test.dart` (new), `test/goldens/kit/kit_checklist_golden_test.dart` (new) with 24 PNGs, `test/phone_setup_progress_screen_test.dart` (look-level finders, TEST-19).
- Pages (map ids): `phone-setup-progress` (adapter). The other 15 pages in the spec's "Replaces" list adopt the part in wave 2/3.
- Specs followed: KitChecklist.md (API, states, tokens, adaptive, a11y, motion, data safety, tests); kit-v2 §1.12, §2.8, §4.9, §8.2, §9.1; STANDARDS.md §1, §15, §16.
- Contract problems (PROC-20):
  - KitChecklist.md "Accessibility" says the live region is "the `progress` line when present, or else a visually hidden summary node". `KitProgressView` is not a live region, and its line carries the eta, which changes on byte ticks, so it would be announced on every tick. The part always owns the hidden summary (current step, title, state word, needs-you, slow) as the one live region. It never duplicates an announcement. Proposed text: "the job header is a visually hidden summary the checklist owns". This does not block the unit.
  - KitChecklist.md "RTL" asks the adapter to wrap byte counts in `KitBidi.ltr`. The owner decision of 2026-09-27 dropped Arabic and RTL review, and the wrapping changes the existing exact-text assertions. Byte strings stay unwrapped (as before this unit). This is deferred to the Arabic pass (no owner).
  - The unit prompt names the record folder `docs/qa/revamp-kit-KitChecklist/`, but EVID-1 (gate G32) requires the date suffix. This record follows EVID-1.
  - The branch is `revamp/kit-KitChecklist-r2`, because `revamp/kit-KitChecklist` already existed at an older base with no commits. It is checked out in another worktree (`wf_1d49ead2-79b-3`, a previous run with uncommitted files), so it could not be switched to or moved.
- New kit parts (KIT-3): `KitChecklist`, `KitStep` (planned in R13; this unit's own part).
- Map items (EVID-11), `phone-setup-progress`:
  - actionsMissing "person-step actions inside the checklist": done (part), `KitStep.personAction`, test 2, golden `kit_checklist_person_step_*`. The adapter has no person steps yet (the engine reports none), so it is deferred to slice-P1.2 / the Termux screen adoption.
  - actionsMissing "report a problem with the log": deferred (no owner in this unit; `KitStateView.error` offers Report).
  - statesMissing "waiting on the person (install Termux, allow Termux, sign in to Claude)": done in the part (test 2, golden). Adapter wiring is deferred to the Termux/Claude Code adoption units.
  - statesMissing "no internet named, Continue when back online": done, `test/kit/kit_checklist_test.dart` "a network failure asks to reconnect" and `test/phone_setup_progress_screen_test.dart` "network errors ask to reconnect".
  - statesMissing "low storage": deferred (engine pre-flight, AUTO-19; not the kit's).
  - infoMissing "failure as a body sentence": done (`setup-progress-job-error` body when no row failed), test 9.
- States per page (STATE-20): before-start, working, person-step, slow, failed, paused, done, compact. Each is a golden (`kit_checklist_<state>_{dark,light}`) and has a behaviour test (1–11). The stopped state is shown by `phone_setup_progress_screen_test` "interrupted and cancelled jobs offer Continue setup".
- Deferred states (STATE-21): none for the part.

## 2. Builds

- Branch `revamp/kit-KitChecklist-r2`, base `8ce9389b11a95d09e6c4e50df34d881cf5a8a3f2` (feat/phone-setup-v2), code head `231e31ec`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_checklist_test.dart` | passes | 15 passed | PASS |
| 2 | `test/phone_setup_progress_screen_test.dart` (5 look-level expectations updated, below) | passes | 25 passed | PASS |
| 3 | `test/goldens/kit/kit_checklist_golden_test.dart --update-goldens` (dark, then light), each image opened | 24 images, G5 accessibility checks pass | 24 passed | PASS |
| 4 | `dart analyze` on the changed files and `lib/ui/screens/phone_setup/` | no issues | No issues found | PASS |
| 5 | Done haptic fix checked against a failing run: `_wasDone` first initialised lazily | test 5 "fires once on the turn to done" fails | failed (`[]`), then passed after moving it to `initState` | PASS |

The owner decision of 2026-09-27 (speed) says to run only this unit's files. The ratchet, design-standard and l10n suites were not run. Their counts for `setup_progress_view.dart` drop, because the file now constructs only `KeyedSubtree` and kit parts, and the integrator regenerates the baselines (R05).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | A11Y-3 | `test/kit/kit_checklist_test.dart` "1. each row reads", "4. a working step escalates at 8 s, once" | run 1 |
  | STATE-5 | same file, "4. a working step escalates at 8 s, once" | run 1 |
  | STATE-11 | golden `kit_checklist_done_*` ("Already installed") | run 3 |
  | KIT-37 | "6. estimate and cost show before the start only" | run 1 |
  | MOT-6 / G8 | "10. reduced motion settles after one pump" | run 1 |
  | MOT-11 | "5. done haptic" (three cases) | run 1 |
  | TEST-5 | "9. SetupProgressView adapter keeps its keys and words" | run 1 |
  | G14x | "11. Tab visits person, retry, resume, stop, then Details" | run 1 |

- Changed test expectations (TEST-19), `test/phone_setup_progress_screen_test.dart`:
  - The failed bar colour went from `statusColor(failure)` to `roles.text1`: KitProgress's failure tone. The failed row states the failure in words.
  - "Show details": `TerminalView` became the `KitLogPanel` keyed `setup-progress-log`. The fold's toggle keeps the word "Details", so the fold-back taps `setup-progress-details` (was "Hide details").
  - "RTL puts the detail on the leading-left side" and "LTR puts the detail on the right" became one test in two directions: the detail is the supporting line under the title, aligned to the start (KitChecklist rows).
  - "the running row is a live region labelled by its stage" became "each row is one node; the job summary is the live region". The label is now `Step 4 of 5, Node.js, Working, Downloading · 18 of 30 MB`, the row is not a live region, and `kit-checklist-summary` is (A11Y-3).
- Goldens (new, each opened and looked at): `test/goldens/kit/kit_checklist_{before_start,working,person_step,slow,failed,paused,done,compact}_{dark,light}.png`, `kit_checklist_working_1280x800_{dark,light}.png`, `kit_checklist_{before_start,failed,done}_text2_{dark,light}.png`. There is no approved VL canvas render for this part (EVID-12: n/a).
- Before and after (EVID-10): `before-phone-setup-progress-running.png` and `before-phone-setup-progress-failed.png` (census, base), and `after-kit-checklist-working.png`, `after-kit-checklist-failed.png`, `after-kit-checklist-person-step.png` (the new goldens). The adapter keeps the head (scene, title, body, bar). Rows now carry their detail under the title instead of trailing. Cancel, Continue and Details follow the list.
- Accessibility:
  - Each row is one node: "Step n of N, title, state[, supporting][, needs you, action]". The mark is excluded.
  - The hidden summary is the one live region. Byte ticks do not change it.
  - Person actions, Try again, resume and stop are KitButtons with 48 dp targets.
  - The compact line is one KitTappable: Enter unfolds it, and its tooltip says "Show steps" or "Hide steps".
  - At 200 % text, row buttons move under the words (golden `failed_text2`).
- Privacy and security: the log goes through `KitLogPanel`, which is redacted (SEC-4) and folded by default. No credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_checklist_test.dart test/phone_setup_progress_screen_test.dart
$F test -j 1 test/goldens/kit/kit_checklist_golden_test.dart --plain-name dark
$F test -j 1 test/goldens/kit/kit_checklist_golden_test.dart --plain-name light
$F analyze lib/ui/kit/kit_checklist.dart lib/ui/widgets/setup_progress_view.dart test/kit/kit_checklist_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite, the ratchet, the design-standard and the l10n coverage tests were not run (owner speed decision). Baselines need an integrator regeneration.
- No Arabic, RTL or 360/800/915x412/1600 galleries (owner decision 2026-09-27).
- The adapter shows no person steps or `onSlow` ways out yet: the engine reports neither.
- The adapter's pinned head (the title and bar stayed while the steps scrolled on tall windows) is gone. The whole state scrolls together (LAY-3, the spec's "Short windows").

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitChecklist-r2` |
| Enabled | Yes (phone setup progress via the adapter) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | `231e31ec` + this record |
| Deployed | No | |
| Released | No | |
