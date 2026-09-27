# Dependency upgrade execution — 2026-09-27

Base: `e7762e60` on `codex/deps`. Seven items applied in the maintainer's order, one commit per item. Only the pinned Shorebird Flutter 3.47.1 / Dart 3.13.1 tools are used; changed Dart files use `dart format --language-version=3.10`. Focused checks are serial. No device/emulator, native build, signing, push or live-server run is part of this batch.

Per maintainer instruction, candidate focused files run once; failures are compared with the original base in a temporary detached worktree (no stash). Existing failures are documented and left unchanged. This is focused coverage, not a full-suite pass. Runtime/device acceptance remains owed as listed below and in the dependency review.

## 1. mobile_scanner 7.4.2

Updated the exact pubspec pin and lock entry; no unrelated dependency resolution changes. Replaced the obsolete scanner KGP-warning comment with its AGP 9 support status.

Command: `flutter test --no-pub --concurrency=1 test/kit/kit_scanner_test.dart test/pairing_scanner_test.dart`.

Result: **21 passed, 2 failed**. The two pairing-scanner permission-denial tests expect a `Try again` button which the current screen does not render. Both fail identically at base `e7762e60` with mobile_scanner 7.4.0, using the exact failure-name filter in the detached base worktree. No new failure identified; existing assertions/UI left unchanged.

Device checks owed: offline/no-Play-Services QR; denied/in-use camera; rotation (including 180°); background/resume; dispose/re-enter; shrinking; camera/sensor release and KGP warning in a native build.
