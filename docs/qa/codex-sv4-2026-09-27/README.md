# SV4: phone-local platform feasibility and storage API

Date: 2026-09-27. Branch: `codex/sv4`. Base: `643a5104`.

## Scope and finish line

Finish line: expose available phone and built-in host storage through a small,
read-only Dart API with focused behavior tests, document existing thermal hooks,
and record exact prerequisites for each blocked feature.

Non-goals: UI integration, native/channel changes, process control, invented
pairing expiry, release metadata, installer publication, or background polling.

Read set: AGENTS.md; STANDARDS.md sections 2, 3, 13, 15 only; platform, voice,
built-in host, update, pairing, relevant native handlers/manifest, and installer
sources. Three independent read-only checks covered storage/thermal,
updates/sharing, and pairing/installer. The coordinator owns all writes.

Write set: `lib/platform/phone_storage.dart`, `test/phone_storage_test.dart`,
this README, and root `COMMIT_MSG.txt`. No excluded single-owner file, UI file,
Kotlin file, native manifest, or existing channel implementation was changed.

Dependencies: existing `oc/voice.getDeviceInfo` and built-in
`projectStorage` methods, already implemented in both Dart and Kotlin. No new
server authentication or credentials are needed. Acceptance: preserve unknown
versus measured zero, independently handle source failures, avoid implicit host
scans, and perform no probes on unsupported platforms.

## Feasibility and UI hook-up

Local features use platform capabilities and actual readings; no
`ServerCapabilities` flag is added. "Unavailable" below is a handoff decision,
not a newly declared flag or a claim that existing UI has been changed.

| item | server has it? | what you built | capability flag | UI hook for the builder |
|---|---|---|---|---|
| Phone nearly full / free space | No server needed; existing Android private-files filesystem probe | `PhoneStorageService.read()` and absolute warning threshold | `PhoneStorageService.isSupported`; then `pressure != unknown` | Read `availableBytes` and `pressure`; never turn null into zero or display a free-space percentage |
| In-app host storage | No server needed; native read-only project/runtime scan exists | Same service, explicit `includeBuiltinHost: true` | `isSupported`; then `builtinAvailability == available` | Display `builtinHost.runtimeBytes` and `projectsBytes` separately; explicit refresh, no polling |
| Thermal data | No server needed; Android thermal API already connected | Reuse documented existing API, no new adapter | Android target, then `reading.status != ThermalStatus.unknown` | `ThermalBridge.current()` plus `readings()`; cancel subscription when leaving the surface |
| Thermal pause | Existing protection requires loopback Gas City AI Team city/session suspension endpoints | Reuse documented existing guard, no new guard or host pause | Existing guard slot non-null and eligible local AI Team; never assume all hosts supported | Observe `thermalGuardSlotProvider.value` and that guard's notifications; use `enabled`, `setEnabled`, `hold`, `lastReading`, `holds`, `notice`, `dismiss` |
| In-app host runaway | Native source missing; Termux metrics are for a different host | Stopped at feasibility | Unavailable; no flag added | No runaway assertion/action until per-process CPU, ownership and a supported control contract exist |
| In-app host memory trend | Native current RSS/usage source missing | Stopped at feasibility | Unavailable; no flag added | No trend chart from physical device RAM capacity or process count |
| Restart now after patch | Not a server feature; no app/native restart facility | Stopped at feasibility | Unavailable; `supportsCodePush` only gates patch transport | Existing `restartRequired` status can support manual-close guidance; do not label a no-op or exit as restart |
| What changes in a patch | Current update contract has no patch release notes | Stopped at feasibility | Unavailable; no notes flag added | Needs trusted metadata keyed to app, release, track and patch; do not substitute desktop release notes |
| Share a file out | No server needed; outgoing native channel and FileProvider absent | Stopped at feasibility | Unavailable; `ShareIntent.supported` is incoming text only | Needs one owner for Dart + Kotlin + provider declaration/path rules before exposing an outgoing action |
| Pinned Linux service installer | Local helper exists; no verified published immutable helper/checksum contract found | Stopped at feasibility | Unavailable for a verified install action | Needs approved HTTPS artifact and expected SHA-256, including verified downstream downloads; existing UI command was outside write scope |
| Pairing expired code | Current documented producer payload/model has no expiry or expiry failure contract | Stopped at feasibility | Unavailable; QR support is not expiry support | Preserve current invalid/authentication failure semantics; never infer expiry from a rejected password |

