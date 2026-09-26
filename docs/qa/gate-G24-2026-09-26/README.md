# gate-G24: architecture boundaries (2026-09-26)

## 1. Scope

- Unit: gate `G24` (W1, gate). Finish line: `test/architecture_boundaries_test.dart` passes on today's code and fails when a `lib/ui` file imports `lib/api`/`lib/api2`, gates on `ServerFlavor` (including inside an allowlisted file), grows the flavour allowlist, or adds a notification-posting path. Non-goal: moving any existing `lib/ui` file off `lib/api` or off `ServerFlavor` (no `lib/` product code changed).
- Files changed: `test/architecture_boundaries_test.dart`, `test/architecture_boundaries_baseline.json`, this folder.
- Pages (map ids): n/a: a source-scan gate, no page.
- Specs followed: STANDARDS.md §18.1 row G24, §18.2 "G24 (ratchet)", rules ARCH-1, ARCH-2, ARCH-10; PROC-13 (baseline shrink-only).
- Contract problems (PROC-20): one, resolved here and flagged for the coordinator. ARCH-2 allows "profile-editor code that sets or labels the flavour, each allowlisted with a reason"; the first version of this gate allowlisted three whole files and did not count them, which departed from that wording and hid debt (`servers_screen.dart:318`, the same server-list credentials handling as the baselined `server_switcher_sheet.dart:186` and `phone_setup_start_screen.dart:337`, and `servers_screen.dart:1699`, a password-field behaviour gate). A review caught it. The allowlist is now per declaration (below). Which declarations count as "sets or labels" is a judgement call made here; the coordinator may move entries to debt (a shrink) but not the other way (G31).
- Interpretation notes:
  - ARCH-1 also counts `package:opencode_sdk` (the generated OpenCode 1 client behind `lib/api/`); it is zero today, so it is absolute in practice.
  - ARCH-2 patterns: `ServerFlavor.`, a `.flavor ==`/`!=` comparison (either side, any identifier ending in `flavor`/`Flavor`), `switch (… flavor …)` (how the Dart 3.10 dot shorthand `case .v2:` / `.v2 =>` branches without naming the type), `flavor.name`/`flavor.index`, and `flavor case`.
  - ARCH-2 allowlist: per declaration, not per file. Every `lib/ui` file is scanned. A use inside a member listed in the baseline's `"ARCH-2 allowlist"` (file → `Class.member` → [reason]) is counted in `"ARCH-2 allowlisted"` under `"member: pattern"`; every other use is debt in `"ARCH-2"`. Both ratchet. The enclosing member comes from a brace/paren scan of dart-formatted source (strings blanked, comments stripped), self-tested in "names the declaration that encloses each use"; `ARCH_BOUNDARIES_EXPLAIN=1` prints every use with its line and member.
  - Allowlisted (sets or labels the flavour): `servers_screen.dart` `_ServersScreenState._enterPhoneCredentials` (sets), `_knownOpenCodeGeneration` (list label), `_ProfileEditorScreenState._save` (stores the probed flavour), `_ProbeVerdict.build` (labels the connection-test verdict); `termux_setup_screen.dart` `_ensureLocalProfile` and `_restoreLocalProfileIfMissing` (write the saved profile for the installed runtime); `builtin_server_screen.dart` `_flavor` (the flavour the saved profile gets).
  - Debt in the same files (branches behaviour on the flavour): `servers_screen.dart` `_openCodeServerEntry` (line 318, credentials sheet mode), `_knownOpenCodeFlavor` (feeds the label but also `_needsManagedRuntimeChoice`, so not allowlisted), `_ProfileEditorScreenState._testConnection` (line 1699, password-field focus); `termux_setup_screen.dart` `_localProfile` and `_saveObservedRuntimeVersion`.
  - No exception lives in the test source any more. The flavour allowlist, the ARCH-10 channel/wire owners (`"ARCH-10 wire"`) and the pre-router callers (`"ARCH-10 calls"`) are baseline sections, so G31's "rises or gains a key" check covers them. Allowlist reasons are one-element lists so that G31's flattening (which ignores string leaves but turns list items into keys) sees each entry and reason as a key. Allowlisting a new member needs a new reason key and a new `"ARCH-2 allowlisted"` count key; either alone fails this test (run 3), and both together are a baseline gain G31 rejects.
  - ARCH-10 before slice-P6.7 ("no unit adds another path"): any string literal `'oc/background'`, `'showCodingAlert'` or `'updateLiveStatus'` is counted per `lib` file (today only `lib/background/live_background.dart` and `lib/background/widget_snapshot.dart`), so a constant or variable holding the channel name is caught, not only `MethodChannel('oc/background')`. Uses of `.showCodingAlert`, `.sendTestNotification` and `.publishLiveStatus` are counted with or without `(`, so tear-offs are caught.
  - ARCH-10 from slice-P6.7: the test switches to router mode when `class NotificationRouter` exists in `lib/`; the alert methods (`showCodingAlert`, `sendTestNotification`) are then allowed only in that file, whatever the baseline says (run 4).
  - `publishLiveStatus` decision (recorded in the test header): it updates the ongoing foreground-service status card (`updateLiveStatus`), not an alert that the router dedupes per server or cancels when answered, and slice-P6.7's non-goal rules out a router rewrite beyond dedupe and cancel-on-answer. So it is not forced into the router; in both modes its callers stay on the ratchet (today `lib/state/connection.dart` x1), and no file may add one.
