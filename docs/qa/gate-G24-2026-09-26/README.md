# gate-G24: architecture boundaries (2026-09-26)

## 1. Scope

- Unit: gate `G24` (W1, gate). Finish line: `test/architecture_boundaries_test.dart` passes on today's code and fails when a `lib/ui` file imports `lib/api`/`lib/api2`, gates on `ServerFlavor`, or adds a notification-posting path. Non-goal: moving any existing `lib/ui` file off `lib/api` or off `ServerFlavor` (no `lib/` product code changed).
- Files changed: `test/architecture_boundaries_test.dart`, `test/architecture_boundaries_baseline.json`, this folder.
- Pages (map ids): n/a: a source-scan gate, no page.
- Specs followed: STANDARDS.md §18.1 row G24, §18.2 "G24 (ratchet)", rules ARCH-1, ARCH-2, ARCH-10; PROC-13 (baseline shrink-only).
- Contract problems (PROC-20): none. Interpretation notes:
  - ARCH-1 also counts `package:opencode_sdk` (the generated OpenCode 1 client behind `lib/api/`); it is zero today, so it is absolute in practice.
  - ARCH-2 "the flavour allowlist gives reasons": allowlisted files (profile-editor code that sets or labels the flavour) are not counted; every other `lib/ui` file is ratcheted. Allowlist: `servers_screen.dart` (profile editor: detect, store, label), `termux_setup_screen.dart` and `builtin_server_screen.dart` (write the saved profile for the chosen runtime). The four remaining files that branch on the flavour (`chat_screen.dart`, `phone_setup_start_screen.dart`, `phone_server_card.dart`, `server_switcher_sheet.dart`) are baselined debt, not allowlisted.
  - ARCH-10 before slice-P6.7 ("no unit adds another path") is made mechanical as: `MethodChannel('oc/background')` constructed only in `lib/background/live_background.dart` and `lib/background/widget_snapshot.dart`; the wire methods `'showCodingAlert'` and `'updateLiveStatus'` named only in `live_background.dart`; Dart calls to `.showCodingAlert(`/`.sendTestNotification(` only from today's files (`lib/state/connection.dart`, `lib/ui/screens/settings/notifications_settings_screen.dart`), a set that may only shrink. From slice-P6.7 the test switches itself to absolute mode as soon as `class NotificationRouter` exists in `lib/`: those calls are then allowed only from the router's file (proven in run 4).
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a: no page.
- States per page (STATE-20): n/a. Deferred states (STATE-21): none.

## 2. Builds

- Branch `gate/G24`, base `9220f070`, code head `add3a87c`.
- No APK (unit agents do not build).

## 3. Devices

None: tests only (a pure-Dart source scan).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/architecture_boundaries_test.dart` on today's code | passes | 7 passed (3 scanner self-tests, ARCH-1, ARCH-2, allowlist, ARCH-10) | PASS |
| 2 | Throwaway `lib/ui/zz_g24_probe.dart` (relative `../api/` import, `package:opencode_mobile/api2/` import, `ServerFlavor.v2` comparison, `MethodChannel('oc/background')`, `.showCodingAlert(` and `'showCodingAlert'`, plus the same patterns inside a comment) | ARCH-1, ARCH-2 and ARCH-10 fail; the commented patterns are not counted | 3 failed with the expected lines (`"lib/api/" x1`, `"lib/api2/" x1`, `"ServerFlavor." x1`, `".flavor ==" x1`, three ARCH-10 lines); see `fail-on-violation.txt` | PASS |
| 3 | Probe removed, one baseline entry raised by 1 | passes and prints the smaller baseline to commit | "ARCH-1 counts dropped. Commit the smaller baseline" + JSON; see `router-mode-and-shrink.txt` | PASS |
| 4 | Throwaway `lib/background/zz_router_probe.dart` declaring `class NotificationRouter {}` (post-P6.7 mode) | ARCH-10 fails for today's two callers | failed: `lib/state/connection.dart` and `notifications_settings_screen.dart` "posts a notification directly; only …zz_router_probe.dart (NotificationRouter) may"; see `router-mode-and-shrink.txt` | PASS |
| 5 | Probes deleted, baseline restored, run 1 again | passes | 7 passed | PASS |
| 6 | `flutter analyze test/architecture_boundaries_test.dart` | no issues | No issues found | PASS |
| 7 | `dart format --language-version=3.10 --set-exit-if-changed` | unchanged | 0 changed | PASS |

## 5. Evidence

- `fail-on-violation.txt`: run 2 output.
- `router-mode-and-shrink.txt`: runs 3 and 4 (one invocation).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | ARCH-1 | `test/architecture_boundaries_test.dart` "ARCH-1: lib/ui never imports lib/api/ or lib/api2/" | `fail-on-violation.txt` |
  | ARCH-2 | same file, "ARCH-2: lib/ui never gates on ServerFlavor" and "ARCH-2: every flavour allowlist entry exists and gives a reason" | `fail-on-violation.txt` |
  | ARCH-10 | same file, "ARCH-10: notifications have one posting path" | `fail-on-violation.txt`, `router-mode-and-shrink.txt` |

- Baseline counts (`test/architecture_boundaries_baseline.json`, generated with `ARCH_BOUNDARIES_WRITE=1`):
  - ARCH-1: 48 `lib/ui` files, 71 imports (`lib/api/` 63, `lib/api2/` 8, `package:opencode_sdk` 0). Largest: `chat_screen.dart` 6; `activity_screen`, `library_screen`, `session_context_screen`, `settings_screen`, `pickers`, `product_states` 3 each. (STANDARDS §19 row 10 says 51 files; today's branch has 48.)
  - ARCH-2: 4 files, 11 uses: `chat_screen.dart` (`ServerFlavor.` 2, `.flavor ==` 2), `phone_setup_start_screen.dart` (1, 1), `phone_server_card.dart` (1, 2), `server_switcher_sheet.dart` (1, 1). Allowlisted and uncounted: 3 files (reasons in `_flavorAllowlist`).
  - ARCH-10: absolute (no baseline file); caller set frozen at 2 files.
- Baseline format, for G31: `{"ARCH-1"|"ARCH-2": {"<lib/ui file>": {"<pattern>": count}}}`, the same file → pattern → count shape as `test/kit_ratchet_baseline.json`.
- Changed test expectations (TEST-19): none.
- Goldens changed: none. Before and after: n/a: no UI change.
- Accessibility: n/a.
- Privacy and security: ARCH-10 keeps notification posting on the existing native path, whose copy is owned natively (no prompt text on the lock screen). No credentials touched.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/architecture_boundaries_test.dart
# regenerate the baseline after a migration lands (only ever smaller):
ARCH_BOUNDARIES_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/architecture_boundaries_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/architecture_boundaries_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (none needed for a source scan).
- The scan is textual: a flavour check hidden behind a helper outside `lib/ui` (for example a `bool isV2` getter in `lib/state`) or an `openCode2:` boolean derived elsewhere is not counted; ARCH-2 reviewers still check those.
- ARCH-10 recognises the router by `class NotificationRouter` in `lib/`; if slice-P6.7 names it differently, the post-P6.7 mode will not switch on.
- The full repository suite was not run (only this file).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G24` |
| Enabled | Yes: runs with `flutter test` | |
| Verified | tests only | this record |
| Committed | Yes | code head `add3a87c` |
| Deployed | No | |
| Released | No | |
