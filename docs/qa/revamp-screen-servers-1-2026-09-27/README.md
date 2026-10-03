# revamp-screen-servers-1: Revamp servers (1 file) (2026-09-27)

## 1. Scope

- Unit: `screen-servers-1` (wave 2b, screen-revamp). Finish line: `lib/ui/screens/servers_screen.dart` constructs only kit parts and §9.1 plumbing (G1, G2, G16, G17, G21 and G7 counts zero), each of its five pages is handled by its map proposal, and the look is VL. Non-goal: the wave-3 redesigns of Servers (grouped by where the agent runs, reachability before a tap) and of the server editor (slice-P3.9 steps); no gateway call, controller field or persistence was added.
- Files changed: `lib/ui/screens/servers_screen.dart`, `lib/l10n/app_en.arb` (6 new keys), `test/revamp/screen_servers_1_test.dart` (new), `test/revamp/goldens/servers_*.png` (14 new), `test/goldens/{add_server_*,first_run_connect_*,servers_welcome_*}.png` (16 regenerated), `test/first_run_auto_test_test.dart`, `test/server_codex_connect_flow_test.dart`, `test/server_profile_editor_test.dart` (handles only), this folder.
- Pages (map ids): `servers` (redesign), `servers-welcome` (keep), `servers-remove-server-sheet` (fix), `profile-editor` (redesign), `profile-editor-discard-sheet` (fix).
- Specs followed: STANDARDS.md MAP-1, KIT-1, KIT-2, KIT-8, KIT-11, KIT-20, KIT-25, KIT-26, KIT-28, KIT-32, KIT-34, KIT-36, KIT-38, KIT-40, LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-12, LAY-6, LAY-7, LAY-8, DATA-11, SEC-3; kit-v2 §9.1; visual-language §2, §4, §5.
- Contract problems (PROC-20):
  - The unit brief asks for `docs/qa/revamp-<unit id>/README.md`; EVID-1 asks for the dated folder. This record follows EVID-1.
  - The brief says "commit every new file (git add -A)"; PROC-13 says never commit `lib/l10n/app_localizations*.dart`. The generated files were regenerated locally and left out of the commits, as PROC-13 says.
  - The brief's Copy rule asks for `app_ar.arb`; the later owner decision (2026-09-27) drops Arabic. New keys are in `app_en.arb` only.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - servers · statesMissing "a saved server that is unreachable right now" → deferred: needs a background probe of every saved server (a gateway call), owner: no owner (the page's redesign has no slice).
  - servers · statesMissing "which server hosts the AI Team" → deferred, no owner (redesign).
  - servers · actionsMissing "test all servers", "reorder/pin a favourite", "undo remove" → deferred, no owner (redesign; undo would need a restorable deletion, DATA-11 keeps the confirm).
  - servers-welcome (keep) · statesMissing "no network on first run", "why 'On this phone' is absent" · actionsMissing "I already have a pairing code" → not in scope for `keep` (MAP-1: no behaviour change); no owner.
  - servers-remove-server-sheet · statesMissing "removing the active server: what shows next" → done: consequence row `remove-server-active-next` (shown when the server is in use; the absent case is tested in `screen_servers_1_test.dart` "the remove sheet says what goes and what the server keeps").
  - servers-remove-server-sheet · actionsMissing "undo: impossible; offer to send/export queued work first" → the counted loss is now a consequence row per kind (queued prompts, drafts); an export-first alternative is deferred: no export of queued prompts exists, no owner.
  - servers-remove-server-sheet · infoMissing "count of queued prompts/drafts lost" → done: `serversRemoveQueued` / `serversRemoveDrafts` consequence rows.
  - profile-editor (redesign) · statesMissing "connected: finished moment", "check >8 s with Cancel", "computer discovered on the network", "adding Paseo next to an existing OpenCode" · actionsMissing "cancel a running check", "one-tap retry of an expired code" → deferred to slice-P3.9.
  - profile-editor-discard-sheet · "Discard error-tonal, Keep editing the safe default" → done: `showKitConfirm(kind: discard)`; golden `servers_profile-editor-discard-sheet_confirm_{dark,light}`, test "closing with unsaved changes asks; Keep editing stays".
- States per page (STATE-20):
  - servers: loaded → golden `servers_servers_loaded_*` (412×915 and 1280×800); busy (the one loading bar) → unchanged `KitScreen.loading`; password-needed → notice kept (`password-reentry-banner`), covered by existing tests; connect/remove failure → inline `server-connect-failure` notice (the removal failure moved there from a snackbar); first-run → welcome golden.
  - servers-welcome: first-run → golden `servers_servers-welcome_first-run_*`; phone-setup-interrupted and no-termux-support → unchanged entries.
  - servers-remove-server-sheet: confirm → golden `servers_servers-remove-server-sheet_confirm_*`.
  - profile-editor: add-opencode → golden `servers_profile-editor_add-opencode_*`; edit with a stored password → golden `servers_profile-editor_edit_*`; add-codex, add-paseo, testing, paired, failed, first-run → `test/goldens/add_server_*`, `first_run_connect_*`.
  - profile-editor-discard-sheet: confirm → golden `servers_profile-editor-discard-sheet_confirm_*`.
- Deferred states (STATE-21): see the map items above (unreachable server, AI Team host, finished moment, slow check with Cancel, discovered computer).

## 2. Builds