- Review of the first version: 5 findings, all confirmed against the code and fixed, none rejected: (1) whole-file flavour allowlist left 3 files uncounted → per-member allowlist, the rest counted as debt; (2) allowlist, pre-router callers and channel owners were consts in the test → baseline sections; (3) dot-shorthand `switch`, `flavor.name/index` and `flavor case` were not counted → counted and self-tested; (4) ARCH-10 checked only the `MethodChannel('oc/background')` form and `(`-calls, and ignored `publishLiveStatus` → any literal, tear-offs, and `publishLiveStatus` ratcheted; (5) this record called the allowlist settled with no growth probe → contract note above and runs 2 and 3.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a: no page.
- States per page (STATE-20): n/a. Deferred states (STATE-21): none.

## 2. Builds

- Branch `gate/G24`, base `9220f070`, code head `81f6c525` (review fixes on top of `add3a87c`).
- No APK (unit agents do not build).

## 3. Devices

None: tests only (a pure-Dart source scan).

## 4. Runs

All runs at code head `81f6c525`; every probe was removed and the baseline restored afterwards (`git status` clean for `lib/` and the baseline).

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/architecture_boundaries_test.dart` on today's code | passes | 12 passed (6 scanner self-tests, ARCH-1, ARCH-2 debt, ARCH-2 allowlisted, allowlist reasons, ARCH-10 wire, ARCH-10 calls) | PASS |
| 2 | Probes: in `servers_screen.dart`, `if (probed?.flavor == ServerFlavor.v2)` inside the allowlisted `_ProfileEditorScreenState._save` and `if (widget.existing?.flavor == ServerFlavor.v2)` inside `_testConnection`; plus a throwaway `lib/ui/zz_g24_probe.dart` with a `../api/` and a `package:opencode_mobile/api2/` import, `switch (p.flavor) { _ => … }`, `switch (p.serverFlavor) { case _: }`, `p.flavor.name == 'v2'`, `p.flavor case _`, `const _name = 'oc/background'`, a tear-off `final post = live.showCodingAlert;` and `live.publishLiveStatus(null)`, and `ServerFlavor.v2` in a comment | growth inside an allowlisted file fails in both the allowlisted and the debt section; every new shape fails; the comment is not counted | 5 failed: ARCH-1 (`lib/api/` x1, `lib/api2/` x1); ARCH-2 (`servers_screen.dart` `ServerFlavor.` x7 vs 6, `.flavor ==` x5 vs 4; probe `switch (flavor)` x2, `flavor.name/index` x1, `flavor case` x1); ARCH-2 allowlisted (`_ProfileEditorScreenState._save: ServerFlavor.` x4 vs 3, `: .flavor ==` x2 vs 1); ARCH-10 wire (`'oc/background'` x1); ARCH-10 calls (`showCodingAlert` x1, `publishLiveStatus` x1). See `fail-on-violation.txt` | PASS |
| 3 | Baseline probes: a reason for `_ProfileEditorScreenState._testConnection` added to `"ARCH-2 allowlist"` alone; a count `_TermuxSetupScreenState._localProfile: ServerFlavor.` added to `"ARCH-2 allowlisted"` alone | each half of an allowlist addition fails on its own | 2 failed: allowlisted `_testConnection: ServerFlavor.` x1 and `: .flavor ==` x1 (baseline 0); "`_localProfile` … has no reason in "ARCH-2 allowlist"". See `allowlist-growth.txt` | PASS |
| 4 | Throwaway `lib/background/zz_router_probe.dart` declaring `class NotificationRouter` that calls `live.showCodingAlert()`, and one ARCH-1 baseline entry raised by 1 | router mode: today's alert callers fail, the router file and `publishLiveStatus` pass; the raised entry passes and prints the smaller baseline | 1 failed: `lib/state/connection.dart` (`.showCodingAlert`) and `notifications_settings_screen.dart` (`.sendTestNotification`) "only …zz_router_probe.dart (NotificationRouter) may post an alert"; "ARCH-1 counts dropped. Commit the smaller baseline" + JSON. See `router-mode-and-shrink.txt` | PASS |
| 5 | Probes deleted, baseline restored, run 1 again | passes | 12 passed | PASS |
| 6 | `flutter analyze test/architecture_boundaries_test.dart` | no issues | No issues found | PASS |
| 7 | `dart format --language-version=3.10 --set-exit-if-changed` | unchanged | 0 changed | PASS |

## 5. Evidence

- `fail-on-violation.txt`: run 2 output.
- `allowlist-growth.txt`: run 3 output.
- `router-mode-and-shrink.txt`: run 4 output (one invocation).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | ARCH-1 | `test/architecture_boundaries_test.dart` "ARCH-1: lib/ui never imports lib/api/ or lib/api2/" | `fail-on-violation.txt` |
  | ARCH-2 | same file, "ARCH-2: lib/ui never gates on ServerFlavor", "ARCH-2: allowlisted profile-editor uses only shrink", "ARCH-2: every allowlisted member exists and gives a reason" | `fail-on-violation.txt`, `allowlist-growth.txt` |
  | ARCH-10 | same file, "ARCH-10: the oc/background wire names stay with their owners", "ARCH-10: notifications have one posting path" | `fail-on-violation.txt`, `router-mode-and-shrink.txt` |

- Baseline counts (`test/architecture_boundaries_baseline.json`, generated with `ARCH_BOUNDARIES_WRITE=1`):
  - `ARCH-1`: 48 `lib/ui` files, 71 imports (`lib/api/` 63, `lib/api2/` 8, `package:opencode_sdk` 0). Largest: `chat_screen.dart` 6; `activity_screen`, `library_screen`, `session_context_screen`, `settings_screen`, `pickers`, `product_states` 3 each. (STANDARDS §19 row 10 says 51 files; today's branch has 48.)
  - `ARCH-2` (debt): 6 files, 27 uses: `chat_screen.dart` (`ServerFlavor.` 2, `.flavor ==` 2), `phone_setup_start_screen.dart` (1, 1), `phone_server_card.dart` (1, 2), `server_switcher_sheet.dart` (1, 1), `servers_screen.dart` (6, 4), `termux_setup_screen.dart` (4, 2). The new patterns (`switch (flavor)`, `flavor.name/index`, `flavor case`) have no debt today.
  - `ARCH-2 allowlist` / `ARCH-2 allowlisted`: 7 members in 3 files, 25 uses: `servers_screen.dart` 15 (`_ProbeVerdict.build` 6, `_ProfileEditorScreenState._save` 4, `_knownOpenCodeGeneration` 3, `_ServersScreenState._enterPhoneCredentials` 2), `termux_setup_screen.dart` 8 (`_ensureLocalProfile` 5, `_restoreLocalProfileIfMissing` 3), `builtin_server_screen.dart` 2 (`_flavor`). Per file, debt + allowlisted equals the whole-file count the review quoted (servers 16 `ServerFlavor.` + 8 `.flavor ==` + 1 `switch (flavor)`; termux 10 + 4; builtin 2 + 0).
  - `ARCH-10 wire`: `live_background.dart` (`'oc/background'` 1, `'showCodingAlert'` 2, `'updateLiveStatus'` 1), `widget_snapshot.dart` (`'oc/background'` 1).
  - `ARCH-10 calls`: `lib/state/connection.dart` (`showCodingAlert` 5, `publishLiveStatus` 1), `notifications_settings_screen.dart` (`sendTestNotification` 1).
- Baseline format, for G31: every section is `{"<section>": {"<file>": {"<key>": count}}}`, the same file → key → count shape as `test/kit_ratchet_baseline.json`, except `"ARCH-2 allowlist"`, which is file → member → [reason] (a one-string list, so G31's flattening turns each reason into a key). Section names: `ARCH-1`, `ARCH-2`, `ARCH-2 allowlist`, `ARCH-2 allowlisted`, `ARCH-10 wire`, `ARCH-10 calls`. A renamed allowlisted member moves its uses to debt and fails until the coordinator renames the two keys (a `split:`-style change; G31 would otherwise see new keys).
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
- The scan is textual: a flavour check hidden behind a helper (for example a `bool isV2` getter in `lib/state`, or a call such as `_knownOpenCodeFlavor(p) != null` in `servers_screen.dart` `_needsManagedRuntimeChoice`) is not counted; ARCH-2 reviewers still check those.
- The enclosing-member scan assumes dart-formatted, compiling source; exotic headers (a record return type or a `Function` return type before the name) fall back to a less precise name, which can only move a use to debt, not into the allowlist.
- Adjacent-string tricks (`'oc/' 'background'`) and dynamic invocation (`noSuchMethod`, `Function.apply` on a stored name string other than the wire literals) are not detected.
- ARCH-10 recognises the router by `class NotificationRouter` in `lib/`; if slice-P6.7 names it differently, the post-P6.7 mode will not switch on.
- G31 itself was not run against this branch (it is being built in parallel); the claim that it rejects new keys in these sections rests on its generic flattening (`tool/qa/check_ratchets_only_shrink.py` in the G31 worktree), read but not executed here.
- The full repository suite was not run (only this file).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G24` |
| Enabled | Yes: runs with `flutter test` | |
| Verified | tests only | this record |
| Committed | Yes | code head `81f6c525` |
| Deployed | No | |
| Released | No | |
