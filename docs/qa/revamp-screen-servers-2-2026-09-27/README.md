# revamp-screen-servers-2: Revamp servers (5 files) (2026-09-27)

## 1. Scope

- Unit: `screen-servers-2` (wave 2b, `screen-revamp`). Finish line: every file in the write set has a G16 count of zero, each page is handled by its map proposal (MAP-1) with the wave-2 missing states and actions, and the look is VL. Non-goal: behaviour planned for wave 3; no gateway call, controller field or persistence is added.
- Files changed:
  - `lib/ui/screens/guide_screen.dart`, `lib/ui/screens/host_management_screen.dart`, `lib/ui/screens/pairing_scanner_screen.dart`, `lib/ui/screens/profile_monitor_screen.dart`, `lib/ui/screens/settings/server_settings_screen.dart` (write set);
  - `lib/ui/screens/settings_screen.dart`: one line, the `package:flutter/services.dart` import removed. The part file was the library's last `Clipboard` user, so the import became an `unnecessary_import` info in that file (PROC-2). This is the only line outside the write set.
  - `lib/l10n/app_en.arb` (+19 keys, prefixed `guide*`, `pairingScanner*`, `profileMonitor*`, `serverSettings*`; owner 2026-09-27: English only) and the generated `app_localizations*.dart`;
  - `test/revamp/screen_servers_2_test.dart`, `test/revamp/screen_servers_2_golden_test.dart`, 36 PNGs under `test/revamp/goldens/servers_*` (2.1 MB).
