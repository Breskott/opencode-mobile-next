# Slice provider-truth — 2026-09-29

Evidence: journeys-2064 J5 (P1-4) and J9 (P1-6).

## 1. Provider status from one source (done, tested)

Root cause: Settings > Providers rows read the credential store
(`/provider` "connected" plus the models.dev catalog, hence "Connected · 19/39
models"), while the model picker read the server runtime
(`unloadedProviderIDs`, from `/config/providers`). Anthropic/Google
subscription sign-ins are saved but the pinned server has no loader for them
(docs/qa/codex-oauth-2026-09-29), so the two views contradicted. "Manage
accounts" was a disabled dead end when the server cannot list credentials.

Change (`integration_tiles.dart`, `integrations_screen.dart`, `app_en.arb`):
- A provider in `unloadedProviderIDs` reads "Signed in, but this server can't
  use it" (or "Signed in, not loaded by this server yet" before a reload
  proved it), shows no model count, and its row tap / menu offers "Add an API
  key" (the supported alternative; a key replaces the unusable sign-in).
- "Connected" only for loaded providers.
- The disabled "Manage accounts" item is removed (enabled only when the server
  can list credentials); its unused string is deleted.
- "Reload providers" lives in the model picker (`pickers.dart`, other agent's
  file, not edited): after one reload the picker already switches to the
  "could not load" wording (`unloadedProvidersUnusable`); the Providers page
  now states the same thing plainly with the fix, so the two agree.

Tests: `test/revamp/slice_provider_truth_test.dart` (3; fails on the base:
the strings/params do not exist) plus `screen_library_3_test.dart` (21 pass),
`kit_ratchet_test.dart` pass, whole-project `flutter analyze` clean.

## 2. Manage space button (NOT proven yet)

Static findings from the release APK (build 2064 and the source manifest):
`<application android:manageSpaceActivity=".ManageSpaceActivity">` is present,
the activity is `exported=true`, no permission, default launchMode, namespace
equals applicationId (no suffix on stable), not debuggable or test-only. The
manifest is therefore correct; the cause needs the Settings app on a device.

Blocked: the shared emulator lock `/home/eslam/Storage/tmp/oc-emulator.lock` is
held by an orphaned `sleep 14400` (pid 2483579, its `flock` parent is gone and
no emulator runs), so no emulator session could start. Device proof and any
manifest fix remain to do.
