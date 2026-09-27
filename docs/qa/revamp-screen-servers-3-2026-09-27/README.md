# revamp-screen-servers-3: Revamp servers — Connect with Tailscale (2026-09-27)

## 1. Scope

- Unit: `screen-servers-3` (wave 2b, screen-revamp, tier 1). Finish line: `lib/ui/screens/tailscale_setup_screen.dart` has a G1/G16/G7/look count of zero, is built from kit parts in the VL look, and the `tailscale-setup` page is handled by its map proposal `fix` with its missing states and actions. Non-goal: no gateway call, controller field or persistence added; validation (`isValidTailscaleAddress`) and the returned origin are unchanged; no Arabic (owner decision 2026-09-27).
- Files changed: `lib/ui/screens/tailscale_setup_screen.dart`; `lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`); `test/tailscale_setup_test.dart`; new `test/revamp/screen_servers_3_golden_test.dart` and 16 goldens under `test/revamp/goldens/servers_tailscale_setup_*`; this record.
- Pages (map ids): `tailscale-setup`.
- Specs followed: STANDARDS.md §1.1, MAP-1, §15 (TEST-1, TEST-6, TEST-10, TEST-19, TEST-20), §16; kit-v2 §9.1; KitScreen.md, KitChecklist.md, KitField.md, KitAction.md; visual language 2026-09-26 (Settings canvas for section labels, ground and panels).
- Contract problems (PROC-20):
  1. KitChecklist (`lib/ui/kit/kit_checklist.dart`, `_StepRow`): at text 1.0 on a compact window the person/retry button sits beside the words in a `Row` with no width cap, so a long label overflows (the old "Get official Android app" overflowed by 38 px at 412 wide inside a panel; "Open Tailscale" by 9 px at 360 wide inside a panel). Proposed: stack the button under the words when it would take more than about half the row, as it already does under `AppTheme.stackedActions`. Worked around here without touching the kit: a shorter label (`tailscaleSetupGetApp` "Get Tailscale") and the checklist on the ground rather than inside a panel. Blocks nothing.
  2. The acceptance line asks to "clean test/goldens/**/failures/ before committing": the base (`feat/phone-setup-v2`) already tracks 24 files under `test/goldens/failures/` (commit `436aa35d`, team agent goldens). They are outside this unit's write set, so they were left alone; the integrator should `git rm` them (TEST-12).
  3. The task's copy line says `app_en.arb` AND `app_ar.arb`; the later owner decision (2026-09-27) drops Arabic, so new copy is in `app_en.arb` only (R15: later owner decision wins).
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - `statesMissing` "returning from Tailscale (auto re-check)" → done: re-check on resume plus the "Welcome back" notice now shown under the steps; `test/tailscale_setup_test.dart` "installed is unverified; open and resume preserve the typed address"; golden `servers_tailscale_setup_returned_address_error_*`.
  - `actionsMissing` "pick the computer from peers (not possible; say so)" → done: the field's helper says "OpenCode can’t list the devices on your tailnet. Copy the HTTPS address Tailscale Serve printed."; test "Continue waits for an address and says why; the counter stays hidden".
  - `whenMissing` `network.tailscale` "offers-enable: Play Store via openExternalLink" → done: the app step's person action "Get Tailscale" goes through `openExternalLink`; test "missing app offers official install with external host review and recheck".
  - `couldBeAutomatic` "yes: re-check the app on resume" (element `tailscale-setup-step1`) → done (already present; kept and tested).
  - Proposal rationale "numbered steps with KitStatusMark, one pinned Continue disabled with a reason, prose into Details" → done: KitChecklist steps under "1." and "2." section labels, `KitActionBlock` primary disabled with `tailscaleSetupContinueReason`, VPN handoff/address rules/Serve/recovery folded under `KitDetailsFold`.
  - Element notes: "'34/2048' counter" → KitField shows the counter only from 80 % of the limit (test asserts no "/2048"); "two FilledButtons" → one pinned primary; "ExpansionTile" → KitDetailsFold.
