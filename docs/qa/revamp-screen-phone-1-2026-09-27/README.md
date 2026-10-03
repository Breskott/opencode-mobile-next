# revamp-screen-phone-1: Revamp phone (7 files) (2026-09-27)

## 1. Scope

- Unit: `screen-phone-1` (wave 2b, screen-revamp). Finish line: every file in the write set has a G16 count of zero, uses kit parts only in the VL look, and each page is handled by its map proposal with the wave-2 missing states and actions. Non-goal: no gateway call, controller field or persistence added; no wave-3 structure (setup flow merge, Claude Code component).
- Files changed: `lib/ui/screens/builtin_server_screen.dart`, `lib/ui/screens/local_agent_screen.dart`, `lib/ui/screens/phone_setup/phone_setup_customize_sheet.dart`, `lib/ui/screens/phone_setup/phone_setup_ready_screen.dart`, `lib/ui/screens/phone_setup/phone_setup_start_screen.dart`, `lib/ui/screens/phone_setup/phone_setup_welcome_entry.dart`, `lib/ui/screens/termux_storage_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/builtin_server_screen_test.dart`, `test/termux_storage_test.dart`, new `test/revamp/screen_phone_1_{test,golden_test,fixtures}.dart`, 38 goldens `test/revamp/goldens/phone_*.png`.
- Pages (map ids): builtin-server-log-sheet, builtin-server-remove-confirm-sheet, builtin-server-setup, local-agent-page, phone-setup-customize-sheet, phone-setup-ready, phone-setup-start, termux-storage, termux-storage-clean-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-20, KIT-22, KIT-26, KIT-27, KIT-30, KIT-31, KIT-33, KIT-34, LOOK-1, LOOK-2, LOOK-4, LOOK-12, LOOK-19, LAY-6, LAY-7, LAY-8, STATE-1, STATE-8, STATE-12, STATE-20, STATE-21, DATA-11, DATA-14, MAP-1; kit-v2 §9.1; visual-language §5.
- Contract problems (PROC-20):
  - `KitSwitchRow(locked:)` draws its word in a `Row` with no flex (`lib/ui/kit/kit_row_parts.dart` `_locked`): a locked word longer than ~8 characters overflows the trailing slot at 412 dp in tests. The copy was shortened to "Required" instead of fixing the kit (not this unit's part). Proposed: wrap the word in `Flexible` or let it move under the title at large text. Blocks: nothing.
  - Task text says new copy goes to `app_en.arb` AND `app_ar.arb`; the owner decision of 2026-09-27 (later, wins) drops Arabic, so only `app_en.arb` was changed.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - phone-setup-start: statesMissing "Termux installed but not yet allowed" → done: `screen_phone_1_test.dart` "Termux there but not allowed says so under Use Termux"; "unsupported device or low storage" → already handled by the P0.8 pre-flight (existing `phone_setup_start_screen_test.dart`); "both in-app and Termux present" → done: "in-app and Termux both there: the Termux one is a row", golden `phone_setup_start_ready_other_ways_*`; "offline before starting" → deferred to slice-P1.3 (needs connectivity data the page does not receive). actionsMissing "'Run Claude Code here' as a first-class choice" → deferred to slice-P1.6b; "start over / remove a half-done setup" → deferred to slice-P1.3 (SetupEngine has no reset call).
  - phone-setup-customize-sheet: statesMissing "selection larger than free space" → done (pre-flight low space as a KitNotice with Open storage); "everything optional installed" → done: "every optional tool installed: nothing to add, and why", golden `phone_setup_customize_all_installed_*`; "a single optional tool left" → done (renders as one switch; no special state needed). actionsMissing "choose OpenCode 1 or 2", "use Termux as host (advanced)", "start setup from the sheet" → deferred to slice-P1.3; "add Claude Code" → deferred to slice-P1.6b; "remove an installed optional tool" → deferred to slice-P1.3 (needs an engine remove call).
  - phone-setup-ready (keep): statesMissing "another server was in use", "Claude Code also installed" → deferred to slice-P1.3 / slice-P1.6b (keep: no behaviour change).
  - termux-storage: statesMissing "scan failed" → done: "a failed scan says so, and Scan starts it again", golden `phone_termux_storage_failed_dark`; "in-app host" → no owner (page is hidden on in-app phones, whenMissing hidden); "phone nearly full" → no owner (needs the phone's free space, not in the report). actionsMissing "rescan after a clean" → done: `termux_storage_test.dart` "cleaning over a gigabyte…" (`termux-storage-rescan-after-clean`); "scan on open (cached)" → the cached report already shows on open; an automatic scan is a battery decision, no owner; "clean everything safe at once" → no owner (only one category, build caches, is cleanable today).
  - termux-storage-clean-sheet: no missing items; rebuilt as `showKitConfirm` destructive with the paths under Details and the clean running inside it (DATA-14): "the clean question lists the exact paths under Details".
  - builtin-server-log-sheet: statesMissing "live" → done (KitLogPanel `live` + `onRefresh` while the server runs); "truncated to the tail" → deferred to slice-P1.3 (the channel returns the tail only; no length is reported). actionsMissing "Restart when the log ends in a crash" → done: `builtin_server_screen_test.dart` "a server that exits while starting shows the failure" (`builtin-server-log-start`); "attach to a bug report" → no owner.
  - builtin-server-remove-confirm-sheet (remove, slice-P1.3): statesMissing "remove failed" → done (uninstall runs inside the confirm): "a failed remove keeps the question open with Try again". actionsMissing "export projects first", "also forget the dead saved server" → deferred to slice-P1.3.
  - builtin-server-setup (merge-into:phone-setup-start, slice-P1.3): least change; all its statesMissing/actionsMissing deferred to slice-P1.3.
  - local-agent-page (redesign, slice-P1.6b): kit-only rebuild of today's layout; all items deferred to slice-P1.6b.
- States per page (STATE-20):
  - phone-setup-start: loading (KitScreen bar), fresh → golden `phone_setup_start_fresh_*`; stopped → `phone_setup_start_stopped_*`; ready + other ways → `phone_setup_start_ready_other_ways_*`; running, termux, pre-flight, failure → existing `phone_setup_start_screen_test.dart` (see NOT proven).
  - phone-setup-customize-sheet: first setup → `phone_setup_customize_first_*`; add, everything installed → `phone_setup_customize_all_installed_*`; checking, nothing chosen → existing tests.
  - phone-setup-ready: default → `phone_setup_ready_default_*`; invalid name → "the name is a labelled kit field…"; close → "Close leaves for the app root".
  - termux-storage: loading (skeleton), intro, scanning, report (+1280x800), category open, failed → goldens `phone_termux_storage_*`; cancelled, in use → `termux_storage_test.dart`.
  - builtin-server-setup: fresh, running (+1280x800) → goldens; start failure, stop, remove → `builtin_server_screen_test.dart`.
  - log sheet / remove sheet: default → goldens `phone_builtin_server_log_sheet_*`, `phone_builtin_server_remove_confirm_*`.
  - welcome entry (part of the welcome): stopped → `phone_setup_welcome_stopped_*`.
  - local-agent-page: no golden (see NOT proven).
- Deferred states (STATE-21): listed per page above.

## 2. Builds

- Branch `revamp/screen-phone-1`, base `2cec35ca`, code head `5088cc85`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_phone_1_test.dart` | passes | 9 passed | PASS |
| 2 | `test/builtin_server_screen_test.dart` | passes | 6 passed | PASS |
| 3 | `test/termux_storage_test.dart --plain-name TermuxStorageScreen` | passes | 6 passed | PASS |
| 4 | `test/revamp/screen_phone_1_golden_test.dart --update-goldens` | renders 38 | 38 passed | PASS |
| 5 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline restored after) | the write set's G1/G2/G7/G16/G17/G21 rows gone | all rows gone | PASS |
| 6 | `flutter analyze` on the changed lib and test files | no issues | no issues | PASS |

Not run (owner decision 2026-09-27, speed): the rest of the suite, design-standard, l10n, glossary and ledger tests.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-34 | `test/builtin_server_screen_test.dart` "Remove asks first, then deletes Ubuntu" (no SnackBar, in-place notice) | run 2 |
  | DATA-14 | "a failed remove keeps the question open with Try again" | run 2 |
  | KIT-31 | `test/termux_storage_test.dart` "scans with the live panel…" (`kit-log-panel`) | run 3 |
  | STATE-8 | "cleaning over a gigabyte…" (`kit-action-reason` under Clean) | run 3 |
  | KIT-30 | "required tools are locked on with a word, not a dead switch" | run 1 |

- Changed test expectations (TEST-19): `termux_storage_test.dart`: `setup-live-output` → `kit-log-panel` (KIT-31); `widget<FilledButton>` → `widget<KitButton>` (KIT-8); "Scan again before cleaning more" now also appears as Clean's disabled reason, so the header line is matched whole and the reason by `kit-action-reason` (STATE-8); the 320 dp fit test names the page's list as its scrollable (the kit rows hold their own). `builtin_server_screen_test.dart`: expectations added only.
- Goldens added (each opened and looked at, contact sheets during the run): 38 `test/revamp/goldens/phone_*.png`. Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Settings.png` for rows on surface1 panels with icon tiles (KitRowGroup in storage and customize: match), `Confirm.png` for the clean and remove questions (match: icon tile, start-aligned title, stacked full-width buttons). Differences: none beyond content.
- Before and after (EVID-10): `before-*.png` from the base census (`docs/qa/screen-census/h-termux/`), `after-*.png` from the new goldens, for 14 page states in this folder.
- Accessibility: every step keeps its one spoken phrase ("Step 2 of 4, done. Install OpenCode"); icon-only controls are KitIconButtons with labels (top bar rescan, log copy); disabled controls say why in visible text (runtime choice, Clean); the 320 dp at 2.5x text test passes; the log is not a live region, the scan state is.
- Privacy and security: n/a: no credentials, stored data, external links or notifications changed. Logs go through KitLogPanel's redaction.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_phone_1_test.dart test/builtin_server_screen_test.dart
$F test -j 1 test/termux_storage_test.dart
$F test -j 1 test/revamp/screen_phone_1_golden_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests not run; likely affected (for the integrator): `test/phone_setup_start_screen_test.dart` (reads the totals as `Text` and a `SwitchListTile`), `test/goldens/phone_setup_golden_test.dart` (setup start, customize, ready and welcome renders change), `test/design_standard_setup_test.dart`, `test/phone_setup_ready_screen_test.dart`, `test/motion_setup_test.dart` (screen A's entrance is now KitSwap), `tool/capture/calm_storage_test.dart` and the `h_termux` census guards, `test/design_standard_test.dart` (`_migrated` entries for the seven files), `test/kit_ratchet_baseline.json` and the l10n coverage baseline (counts dropped).
- local-agent-page has no golden: its onboarding block needs the `oc/termux` channel fixture of another area; the page is a thin kit frame around it.
- `test/goldens/failures/` holds 24 tracked files from the base; untouched here.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-phone-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `5088cc85` |
| Deployed | No | |
| Released | No | |
