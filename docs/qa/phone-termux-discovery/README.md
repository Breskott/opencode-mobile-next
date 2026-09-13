# UXTERMUX-01 — Termux is hidden for phone users with remote profiles

Priority P1. Reported by the maintainer on checkpoint724a8bd. Source-confirmed cause: the first-run simplification moved the Android Termux row inside the collapsed Servers → More setup options. More had no Termux destination. Server settings only exposes managed-server controls when `supportsTermux && TermuxBridge.managesServerUrl(activeProfile.baseUrl)`. A remote profile therefore removes the visible management route even though Termux remains a supported phone capability.

Finish line: on Android, a user with a saved remote profile can find and open the existing Termux setup/controls from an obvious entry. Non-goal: installing, restarting or changing a real Termux service, replacing profiles, or redesigning onboarding. Ownership: library_screen.dart (its part files remain untouched), servers_screen.dart, focused tests/captures. No bridge, global state, home or chat changes. Existing localized copy reused; no ARB/output ownership overlap.

Repair: a direct **Termux setup — Run OpenCode on this phone** row appears immediately below More search, before server tools. First-run and saved Servers expose that same route without expanding an advanced group. The duplicate collapsed row is removed. Availability depends on platform `supportsTermux`, not the active remote server capability/URL or installation status. Missing installation belongs to the existing setup flow, rather than hiding its entry. Desktop/iOS do not get an impossible destination. Opening setup does not replace the active remote profile.

Existing destination truth: TermuxSetupScreen._refresh first inspects getCapabilities. It separately handles absent package, incompatible service/protocol, missing permission and available bridge/status. Existing direct setup controls remain responsible for install/permission/start actions. This repair does not infer installation or permission from a visible entry and adds no automatic service command.

Focused validation plan: new phone_termux_discovery tests cover visible/searchable More entry at normal/large text, saved remote Servers direct entry, opening actual missing-install/permission/unsupported-version states, retaining the remote profile and calling only getCapabilities in these states, and desktop/iOS gating. Existing Library/first-run/platform and Termux setup tests cover surrounding routing and installed/setup state behavior.

Matched capture plan: synthetic remote profile https://work.example, same390×844 logical geometry, app theme and1×/2× text for More/Servers/first-run in dark/light. Capture before from724a8bd source and after from this repair with the same fixture, saving source stage in each filename. These are widget renders, not installed APK/native runtime proof.

State: implemented and focused-tested locally; awaiting coordinator integration and device verification. No deployment/release claim.

## Verification results

- Pinned Shorebird Flutter3.47.2, frameworke16cf749cc. Pub get succeeded.
- Focused behavior:44 cases across phone_termux_discovery_test.dart, library_screen_test.dart, first_run_welcome_test.dart and desktop_platform_gating_test.dart. All pass after correcting one new assertion to the destination's existing user-facing unsupported-version copy. Production code did not change after the first behavior run.
- Matched before captures:12 cases pass on checkpoint724a8bd versions of the two owned screen files, restored in a Python finally block. After captures:12 cases pass on repair source. Same synthetic remote profile,390×844 logical geometry, actual app fonts, dark/light and1×/2× text; exported at2×pixel ratio. Source restoration verified by final diff.
- Scoped analyzer clean after adding required test braces and removing a redundant test-only platform override from the capture script; it now asserts the default Flutter test Android capability. No ignores added.
- Personally inspected before/after More light1× and after Servers dark2×. The new Termux row is visible immediately below More search. On saved Servers at2×, its title is complete and its subtitle wraps into two lines; the row is outside the collapsed options and does not overlap adjacent controls.
- Existing termux_setup_screen.dart and MethodChannel implementation unchanged. No new automatic permission/install/start/stop request. Tests exercise actual destination absent-package, permission-needed and incompatible-version states using recorded native inspection doubles; this is not real-device or installed-service verification.

Focused logs are retained outside Git under the shared audit followup folder. Main repo full suite, final integration analyzer and APK/runtime are coordinator-owned gates.
