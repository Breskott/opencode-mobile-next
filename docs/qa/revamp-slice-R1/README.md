# revamp-slice-R1: R1 KitTopBar flat and on the gutter; KitShellControls and KitViewer header fixes (2026-09-27)

## 1. Scope

- Unit: `slice-R1` (wave 3, kit-change, tier 1). Finish line: the top bar's title and the viewer's name, subtitle, primary action and body all start on the 16 dp gutter, the PC toolbar is flat, and the PC sidebar never cuts the server name. Non-goal: no change to KitTopBar's or KitViewer's public API beyond the added `KitViewer.folderOf`, and no screen (caller) edits.
- Files changed: `lib/ui/kit/kit_top_bar.dart`, `lib/ui/kit/kit_viewer.dart`, `test/kit/kit_top_bar_test.dart` (one finder), new `test/kit/kit_top_bar_r1_test.dart`, `test/kit/kit_viewer_r1_test.dart`, `test/kit/goldens/kit_top_bar_r1_*`, `test/kit/goldens/kit_viewer_r1_*`, regenerated gallery goldens under `test/goldens/kit/kit_top_bar_*` (10) and `test/goldens/kit/kit_viewer_*` (44).
- Pages (map ids): none of its own (kit change); every page with a `KitTopBar`, the PC sidebar (`KitShellControls` sidebar) and every `KitViewer` caller (files, file preview, PDF preview, licences, voice notices) get the change.
- Specs followed: leftover-units.json `slice-R1` acceptance; STANDARDS LAY-8, LOOK-21 (hairline through `KitDivider`), STATE-9, A11Y-4, LAY-10 (Tab order); kit-api KitTopBar.md, KitViewer.md; VL §6 (glass on the floating navigation layer only, per the unit's acceptance).
- Contract problems (PROC-20):
  - KitTopBar.md §"Look" and line 162 say the PC toolbar "is a `KitGlass` surface"; the unit's acceptance (dated later) makes it flat on ground with a hairline. Built to the acceptance. Proposed text for KitTopBar.md: "On PC the bar is the pane's toolbar: flat on `ground` with a hairline below; glass stays on the floating navigation layer."
  - KitTopBar.md "Open questions" and the `serverStatus` comment say the status word always shows, including "Connected" (STATE-9). The unit's acceptance drops the word for Connected in the 296 dp sidebar. Built to the acceptance; the word stays in the pill's semantics label, and the bar layout (phone, tablet) still shows it. Proposed text: "Sidebar layout: the name is never cut; the status is a second line; Connected is carried by the green dot on screen and by the label."
  - KitViewer.md: "`path` under it (… middle ellipsis …, full value in semantics)". Now the subtitle is the parent folder (`KitViewer.folderOf`); the full path stays in semantics. Proposed text: "`path` → its parent folder under the name ('docs/'), none for a root file; full value in semantics".
  - Task list says `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 adds `-<YYYY-MM-DD>`. Followed the task list, like the existing `docs/qa/revamp-chat-*` records.
- New kit parts (KIT-3): none. New public static: `KitViewer.folderOf(String path, String name)` (additive, R11).
- Map items (EVID-11): n/a (kit unit with no pages).
- States per page (STATE-20): KitShellControls sidebar connected, offline, reconnecting → `test/kit/kit_top_bar_r1_test.dart`; KitViewer header with and without primary, root file, loaded code, binary → `test/kit/kit_viewer_r1_test.dart`; every KitViewer state → regenerated gallery.
- Deferred states (STATE-21): none.

### Items moved or removed (owner rethink rule)

- KitViewer header: the file name no longer shows twice (the subtitle drops the name: "README.md / README.md" is gone; a root file has no subtitle).
- KitViewer primary action: moved out of the header row (beside More and Close on medium and up) to its own row under the name, start-aligned, on every window size.
- KitShellControls sidebar: "Connected" removed from the screen (the green dot says it; the label keeps it).
- KitTopBar PC toolbar: the glass panel with its 8 dp inset removed; the bar is flat, full width, with a hairline below.

## 2. Builds

- Branch `revamp/slice-R1`, base `643a5104`, code head `9413f93d`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_top_bar_r1_test.dart` | passes | 11 passed | PASS |
| 2 | `test/kit/kit_viewer_r1_test.dart` | passes | 14 passed | PASS |
| 3 | `test/kit/kit_top_bar_test.dart test/kit/kit_viewer_test.dart` (the part's tests, one finder changed) | pass | 38 passed | PASS |
| 4 | `--update-goldens test/goldens/kit/kit_top_bar_golden_test.dart` | 22 shots, only the changed states rewritten | 22 passed; 10 PNGs changed (brand, close, switcher, default 1280, shell sidebar 1280) | PASS |
| 5 | `--update-goldens test/goldens/kit/kit_viewer_golden_test.dart` | 44 shots | 44 passed; all header shots changed (folder subtitle, primary row, gutter) | PASS |
| 6 | `dart analyze` on the four changed/new Dart files | no issues | no issues | PASS |

Not run (owner decision 2026-09-27, speed): ratchet, design-standard, l10n and the full suite; the integrator runs them.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | R1 gutter | `test/kit/kit_top_bar_r1_test.dart` "no exit: the title starts at the gutter, like the first content row"; golden `test/kit/goldens/kit_top_bar_r1_gutter_{dark,light}.png` | run 1 |
  | R1 flat toolbar | `test/kit/kit_top_bar_r1_test.dart` "1280x800: the toolbar is flat on the ground with a hairline below, no glass"; `test/goldens/kit/kit_top_bar_default_1280x800_*.png` | run 1, 4 |
  | R1 sidebar name | `test/kit/kit_top_bar_r1_test.dart` "connected: the whole name shows…", "Offline: …", "Reconnecting: …"; golden `test/kit/goldens/kit_top_bar_r1_sidebar_296_1280x800_*.png` | run 1 |
  | R1 viewer gutter | `test/kit/kit_viewer_r1_test.dart` "the body is on the gutter, like the name", "\"Can't show this file\" is on the gutter too" | run 2 |
  | R1 primary row | `test/kit/kit_viewer_r1_test.dart` "phone: the primary has its own row…", "PC: …" | run 2 |
  | R1 folder subtitle | `test/kit/kit_viewer_r1_test.dart` group "KitViewer.folderOf", "a root file shows its name once", "the subtitle is the folder; the label and Copy path keep the full path" | run 2 |
  | LAY-10 Tab order | `test/kit/kit_viewer_test.dart` "Esc closes, Ctrl+F finds, Tab reaches primary, More, Close" | run 3 |

- Changed test expectations (TEST-19): `test/kit/kit_top_bar_test.dart` "sidebar: pill, project, search stacked…" found the pill by the text "Connected"; now by the server name, since the sidebar no longer shows "Connected" (unit acceptance).
- Goldens changed (each opened and looked at):
  - `kit_top_bar_brand_*`, `kit_top_bar_close_*`: title moves 4 dp to the gutter (16 dp).
  - `kit_top_bar_switcher_*`: switcher words at 16 dp (were 20 dp).
  - `kit_top_bar_default_1280x800_*`: glass panel gone; flat bar with a hairline below.
  - `kit_top_bar_shell_sidebar_1280x800_*`: "Laptop" alone beside the green dot; no "· Connected".
  - `kit_viewer_*` (all 44): subtitle is the folder, primary on its own row, code at 16 dp, binary and error states at 16 dp (were 32 dp).
  - Approved VL canvas renders (EVID-12): none exist for these states.
- Before and after (EVID-10): `before-/after-kit_top_bar_default_1280x800_dark.png`, `before-/after-kit_top_bar_shell_sidebar_1280x800_light.png`, `before-/after-kit_top_bar_switcher_light.png`, `before-/after-kit_viewer_code_dark.png`, `before-/after-kit_viewer_binary_1280x800_light.png` (before from base `643a5104`).
- Accessibility: the sidebar pill's label still reads "<server>, Connected, Switch server"; the viewer's subtitle carries the full path as its semantics label; Tab order in the viewer stays primary, More, Close (an `OrderedTraversalPolicy` group now that the primary is below the header); the switcher's tap target is unchanged (48 dp). Gallery accessibility checks (G5: labels, reading order, targets) pass for every shot. 200 % text: the existing overflow tests (`kit_viewer_test.dart` group 18, `kit_top_bar_test.dart` 200 % case) pass.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_top_bar_r1_test.dart test/kit/kit_viewer_r1_test.dart
$F test -j 1 test/kit/kit_top_bar_test.dart test/kit/kit_viewer_test.dart
$F test -j 1 test/goldens/kit/kit_top_bar_golden_test.dart
$F test -j 1 test/goldens/kit/kit_viewer_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Screens that embed these parts (home shell, files, file preview, licences, voice notices) and their goldens were not re-rendered; their goldens that show a top bar without an exit, a PC toolbar, the sidebar pill or a viewer header will differ by these changes and need regenerating by the integrator.
- The full suite, ratchet, design-standard and l10n gates were not run (owner decision 2026-09-27).
- Still open: the viewer shows the caller's primary ("Add to prompt") in the error state, where it cannot act on a file that did not load (see `after`/gallery `kit_viewer_error_*`); left as it was, not in this unit's acceptance.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R1` |
| Enabled | Yes (every caller of the parts) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `9413f93d` |
| Deployed | No | |
| Released | No | |
