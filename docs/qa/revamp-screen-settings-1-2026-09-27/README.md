# revamp-screen-settings-1: Revamp settings (4 files) (2026-09-27)

## 1. Scope

- Unit: `screen-settings-1` (wave 2b, screen-revamp, tier 1). Finish line: every file in the write set has G1, G16, G7, G17 and G21 counts of zero, Settings is `KitScreen.twoPane` from expanded, and each page is handled by its map proposal in the VL look. Non-goal: the new Settings IA and search (slice-P3.10, slice-P9.4); no gateway call, controller field or persistence was added.
- Files changed: `lib/ui/screens/settings_screen.dart`, `lib/ui/screens/settings/notifications_settings_screen.dart`, `lib/ui/screens/settings/personal_settings_screens.dart`, `lib/ui/screens/saved_permissions_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), tests `test/settings_hub_test.dart`, `test/saved_permissions_screen_test.dart`, `test/theme_packs_test.dart`, new `test/revamp/screen_settings_1_test.dart`, new `test/revamp/screen_settings_1_golden_test.dart` and its 24 goldens in `test/revamp/goldens/settings_*.png`.
- Pages (map ids): settings, saved-permissions, saved-permissions-revoke-dialog, notifications-settings, notifications-settings-quiet-time-dialog, appearance-settings, privacy-settings, privacy-settings-clear-drafts-sheet, privacy-settings-clear-queued-sheet.
- Specs followed: STANDARDS.md MAP-1, KIT-1, KIT-2, KIT-20, KIT-22, KIT-24, KIT-25, KIT-26, KIT-27, KIT-28, KIT-33, KIT-34, KIT-38, LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-12, LOOK-27, LAY-1, LAY-5, LAY-6, LAY-7, LAY-8, STATE-20, STATE-21, TEST-10, TEST-19, TEST-20; kit-v2 §9.1; visual-language §4, §5, §6; KitScreen.md "Panes".
- Contract problems (PROC-20):
  1. {KitSearchField.md "Where it sits" says the field "is on the 16 dp rails (`KitTokens.gutter`)"; `KitScreen(search:)` places it with no gutter and `KitSearchField` adds none, so a pinned search runs edge to edge (see `after-settings-loaded.png`, `after-settings-loaded-1280x800.png`); `search` is typed `KitSearchField?`, so a screen cannot pad it without breaking LAY-6. Proposed: KitScreen pads `search` with `KitTokens.gutter` on both sides (kit-KitScreen follow-up). Blocks: nothing; the look is off until the kit fix.}
  2. {The unit brief says `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 says `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. This record follows EVID-1.}
  3. {The base commit tracks `test/goldens/failures/team_agent_*` PNGs (TEST-12). This unit did not touch them (write set); the integrator should delete them.}
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - settings (proposal `redesign`): kit-only rebuild of today's layout, twoPane from expanded (C37) → done: `test/settings_hub_test.dart` "screen-settings-1: two panes from expanded" (5 tests), goldens `settings_hub_loaded_1280x800_*`. actionsMissing: configuration assistant → deferred to slice-P3.10; jump to and highlight the exact row a search names → deferred to slice-P9.4; undo Show tips again → no owner (no restore API; the row now says "Tips will show again." in place of a snackbar, test "Show tips again says so on its row, not in a snackbar"); Reconnect after Disconnect, reset app settings, move settings to a new phone → deferred to slice-P3.10. statesMissing (redesign: deferred with the structure) → slice-P3.10 (vanished rows, catalog loading shift, health check past 8 s, first run), slice-P9.4 (search misses).
  - saved-permissions (`fix`): KitRow + row menu with revoke, one intro line, "actions" not "grants" → done: `test/saved_permissions_screen_test.dart` group "screen-settings-1" (4 tests), goldens `settings_saved_permissions_{loaded,empty,error}_*`. "(all matching resources)" in mono (honest-state) → done: "a pattern-less action says so in words, not in mono". actionsMissing: undo a revoke → no owner (the gateway has no call to re-add a saved permission; confirmation kept per DATA-11); add a rule ahead of time → no owner (needs a gateway call); switch project → no owner. statesMissing: offline last known list → done (a failed refresh or revoke keeps the list with a `KitNotice.error` and Try again: "failed revocation keeps the grant visible and retryable"); other projects' rules → deferred: needs a per-project list the gateway does not return, no owner. couldBeAutomatic (refresh on open): already loads on open; the bar's refresh stays for PC (no pull gesture).
  - saved-permissions-revoke-dialog (`fix`): the destructive confirm sheet saying the agent will ask again → done: `showKitConfirm(kind: destructive)` with `savedPermissionsRevokeBody`, golden `settings_saved_permissions_revoke_dialog_confirming_*`, test "lists and revokes one exact always allowed action".
  - notifications-settings (`fix`): every row a KitSwitchRow/KitRow/KitPickerRow, mechanics folded into Details → done: `test/revamp/screen_settings_1_test.dart` "how monitoring works is folded into Details", golden `settings_notifications_loaded_*`. actionsMissing: send a test notification, open Android notification settings → already present, kept (keys `notify-send-test`, `notifications-open-settings`). statesMissing: permission denied → present (blocked notice first; the three notifying switches now rest with the reason "Notifications are off for this app"); no other saved servers → done: "no saved servers is said, not an empty section"; background hours left today → deferred: needs the remaining dataSync budget, which `BackgroundLiveController` does not expose, no owner. whenMissing perm.notifications hidden / perm.battery offers-enable → kept. "Move Background to Keep running" and "one name for Keep live" → deferred to slice-P3.10 (they move rows and copy across pages).
  - notifications-settings-quiet-time-dialog (`fix`): says which end it sets, verb on its button → done: `helpText`/`confirmText`, test "the quiet time picker says which end it sets"; start equals end not explained → done: "the same start and end are explained as all day".
  - appearance-settings (`fix`): Language on a kit row, light/dark inline, Animations top-aligned → done: `test/theme_packs_test.dart` group "screen-settings-1: appearance" ("light or dark is one tap on the page", "the language is a picker row with its value", "effects preview glass through the kit tab bar"), golden `settings_appearance_loaded_*`.
  - privacy-settings (`fix`): kit rows, the policy row → done: "the policy is one row away"; results as notices, not snackbars → done: "the delete confirmation carries the counted verb", "a failed delete says so and keeps the drafts". Retitle: the page already reads "Privacy and local data" (`settingsHubPrivacyRow`). actionsMissing: open older drafts, free space from voice models or Ubuntu → deferred: need sizes and actions from other features' stores, no owner. statesMissing: sizes of other local data → deferred, same reason.
  - privacy-settings-clear-drafts-sheet, privacy-settings-clear-queued-sheet (`keep`): kit-only (`showKitConfirm`), with the counted verb → done: "Delete 3 drafts" test, golden `settings_privacy_clear_drafts_sheet_confirming_*`.
- States per page (STATE-20): settings: loaded (phone and twoPane), search results, no match (`KitSearchNoMatch`), health checking (loading bar), health failed (row Try again) → `test/settings_hub_test.dart`, goldens. saved-permissions: loading (`KitSkeletonRows`), empty, error, loaded, refresh or revoke failed (notice on the list), revoking (row button working) → `test/saved_permissions_screen_test.dart`, goldens. notifications: loaded, blocked, saving (loading bar), save failed (notice), check-in on (picker row), quiet hours on / all day, no servers → tests and goldens. appearance: loaded, save failed (notice), system still (line under Animations), Material You unavailable (swatch reason) → `test/theme_packs_test.dart`, `test/appearance_effects_test.dart` (shared). privacy: loaded, nothing stored (rows rest), queue unreadable, delete working (loading bar), delete done/failed (notice) → `test/revamp/screen_settings_1_test.dart`.
- Deferred states (STATE-21): background hours left → needs the dataSync budget, no owner; other projects' rules → needs a per-project list, no owner; other local data sizes → needs other stores' sizes, no owner; hub states → slice-P3.10 / slice-P9.4.

## 2. Builds

- Branch `revamp/screen-settings-1`, base `8dc27c66`, code head `477e2075`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a | New behaviour and a rebuild; no fix of a reported bug | PASS |
| 2 | `test/settings_hub_test.dart` | passes | 20 passed | PASS |
| 3 | `test/saved_permissions_screen_test.dart` | passes | 13 passed | PASS |
| 4 | `test/theme_packs_test.dart` | passes | 11 passed | PASS |
| 5 | `test/session_read_state_test.dart` | passes | all passed | PASS |
| 6 | `test/revamp/screen_settings_1_test.dart` | passes | 7 passed | PASS |
| 7 | `test/revamp/screen_settings_1_golden_test.dart --update-goldens` then looked at | 24 images | 24 written, each opened | PASS |
| 8 | Ratchet counts for the four files (`KIT_RATCHET_WRITE=1`, baseline restored after) | no entry for these files in any gate | none | PASS |
| 9 | `test/kit_ratchet_test.dart` | passes | 2 failures, both outside this unit (G17 `lib/ui/widgets/quota_monitor_section.dart`, G21 kit files `kit_choice_list`, `kit_task_card`, `kit_nav`, ...), present on the base | FAIL (not this unit) |
| 10 | `flutter analyze lib test` | no issues in changed paths | 1 info in `test/goldens/kit/kit_tappable_golden_test.dart` (not this unit) | PASS |

Owner decision 2026-09-27: other suites were not run.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-1, KIT-2 (G1, G16) | ratchet counts, step 8 | none left for the four files |
  | LAY-5 (twoPane) | `test/settings_hub_test.dart` "the groups are the list and a group fills the detail" | step 2 |
  | KIT-34 | "a revoke is said on the page, never in a snackbar"; "Show tips again says so on its row, not in a snackbar"; "the delete confirmation carries the counted verb" | steps 2, 3, 6 |
  | KIT-25 | "the language is a picker row with its value" | step 4 |
  | KIT-24 | "light or dark is one tap on the page" | step 4 |
  | LOOK-27 | "effects preview glass through the kit tab bar" | step 4 |
  | KIT-33 | "how monitoring works is folded into Details" | step 6 |

- Changed test expectations (TEST-19): `test/settings_hub_test.dart`: every `enterText` on the search is followed by `_settleSearch` (the kit field reports a query after `KitMotion.typingSettle`, KIT-20); the 320 dp walk scrolls the hub list, not the first `Scrollable` (the search field is now pinned above it, KIT-20). `test/saved_permissions_screen_test.dart`: a `pumpAndSettle` after `ensureVisible` before tapping revoke (the rows are KitRows in a panel, LAY-6). `test/theme_packs_test.dart`: the harvested Material You swatch is centred before the tap (the grid is `KitSwatchGrid`, KIT-1).
- Goldens changed (each opened and looked at), all new in `test/revamp/goldens/`:
  - `settings_hub_loaded_{dark,light}`, `settings_hub_loaded_1280x800_{dark,light}`: hub as KitRowGroup panels; two panes from expanded; approved render `docs/design/visual-language-2026-09-26/Settings.png`: differences — no largeTitle (the pushed page uses KitTopBar; the shell tab keeps the shell's bar until screen-shell), no attention banner (Settings has no cross-settings condition yet, slice-P3.10), group names and rows are today's IA, the search field runs edge to edge (contract problem 1), values sit under titles instead of at the end (today's supporting lines).
  - `settings_notifications_loaded_{dark,light,1280x800_dark}`, `settings_appearance_loaded_{dark,light,1280x800_dark}`, `settings_privacy_loaded_{dark,light,1280x800_dark}`, `settings_privacy_clear_drafts_sheet_confirming_{dark,light}`, `settings_saved_permissions_{loaded,empty,error}_{dark,light}`, `settings_saved_permissions_loaded_1280x800_dark`, `settings_saved_permissions_revoke_dialog_confirming_{dark,light}`: no approved canvas render for these pages; they follow Settings.png's panels, rows and icon tiles.
- Before and after (EVID-10), dark: `before-settings-loaded.png` / `after-settings-loaded.png` (+ `after-settings-loaded-1280x800.png`), `before-saved-permissions-loaded.png` / `after-saved-permissions-loaded.png`, `before-saved-permissions-revoke-dialog-confirming.png` / `after-...`, `before-notifications-settings-loaded.png` / `after-...`, `before-appearance-settings-loaded.png` / `after-...`, `before-privacy-settings-loaded.png` / `after-...`, `before-privacy-settings-clear-drafts-sheet-confirming.png` / `after-...`. Before images are the base census renders (`docs/qa/screen-census/j1-settings-more/`).
- Accessibility: every icon-only control is a `KitIconButton` with a label (revoke names the action, server Try again, background restart); group and section names are headers (KitRowGroup); disabled switches carry their reason as the supporting line; the effects preview is excluded from semantics; the 320 dp × max text walk of the hub passes; the compact large-text revoke confirmation passes. Arabic not reviewed (owner decision 2026-09-27).
- Privacy and security: no credentials, keys or links changed. The privacy policy row reuses the search index's own entry (`settings-privacy-data-use`). The Always allowed actions pattern is copyable from the row menu (it is not a secret).
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/settings_hub_test.dart test/saved_permissions_screen_test.dart
$F test -j 1 test/theme_packs_test.dart test/session_read_state_test.dart
$F test -j 1 test/revamp/screen_settings_1_test.dart test/revamp/screen_settings_1_golden_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator; the twoPane Settings on a tablet or PC window is proven by widget tests and goldens only.
- Shared tests that exercise these pages were not run (owner decision): likely to need updating by the integrator — `test/goldens/settings_golden_test.dart` (hub, notifications, appearance, privacy images changed), `test/notifications_settings_screen_test.dart` (Switch/ListTile/Dropdown finders, check-in picker is now a sheet), `test/appearance_effects_test.dart` (segmented and preview), `test/profile_monitor_screen_test.dart`, and every test that types into `library-search` and pumps once (`test/search_index_test.dart`, `test/v2_feature_gating_test.dart`, `test/desktop_shortcuts_test.dart`, `test/phone_termux_discovery_test.dart`); `test/design_standard_test.dart` `_migrated` entries for the four files are the integrator's (R10).
- The census guards in `tool/capture/census/` were not re-run.
- A time picker is still the stock `showTimePicker` (KitDateTimePicker has not landed).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-settings-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `477e2075` |
| Deployed | No | |
| Released | No | |
