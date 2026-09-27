# revamp-shared-system-1: Revamp system (2026-09-27)

## 1. Scope

- Unit: `shared-system-1` (wave 2a, tier 1, screen-revamp of shared files). Finish line: `external_link.dart`, `product_states.dart` and `run_command_dialog.dart` are built only from kit parts (G1, G16, G7, G17, G21 all 0), the Product* states and GatedRow/SectionLabel are thin wrappers over KitStateView/KitRow, and the three pages' map fixes are in. Non-goal: no call site outside the write set changes; no gateway call, controller field or persistence is added.
- Files changed: `lib/ui/widgets/{external_link,product_states,run_command_dialog}.dart`; `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`); tests `test/{external_link,glass_surface,release_blockers,v2_feature_gating}_test.dart`; new `test/revamp/shared_system_1_{test,golden_test,fixtures}.dart` and 36 goldens under `test/revamp/goldens/system_*`; census guards for `external-link-dialog` in `tool/capture/census/areas/a_shell.dart` (TEST-17).
- Pages (map ids): `embedded-product-states`, `external-link-dialog`, `run-command-dialog` (all proposal `fix`).
- Specs followed: STANDARDS.md §1, KIT-2, KIT-34, STATE-3, STATE-12, SEC-1, MAP-1, TEST-5, TEST-19, TEST-20, §16; kit-api KitStateView, KitRow, KitDialog, KitSheet/KitConfirm, KitNotice, KitField, KitChoiceList; visual-language (kit parts carry the look).
- Contract problems (PROC-20):
  1. KitConfirm has no "risky but not destructive" kind. The map fix for http ("Don't open" filled, "Open anyway" as error text) cannot be expressed; the http question uses `KitConfirmKind.destructive` with cancel "Don't open": the risky act is error-toned and Enter never confirms it, but "Don't open" is the secondary, not the filled button. Proposed: a `KitConfirmKind.risky` whose cancel is the filled default. Blocks nothing.
  2. The task text says new copy goes to `app_en.arb` AND `app_ar.arb`; the later owner decision (2026-09-27, Arabic dropped) wins, so only `app_en.arb` gained keys.
  3. `KitReportHook.handler` is not set anywhere in `lib/`, so `KitStateView.error` would never show "Report a problem". ProductErrorState therefore uses the plain KitStateView with its own "Report a bug" tertiary (as `global_sessions_screen.dart` already does). Once the app sets the hook, the wrapper can move to `KitStateView.error`.
- New kit parts (KIT-3): none.
- Moved or removed (owner rethink rule):
  - GatedRowTile's tap snackbar ("Requires an OpenCode N server") removed: the row's reason line already says it, and the generation is now the row's spoken hint.
  - The run-command Cancel button removed: the sheet's close button, back and swipe do it (and ask first when arguments were typed).
  - The external-link blocked/no-app/failure snackbars became kit alerts; the full URL moved under Details (on request).
- Map items (EVID-11):
  - embedded-product-states: actionsMissing "Switch server for network errors" → done: `shared_system_1_test.dart` "a network error offers Switch server, not Report"; statesMissing "error with a title and a cause in words" → done: same file "an unexpected error: a title, the cause…", golden `system_embedded-product-states_error_*`; "network error vs unexpected error" → done: golden `system_embedded-product-states_network-error_*`; infoMissing "a title" / "a diagnosis; raw text under Details" → done: "a caller title and errorKind win; raw details fold away". Callers still pass only `message`; passing `error:`/`title:`/`details:` is each owning screen unit's work (the wrapper classifies only what it is given).
  - external-link-dialog: actionsMissing "copy the link instead" → done: `external_link_test.dart` "copy the link instead copies the full address and opens nothing"; infoMissing "the full URL on request" → done: "the full address is one tap away under Details"; critic fix (risky http emphasis) → partial, see contract problem 1.
  - run-command-dialog: statesMissing "run failed" → done: `shared_system_1_test.dart` "a failed run stays in the sheet with the arguments kept", golden `system_run-command-dialog_run-failed_*`; infoMissing "what arguments it takes" → done: the command description as subtitle plus a helper line ("says what the command does and what the field takes"); couldBeAutomatic "default to the current conversation" → partial: defaults to the most recent conversation; the controller has no "current conversation" field and adding one is out of scope (no owner).
- States per page (STATE-20): embedded-product-states: error, network error, empty, inline empty, refresh failed, gated row → goldens `system_embedded-product-states_*` and `shared_system_1_test.dart`. external-link-dialog: https, insecure-http, blocked, no app, failed → goldens `system_external-link-dialog_*` and `external_link_test.dart`. run-command-dialog: idle, sending (working primary), run failed → goldens and `shared_system_1_test.dart` "a run in flight cannot be sent twice".
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/shared-system-1`, base `b24addac`, code head `4fa16b12`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/shared_system_1_test.dart` | passes | 11 passed | PASS |
| 2 | `test/revamp/shared_system_1_golden_test.dart` | 36 goldens match | 36 passed | PASS |
| 3 | `test/external_link_test.dart`, `test/glass_surface_test.dart`, `test/bug_report_test.dart`, `test/product_error_text_test.dart` | pass | passed (`run-own-tests.txt`, 149 total with rows 1-2) | PASS |
| 4 | `test/v2_feature_gating_test.dart` | my changed expectations pass | GatedRow tests pass; 3 failures that also fail on base `b24addac` with lib reverted (menu actions ×2, "v2 hides the shell row") | PASS (pre-existing failures listed) |
| 5 | `test/release_blockers_test.dart` | link-gate test passes | passes; "question sheet keeps actions reachable with keyboard and 2x text" fails on base too | PASS (pre-existing failure listed) |
| 6 | `test/chat_live_events_test.dart` | no new failures | 9 failures, the same 9 on base `b24addac`; "todos sheet failure offers retry" passes (it failed on my first cut until short slots got the inline state) | PASS |
| 7 | `test/kit_ratchet_test.dart` (write mode, baseline then restored) | write-set counts 0 | G1, G16, G2, G7, G15x, G17, G21, G48 have no entry for the three files | PASS |
| 8 | `flutter analyze` on changed paths; `lib`, `test`, `tool` | no issues in changed paths | changed paths: no issues; elsewhere 3 + 5 pre-existing infos/warnings in files this unit did not touch | PASS |

