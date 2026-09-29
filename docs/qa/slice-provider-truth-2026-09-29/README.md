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

## 2. Manage space (proven on emulator-5554, Pixel_6 API 34, build 2065)

Finding: there is no bug. On stock Android 14+ the Settings Storage page has
no button labelled "Manage space": the button labelled "Clear storage" IS the
manage-space entry when the app declares `android:manageSpaceActivity`.
Evidence:
- A manifest-only test app declaring `manageSpaceActivity` (no code) shows the
  same "Clear storage / Clear cache" pair, so the label is the platform's.
- Tapping "Clear storage" on our app opens `.ManageSpaceActivity`
  (`topResumedActivity` = `io.github.eslamasabry.opencode_mobile/.ManageSpaceActivity`):
  `manage-space-opened-from-storage.png` (our page: Export projects first,
  cache-only, Delete everything, sizes). `android-storage-page.png` is the
  Android page it was opened from.
- Manifest checked earlier: attribute present on `<application>`, activity
  exported, no permission, package name resolves (`cmd package resolve-activity`
  finds it). No manifest change was needed, so none was made. The journey
  J9 finding "Manage space not reachable" was a misreading of the label.
- Not tested: OEM Settings (Nubia). If one ignores the attribute the in-app
  path This phone > Export projects remains.

Notes: the manage-space page rendered in a light theme while the system was in
night mode (the page runs its own engine and follows the app's own theme
setting, not the system); not changed here. Emulator session held the shared
lock only for this proof and was killed by exact PID.
