# revamp-screen-system-2: Update and feedback notices (2026-09-27)

## 1. Scope

- Unit: `screen-system-2` (wave 2b, tier 1, screen). Finish line: the code-push update and the desktop release are told in the app's one status line (KitStatusLine through the KitScreen status slot) and the bug-report fallback in a kit sheet, with no snackbar left in the three files. Non-goal: `lib/main.dart` wiring (coord-main), a real in-app restart, and the app-wide "Report a problem" hook (`KitReportHook`, coord-main).
- Files changed: `lib/feedback/bug_report.dart`, `lib/update/desktop_release_check.dart`, `lib/update/shorebird_update_notice.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/bug_report_test.dart`, `test/desktop_release_check_test.dart`, `test/shorebird_update_notice_test.dart`, `test/revamp/screen_system_2_golden_test.dart` (new), `test/revamp/goldens/system_*` (12 new PNGs), `tool/capture/census/areas/a_shell.dart` (the two update pages' guards only, TEST-17).
- Pages (map ids): `desktop-release-notice`, `shorebird-update-notice`.
- Specs followed: STANDARDS.md KIT-1, KIT-11, KIT-23, KIT-35, KIT-43, STATE-5, STATE-12, STATE-19, SEC-1, COPY-8, TEST-5, TEST-17, TEST-20; kit-api `KitStatusLine.md` (Replaces: the update and release snackbars, C31), `KitUndo.md` (Non-goals: copy feedback and updates leave through KitCopy / KitNotice / KitStatusLine), `KitScreen.md` (status slot); visual-language 2026-09-26 (solid sheet, status line under the top bar).
- Contract problems (PROC-20):
  - The task list says new copy goes to `app_en.arb` **and** `app_ar.arb`; the later owner decision (2026-09-27) drops Arabic. Followed the owner: English only; generated Arabic falls back to English.
  - The task says `docs/qa/revamp-<unit id>/README.md`; EVID-1 adds the date. Followed EVID-1.
  - `KitStatusScope` says it is "provided once above the Navigator by main.dart". The notices are also above the Navigator, inside `MaterialApp.builder`, and main.dart does not provide a scope yet. They therefore add their condition with `UpdateStatusScope` (in `shorebird_update_notice.dart`), which merges its status into the conditions of any `KitStatusScope` above it. **coord-main:** put main.dart's `KitStatusScope` *above* `ShorebirdUpdateNotice` (or around the `MaterialApp.builder` child before the notices), otherwise a scope placed below the notices would hide their line.
- New kit parts (KIT-3): none. `UpdateStatusScope` is not a UI component (it draws nothing; it composes `KitStatusScope`).
- Map items (EVID-11):
  - shorebird-update-notice · statesMissing "download failed" → done: silent by owner verdict (the download itself is silent), never claims readiness, retries on a later resume; `test/shorebird_update_notice_test.dart` "never claims readiness after a failed download".
  - shorebird-update-notice · statesMissing "restart requested while a message is sending" → deferred to coord-main (no owner for a restart path: the app has no restart facility; see actionsMissing).
  - shorebird-update-notice · actionsMissing "Restart now (after checking nothing is mid-send)" → deferred, no owner. Feasibility check (rule 2): no restart package or API exists in the app; closing the process on Android does not reopen it, so a "Restart" button would be dishonest. The line says instead when the update applies ("It takes effect when you fully close the app and open it again.").
  - shorebird-update-notice · infoMissing "that it applies on next open" → done: supporting line; golden `system_shorebird-update-notice_ready_*`.
  - shorebird-update-notice · infoMissing "what changes" → deferred, no owner (code-push patches carry no release notes).
  - shorebird-update-notice · couldBeAutomatic "download silently; say nothing" (receiving) → done: `test/shorebird_update_notice_test.dart` "downloads silently, then says the update is ready once".
  - shorebird-update-notice · couldBeAutomatic "apply on next cold start and say so once" (got-it) → done: one line per run, Dismiss hides it; "Dismiss hides the line for the rest of the run".
  - shorebird-update-notice · personaNotes newcomer "should not see a tool name" → done: no "Shorebird" in any copy (asserted).
  - shorebird-update-notice · rationale "never covers the pinned action" → done: the line sits in the status slot under the top bar (asserted by position in both notice tests; goldens).
  - desktop-release-notice · infoMissing "what changed" → done: supporting line "The release page lists what changed and has the downloads." and "Open release page"; `test/desktop_release_check_test.dart`.
  - desktop-release-notice · rationale "localise and lift above pinned actions" → done: ARB copy; status line under the top bar.
  - desktop-release-notice · actionsMissing, statesMissing: none in the record.
- States per page (STATE-20): these are overlays, not pages; their states are the line's.
  - shorebird-update-notice: nothing shown (checking, downloading, up to date, unavailable, failed) → tests; ready → test + golden; dismissed → test.
  - desktop-release-notice: nothing shown (not desktop, older/equal, failed check) → tests; available → test + golden; dismissed → test.
  - bug report: opened (nothing in the app) → test; not opened (copied-link sheet) → test + golden.
- Deferred states (STATE-21): "restart requested while a message is sending" → needs a restart facility, no owner.
- Moved or removed (owner rule, rethink):
  - Removed: the "Receiving Shorebird update…" snackbar with a spinner (progress inside a done-with-undo container; owner: silent download).
  - Removed: "Got it" (it did not apply anything; honest-state finding). Replaced by the status line's Dismiss, offered because dismissing changes nothing real.
  - Renamed: "View" → "Open release page" (names what it acts on, COPY-8).
  - Moved: both notices from a bottom snackbar that covered the pinned New conversation to the one status line under the top bar of whichever KitScreen is showing.
  - Bug-report fallback: snackbar → a sheet titled "Report a bug" with a KitNotice and "Copy bug form link".

## 2. Builds

- Branch `revamp/screen-system-2`, base `7011dc46` (feat/phone-setup-v2 when the branch was cut; it has since moved to `3ad112de`), code head `5a42b94d`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/shorebird_update_notice_test.dart` | passes | 5 passed | PASS |
| 2 | `test/desktop_release_check_test.dart` | passes | 13 passed | PASS |
| 3 | `test/bug_report_test.dart` | passes | 8 passed | PASS |
| 4 | `test/revamp/screen_system_2_golden_test.dart` (after `--update-goldens`) | 12 goldens match | 12 passed | PASS |
| 5 | `test/update_channel_platform_test.dart` (shared; constructs `DesktopReleaseNotice` with `messengerKey`) | still compiles and passes | 3 passed | PASS |
| 6 | `flutter analyze` on the changed lib, test and tool files | no issues | No issues found | PASS |
| 7 | Pattern scan of the three write-set files for SnackBar, showSnackBar, MaterialBanner, showConfirmSheet, EdgeInsets, SizedBox, TextStyle, Colors., Positioned, Tooltip, Icon(, Text(, Clipboard, duration:, Curves. | none | none | PASS |

Not run (owner decision 2026-09-27, speed): the ratchet, design-standard, l10n-coverage, glossary and ledger suites. G1 for the three files drops from 1/1, 1/1, 2/2 to 0; G17 "SizedBox numeric" in `shorebird_update_notice.dart` drops 1 → 0; G2 `Clipboard.setData(` in `bug_report.dart` drops 1 → 0 (`launchUrl(` stays 1: the app-authored bug form link). Baselines are the integrator's (R05).

## 5. Evidence

- No fix-with-failing-first: the change replaces presentation; no bug fix claimed.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-35 / STATE-19 | `test/shorebird_update_notice_test.dart` "a higher condition from an outer scope wins the one line" | run 1 |
  | STATE-12 (no silent claim) | `test/shorebird_update_notice_test.dart` "never claims readiness after a failed download" | run 1 |
  | SEC-1 | `test/desktop_release_check_test.dart` "production Open release page uses the external-link confirmation" | run 2 |
  | KIT-23 | `test/bug_report_test.dart` "a failed launch copies the link and says so in a sheet" | run 3 |

- Changed test expectations (TEST-19, category 1: old copy and snackbar containers the kit replaced):
  - shorebird: "Receiving Shorebird update…" shown → nothing shown while downloading (owner verdict); "Shorebird update ready — restart to apply." + "Got it" → "App update ready" + supporting line, Dismiss (KitStatusLine.md Replaces).
  - desktop: "OpenCode … is available." + "View" → "OpenCode … is available" + "Open release page" (COPY-8); the "missing messenger" test is replaced by "Dismiss hides the line for the rest of the run" (the notice no longer needs a messenger); the host now mounts the notice above a KitScreen page.
  - bug report: "Bug report link copied — open it in a browser." snackbar → sheet text and "Copy bug form link"; the copy is asserted on the clipboard channel.
- Goldens added (each opened and looked at), `test/revamp/goldens/`:
  - `system_shorebird-update-notice_ready{,_1280x800}_{dark,light}.png`: the line under the Work top bar, download glyph, Dismiss at the end, pinned New conversation visible.
  - `system_desktop-release-notice_shown{,_1280x800}_{dark,light}.png`: the same line with "Open release page" inline.
  - `system_bug-report_link-copied{,_1280x800}_{dark,light}.png`: bottom sheet on the phone, centred panel at 1280x800, KitNotice with copy glyph, primary "Copy bug form link".
  - Approved render (EVID-12): no VL canvas covers these overlays; the nearest, `docs/design/visual-language-2026-09-26/Main.png`, has no update line. Differences: n/a.
- Before and after (EVID-10): `before-shorebird-update-notice-ready.png`, `before-shorebird-update-notice-receiving.png`, `before-desktop-release-notice-shown.png` (census renders), `after-shorebird-update-notice-ready.png`, `after-desktop-release-notice-shown.png`, `after-bug-report-link-copied.png` (no before render for the bug-report fallback).
- Accessibility: the status line is one live region (kit), Dismiss is a 48 dp labelled control ("Dismiss"), the action is a KitButton; the sheet's KitNotice is a live region and the copy announces "Bug form link copied" once. Text 2.0 not rendered (galleries limited to two sizes by owner decision); the kit's own KitStatusLine and KitSheet galleries cover 200 % text.
- Privacy and security: the release link still passes `_trustedReleaseUri` and, in production, `openExternalLink` (SEC-1). The bug-form link is app-authored and carries version and platform only; it is copied through `KitCopy.copy` (redacting by default).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/shorebird_update_notice_test.dart test/desktop_release_check_test.dart
$F test -j 1 test/bug_report_test.dart test/revamp/screen_system_2_golden_test.dart
$F analyze lib/feedback lib/update test/bug_report_test.dart test/desktop_release_check_test.dart test/shorebird_update_notice_test.dart test/revamp/screen_system_2_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; no live Shorebird patch or GitHub release was used.
- That the line shows in the real app: main.dart mounts the notices above every KitScreen, and the tests reproduce that placement, but the census shots were not re-rendered (coordinator work) and screens not yet on KitScreen show no line.
- The ratchet, design-standard, l10n-coverage, glossary and ledger suites were not run (owner decision); no ledger part entry was added.
- Text 2.0 and RTL renders (Arabic dropped; galleries limited by owner decision).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-system-2` |
| Enabled | Yes (no flag); the line needs a KitScreen on screen | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `5a42b94d` |
| Deployed | No | |
| Released | No | |
