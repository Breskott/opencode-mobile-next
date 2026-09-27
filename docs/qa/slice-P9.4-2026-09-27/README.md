# slice-P9.4 — Search that finds any setting (2026-09-27)

Finish line: Settings search, the chat command launcher and the desktop palette use one typo-tolerant, bilingual matcher. Rows inside pages are indexed: the four Effects rows, Keep running's battery step and heat pause, and This phone's crash restart. "crash" also finds App diagnostics. Opening a row result brings you to that row: the page scrolls to it, focuses it and briefly marks it. The dead aliases are gone.
Non-goal: the setup assistant (P2). KitSearchField and the Settings hub layout are unchanged (P3.10 owns the hub).

Built on the Codex domain half (`docs/qa/codex-p94-2026-09-27`, `lib/domain/settings_search*.dart`, used unchanged).

## What changed

| Where | Change |
|---|---|
| `lib/ui/search/search_index.dart` | `searchEntries` ranks with `SettingsSearchIndex` over `settingsSearchCatalog`. Every word must match, by the whole word, a prefix or one typo. A whole title ranks first, and a row inside a page beats the broad entry for the whole page on a tie. `SearchEntry.matches` uses the same matcher. `searchIndex` adds each entry's words from every other language, so an Arabic word finds a setting while the app is in English, and the reverse. New entries: `inside-appearance-{vibration,glass,motion,celebrations}`, `inside-keep-running-{battery,thermal}` and `inside-phone-crash-recovery`. `app-diagnostics-entry` now also answers "crash". Each entry carries a stable `SettingsSearchTarget` (page, section and row ids, not routes), so it keeps working when the Settings pages move (P3.10). Row targets open through `_arrive`, which picks the page by target and wraps it in `KitArrivalScope`. `SearchScope.thermalGuard` is read from `thermalGuardSlotProvider`. The heat row shows only while the heat guard runs. The crash-restart row shows only with Termux and a saved server that Termux manages, the same check This phone uses. |
| `lib/ui/kit/kit_arrival.dart` (new kit part) + `docs/ux-system/kit-api/KitArrival.md` | `KitArrivalScope` is a one-shot request for one row id. `KitArrival` marks an anchor row. Once the row is laid out, it scrolls the row into view, sends a TalkBack focus event to it and shows an accent wash (.18) behind it for 2.4 s, which then fades. Under reduced motion it jumps instead of scrolling, drops the wash at once and runs no ticker. A rebuild or remount never repeats the arrival. |
| `personal_settings_screens.dart`, `keep_running_screen.dart`, `widgets/managed_server_recovery_option.dart` | The rows above are wrapped in `KitArrival` (row keys unchanged). Keep running's list is now one Column inside the ListView, so the row a result points to is always laid out. |
| `lib/ui/desktop/shortcuts.dart` | `matchCommands` (Ctrl+K palette) uses the same matcher, so it tolerates typos and ranks results. |
| `lib/main.dart` (one line) | The palette's `SearchScope` passes `thermalGuard`. |
| `lib/l10n/app_{en,ar}.arb` | Dead aliases removed: "font text size" from Appearance, which has no text-size control. "battery" from Notifications and its background section, because battery now belongs to Keep running. "Older drafts" is no longer added to Privacy's keywords in code. |

The chat command launcher (`chat/command_launcher.dart`, not edited) calls `searchEntries`, so it gets the new behaviour without changes.

## Tests

- New: `test/settings_search_rows_test.dart` (7 tests):
  - vibration, heat, crash and battery each lead to the right row;
  - typos and prefixes;
  - bilingual aliases in both display languages;
  - gates: no heat guard, no Termux, and a desktop;
  - the dead aliases find nothing;
  - arrival from Settings search at Appearance › Vibration and Keep running › battery, marked once.
- New: `test/kit/kit_arrival_test.dart` (9 tests):
  - arrival scrolls to the row and marks it;
  - it never repeats;
  - no request, or an unknown row, does nothing;
  - reduced motion;
  - the TalkBack focus event;
  - MOT-7 still samples.
- New: the gallery `test/goldens/kit/kit_arrival_golden_test.dart` (412×915, 1280×800 and 2.0 text, in dark and light), and an overflow scene in `test/kit/kit_overflow_scenes.dart`.
- Existing file, one assertion added: `test/revamp/screen_shell_2_test.dart` checks that the palette finds a command despite one typo.
- `test/search_index_test.dart` had 5 failures before this slice, on base `e1ccfc42`: KitSearchField reports a query only after `KitMotion.typingSettle`, but the tests pumped once. They now pump the settle time, and all pass.
- Passing: `settings_search_domain_test`, `search_index_test`, `settings_search_rows_test`, `kit_arrival_test`, the arrival gallery, `appearance_effects_test`, `revamp/screen_system_1_test` and its golden test, `revamp/screen_shell_1_test` and its golden test, `revamp/screen_shell_2_test`, `revamp/shared_phone_1_test`, `thermal_guard_test`, `team_phone_onboarding_test`.
- These fail on base `e1ccfc42` too, compared in a second worktree, and none of the failures names a file this slice touched:
  - `kit_manifest_test` G4: `KitScrollBehavior`, `KitNumberFormatter` and `KitLogBuffer` are unclassified.
  - `kit_ratchet_test` G17 and G21.
  - `architecture_boundaries_test` ARCH-1.
  - `kit_motion_test`: G8x manifest checks and `KitRowMenu`.
  - `design_standard_test` goldens.
  - `golden_harness_test` G23.
  - `text_scale_overflow_test`: the same 3 failures.
  - `app_exit_recovery_test`: base 3, now 2.
  - `phone_server_screens_test`: 3.
  - `this_phone_screen_test`: Update not offered.
  - Every test this slice added is in the passing list above.
- `flutter analyze`: clean.

## Images (Settings search at 412×915 and 1280×800)

| | Before (base) | After |
|---|---|---|
| "vibration" | `before_search_vibration_*.png`: nothing matches | `after_search_vibration_*.png`: Vibration · In Appearance · Effects |
| "batery" (typo) | `before_search_batery_*.png`: nothing | `after_search_batery_*.png`: Don't optimize battery · In Keep running |
| "heat" | `before_search_heat_*.png` | `after_search_heat_*.png`: nothing, correctly. These shots have no heat guard running, so Keep running hides its switch and search must not offer it. The row itself is covered by the unit tests. |
| arrival | none | `after_arrived_vibration_*.png`: Appearance opened scrolled to Vibration with its wash |

Kit gallery: `test/goldens/kit/kit_arrival_marked_*.png`.

## Still needs a device

- Emulator recording (the programme's proof). Check:
  - with a running heat guard, "heat" opens Keep running at the heat pause;
  - with a Termux-managed server, "crash" opens This phone at "Restart after a crash";
  - TalkBack lands on the arrived row.
- This phone was not edited, because the phone setup area belongs to another agent. Its recovery row is the third child of a lazy ListView under the status card. On a very small screen at large text it could start beyond the cache extent. The arrival then does nothing and the page still opens. Making that list non-lazy is a one-line follow-up for the This phone owner.