- Pages (map ids): embedded-profile-monitor-inbox, guide, host-management, pairing-scanner, profile-monitor, profile-monitor-switch-server-dialog, server-settings, server-settings-restart-dialog, server-settings-upgrade-sheet.
- Specs followed: STANDARDS.md §1, §4 (KIT-1, KIT-23, KIT-34), §5 (LOOK-1, LOOK-5, LOOK-12, LOOK-24, LOOK-33), §6 (LAY-8), §9 (STATE-5, STATE-8, STATE-12, STATE-20), §13 (SEC-1), §15, §16; kit-v2 §4.1, §4.3, §4.7, §4.8, §9.1; visual language §4, §5 (grouped rows, sheets, consequences panel).
- Contract problems (PROC-20):
  1. **kit-KitScanner is not built.** `work-units.json` lists `kit-KitScanner` in this unit's `after`, and the task says it is integrated on `feat/phone-setup-v2`. The merge `42d1c7c2` ("Merge revamp/kit-KitScanner") brought only the unit's QA record, which says it was blocked on kit-KitSince (`docs/qa/revamp-kit-KitScanner-2026-09-26/README.md`). There is no `lib/ui/kit/kit_scanner.dart`. Per R13 no local substitute was built: the camera surface stays the existing `MobileScanner` widget (a package widget, not counted by G16) inside the screen, and everything around it (states, instruction, rejected line) is now kit. Blocks: moving the preview, viewfinder and paused state into `KitScanner`; the unit that builds KitScanner should also swap `_preview` in `pairing_scanner_screen.dart`.
  2. **host-management has no owning slice.** Its proposal is `redesign`, but no programme slice in `work-units.json` lists the page (G30 would flag it). Recorded as "deferred to no owner" below, with `// revamp: redesign (no owner)` above the class.
  3. **The phone's own server still updates through `/termux-setup`.** server-settings' fix asks to route the managed update to phone setup v2's "This phone" card. `server_settings_screen.dart` is a `part of settings_screen.dart`, and adding the `phone_setup_routes.dart` import means editing that library's imports, which are outside the write set (and the settings test expects `/termux-setup`). Deferred: the owner of `settings_screen.dart`.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - guide: actionsMissing "'Add a server' at step 2" → done: `screen_servers_2_test.dart` "step 2 has Add server, which opens Servers" (label is the real Servers button, "Add server"); "'No computer? Run it on this phone'" → done: "a phone offers the no-computer path; a desktop does not" (opens `openPhoneSetupStart`); statesMissing "already connected: still reads as first run" → deferred to no owner (needs a connected-state variant of the story); infoMissing "phone-only path" → done (same row); honest-state "'Paste pairing code' vs 'Paste code'" → done: "step 2 names the real Servers buttons".
  - pairing-scanner: actionsMissing "'Allow camera' as the denied primary" → done: "denied: Allow camera is the primary and asks again"; statesMissing "QR that isn't a pairing code" → done: the rejected line is a `KitNotice` under the preview (key `pairing-scanner-rejected`; not rendered, the preview needs a camera); "expired code" → deferred to no owner (pairing payloads carry no expiry, `lib/state/pairing.dart`; nothing to detect).
  - host-management (redesign): actionsMissing "check the service is running", statesMissing "Mac/Windows host", "service already installed", infoMissing "what the script does", "pin/checksum" → deferred to no owner (redesign slice missing, contract problem 2). Done now: `launchUrl` → `openExternalLink` (SEC-1), copy through the kit's code block, the address in `KitText.mono` (a11y "wrapped URL unreadable").
  - server-settings: actionsMissing "add/change password here" → partial: the Authentication row now says "Add or change it in Servers" and opens Servers (the profile editor lives there; an in-place editor would add persistence, out of scope); "re-check after a restart" → done: restart sheet test; statesMissing "health failed" → done: golden `servers_server_settings_health_failed_*`; "Codex/Paseo: what applies" → deferred to no owner (needs per-flavor capability words); infoMissing "how to add a password" → done (same row); ledgerStale managed update → deferred (contract problem 3). Rationale items: health-reported version everywhere → done: "the update question states the health-reported version"; address to Details → done: "the address is in Details, not on the identity row".
  - server-settings-restart-dialog: actionsMissing "Copy command", "I restarted it"; infoMissing "the command" → done: "restart: the command to run, and I restarted it re-checks"; statesMissing "restarted (verified)" → partial: "I restarted it" re-runs the health probe and the health row shows the answer; confirming the new version is running is the connection's (unchanged).
  - server-settings-upgrade-sheet: statesMissing "installing progress", "failed" → done: the install runs inside `showKitConfirm(action:)` (working confirm button; failure keeps the question open with the kit notice and Try again, and the row shows the reason); infoMissing "downtime", "restart needed after" → done: consequences panel, test "the update question states the health-reported version"; golden `servers_server_settings_upgrade_sheet_confirm_*`.
  - profile-monitor (merge-into:servers): statesMissing "watching stopped by Android", "server not answering", "no other servers"; actionsMissing "Watch this server", "answer without switching"; infoMissing "project of the request", "waiting time" → deferred to slice-P4.2b (MAP-1: least change; `// revamp: merge-into:servers (slice-P4.2b)` above the class).
  - profile-monitor-switch-server-dialog: infoMissing "server names" → done: "switching names both servers and what keeps running"; actionsMissing "answer without switching" → deferred to slice-P4.2b (cross-server answering).
  - embedded-profile-monitor-inbox: rationale "other-server requests in the Inbox's own request pattern with an 'On Laptop' label" → done: `KitNeedsYou.row` with the server, test "another server's request is a needs-you row naming it"; "the summary links to Servers without recounting" → deferred to slice-P4.2b ("the badge counts each request once"); statesMissing "stale / watching stopped" → deferred to slice-P4.2b; actionsMissing "answer in place" → deferred to slice-P4.2a/P4.2b (landing contract); infoMissing "relative age" → deferred (monitored requests carry no creation time; `KitNeedsYou.row(since:)` is ready).
