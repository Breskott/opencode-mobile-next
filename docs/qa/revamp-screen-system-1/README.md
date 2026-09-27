# revamp-screen-system-1: Revamp system (5 files) (2026-09-27)

## 1. Scope

- Unit: `screen-system-1` (wave 2b, screen-revamp). Finish line: the five files are built only from kit parts (G1, G2, G7, G16, G17 and G21 at zero for each), each page follows its map proposal with the wave-2 missing states and actions, and the look is the visual language. Non-goal: no gateway call, controller field or persistence added.
- Files changed: `lib/ui/screens/about_screen.dart`, `lib/ui/screens/app_diagnostics_screen.dart`, `lib/ui/screens/keep_running_screen.dart`, `lib/ui/screens/perf_trace_section.dart`, `lib/ui/screens/server_capabilities_screen.dart`, `lib/l10n/app_en.arb` (36 new keys, English only per the owner decision of 2026-09-27), `test/about_alpha_notice_test.dart`, `test/app_diagnostics_screen_test.dart`, `test/server_capabilities_screen_test.dart`, new `test/revamp/screen_system_1_test.dart`, `test/revamp/screen_system_1_golden_test.dart`, `test/revamp/screen_system_1_fixtures.dart`, 18 goldens `test/revamp/goldens/system_*`. The generated `lib/l10n/app_localizations*.dart` were regenerated locally but not committed (sibling units' practice; the integrator regenerates after merges).
- Pages (map ids): `about`, `about-privacy-tab`, `about-open-source-tab`, `app-diagnostics`, `app-diagnostics-clear-sheet`, `keep-running`, `server-capabilities`.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-22, KIT-23, KIT-26, KIT-27, KIT-32, KIT-33, KIT-34, KIT-36, LOOK-4, LOOK-5, LOOK-6, LOOK-12, LOOK-21, STATE-8, STATE-12, DATA-11, MAP-1, COPY-9; kit-v2 §9.1; visual-language §4–§5 (grouped panels, icon tiles, muted second lines).
- Contract problems (PROC-20):
  - The unit brief says app_ar.arb with real Arabic (R04); the owner decision of 2026-09-27 drops Arabic. The later owner decision was followed (§0.2).
  - KIT-33 says the Details fold sits last on its page. On About the map (rationale "show identity once above the tabs with the package id under Details") puts it with the identity; last would put it under 400 lines of licence notices. The map was followed; the fold is the only one on the page.
  - `app-diagnostics` is `redesign` (MAP-1: kit-only rebuild of today's layout, new structure in slice-P8.2), while its sheet `app-diagnostics-clear-sheet` is `fix`. The count in the clear question was done; the rest waits for P8.2.
- New kit parts (KIT-3): none.
- Moved or removed (owner rule "rethink, not just restyle"):
  - About: the app-bar "Report a bug" icon was removed (it duplicated the notice's action); the one report action is now "Report a bug on GitHub" inside the build notice. The identity, non-affiliation statement and build notice are shown once above the tabs instead of repeated on each tab. The package id and signer moved under Details. The two product names ("OpenCode for Android", "OpenCode for desktop", "OpenCode for iOS") became one, "OpenCode Mobile", with the platform in the line under it.
  - App diagnostics: the three snackbars ("Diagnostics copied", "sent", "could not send") were removed: copy announces through KitCopy, the send result is a notice under the buttons. "Send" became "Send to Workstation's log" with one line under it saying where it goes and that the app's makers don't receive it. "Copy" became "Copy errors", "Clear" became "Clear errors".
  - Performance: "Clear" became "Clear timings" (it was the same word as the confirmed error Clear); failed steps are no longer painted red, the row says "1 failed".
  - Keep running: the open-failure snackbar became an in-place notice; the tooltip-wrapped external icon became an "Open" value with chevron; the heat-pause switch sits in its own panel after the steps; the swipe warning no longer uses the attention colour (LOOK-4: amber only for "needs you").
  - Available on this server: the three state headings ("Available here", "Not available on this server", "Not available on this device") were removed (owner rule: no state sections); each row carries its state in words and the available features fold into one row.
- Map items (EVID-11):
  - about: actionsMissing "copy version in one tap" → done: `test/about_alpha_notice_test.dart` "the version copies in one tap"; "check for updates" → done: "check for updates: fetches an update and says to reopen", "check for updates: up to date, and a build that cannot" (Android builds and an injected `updateService`; desktop has no row: its GitHub release check stays in `DesktopReleaseNotice`, no owner). infoMissing "signer under Details" → done ("About shows the build once…", Details unfolds the package id); "update available" → done through the update row. statesMissing: none.
  - about-privacy-tab: actionsMissing "jump from a policy section to the matching control" → deferred: no owner (needs anchors in PRIVACY.md and routes per section). infoMissing "a plain summary before the full text" → deferred: no owner (document content, not UI). Soft breaks joined → done: `reflowMarkdown`, golden `system_about_*`.
  - about-open-source-tab: actionsMissing "full licence list (showLicensePage)" → done with the kit viewer instead of the Material page: "the tabs switch the document; Open source lists licenses", golden `system_about_open_source_*`. infoMissing "voice model licences (separate page)" → deferred to the voice unit (the voice notices page is outside this write set).
  - app-diagnostics (redesign): kit-only rebuild; actionsMissing ("one Report a problem flow", "preview exactly what is sent", "attach a screenshot", "reach it from every error state") → deferred to slice-P8.2. statesMissing "after a crash or restart: the log is empty" → done in the empty body copy ("After a crash or a restart this list starts empty", golden-free: `appDiagnosticsEmptyBody`, test "diagnostics screen explains an empty process-local report"); "arrived from an error: that error preselected" → deferred to slice-P8.2. infoMissing "where Send goes" → done: test "Send names the server it goes to and says what happens". couldBeAutomatic "offer to report when an error state shows" → deferred to slice-P8.2.
  - app-diagnostics-clear-sheet: infoMissing "how many" → done: test "Clear asks first with the count, then empties the list", golden `system_app_diagnostics_clear_sheet_*`.
  - keep-running: statesMissing "all steps done: You're set" → done: `test/revamp/screen_system_1_test.dart` "a Pixel with battery allowed: You're set, nothing left", golden `system_keep_running_set_*` (only on stock Android, where the battery exemption is the whole list; makers with their own screens are never told "You're set" because the app cannot read those screens); "Android 15+ daily 6 h budget and use today" → the limit is stated (same test); "use today" deferred: no owner (no usage source exists). actionsMissing "the background switch itself (on Notifications)" → deferred: no owner (the switch and its controller live in the Notifications settings, outside this write set; moving it needs a controller the screen does not take). couldBeAutomatic "request the battery exemption in-flow when the phone server starts" → deferred: no owner (phone server start is outside this unit).
  - server-capabilities: statesMissing "opened for one missing feature: that feature first" → done: `focusFeature` parameter, test "opened about one feature: that feature is first". actionsMissing "per missing feature: update server, switch server, set up on this phone, or ask the assistant" → partly done: each missing server feature names the servers that have it (KitCapabilityExplainer.hostsLineOf), and "Add a server that has these" runs the registered add-server flow (test "Add a server appears only when the app can open that flow"); "update server" and "ask the assistant" → no owner (no flow in the capability registry). infoMissing "how to get a missing feature" → done (same). couldBeAutomatic "each missing row offers its fix" → only where a flow exists (add server).
- States per page (STATE-20): about: loading (skeleton rows), documents failed (KitStateView inline), loaded (golden `system_about_*`), update idle/checking/current/downloading/ready/cannot/failed (tests); app-diagnostics: empty (test), loaded (golden `system_app_diagnostics_*`), gated (`test/v2_feature_gating_test.dart`, not run), sending, sent, send failed (test for sent); keep-running: loading (KitScreen loading bar), steps left (golden `system_keep_running_*`), all set (golden `system_keep_running_set_*`), open failed (test); server-capabilities: gaps (golden `system_server_capabilities_*`), all available (desktop test), focus (test).
- Deferred states (STATE-21): background time used today → needs a usage source, no owner; diagnostics "arrived from an error" → slice-P8.2.

## 2. Builds

- Branch `revamp/screen-system-1`, base `7011dc46` (feat/phone-setup-v2 when the branch was cut), code head `c2889432`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Owned tests: `test/about_alpha_notice_test.dart`, `test/app_diagnostics_screen_test.dart`, `test/server_capabilities_screen_test.dart` | pass | 23 passed | PASS |
| 2 | `test/revamp/screen_system_1_test.dart` (4) and `test/revamp/screen_system_1_golden_test.dart` (18 goldens, regenerated and looked at) | pass | 22 passed | PASS |
| 3 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1`, baseline inspected then restored (never staged) | no entry left for the five files | none left in G1, G2, G7, G15, G16, G17, G21 | PASS |
| 4 | `test/l10n_coverage_test.dart` | passes | passed; about_screen 5 → 0, app_diagnostics_screen 12 → 0 | PASS |
| 5 | `test/ui_glossary_test.dart`, `test/ui_ledger_coverage_test.dart` | no finding for this unit's keys | 3 glossary failures, all on other units' keys (`projectFolderMissingTitle`, `servicesStop`, `teamPhoneRemoveLost`, `kitCap*`, …); ledger passed | PASS (for this unit) |
| 6 | `flutter analyze --no-pub` on the five files and the unit's tests | no issues | no issues (`analyze.txt`); over `lib/ui/screens` + `test/revamp`: 4 infos, all in `test/revamp/screen_shell_1_*` (another unit) | PASS |

Steps 1–2 in one run: `tests.txt` (45 passed).

## 5. Evidence

- `tests.txt`: steps 1–2; `analyze.txt`: step 6.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-34 (no snackbar; result in place) | `test/app_diagnostics_screen_test.dart` "diagnostics are readable at narrow width and sent explicitly"; `test/revamp/screen_system_1_test.dart` "a settings screen the phone lacks is said in place" | `tests.txt` |
  | DATA-11, COPY-9 (confirm with count) | `test/app_diagnostics_screen_test.dart` "Clear asks first with the count, then empties the list" | `tests.txt` |
  | KIT-23 (copy through KitCopy) | `test/about_alpha_notice_test.dart` "the version copies in one tap" | `tests.txt` |
  | KIT-33 (Details fold) | `test/about_alpha_notice_test.dart` "About shows the build once, provenance and one report path" | `tests.txt` |
  | STATE-12 (explain, offer only a real flow) | `test/server_capabilities_screen_test.dart` "one list: what is missing first…", "Add a server appears only when the app can open that flow" | `tests.txt` |
  | Owner rule: no state sections | "one list: what is missing first…"; "a Xiaomi: what is left first, an allowed step moves last" | `tests.txt` |
  | LOOK-5 (no error colour for slow) | `test/revamp/screen_system_1_test.dart` "a failed step says so in words; Clear names the timings" | `tests.txt` |

- Changed test expectations (TEST-19):
  - `test/about_alpha_notice_test.dart`: the app-bar bug icon is expected gone (map: drop it); the report action is "Report a bug on GitHub"; new tests for copy version, update check, tabs, licences; documents are evicted from the asset cache per test and given real time to load.
  - `test/app_diagnostics_screen_test.dart`: "Diagnostics sent to OpenCode" snackbar → the in-page notice "Sent to OpenCode server's log" (KIT-34).
  - `test/server_capabilities_screen_test.dart`: rows are KitRows, not ListTiles; the headings are gone (owner rule), so rows are found by their state keys and the available fold is unfolded first; the 320 dp / 2.5× check lays out every row on a tall 320 dp surface instead of scrolling.
- Goldens (all new, each opened and looked at): `test/revamp/goldens/system_{about,about_open_source,app_diagnostics,app_diagnostics_clear_sheet,keep_running,keep_running_set,server_capabilities}_{dark,light}.png`, `system_about_1280x800_dark.png`, `system_app_diagnostics_1280x800_dark.png`, `system_server_capabilities_1280x800_dark.png`, `system_keep_running_1280x800_light.png`.
- Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Settings.png` for the grouped rows (surface1 panels, 30 px icon tiles, muted second line, sentence-case labels) — matches for Keep running, capabilities, the About identity and the diagnostics lists; difference: these pages carry a small top bar title (KitTopBar headline) rather than Settings' large title, as pushed pages do. `Confirm.png` for the clear question — matches (danger icon tile, question title, danger-filled confirm, Cancel).
- Before and after (EVID-10): `before-about.png` → `after-about.png`, `before-about-open-source-tab.png` → `after-about-open-source-tab.png`, `before-app-diagnostics-loaded.png` → `after-app-diagnostics-loaded.png`, `before-app-diagnostics-clear-sheet.png` → `after-app-diagnostics-clear-sheet.png`, `before-server-capabilities.png` → `after-server-capabilities.png`; keep-running: no before render (not in the census), `after-keep-running.png`, `after-keep-running-set.png`.
- Accessibility: icon-only controls are KitIconButtons with labels ("Copy version"); the tab strip is named "Documents"; rows are 48 dp+ KitTappables; state is in words, never colour alone ("Works here", "Not on this server", "Allowed", "1 failed"); the update row's working state disables the row with its reason. 200 % text was checked only for the capabilities list (320 dp, 2.5×, English and the Arabic fallback).
- Privacy and security: no credentials or stored data changed. The report action still goes through `openBugReport` (external link path unchanged). Copied text goes through KitCopy's redaction; the Details fold redacts values. The update check uses the existing `AppUpdateService` (no new network endpoint).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test --no-pub -j 1 test/about_alpha_notice_test.dart test/app_diagnostics_screen_test.dart test/server_capabilities_screen_test.dart
$F test --no-pub -j 1 test/revamp/screen_system_1_test.dart test/revamp/screen_system_1_golden_test.dart
KIT_RATCHET_WRITE=1 $F test --no-pub -j 1 test/kit_ratchet_test.dart   # then: git checkout test/kit_ratchet_baseline.json
$F analyze --no-pub lib/ui/screens test/revamp
```

## 7. NOT proven

- Not run on a device or emulator; the real Shorebird update check and download were not exercised (a scripted `AppUpdateService` stands in).
- Shared tests not run (owner decision 2026-09-27); likely broken and left to the integrator:
  - `test/perf_trace_test.dart`: expects the visible "Performance report copied" snackbar text (now a screen-reader announcement through KitCopy).
  - `test/release_blockers_test.dart` "bundled privacy policy and open source notices render in app": expects the old title "About and open source notices", and documents in a lazily built list under the identity (now further down one scroll).
  - `test/ios_remote_platform_gating_test.dart` (About on iOS): expects the "OpenCode for iOS" title (now the one product name; the iOS summary line is unchanged).
  - `test/first_run_welcome_test.dart:183`: finds a tooltip "About and open source notices" (the About title changed; the tooltip may come from the opener, not checked).
  - Possibly `test/app_exit_recovery_test.dart` and `test/thermal_guard_test.dart` (Keep running rows and switch keep their keys; not run), `test/v2_feature_gating_test.dart` (gated key kept; not run).
  - Integrator-owned scenes (`test/support/settings_scenes.dart`: settings_about, settings_diagnostics) and `test/design_standard_test.dart` goldens will change.
- `test/design_standard_test.dart` `_migrated` entries, `test/kit_ratchet_baseline.json` and `test/l10n_coverage_test.dart` `_baseline` were not written (shared files the unit never stages).
- Callers outside the write set still push these pages with `MaterialPageRoute` (`chat_screen.dart:5806`, `search_index.dart`); the pages draw their own KitTopBar, which works there, but the routes should become `pushKitPage`. The hidden-feature explainers elsewhere do not yet pass `focusFeature`.
- 200 % text on About, diagnostics and Keep running was not rendered.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-system-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `c2889432` |
| Deployed | No | |
| Released | No | |