## Dart API for the UI builder

New source: [phone_storage.dart](../../../lib/platform/phone_storage.dart).

| API | Contract |
|---|---|
| `PhoneStorageService()` | Uses existing native adapters. Optional `readDeviceInfo`, `readBuiltinStorage`, and `capabilities` arguments are injectable seams; production normally uses defaults. |
| `nearlyFullAtBytes` | Public, configurable inclusive byte threshold; defaults to 1 GiB, rejects negative input. This is an app warning policy, not Android's system low-storage signal. |
| `isSupported` | True on Android, false elsewhere; means a probe can be attempted, not that a particular APK answered it. |
| `Future<PhoneStorageSnapshot> read({bool includeBuiltinHost = false})` | Fresh transient result. No persistence, cleanup, automatic retry, or timers. Callback/native exceptions become unknown data without exposing error text. A host failure does not erase free space and vice versa. |
| `PhoneStorageSnapshot.availableBytes` | Nonnegative bytes available where the app's private files reside, or null. No total-capacity/percentage claim; not remote or Termux filesystem space. |
| `PhoneStorageSnapshot.pressure` / `PhoneStoragePressure` | `unknown`, `nearlyFull` (at or below threshold, including zero), or `aboveThreshold`. Above threshold is not a guarantee an operation will fit. |
| `PhoneStorageSnapshot.builtinHost` | Nullable existing `BuiltinProjectStorage`; `runtimeBytes`, `projectsBytes`, `measuredAtMilliseconds` describe the native scan. Logical sizes, not allocated blocks or total app storage. Invalid negative readings are discarded. |
| `PhoneStorageSnapshot.builtinAvailability` / `BuiltinStorageAvailability` | `notRequested`, `unavailable`, or `available`; a measured empty host remains available. The snapshot's const constructor just holds these values. |

Minimal integration:

```dart
final storage = PhoneStorageService();
final phone = await storage.read();
// Only on the built-in host's storage surface, after choosing that host:
final host = await storage.read(includeBuiltinHost: true);
```

Keep loading/error presentation in the owning controller/kit. Serialize refresh
requests, await each disk walk, ignore results after disposal, and refresh after
cleanup or app resume. Do not call from `build`, poll recursively, or attribute
these readings to a selected remote/Termux server. The existing device probe has
a five-second timeout; native host scans have no cancellation/timeout contract.
The service does not start a background service and makes no lifetime claim.

Thermal hooks already exist in [thermal.dart](../../../lib/platform/thermal.dart)
and [thermal_guard_teams.dart](../../../lib/builtin/thermal_guard_teams.dart).
`current()` provides the initial reading; `readings()` supplies updates.
`ThermalReading.status` may be unknown and `headroom` may be null. Headroom is a
30-second throttling forecast, not degrees Celsius. The existing
`thermalGuardSlotProvider` holds a `ValueNotifier<ThermalGuard?>`; observe slot
replacement and the guard itself, and detach listeners on disposal. Do not
start a second guard. Its pause behavior is limited to eligible local AI Teams;
it does not suspend arbitrary Linux processes or the OpenCode server.

## Evidence and missing prerequisites

- Free-space source: [device.dart](../../../lib/voice/device.dart):82-110;
  `MainActivity.kt:830-840` uses `StatFs(filesDir)` without requesting microphone
  permission. Existing setup preflight already reuses this device probe.
- Host measurement: [builtin_linux.dart](../../../lib/builtin/builtin_linux.dart):108-143,
  260-270; `BuiltinLinux.kt:432-440` and `BuiltinProjectStorage.kt:119-127` provide
  a read-only recursive logical-size scan, avoiding symlink targets and rejecting
  runtime installation. Paths/content never enter the new API.