- States per page (STATE-20):
  - guide: loaded → `servers_guide_loaded_{dark,light}`, `_1280x800_*`; advanced open → behaviour only (`desktop_platform_gating_test` taps `guide-advanced`).
  - host-management: loaded → `servers_host_management_loaded_*` (+ wide).
  - pairing-scanner: starting → `servers_pairing_scanner_starting_*`; denied → `_denied_*` (+ wide); blocked → `_blocked_*`; no camera → `_no_camera_*`; failed → code path only (the fake camera cannot fail `MobileScannerController.start`); scanning/rejected → needs a camera (KitScanner, contract problem 1).
  - embedded-profile-monitor-inbox: pending → `servers_embedded_profile_monitor_inbox_pending_*`; isolated → hidden (unchanged).
  - profile-monitor-switch-server-dialog: confirm → `servers_profile_monitor_switch_server_dialog_confirm_*`.
  - server-settings: loaded (externally managed) → `servers_server_settings_loaded_*` (+ wide); update available → `_update_available_*`; health failed → `_health_failed_*`; updates gated → `_updates_gated_*`; checking → the loading bar and "Checking server health…" row (not rendered).
  - server-settings-restart-dialog: notice → `servers_server_settings_restart_dialog_notice_*`.
  - server-settings-upgrade-sheet: confirm → `servers_server_settings_upgrade_sheet_confirm_*`.
  - profile-monitor: no golden (MAP-1 merge-into).
- Deferred states (STATE-21): scanning and rejected renders → need kit-KitScanner (owner: that kit unit); pairing expiry → needs payload data (no owner); monitor stale/watching-stopped → needs monitor lifecycle data (slice-P4.2b).

## 2. Builds

- Branch `revamp/screen-servers-2`, base `4c871866` (`feat/phone-setup-v2`), code head `337b478d`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | — | Not run (owner 2026-09-27: speed; own new tests only). The fixed behaviours (Allow camera, restart command, health version) did not exist on the base, so the new tests cannot pass there | n/a |
| 2 | `test/revamp/screen_servers_2_test.dart` + `test/revamp/screen_servers_2_golden_test.dart` | pass | 47 passed (`run-tests.txt`) | PASS |
| 3 | `KIT_RATCHET_WRITE=1 … test/kit_ratchet_test.dart` (to read counts; the baseline was restored with `git checkout`, R05) | the five files absent from every gate | no G1, G2, G7, G15x, G16, G17, G21 or G48 entry for any of the five files; `settings_screen.dart` unchanged | PASS |
| 4 | `flutter analyze --no-pub lib test/revamp` | no issues | No issues found | PASS |
| 5 | `flutter analyze --no-pub test` | no new issues | one pre-existing info in `test/goldens/kit/kit_tappable_golden_test.dart` (not this unit) | PASS |
| 6 | Other suites (ratchet compare mode, design-standard, l10n, ledger, shared screen tests) | — | not run (owner 2026-09-27); see Expected shared breaks | n/a |

## 5. Evidence

- `run-tests.txt`: tail of run 2.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-23 / K2 §4.8 | `screen_servers_2_test.dart` "externally managed: the commands copy in place" | `run-tests.txt` |
  | STATE-12 | golden `servers_server_settings_updates_gated_*` (KitRow.unavailable with its reason) | — |
  | STATE-5 | golden `servers_pairing_scanner_starting_*` (KitStateView with `since`, Paste it instead after 8 s) | — |
  | SEC-1 | `host_management_screen.dart` uses `openExternalLink`; G2 `launchUrl(` count 0 (run 3) | — |

- Changed test expectations (TEST-19): none (shared tests untouched, R08).
- Expected shared breaks (not run; for the integrator):
  - `test/host_management_screen_test.dart` "copy buttons place the exact command on the clipboard": expects the SnackBar text "Copied. Run it on the server's computer."; the copy is now the code block's in-place check (G1, KIT-23, K2 §4.8). Case 1 of TEST-19.
  - `test/v2_feature_gating_test.dart` "v2 points server updates at the host machine": `tester.widget<ListTile>(gated-remote-upgrade)`; the row is now `KitRow.unavailable` (same key, same reason text, disabled). Case 1.
  - `test/settings_server_updates_test.dart` "remote update event offers the exact generated upgrade": expects `textContaining('Restart its server process to use it')`, which is now the updates row's supporting line (was the SnackBar); should still pass. "failed remote upgrade remains visible and retryable" should still pass (the row shows the reason behind the kept-open question).
  - `test/profile_monitor_screen_test.dart`, `test/e7_setup_layout_test.dart` (scanner, host pages), `test/desktop_platform_gating_test.dart`, `test/ios_remote_platform_gating_test.dart`: keys kept (`guide-advanced`, `guide-pair-command`, `guide-termux-section`, `pairing-scanner-*`, `host-docs-link`, `host-command-adb-reverse`, `copy-host-command-*`, `monitor-notification-settings`, `monitor-busy-*`, `monitor-row-*`, `server-updates-tile`, `confirm-server-upgrade`, `host-management-entry`); expected to pass, not run.
