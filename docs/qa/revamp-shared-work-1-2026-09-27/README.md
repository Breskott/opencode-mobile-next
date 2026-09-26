# revamp-shared-work-1: Revamp work, three shared widgets (2026-09-27)

## 1. Scope

- Unit: `shared-work-1` (wave 2a, tier 1 screen unit). Finish line: "Open a project", the AI Team's door on Work and the grace timer are built from kit parts only, and the folder browser has the states its map record asks for. Non-goal: cloning a repository, and listing recent projects first.
- Files changed: `lib/ui/widgets/folder_browser.dart`, `lib/ui/widgets/grace_timer.dart` (doc only: it draws nothing), `lib/ui/widgets/team_discover.dart`, `lib/l10n/app_en.arb` (3 new keys), `test/goldens/folder_browser_golden_test.dart` and its PNGs, `test/revamp/shared_work_1_test.dart`.
- Pages (map ids): `project-folder-browser`, `embedded-team-discover`.
- Specs followed: STANDARDS.md §1, §4 (KIT-1, KIT-17), §5, §9 (STATE-20), §15, §16; kit-v2 §9.1 allowlist; kit-api KitSheet, KitField, KitStateView, KitSince, KitIconButton.
- Contract problems (PROC-20): the unit brief says to write new copy to `app_ar.arb` with real Arabic (R04), but the owner decision of 2026-09-27 drops Arabic. The later owner decision was followed: the 3 new keys are in `app_en.arb` only.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - project-folder-browser, statesMissing "empty projects folder (first run) with a first step": done, `test/revamp/shared_work_1_test.dart` "an empty projects folder offers its first step"; golden `folder_browser_empty_*`.
  - project-folder-browser, statesMissing "slow Termux read (up to 15 s) without a word": done, "a slow read says so after 8 s, not before"; golden `folder_browser_slow_*`.
  - project-folder-browser, actionsMissing "Go up after a permission error": done, "a folder the app may not read is left by going up"; golden `folder_browser_error_*`.
  - project-folder-browser, actionsMissing "clone a repository": deferred, because it needs a gateway call (wave 3). No owner.
  - project-folder-browser, infoMissing "recent projects first": deferred, because it needs the order from the server. No owner.
  - project-folder-browser, couldBeAutomatic "open a marked project on tap": done, "a project opens with a tap; its chevron shows inside".
  - embedded-team-discover, statesMissing "no census render": looked at in `test/goldens/team_discover_golden_test.dart` (`team_discover_work*`, integrator-owned, rendered and then restored). See `before-after-embedded-team-discover.png`.
- States per page (STATE-20):
  - project-folder-browser covers these states: loaded (projects, inside), loading, slow (after 8 s), empty (first run), error (denied). Evidence: the `folder_browser_*` goldens and the unit tests. Disabled rows while a listing runs are covered by the code and are not shot separately.
  - embedded-team-discover covers these states: first-time and folded. Evidence: `team_discover_work*` goldens (integrator) and `test/team_discover_test.dart` (shared).
- Deferred states (STATE-21): none.
- Critic suggestion not taken: the map rationale suggests a single "New project…" tertiary action that opens a name dialog. The inline KitField stays because it keeps the name next to the folder it is made in and avoids a second modal. The empty projects folder's first step now focuses that field.

## 2. Builds

- Branch `revamp/shared-work-1`, base `c0f56f27`, code head `d4878833`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof belongs in the wave 2a checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/shared_work_1_test.dart` | passes | 5 passed | PASS |
| 2 | `test/goldens/folder_browser_golden_test.dart --update-goldens`, then the images inspected | renders all shots with no exceptions | 26 passed, and the images were inspected | PASS |
| 3 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart` (the baseline was restored afterwards) | the three files have no entry in any gate | no entries (G1, G2, G7, G15, G16, G17, G21 all 0) | PASS |
| 4 | `flutter analyze` on the 3 widgets and 2 test files | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-1 | `test/kit_ratchet_test.dart` (G16, write mode) | run 3 |
  | STATE-10 (8 s escalation) | `test/revamp/shared_work_1_test.dart` "a slow read says so after 8 s, not before" | run 1 |
  | STATE-20 | `test/goldens/folder_browser_golden_test.dart` | run 2 |

- Changed test expectations (TEST-19): `folder_browser_compact_ar_*` was removed because Arabic galleries are dropped (owner decision 2026-09-27). The wide shots (1280x800) and the `slow` scene were added.
- Goldens changed (each one was opened and inspected):
  - `folder_browser_{projects,inside,loading,empty,error}_{dark,light}.png`: now rendered with KitSheet, KitRow, KitField and KitStateView v2. Empty has the "Name your first project" step. Error has Try again, "Up one folder" and Details. There is no approved VL canvas render (EVID-12).
  - `folder_browser_slow_*` and every `*_wide_*` shot are new. There is no approved render.
- Before and after: `before-project-folder-browser-{projects,empty,error}.png` come from base `c0f56f27`. `after-project-folder-browser-{projects,empty,error,slow}.png` are new. `before-after-embedded-team-discover.png` shows base then after, first-time (dark) and folded (light). The only visible difference is that the "Not now" glyph uses the KitIconButton foreground.
- Accessibility: the chevron that shows a project's contents is a KitIconButton with the tooltip and label "Show the folders in <name>". The "Not now" button keeps its tooltip through KitIconButton. The path is read as "Current folder: <path>". The slow word sits under the skeleton, and "Enter a path" stays pinned while the read continues. 200 % text was not re-shot, because the compact Arabic 2.0 shot was dropped with Arabic.
- Privacy and security: n/a. No credentials, stored data, links or notifications changed.
- Migration: n/a. No stored format changed (`oc.teamDiscover.folded` is unchanged).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/shared_work_1_test.dart
$F test -j 1 test/goldens/folder_browser_golden_test.dart
$F analyze lib/ui/widgets/folder_browser.dart lib/ui/widgets/grace_timer.dart lib/ui/widgets/team_discover.dart
```

## 7. NOT proven

- Nothing was run on a device or emulator.
- `test/team_discover_test.dart` and `test/goldens/team_discover_golden_test.dart` were not run as checks (owner decision: do not re-run other suites). The `team_discover_work*` goldens will differ in the "Not now" glyph colour and need the integrator's regeneration.
- `test/design_standard_test.dart`, the l10n coverage tests and the full suite were not run.
- The real host opens the sheet from `ProjectFolderActions`, which is outside this write set. Only the test harness was used here.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-work-1` |
| Enabled | Yes | no flag |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `d4878833` |
| Deployed | No | |
| Released | No | |