- Process gap: [local_terminal.dart](../../../lib/builtin/local_terminal.dart):142-153
  and native `LocalTerminal.kt:280-286`, `BuiltinLinux.kt:707-717` provide a process
  count, not the in-app host CPU/RSS source needed for these requests.
  `VoiceDeviceInfo.totalMemoryMb` is capacity, not sampled memory consumption.
- Existing guard: [thermal_guard.dart](../../../lib/builtin/thermal_guard.dart):285-305;
  [thermal_guard_teams.dart](../../../lib/builtin/thermal_guard_teams.dart):35-49,
  110-129, 277-306. Local thermal readings need no server; automatic AI Team
  suspension does use authenticated local team operations.
- Update gap: [shorebird_update_notice.dart](../../../lib/update/shorebird_update_notice.dart):14-20
  offers availability/check/download only. Pinned `shorebird_code_push` 2.0.7's
  cached `Patch` contains only `number`. `AppLifecycle.kt:47-60` exposes launch
  report and keep-alive methods, no restart. A native owner must implement a real
  process/engine restart with both halves together; rebuilding widgets is not
  patch activation. A release owner must provide the notes artifact/contract.
- Sharing gap: [share_intent.dart](../../../lib/platform/share_intent.dart):28-37
  and `MainActivity.kt:122-137` only consume incoming text. The
  [manifest](../../../android/app/src/main/AndroidManifest.xml) has no app-owned
  FileProvider. A future native owner needs a scoped provider, temporary content
  URI grants, correct MIME handling and outgoing channel result semantics;
  no provider-only or Dart-only half was added here.
- Installer gap: [ubuntu-opencode.sh](../../../scripts/host/ubuntu-opencode.sh):75
  executes a mutable downstream installer. Existing
  `lib/ui/screens/host_management_screen.dart:31-33,102-104` references mutable
  master and executes without checking a digest. No publication/checksum entry
  for this helper was found in release workflows. No network publication was
  verified; local Git history is not proof of an approved published artifact.
- Expiry gap: [pairing.dart](../../../lib/state/pairing.dart):4-6,55-70,237-244
  describes and parses `{urls, username, password}`. Authentication rejection
  at 347-358 is not proof of expiry. A producer contract must establish expiry
  fields, time units/clock behavior, backward compatibility and server enforcement
  before an expired-code status can be implemented truthfully.

Contract problems: the requested outgoing share needs Kotlin, explicitly excluded
by this task. Respect the exclusion and stop that slice. The broad "no server
needed" description applies to thermal measurement but not the existing AI Team
pause mechanism. Other missing-source items remain blocked rather than being
represented by speculative adapters.

## Verification and state

- Four focused behavior tests written in
  [phone_storage_test.dart](../../../test/phone_storage_test.dart): threshold and
  unknown/zero behavior; independent failure and invalid readings; unsupported
  platform; existing native adapter calls without microphone permission or cleanup.
- **Not run:** Flutter tests, analyzer, full suite, native build, device checks.
  The user explicitly said Flutter cannot be run and assigned execution to a
  verifier. No test pass or runtime compilation is claimed.
- Pinned Dart formatter ran with `--language-version=3.10` successfully. It
  warned that `package:flutter_lints/flutter.yaml` could not resolve in this
  worktree; formatting is not analyzer verification.
- Static review checked adapter signatures, platform override setter, nullable
  values and allowed write paths. Diff whitespace and relative documentation
  links checked locally.

Verifier commands (not executed here):

```sh
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/phone_storage_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter analyze lib test
```

Implemented: partial requested scope (storage API; existing thermal APIs
documented). Enabled: new storage UI not wired; thermal behavior unchanged.
Verified: formatting/static inspection only; runtime verification pending.
Blocked: host process metrics, general host thermal pause, native restart,
patch notes, outgoing sharing, verified installer, pairing expiry.
Committed: see branch history and root `COMMIT_MSG.txt`; no push requested.
Deployed/released: no.

Security/migration: no new persistence, credentials, profile keys, logs or data
format; therefore no deletion integration or migration required. `KitRedact` is
not needed for this transient numeric-only result. If a future owner persists
diagnostic text, it must pass through `KitRedact` before storage. No background
service or assumption of unlimited Android `dataSync` lifetime is introduced.
