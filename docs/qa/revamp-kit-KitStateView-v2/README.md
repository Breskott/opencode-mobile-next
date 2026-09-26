# revamp-kit-KitStateView-v2: KitStateView v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitStateView-v2` (wave 1, tier 3, kit-change). Finish line: `KitStateView` gains `.error` (kit error defaults: Copy details, and Report a problem or the network fix), `.missing` (whenMissing explains / offers-enable, cost line, prerequisite assert), the 8 s escalation through `KitSince` (`since`, `onSlow`), `detailValues` and `detailsKey`, and its details slot rebuilt on `KitDetailsFold`, with every current caller still compiling. Non-goal: no edits to `product_states.dart` (its Product* states become wrappers in wave 2a), no screen, no capability registry.
- Files changed: `lib/ui/kit/kit_state_view.dart`, `test/kit/kit_state_view_test.dart` (new), `test/goldens/kit/kit_state_view_golden_test.dart` (new) and its PNGs, this record.
- Pages (map ids): none changed directly. The part serves the 23 map elements listed under "Replaces" in `docs/ux-system/kit-api/KitStateView.md`; wave-2 units move them.
- Specs followed: `docs/ux-system/kit-api/KitStateView.md` (frozen API); STATE-1/2/3/5/12/13/20, LOOK-23, KIT-12, KIT-38, KIT-43, SEC-2, SEC-11.
- Contract problems (PROC-20):
  1. The "Tokens" section of `KitStateView.md` names a shared tone map, `KitTokens.toneFor` / `toneColor` (README D12), as a pre-wave token. It does not exist on `feat/phone-setup-v2`, and `lib/ui/kit/kit_icon.dart:11` notes the same gap. This part uses a private copy of the map that `KitNotice._tintFor` uses: neutral → text2, progress → accent, ok → success, attention and failure → text1. Proposed fix: add `KitTokens.toneColor(AppStatusTone)` in kit-hygiene and point both parts at it. Blocks nothing.
  2. The spec says `onSlow` holds at most 2 actions, "asserted". This cannot be an assert on the const constructor, because `List.length` is not a potentially constant expression. The assert runs when the state mounts or updates (debug builds). The behaviour matches the spec; this note tells the reviewer not to look for the assert in the initializer list.
  3. The acceptance lines say "Report this" and "Retry / Restart / Leave it running". The frozen spec supersedes both: the label is "Report a problem" (STATE-3), the retry word is "Try again" (COPY-7), and "Leave it running" is what happens when the person does nothing, not a button. The part is built to the frozen spec.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a: kit change; the map elements move in wave 2.
- States (STATE-20): loading, working, empty, error-network, error-other, missing-explains, missing-enable and slow each have a golden. Finished is covered by the haptic test. Disabled actions are KitActionBlock's, unchanged.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitStateView-v2`, base `024e97b0`, code head: see the branch log.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

Owner decision 2026-09-27 (speed): only this unit's own test files were run, and no other suite.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_state_view_test.dart` | passes | 13 passed | PASS |
| 2 | `test/goldens/kit/kit_state_view_golden_test.dart --update-goldens` (each image opened) | renders, G5 passes | 24 rendered | PASS |
| 3 | `flutter analyze` on the three changed Dart files | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31), all in `test/kit/kit_state_view_test.dart`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | P7.6: escalation, announced once | "7 s: unchanged; 8 s: …" |
  | onSlow ≤ 2 | "onSlow with three actions asserts" |
  | STATE-3: network fix | "network: Try again, Switch server, Copy details; no Report" |
  | P8.3, SEC-11: Report in one tap, redacted | "other with a handler: …" |
  | SEC-2: copy redacted, no SnackBar | "no Report; Copy details copies the redacted text, …" |
  | STATE-12, STATE-13, G37 | the three `.missing` tests |
  | KIT-43: default constructor unchanged | "the default constructor with tone failure adds no defaults" |
  | TEST-5: keys kept | "the details fold holds notes, values, text and child; …" |
  | MOT-11 | "progress to ok gives the finish haptic once, …" |
  | G8 | "reduced motion settles after one pump (G8)" |

- What changes for existing callers:
  - The icon sits in a `surface3` icon tile (44 dp on a page, 30 dp inline; LOOK-23) instead of a 14 % tonal circle.
  - Type comes from KitText roles.
  - The details toggle is now `KitDetailsFold`'s row: its label is "Details", and there is no "Hide details".
  - `kit-state-details-text` now keys only the fold's raw-text block. Notes and the child sit beside that block, not inside it.
  - Screen goldens that show a KitStateView will change. They were not regenerated (integrator, R07).
- Accessibility:
  - The state is one live region. The escalation changes it once, to "title\nStill waiting after 8 s".
  - The fold toggle is a 48 dp row with expanded semantics.
  - The error state has a 2.0 text gallery.
- Privacy and security:
  - Details are redacted with `KitReportHook.redact` before Copy details and before Report.
  - `error` is only classified, never shown.
  - Report appears only when a handler is set.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_state_view_test.dart test/goldens/kit/kit_state_view_golden_test.dart
$F analyze lib/ui/kit/kit_state_view.dart test/kit/kit_state_view_test.dart test/goldens/kit/kit_state_view_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Other suites were not run (owner decision). These tests look inside the old fold and may need updates:
  - `test/saved_server_connection_card_test.dart`
  - `test/kit_motion_app_test.dart`
  - `test/kit_motion_test.dart`
  - `test/team_design_standard_test.dart`
  - `test/chat_states_standard_test.dart`

  Every screen golden that shows a KitStateView may also need updating.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitStateView-v2` |
| Enabled | Yes: existing callers get the new look; `.error` and `.missing` are opt-in | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
