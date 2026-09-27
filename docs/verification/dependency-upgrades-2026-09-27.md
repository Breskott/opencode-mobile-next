# Dependency upgrade execution — 2026-09-27

Base: `e7762e60` on `codex/deps`. Seven items applied in the maintainer's order, one commit per item. Only the pinned Shorebird Flutter 3.47.1 / Dart 3.13.1 tools are used; changed Dart files use `dart format --language-version=3.10`. Focused checks are serial. No device/emulator, native build, signing, push or live-server run is part of this batch.

Per maintainer instruction, candidate focused files run once; failures are compared with the original base in a temporary detached worktree (no stash). Existing failures are documented and left unchanged. This is focused coverage, not a full-suite pass. Runtime/device acceptance remains owed as listed below and in the dependency review.

## 1. mobile_scanner 7.4.2

Updated the exact pubspec pin and lock entry; no unrelated dependency resolution changes. Replaced the obsolete scanner KGP-warning comment with its AGP 9 support status.

Command: `flutter test --no-pub --concurrency=1 test/kit/kit_scanner_test.dart test/pairing_scanner_test.dart`.

Result: **21 passed, 2 failed**. The two pairing-scanner permission-denial tests expect a `Try again` button which the current screen does not render. Both fail identically at base `e7762e60` with mobile_scanner 7.4.0, using the exact failure-name filter in the detached base worktree. No new failure identified; existing assertions/UI left unchanged.

Device checks owed: offline/no-Play-Services QR; denied/in-use camera; rotation (including 180°); background/resume; dispose/re-enter; shrinking; camera/sensor release and KGP warning in a native build.

## 2. Paseo 0.9.2

Updated `localAgentsPins.paseo_version` and its exact script-test expectation. `clientAppVersion` remains 0.8.0. Kept prior real-daemon verification history separate from the newly reviewed target.

Command: `flutter test --no-pub --concurrency=1 test/local_agent_runtime_test.dart test/paseo_gateway_test.dart test/local_agent_onboarding_test.dart`.

Result: **80 passed, 1 skipped, 1 failed**. Shellcheck is unavailable (existing optional skip). The onboarding restart/stop confirmation test expects the interruption warning to be absent; the warning is present. The exact same test fails at base `e7762e60` with Paseo 0.9.1. No new failure identified; existing UI/test left unchanged.

Device checks owed: explicit install/repair, node-pty loading, authenticated hello, Claude create/send/stream/approve/cancel, history/reconnect, repeated connection teardown and idle CPU/RSS, restart/reboot/stale-PID recovery. Capture the Claude version because repair also updates unpinned Claude Code.