- Goldens changed (each opened and looked at): 36 new PNGs `test/revamp/goldens/servers_*` (no previous goldens for these pages). Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Settings.png` for server-settings (grouped `surface1` rows with icon tiles, chevrons, section air: matches; differences: no large title, the page is a pushed route with the top bar; the Details fold sits below the groups) and `Confirm.png` for the upgrade and switch questions (icon tile, question, body, consequences panel, full-width primary and Cancel: matches). No approved render for the guide, host, scanner or inbox rows.
- Look notes for the reviewer: `KitCodeBlock` inside a `KitRow.below` draws its copy button on a row of its own above the command, which makes one-line commands tall (visible in the guide and host goldens); that is the kit part's layout, not changed here.
- Before and after (EVID-10): `before-guide-static.png` / `after-guide-loaded.png`; `before-host-management-static.png` / `after-host-management-loaded.png`; `before-pairing-scanner-denied.png` / `after-pairing-scanner-denied.png`; `before-embedded-profile-monitor-inbox-pending.png` / `after-embedded-profile-monitor-inbox-pending.png`; `before-profile-monitor-switch-server-dialog-confirm.png` / `after-…`; `before-server-settings-update-available.png` / `after-…`; `before-server-settings-restart-dialog-notice.png` / `after-…`; `before-server-settings-upgrade-sheet-confirm.png` / `after-…` (before: base census under `docs/qa/screen-census/`).
- Accessibility: every icon-only control is a `KitIconButton` with a tooltip ("Check server health", "Copy update commands"); guide steps keep "Step n of 3" as a container label; needs-you rows carry the kit's one merged label (title, reason, server, if ignored); the switch/upgrade questions are the kit confirm (Esc cancels); the scanner rejected line is a live-region `KitNotice`; row targets are the kit's 48 dp. 200 % text was not rendered for these pages.
- Privacy and security: the external docs link now goes through `openExternalLink` (SEC-1). The scanner still never holds, renders or logs the decoded text; the camera failure's device message moved from the body into the folded Details. No credentials, stored data or notifications changed; the golden fixture password is a placeholder and is never displayed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_servers_2_test.dart test/revamp/screen_servers_2_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze --no-pub lib test
```

## 7. NOT proven

- Not run on a device or emulator; the camera preview, the rejected line over a live preview and the failed-camera state were not rendered.
- Shared test suites, the ratchet in compare mode, design-standard, l10n coverage, glossary and ledger tests were not run (owner decision 2026-09-27); the expected breaks above are reasoned, not observed.
- No failing-first run was saved (TEST-2) for the fixes.
- 200 % text and the LAY-4 overflow sizes other than 412×915 and 1280×800 were not checked.
- The files are not in `_migrated` (`test/design_standard_test.dart` is integrator-owned, R10); the ratchet baseline and the l10n `_baseline` were not regenerated (R05).
- `docs/design/ui-ledger/parts/*.json` not updated: `server-settings-restart-dialog` is now a sheet (kind `dialog` → `sheet`) and the Authentication row now opens Servers.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (scanner preview waits on kit-KitScanner; host redesign and P4.2b items deferred) | `revamp/screen-servers-2` |
| Enabled | Yes | |
| Verified | own tests and goldens only | this record |
| Committed | Yes | code head `337b478d` |
| Deployed | No | |
| Released | No | |
