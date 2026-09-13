# UXOC2-TERMUX-01 — managed generation switching

Base:881e0d1. Owner: onboarding_journey. Branch: fix/oc2-managed-switch.

Problem: installed OC1 hid the first-run generation radios; the manager correctly rejected silent generation migration. Users had no discoverable, supported way to try OC2 and return.

Implemented journey: show installed runtime and Try OpenCode2 beta near the top of Android setup. Explicit confirmation explains that this stops the current phone server and any work running there, with separate chats/providers/credentials and shared project files/configuration. Known active local work blocks; saved queues/drafts remain. Recovery is disabled and only the active local connection retires. A separate OC2 profile uses the same managed4096 slot; old profile metadata cannot silently change generation on reconnect.

New OC2 installs reached from OC1 use isolated XDG data/cache/state/config roots, explicit config directory and database beneath /root/.oc-opencode2. Inherited OPENCODE_CONFIG and OPENCODE_CONFIG_CONTENT are removed only on this isolated path. Existing first-run OC2 installs keep their original roots and are not offered a fabricated OC1 return. The isolated-mode marker persists across switches and same-runtime updates/recovery.

The manager stages a missing target binary while preserving the old binary, stores credentials privately by runtime, journals previous/target/phase/operation before stopping the verified managed PID/process group, and commits only authenticated-ready state. Failed/interrupted switches keep explicit retry/return choices. Returning refuses a changed target profile credential; initial switching refuses missing previous profile credentials. No history/provider migration or automatic rollback is claimed.

Validation planned: test/termux_runtime_switch_test.dart, test/managed_runtime_switch_preflight_test.dart, test/termux_setup_screen_test.dart plus existing scripts/recovery/v2 gateway tests. Synthetic captures in this folder cover OC1, isolatedOC2, failure, progress, legacyOC2 and confirmation in normal light/dark and320dp2x text, using actual bundled fonts. Native/provider-free proof is coordinator-owned and separately reported. Final focused gates on pinned Flutter3.47.2/e16cf749ccaa38d7050335ff305def49b1c7c84c:
- termux_runtime_switch_test.dart:12 passed.
- managed_runtime_switch_preflight_test.dart:18 passed (test-double nullable signature corrected before green rerun).
- connection_v2_gateway_test.dart:5 passed.
- termux_scripts_test.dart, termux_recovery_scripts_test.dart, managed_server_recovery_test.dart:58 passed (same manager/controller production source).
- termux_setup_screen_test.dart:42 passed after final compact installed-screen changes.
- Synthetic capture fixture:15 passed and18 files generated before correcting overlay text-scale scope.17 valid PNGs retained; the incorrectly scaled large-confirmation PNG is deliberately omitted.
- Scoped analyzer for the3 production Dart files and4 test/capture files: no issues. Format/diff check clean at gate.

The capture fixture now applies platform text scale to dialogs as well as the page. This2-line evidence-only correction is not yet re-executed because coordinator resumed the native slot. Integration must run `flutter test --no-pub --concurrency=1 tool/capture/termux_runtime_switch_test.dart --plain-name 'managed switch large'` to regenerate all5 large cases and the actual2x confirmation. Real app-builder2x confirmation/switch/return behavior already passes in the42-case UI gate. Do not claim the omitted PNG as inspected evidence.

Visual spot-check inspected final light-oc1, dark-oc2 and large-failed: current generation/status and one primary connection action are clear; switch/return precedes explanatory text;2x recovery actions remain readable and available before long diagnostics. Coordinator independently approved lightOC1/largeOC2 compact layout. First-run checklist/existing-server advice is now collapsed under Setup help for installed users.

Native/proot/provider-free validation, integrated full suite, APK and deployment remain coordinator-owned pending gates. No device-runtime completion claimed by this slice.

Source review: external oc_app-ui-audit-20260909/oc2-setup/switch-independent-review.md. Reviewer ran no checks. No signing, releases, provider configuration changes, real phone service stop or real phone installation in this slice.

Integration capture correction: all5 large cases passed with the fixed platform scale. The actual2x large-confirmation.png is now included; the earlier overlay limitation above is resolved.

Integration copy review: shortened the stop/data-separation disclosure and renamed the action “Switch version”. All 42 setup behavior tests and 15 capture cases passed; the true 320dp/2× confirmation now shows both actions in its initial viewport. Full analyzer passed.