## 5. Evidence

- `run-own-tests.txt`: output of rows 1-3.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-34 | `test/revamp/shared_system_1_test.dart` "showProductError is an alert, never a snackbar"; `test/external_link_test.dart` "never answers with a snackbar (KIT-34)" | `run-own-tests.txt` |
  | STATE-3 | `test/revamp/shared_system_1_test.dart` "a network error offers Switch server, not Report" | `run-own-tests.txt` |
  | STATE-12 | `test/revamp/shared_system_1_test.dart` "GatedRow is an unavailable KitRow with its reason" | `run-own-tests.txt` |
  | SEC-1 | `test/external_link_test.dart` (every scheme/credential/host test unchanged and passing) | `run-own-tests.txt` |

- Changed test expectations (TEST-19):
  - `test/external_link_test.dart`: host `find.text('example.com')` → `'Opens example.com outside this app.'` (the body now says what happens); "Could not open link" → "Couldn't open link" (alert title) — KIT-34, COPY.
  - `test/release_blockers_test.dart`: the blocked answer is now a modal alert, so the test closes it before tapping the next link; host text as above — KIT-34.
  - `test/glass_surface_test.dart`: "error snackbar has readable text" → "an action failure is an alert": no SnackBar, title and message shown, message readable against the surface — KIT-34.
  - `test/v2_feature_gating_test.dart`: `tester.widget<ListTile>` → `tester.widget<KitRow>` for gated rows (KitRow.unavailable, KIT-1); the tap-snackbar expectation replaced by the spoken hint "Needs an OpenCode 1 server" and no SnackBar on tap — KIT-34.
- Goldens changed (each opened and looked at): all 36 are new, `test/revamp/goldens/system_<page>_<state>[_1280x800]_{dark,light}.png`:
  - `system_embedded-product-states_{error,network-error,empty,rows}`: KitStateView page states and the rows composite (KitNotice.error over kept content, kit section label, dimmed KitRow with reason, inline KitStateView).
  - `system_external-link-dialog_{https,insecure-http,blocked}`: KitConfirm bottom sheet on phone, centred panel on 1280x800; http is error-toned with the unencrypted consequence; blocked is a KitDialog alert.
  - `system_run-command-dialog_{idle,run-failed}`: KitSheet with description, arguments field and helper, "Runs in" expand row, the failure notice and the Run primary.
  - Approved render (EVID-12): `docs/design/visual-language-2026-09-26/Confirm.png` for the external-link confirmation: the kit's KitConfirm draws it, no differences introduced by this unit beyond the Copy link alternative and the Details fold. The other pages have no approved canvas render.
- Before and after (EVID-10): `before-embedded-product-states-{error,empty}.png`, `before-external-link-dialog-{https,insecure-http}.png`, `before-run-command-dialog-idle.png` (from base census PNGs) next to `after-*.png` (dark phone goldens).
- Accessibility: every action is a KitButton (48 dp+); the gated row speaks its needed server generation; the error state's title is a live-region state (KitStateView); section labels are headers; the run sheet's field has a visible label and helper. Text 2.0 not rendered (galleries limited to phone and 1280x800 by the owner decision).
- Privacy and security: `openExternalLink` is still the only launcher path for URLs the app did not author (SEC-1); the policy (`safeExternalLinkUri`) is unchanged. A blocked value is never echoed. "Copy link" copies only an address that passed the policy, unredacted on purpose (a link is not a secret, and redaction could alter it). Raw error details in ProductErrorState are redacted before Copy details.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_system_1_test.dart test/revamp/shared_system_1_golden_test.dart
$F test -j 1 test/external_link_test.dart test/glass_surface_test.dart test/bug_report_test.dart test/product_error_text_test.dart
$F analyze lib/ui/widgets test/revamp/shared_system_1_test.dart test/revamp/shared_system_1_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests outside this unit's write set were not run (owner decision 2026-09-27); likely broken ones are listed for the integrator: `test/library_commands_test.dart` (reads the arguments field as `TextField`, expects an `AlertDialog`, taps a dropdown item), `test/motion_adopt_test.dart` (finds `MaterialBanner` in ProductRefreshBody), `test/plugins_screen_test.dart` (run-command keys kept, flow not checked), and any test that expects `showProductError`'s old snackbar or taps under its new modal alert.
- The design-standard, l10n coverage, glossary and ledger tests were not run.
- Text scale 2.0 and the other LAY-4 sizes were not rendered.
- The ~25 callers of ProductErrorState still pass only a message, so the network form and titles appear only where a caller passes `error:`/`title:`.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-system-1` |
| Enabled | Yes | every page that embeds these widgets |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `4fa16b12` |
| Deployed | No | |
| Released | No | |