- Branch `revamp/screen-servers-1`, base `4c871866`, code head `aea34722`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_servers_1_test.dart` | passes | 27 passed (`run-1.txt`) | PASS |
| 2 | `test/goldens/servers_motion_golden_test.dart --update-goldens`, then each image opened | renders without exception | 16 passed; images looked at | PASS |
| 3 | `test/kit_ratchet_test.dart` | `servers_screen.dart` has no count left | every G1/G16 entry for the file reported `-> 0`; the test fails on rows in other files already on the base (kit_choice_list, kit_task_card, quota_monitor_section, …) | PASS for this file |
| 4 | `dart analyze` on `servers_screen.dart` and the nine write-set tests | no issues | no issues | PASS |

Not run (owner decision 2026-09-27, speed): the eight existing write-set test files, design-standard, l10n, glossary and ledger tests, and `flutter analyze lib test`.

## 5. Evidence

- `run-1.txt`: output of step 1.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | SEC-3, KIT-40 | `test/revamp/screen_servers_1_test.dart` "a stored password is held, never shown, and kept on save" | `run-1.txt` |
  | KIT-40 | same file, "Replace takes a new password" | `run-1.txt` |
  | KIT-28 | same file, "a saved server's actions open on long-press, no ⋮ button" | `run-1.txt` |
  | DATA-11, KIT-11 | same file, "the remove sheet says what goes and what the server keeps" | `run-1.txt` |
  | MAP-1 (discard fix) | same file, "closing with unsaved changes asks; Keep editing stays" | `run-1.txt` |
  | LAY-4 | same file, "the loaded list lays out at <w> dp" (320–1600) | `run-1.txt` |

- Changed test expectations (TEST-19):
  - `first_run_auto_test_test.dart`, `server_codex_connect_flow_test.dart`, `server_profile_editor_test.dart`: `tap(find.byType(KitRowMenu))` → long-press the saved row (KIT-28); `byTooltip('Close server editor')` → `byKey('server-editor-close')` (KitTopBar owns the close label); `widgetWithText(AppBar, …)` → `widgetWithText(KitTopBar, …)`; the password field's `TextField` is found inside its `fieldKey`; the reveal tooltip is the kit's "Hide Server password". These edits were analysed, not run.
- Goldens changed (each opened and looked at):
  - `test/revamp/goldens/servers_servers_loaded_{dark,light}.png`, `_1280x800_{dark,light}.png` (new): saved servers in one surface1 panel with a section label, other ways in a second panel, the brand top bar; approved render `docs/design/visual-language-2026-09-26/Settings.png`: same panel, label and row anatomy; differences: the top bar is a brand bar (a root page), not a large title.
  - `test/revamp/goldens/servers_servers-welcome_first-run_*` (new): largeTitle and body roles, the three answers as one row panel.
  - `test/revamp/goldens/servers_servers-remove-server-sheet_confirm_*` (new) and `servers_profile-editor-discard-sheet_confirm_*` (new): the kit confirm; approved render `docs/design/visual-language-2026-09-26/Confirm.png`: same sheet anatomy (grabber, icon tile, start-aligned title, consequences panel, stacked buttons); differences: none beyond copy.
  - `test/revamp/goldens/servers_profile-editor_{add-opencode,edit}_*` (new): labelled kit fields, the saved password as "Saved · Replace", the backend as a kit choice list, the command in a kit code block.
  - `test/goldens/add_server_*`, `first_run_connect_*`, `servers_welcome_*` (regenerated): the same form in kit parts; the caption line under the drawing uses the secondary role.
- Before and after (EVID-10): `before-servers-loaded.png` (base `test/goldens/servers_list_dark.png`) / `after-servers-loaded.png`; `before-servers-welcome-first-run.png` / `after-servers-welcome-first-run.png`; `before-profile-editor-failed.png` / `after-profile-editor-failed.png`; `before-servers-remove-server-sheet-confirm.png` and `before-profile-editor-discard-sheet-confirm.png` (census PNGs) / the `after-` pairs.
- Accessibility: every control is a kit part with its own label (top bar actions carry their words as tooltips; fields have visible labels above them, KIT-20); the saved password reads "Server password, Saved, Replace"; the choice list is a radio group; section labels and the welcome question are headers; row menus are semantic custom actions (KIT-28). Text scale 2.0 was not rendered in this unit.
- Privacy and security: a stored password or token is never put back into a field (SEC-3): the editor holds it and the field shows "Saved · Replace"; a save keeps it; a pairing code's password is held the same way and never reaches a visible field; a pairing payload pasted into the password field is emptied at once and routed to pairing. No log, notice or copy path sees a secret.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_servers_1_test.dart
$F test -j 1 test/goldens/servers_motion_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The eight existing write-set test files were updated for the new handles but not run (owner decision 2026-09-27); expectations tied to the old widgets (`SelectableText`, `FilledButton`, `TextButton` counts in `add_server_flow_test.dart`; a prefilled password in `server_pairing_paste_test.dart` and `server_v2_connect_flow_test.dart`) may fail.
- Goldens at text 2.0, 800×1280 and in Arabic were not rendered (Arabic dropped by the owner; the brief limits galleries to 412×915 and 1280×800).
- `flutter analyze lib test` for the whole tree, and the design-standard, l10n, glossary and ledger tests, were not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-servers-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `aea34722` |
| Deployed | No | |
| Released | No | |
