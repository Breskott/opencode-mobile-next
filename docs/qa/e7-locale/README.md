# E7 locale foundation

Finish line: Settings > Appearance can persist System / English / Arabic globally; a saved change updates the app locale and direction without losing the current route, survives restart, and a failed save leaves the previous choice active with a retryable error.

Non-goals: translating the baseline corpus (two separate owners), other new features, provider/server changes, or claiming Arabic complete before the full catalog and final native integration gates.

Ownership: main.dart, connection.dart, locale store/picker, app theme locale adaptation, directional primitives, native locale resources, focused tests/captures. Appearance owner places LanguageSettingsTile(controller:). Root integrates the complete Arabic corpus and performs final cross-page/native verification.

Plan: persist validated locale overrides → bind root locale without replacing navigator → reachable adaptive language sheet with save-failure truth → localize shell copy → verify restart, rapid changes, failures, RTL and 320dp / 2.5x layouts.

Findings: E7-LOCALE-01 app root only supports English; E7-LOCALE-02 no persistent language override; E7-LOCALE-03 display font uses Latin-specific negative tracking; E7-LOCALE-04 startup and desktop command labels bypass localization.

Verification: pending focused slot and complete Arabic corpus. No partial Arabic completion claim.

## Implemented

- Global `oc.appLocale` override: null follows system; supported overrides normalize to `en` / `ar`. Unsupported saved values fall back to system. The profile deletion sweep leaves this global preference alone.
- `ConnectionController.appLocale` publishes only acknowledged saves. Writes serialize; refusal/exception preserves the visible choice and refreshes the preferences cache. A disposed controller does not notify.
- `LanguageSettingsTile(controller:)` opens a scrollable, directional sheet. Closing without selecting preserves the choice; saving disables dismissal/choices, and failure leaves a retryable message. Appearance placement belongs to the appearance branch.
- MaterialApp observes locale changes without replacing its navigator. Flutter's generated supported locales and localization delegates supply locale resolution and root Directionality; no blanket LTR user-content wrapper is introduced.
- Arabic root typography uses platform Arabic-capable sans fallbacks with zero tracking. `TechnicalDirection` explicitly isolates only code/commands/paths/URLs. Desktop shortcut key text retains LTR.
- Startup and desktop shell/palette/help copy is externalized. `messages_ar.json` contains exactly the 43 new keys for root corpus merge. Native widget/shortcut resource strings have Arabic translations and the manifest opts into RTL.

## Focused verification

Pinned Flutter 3.47.2 at the contract path; no analyzer, full suite or native build run in this branch.

- `flutter pub get`, `flutter gen-l10n`: succeeded; generated English output committed. Full Arabic generation is integration-owned.
- `flutter test --no-pub --concurrency=1 test/app_locale_test.dart test/language_picker_test.dart`: 10 passed (`locale-rerun.log`). This supersedes four picker failures in `focused.log` caused by the store eagerly constructing a pending future before the test widget zone; serial writes now initialize lazily.
- `flutter test --no-pub --concurrency=1 test/language_picker_test.dart test/desktop_shortcuts_test.dart`: 19 passed (`picker-desktop-final.log`), including actual shell keyboard routing with the localized command helper.
- Initial `focused.log` also completed all 11 launch-shortcut routing cases successfully, but the mixed run overall failed on the superseded picker cases; it is not recorded as an overall pass.
- Capture run `picker-desktop.log` was interrupted during capture file I/O in the fake test clock. Capture I/O now uses `tester.runAsync`; final two 320dp / 2.5x captures passed (`captures-final.log`). Both PNGs were inspected; they show the scrolled lower choices, as intended by the reachability check.
- Pinned Dart formatting and `git diff --check`: passed. Final const-only cleanup does not change behavior.

## Integration limits

This commit is locale foundation, not complete Arabic support: no partial `app_ar.arb` is added. The production supportedLocales list stays generated from the English-only branch corpus until root merges both Arabic corpus fragments and regenerates. Arabic picker screenshots use a small explicit test delegate; they prove this sheet's RTL layout, not whole-app translation completeness. Capture Arabic uses host DejaVu sans; actual Android font shaping requires native verification.

Root must integrate the Appearance tile placement and complete corpus, then verify actual root Arabic/system resolution, route retention/restart, all-page RTL, TalkBack and native resources. The reader owner supplies ReaderPreferencesScope; root wraps MaterialApp's child after integrating that branch. Native widget/launcher resource labels follow Android's configuration; this slice does not add a separate Android per-app picker or synchronize a Flutter-only override into out-of-process native widgets. That limitation is explicit rather than two independently persisted language settings.