- States per page (STATE-20): `tailscale-setup`: checking (golden `checking`), installed/loaded (golden `installed`, `installed_1280x800`), missing (golden + test), unsupported (golden + test), check failed (golden + test), open failed (golden + test), returned + address error (golden + tests), address empty → Continue disabled with reason (test).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/screen-servers-3`, base `4c871866` (`feat/phone-setup-v2`), code head `b738e8e7`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: a rebuild, no bug fix | n/a | PASS |
| 2 | `test/tailscale_setup_test.dart` | passes | 20 passed (`run-2.txt`) | PASS |
| 3 | `test/revamp/screen_servers_3_golden_test.dart` (compare, no update) | passes | 16 passed (`run-3.txt`) | PASS |
| 4 | `flutter analyze` on the three changed Dart files | no issues | No issues found | PASS |
| 5 | Ratchet, design-standard, l10n, glossary, ledger tests | pass | not run (owner decision 2026-09-27: run only the unit's own test files); a grep of the screen finds no framework widget outside the §9.1 allowlist, no `textTheme`, no numeric `EdgeInsets`/`SizedBox`, no `showConfirmSheet`, no `Positioned(` | NOT RUN |
| 6 | `flutter analyze lib test` (whole tree) | clean | not run (owner decision: analyze on your files) | NOT RUN |

## 5. Evidence

- `run-2.txt`: behaviour tests. `run-3.txt`: golden comparison.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | SEC-1 (external links) | `test/tailscale_setup_test.dart` "missing app offers official install…", "official guides fold under Details and open for review" | `run-2.txt` |
  | STATE-8 (disabled says why) | `test/tailscale_setup_test.dart` "Continue waits for an address and says why; the counter stays hidden" | `run-2.txt` |
  | STATE-11 / honest state (VPN never shown done) | goldens `servers_tailscale_setup_installed_*` (VPN step waiting, "Needs you") | `run-3.txt` |
  | DATA-1 (typed address survives) | "installed is unverified; open and resume preserve the typed address" | `run-2.txt` |
  | LAY-4 overflow | "lays out without overflow at Size(…), text 1.0/2.0" (360×800, 412×915, 915×412, 800×1280, 1280×800) | `run-2.txt` |

- Changed test expectations (TEST-19):
  - "late package check after dismissal is ignored": `tester.pageBack()` → `tester.binding.handlePopRoute()` (the kit top bar's Back is not a Material `BackButton`; the behaviour, a system back, is the same). KIT-1.
  - "installed is unverified…": `find.textContaining('Welcome back.')` → `find.textContaining('Welcome back.', findRichText: true)`. KIT-1.
  - "missing app offers…": button label "Get official Android app" → "Get Tailscale" (shorter label so the checklist row fits, contract problem 1). COPY-8.
  - "failed launch gives recovery…": `textContaining('could not open')` → `textContaining('didn’t open')` (the step's short reason, `tailscaleSetupOpenFailed`). STATE-1.
- Goldens added (each opened and looked at): `test/revamp/goldens/servers_tailscale_setup_{installed,checking,missing,unsupported,check_failed,open_failed,returned_address_error}_{dark,light}.png` and `servers_tailscale_setup_installed_1280x800_{dark,light}.png` (16 PNGs). Approved render: `docs/design/visual-language-2026-09-26/Settings.png` (the nearest canvas; there is no Tailscale canvas). Differences: section labels and ground match; the steps and the address field sit on the ground rather than in a surface1 panel (contract problem 1: the checklist's side button overflows inside a panel on 360 dp); no large title (this is a pushed page with the plain title header the map records as its chrome).
- Before and after: `before-tailscale-setup-installed.png`, `before-tailscale-setup-missing.png` (base census `docs/qa/screen-census/g-servers/tailscale-setup--{installed,missing}.png`); `after-tailscale-setup-installed.png`, `after-tailscale-setup-missing.png` (dark goldens) (EVID-10).
- Accessibility: every step row is one semantics node with its step number, state word and action (KitChecklist); section labels are headers; the field's label is its semantic name and the error is a live region (KitField); Continue's disabled reason is its semantic hint; 200 % text checked at all five LAY-4 sizes with no overflow.
- Privacy and security: external links (Play Store, two tailscale.com guides) still go through `openExternalLink` with its host review; no credentials, stored data or notifications changed; the address is never probed, saved or sent by this screen.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/tailscale_setup_test.dart test/revamp/screen_servers_3_golden_test.dart
$F analyze lib/ui/screens/tailscale_setup_screen.dart test/tailscale_setup_test.dart test/revamp/screen_servers_3_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (the real `oc/tailscale` channel, the Play Store handoff and the resume after Tailscale).
- The shared gates (kit ratchet, design standard, l10n coverage, glossary, ledger) and the whole-tree analyze were not run (owner decision 2026-09-27); the integrator regenerates `test/kit_ratchet_baseline.json` and the l10n `_baseline`, and adds this file to `_migrated` in `test/design_standard_test.dart` (R05, R10).
- No Arabic or right-to-left render (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-servers-3` |
| Enabled | Yes (same entry points: servers More setup options, profile editor, settings) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `b738e8e7` |
| Deployed | No | |
| Released | No | |
