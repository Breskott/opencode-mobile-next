# Termux running-server entry

Finish line: an observed running app-managed Termux server is directly connectable from both welcome and Servers, preserving remote profiles and routing missing credentials directly to the existing password editor.

Non-goal: setup/restart/runtime switching, generic port discovery, Gas City, broad redesign, releases or native bridge rewrites.

The old Servers UI hid OpenCode 2's generic address editor in setup choices and only exposed managed runtime actions through Termux setup. Those address and local-runtime journeys were different. A saved remote profile did not get an independently discovered local-server action.

The new screen-local observation requires Android Termux capabilities, already-granted permission, ready manager state at the authored loopback port, no pending runtime switch, and a live health response. HTTP discovery uses only 127.0.0.1:4096, never follows redirects, has bounded timeouts, and never logs credentials. A 401 proves a live responder, not authenticated health; copy says “Server found” and the explicit action opens credential entry. Healthy v2 responses do not require a version field. Manager status may reconcile stale bookkeeping but no install/start/restart/switch verb is issued.

The entry precedes generic setup choices even when remote profiles exist. Discovery never selects a profile or connects automatically. Connect rechecks; stopped/failed detection cannot invoke connection. A matching loopback runtime profile is reused; a remote profile is never chosen or replaced. Missing/rejected/decryption-lost credentials open the existing profile editor immediately. Save and connect is preserved even for a previously inactive local profile.

Version and observation time are behind Server details. Buttons have 48dp minimum height and wrap at large text sizes. Permission and unavailable states make no running claim and permit a manual retry. Resume and return from setup revalidate. No persistent observation or new storage keys are introduced.

## Validation handoff

Source/diff review and `git diff --check` completed. No Flutter, Dart or native processes were launched by this worker: coordinator owns the serialized check slot. English/Arabic copy is supplied in `termux-running-entry-copy.json`; merge it and generate localization before compilation.

Focused checks after localization integration:

```sh
dart format lib/state/termux_running_server.dart lib/ui/widgets/termux_running_server_entry.dart lib/ui/screens/servers_screen.dart test/termux_running_server_test.dart
flutter test --concurrency=1 test/termux_running_server_test.dart test/server_profile_editor_test.dart test/managed_server_health_test.dart test/termux_setup_screen_test.dart
flutter analyze
```

The new test file includes an optional screenshot harness for a 390px phone at 1x and 2x text. To capture while running that file:

```sh
flutter test --concurrency=1 --dart-define=TERMUX_ENTRY_CAPTURE_DIR=/tmp/termux-running-entry-captures test/termux_running_server_test.dart
```

Tests/captures are authored but not yet executed. Real Termux permission, manager and authenticated-server behavior remains a coordinator device check; no fake screenshot is claimed as device verification. No server or credential was accessed during implementation.

## Discovery lifetime correction

Coordinator integration ran the initial 15 running-server tests successfully but exposed pending five-second discovery timers in all nine existing profile-editor tests. Discovery now owns cancellable deadlines instead of `Future.timeout`: widget disposal cancels them immediately, closes the production Dio request, and prevents late capability/status replies from starting another stage. Native method-channel operations already submitted cannot be recalled; they remain read-only and their late replies are ignored.

Six new regression cases dispose while capabilities, status, or health are pending, each both without a reply and with a late reply. The no-reply cases deliberately leave the fake platform future unresolved, allowing Flutter's pending-timer invariant to verify cleanup. Editor fixtures now explicitly report that Termux is absent. This correction has source/diff validation only; coordinator must rerun the 21 running-entry and nine editor tests serially.
