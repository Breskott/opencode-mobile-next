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

## 3. Dio 5.11.1 through the SDK generator

Changed the pubspec/README generator templates. Used pinned `dart pub get` in a temporary directory containing the SDK manifest and lock; its only resolved-package change was Dio. Copied that **solver-produced** lock back as generator input, then ran `bash tool/sdk/generate.sh`. No generated source or generated pubspec was hand-edited.

The first generation stopped before publishing because the reviewed template edit invalidated the recorded source hash. The independent verifier passes at the original base. Recomputed hashes with `verify_artifacts_independent.dart --print-source-hashes`: only `templates` changed, so only that manifest hash was refreshed. Generation then passed its contract/matrix/hash verifiers, 47 internal SDK tests, analyzer and compiled smoke. Generated API/model/runtime Dart hashes remain identical; no Dart source diff or formatter change was introduced.

Explicit checks in the published `packages/opencode_sdk/`: `dart analyze` **clean**; `dart test --concurrency=1` **47 passed**. Root `flutter pub get` changed only the Dio lock entry for this item.

App command: `flutter test --no-pub --concurrency=1 test/api2_transport_test.dart test/api2_sse_test.dart test/connection_sse_test.dart test/server_probe_test.dart` — **67 passed**. All named files existed.

Device checks owed: sustained paused/large SSE responses, cancellation/reconnect and bounded RSS/socket backpressure across OpenCode/Gas City/quota streams; retain auth-header and diagnostic redaction behavior. Ordinary transport fixtures do not establish the memory improvement on a phone.

## 4. flutter_secure_storage 11.2.0

Updated the exact root pin; the only lock changes are flutter_secure_storage 11.2.0 and its required platform interface 2.1.1. No key names, namespaces, biometric options or credential migration behavior changed.

Command: `flutter test --no-pub --concurrency=1 test/profile_secure_storage_test.dart test/profile_store_test.dart test/external_agent_state_test.dart test/team_control_test.dart test/team_controller_test.dart` — **96 passed**. These cover the review's profile, external-agent and team-store areas. Tests use secure-storage channel mocks or injected memory/failing storage implementations which override the native operations; none relies on an unmocked ProfileStore channel.

Device checks owed: credentials from an existing installation survive upgrade/restart; concurrent store instances; deleting one profile leaves other profiles' credentials intact. This upgrade does not recover credentials already lost when skipping the older major-version migration.

## 5. OpenCode 1 1.18.32

Updated all four active literals: enum, default version, setup fallback and switch-if-missing fallback in `lib/termux/bridge.dart`. Rechecked `lib/builtin/builtin_linux.dart` and `lib/builtin/setup/components.dart`: both inherit `runtime.pinnedVersion`; no separate built-in pin remains. Aligned the built-in setup script's accepted-version fake with 1.18.32; historical/parser/display fixtures keep their historical versions.

Command: `flutter test --no-pub --concurrency=1 test/termux_scripts_test.dart test/termux_runtime_switch_test.dart test/managed_runtime_switch_preflight_test.dart` — **78 passed**. The setup-script fixture was updated but its additional test file was not separately run, following the requested named-test scope. In `packages/opencode_sdk/`, `dart analyze` remains **clean** and `dart test --concurrency=1` gives **47 passed** for the review's SDK checks.

Device checks owed: fresh install and explicit update of an existing install, observed installed version, authenticated chat/SSE reconnect, provider variants and image attachments, Gas City ACP load/resume/fork. Switching to an already-installed runtime does not itself update it.

## 6. Dolt 2.3.5

Downloaded both [arm64](https://github.com/dolthub/dolt/releases/download/v2.3.5/dolt-linux-arm64.tar.gz) and [amd64](https://github.com/dolthub/dolt/releases/download/v2.3.5/dolt-linux-amd64.tar.gz) release archives on 2026-09-27 **before editing pins**. Stream-computed SHA-256 and byte counts matched GitHub's release-asset digest/size; inspected each archive for `dolt-linux-<arch>/bin/dolt`. Both archive downloads were deleted after verification.

| Architecture | Measured bytes | Measured SHA-256 |
|---|---:|---|
| arm64 | 40,789,338 | `9ce70fc81e50139e97758ef7f4dc57e9583e4e5ef05ad75d7535c30caa161387` |
| amd64 | 44,023,897 | `c49d4c3e004cf1581ba0d4a00c5023a26f84eb2ec15d5fe876eed36d5343f463` |

Updated `AiTeamPins.dolt`, both hash/size records and the verification-date comment. Both built-in and Termux flows use these shared upstream Linux pins. Old native manifests are historical and explicitly unread by the current flows; they were not relabeled with Linux artifact hashes. Aligned the Termux AI Team script fixture's version responses; that extra fixture file was not separately run under the requested named-test scope.

Command: `flutter test --no-pub --concurrency=1 test/aiteam_component_test.dart test/builtin_team_test.dart test/builtin_team_hot_test.dart` — **37 passed**.

Device checks owed: actual arm64/proot binary startup, fresh city and copied existing-store reopen, interrupted initialization/restart, claim→close→merge, and database integrity after stop. No Beads/Gas City/schema upgrade is part of this patch.

## 7. Termux Ubuntu Base 24.04.5

Fetched Canonical's [live SHA256SUMS](https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/SHA256SUMS) on 2026-09-27 (HTTP 200, Last-Modified 2026-09-10 16:44:42 GMT), independently of the earlier review. Updated the three Termux archive names, their checksums and the interrupted-install marker. Built-in Kotlin already has the same .5 arm64/amd64 hashes and remains unchanged.

| Image architecture | Verified SHA-256 |
|---|---|
| arm64 | `a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2` |
| armhf | `4fcee4d278f1c5232e085a021a85e4c6cef3853557a88d98ff380b5e5d5841bb` |
| amd64 | `e77b6f10c2590cef872b33ee9f635a0e3fd1f57fb074c0e52b5c7f56147a0c86` |

Command: `flutter test --no-pub --concurrency=1 test/termux_scripts_test.dart test/builtin_linux_test.dart` — initially **61 passed, 1 failed**. The manager-script checksum guard passes at base and correctly detects the intentional OpenCode/Ubuntu pin changes. Reviewed the script diff and updated only the guard's expected hash/comment; script length remains 51,360. Reran only `--plain-name 'shared OpenCode setup script the Termux manager script changes only on purpose'`: **1 passed**. No broad rerun or unrelated failure fix.

Device checks owed: checksum refusal, interrupted extraction recovery, existing-rootfs/project preservation, fresh setup, DNS/CA/apt, node/npm and every local runtime on arm64. A new-image pin does not patch existing userlands; no existing rootfs was modified in this batch.

## Final local checks and limits

Pinned `flutter analyze`: **No issues found** (22.9 seconds). `dart format --language-version=3.10 --output=none --set-exit-if-changed` on all seven changed Dart files: zero formatting changes. `git diff --check`: clean. Verified all requested target versions and checksums/sizes directly against source; root lock changes are limited to mobile_scanner, Dio, flutter_secure_storage and its platform interface. Generated Dart sources are unchanged.

Known pre-existing failures remain: two scanner permission-denial assertions and one local-agent restart-confirmation assertion, each reproduced at original base. One existing shellcheck test skipped because the binary is unavailable. No requested named test file was missing. No full-suite, device/emulator, live-server, native release build, signing or publication claim is made. The temporary baseline worktree and downloaded Dolt archives are removed after verification; raw command logs were kept outside the repository, with the results and artifact provenance recorded here.
