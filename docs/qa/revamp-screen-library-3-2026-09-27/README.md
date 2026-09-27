# revamp-screen-library-3: Revamp library (5 files) (2026-09-27)

## 1. Scope

- Unit: `screen-library-3` (wave 2b, screen-revamp). Finish line: every file in the write set has G1, G2, G7, G16, G17 and G21 counts of zero, is built from kit parts only in the visual language, and each page is handled by its map proposal. Non-goal: no gateway call, controller field or persistence added; the wave-3 merges (team-plugin-sheet into team-home, command-auth-sheet redesign) are not built.
- Files changed: `lib/ui/screens/library/command_auth_sheet.dart`, `lib/ui/screens/library/credential_sheet.dart`, `lib/ui/screens/library/pending_auth_recovery.dart`, `lib/ui/screens/settings/plugins_screen.dart`, `lib/ui/screens/tools_screen.dart`, `lib/ui/screens/library_screen.dart` (one import line removed, see Contract problems), `lib/l10n/app_en.arb` (27 new keys: `commandAuthSheet*`, `credentialSheet*`, `pendingAuthRecovery*`, `toolsScreen*`, `toolsDetail*`), `test/plugins_screen_test.dart`, `test/team_plugins_screen_test.dart`, `test/revamp/screen_library_3_fixtures.dart`, `test/revamp/screen_library_3_test.dart`, `test/revamp/screen_library_3_golden_test.dart`, `test/revamp/goldens/{library,settings}_*.png` (20).
- Pages (map ids): command-auth-sheet, command-auth-sheet-confirm-sheet, credential-management-sheet, credential-management-sheet-remove-sheet, credential-management-sheet-rename-dialog, integrations-forget-pending-auth-sheet, integrations-forget-uncertain-auth-sheet, plugins-settings, team-plugin-sheet, tools, tools-detail-sheet.
- Specs followed: STANDARDS.md §1, MAP-1, §15 (TEST-1, TEST-6, TEST-19, TEST-20), §16; kit-v2 §4.1 (confirm), §4.2 (destructive naming), §4.3 (one details fold), §4.7 (no sheet on a sheet: every confirm raised from a sheet is `showKitConfirm`, which swaps in place), §4.8 (feedback in place: no snackbars left), §9 (kit only); visual-language §4 (row panels), owner rules 2026-09-27 (rethink, no state sections, Arabic dropped).
- Contract problems (PROC-20):
  - `lib/ui/screens/library_screen.dart` is outside the write set, but after the part files stopped calling `showConfirmSheet`, its `import '../widgets/confirm_sheet.dart';` became unused (an analyzer warning). The one line was removed, as screen-library-1 did for the same file. Proposed: part-file units own their library file's import block.
  - The task text asks for `app_ar.arb` entries (R04) while the owner decision of 2026-09-27 drops Arabic; the later owner decision was followed (app_en.arb only).
  - `showKitInputDialog` (kit, not this unit's) misses the first edit: `_lastText` is `late` and is first read inside `_onText`, after the text already changed, so the first keystroke never marks the field edited and a validation reason does not show until the second edit. `test/revamp/screen_library_3_test.dart` "an empty label is refused" types twice and says why. Proposed fix: initialise `_lastText` in `initState`.
  - At the 800x600 test window the AI Team sheet (now a `showKitSheet`) opens as a side panel where `tester.getRect`/`ensureVisible` put the pinned-under-body actions below the viewport (scroll at max, content not translated in the reported transform). At phone size it works. Not proven whether a real pointer misses too; it needs a kit look (`_RenderKitSheetFrame.applyPaintTransform`). The two turn-off tests in `test/team_plugins_screen_test.dart` now use a 412x915 window.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - command-auth-sheet (redesign): statesMissing "signing in over 8 s with Check now", "server went away mid-sign-in", actionsMissing "auto-refresh Providers on success" → deferred, no owner (no wave-3 slice lists this page). Kit-only rebuild of today's layout done: `library_command_auth_sheet_*`.
  - command-auth-sheet-confirm-sheet (merge-into:command-auth-sheet): least change, `showKitConfirm` swapping in place, marked `// revamp: merge-into:command-auth-sheet (no owner)`; test "asks in place, then starts and offers Check and Cancel".
  - credential-management-sheet (fix): statesMissing "one account marked current" → done (row says "Active" only after a server event; nothing is marked while unknown): test "one row per account, no mark while the active one is unknown"; "no accounts" → done (`KitStateView` inline with what to do): code path `credential-empty`; "action failed" → done (`KitNotice` failure with Refresh accounts, and the rename failure stays in its dialog): test "a failed rename keeps the dialog open with the reason". actionsMissing "add another account" → deferred, no owner (the connect-with-key flow lives in `integrations_screen.dart`, screen-library-1's file; the empty state says to sign in again from Providers). couldBeAutomatic "refresh on open and on credential.switched" → already automatic; the standalone Refresh button was removed.
  - credential-management-sheet-remove-sheet (fix): infoMissing "consequence" → done: "Removes Work from this server. Projects that use it will need another Anthropic account.", confirm "Remove Work": test "remove asks with its consequence, then removes", golden `library_credential_management_remove_sheet_*`.
  - credential-management-sheet-rename-dialog (keep): `showKitInputDialog` (counter from the kit field, only near the limit); statesMissing "save failed" → done (onSubmit keeps it open with the reason): test "a failed rename keeps the dialog open with the reason".
  - integrations-forget-pending-auth-sheet (fix): done, "Forget the cloud sign-in?" / "The app stops tracking it on this device. Nothing is cancelled on the server; an unfinished sign-in there expires on its own.": test "the card offers resume, the code, cancel and forget; forget asks first".
  - integrations-forget-uncertain-auth-sheet (merge-into:integrations-forget-pending-auth-sheet): least change, `showKitConfirm`, copy kept (integration_auth_recovery_test asserts it), marked `// revamp: merge-into:integrations-forget-pending-auth-sheet (no owner)`.
  - plugins-settings (fix): statesMissing "a failed plugin's reason and fix on the row" and the rationale's "worded Reload, refresh into the section menu" live in `server_plugins_section.dart` → deferred to slice-P3.1; "send AI Team to the one AI Team page" → deferred to slice-P0.5 / slice-P3.4. actionsMissing "install, enable or disable a plugin", "ask the configuration assistant to add a plugin" → deferred to slice-P3.1. Kit-only page: `settings_plugins_loaded_*`.
  - team-plugin-sheet (merge-into:team-home): least change, kit-only, marked `// revamp: merge-into:team-home (slice-P3.4)`; statesMissing "phone too hot", actionsMissing "Set up AI Team", "open the AI Team page" → deferred to slice-P3.4. The duplicated "Off" over "Off" was removed because the status row now says it once (test "the AI Team sheet says Off once").
  - tools (fix): statesMissing "loading skeleton" → `KitSkeletonRows` (code path), "model has no tools" → `KitStateView` inline with the teaching line (teaching_empty_states_test); the rationale's model line "Claude Sonnet 4 · Anthropic" with Change, one muted count line, description as title and id as supporting, search from 8 tools → done: tests "names the model and provider, and lists callable first", "search appears from eight tools and filters", golden `library_tools_loaded_*`. infoMissing "source MCP server" and actionsMissing "turn a tool or MCP server off" → deferred, no owner (the server reports neither).
  - tools-detail-sheet (fix): infoMissing "plain parameter summary" → done ("Takes" rows: "text · required · …"), JSON under a collapsed Parameter schema fold with its copy: test "the detail sheet says what the tool takes before the JSON", golden `library_tools_detail_sheet_*`.
- Moved or removed (owner rethink rule): Tools lost its two state sections ("Callable by this model" / "Registered, not callable"): one list, callable first, each registered-only row says so. The Tools model header lost the mono `provider/model` id (the picker shows it). The in-header refresh icon of the embedded Tools body is gone (pull to refresh stays; the page's top bar keeps Refresh tools). Manage accounts lost its standalone "Refresh accounts" button (it loads on open and after every change; Refresh sits on the failure notice). The three per-account text buttons became one row menu naming the account ("Use Work", "Rename Work…", "Remove Work"). The copy-schema snackbar, the saved/turned-off snackbars of the AI Team sheet and the "Sign-in complete" snackbar became feedback in place (KitCodeBlock copy check, a `KitNotice` in the sheet, the card's own line).
- States per page (STATE-20): tools: loading (skeleton), empty (no tools, no match), error (`KitStateView.error` with Try again), loaded (golden). credential sheet: loading bar, empty, error notice, loaded (golden). command sheet: idle (golden), pending, complete, failed, expired, scope changed (notices). pending card: loaded (golden). plugins: no server (`KitNotice`), loaded (golden).
- Deferred states (STATE-21): see Map items.

## 2. Builds

- Branch `revamp/screen-library-3`, base `7011dc46`, code head `0d4d1e71`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_library_3_test.dart` | passes | 13 passed | PASS |
| 2 | `test/revamp/screen_library_3_golden_test.dart` | passes after deliberate regeneration | 20 passed | PASS |
| 3 | `test/plugins_screen_test.dart` | passes | 12 passed | PASS |
| 4 | `test/team_plugins_screen_test.dart` | passes | 25 passed, 6 failed: the "manual add › host kind" group looks for `team-host-kind-*` ChoiceChips that shared-team-1 already removed from `team_host_form.dart` on the base (not this unit's change; `grep -rn team-host-kind lib/` finds nothing) | FAIL (pre-existing) |
| 5 | `test/kit_ratchet_test.dart` in write mode, then the baseline restored | no entry left for the five files | none of the five files appear under any gate | PASS |
| 6 | `flutter analyze lib test` | no issues in changed paths | 5 infos, all in other units' test files | PASS |

## 5. Evidence

- `tests.txt`: steps 1 to 3. `team-plugins-screen-test.txt`: step 4.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-1/G16 | ratchet write mode (step 5) | this record |
  | K2 §4.7 | `screen_library_3_test.dart` "asks in place, then starts and offers Check and Cancel" | `tests.txt` |
  | K2 §4.2 | "remove asks with its consequence, then removes" | `tests.txt` |
  | STATE-12 | "a failed rename keeps the dialog open with the reason" | `tests.txt` |

- Changed test expectations (TEST-19): `test/plugins_screen_test.dart` "one Plugins screen" `find.byType(AppBar)` → `find.byType(KitTopBar)` (KIT-1: the kit top bar replaced AppBar). `test/team_plugins_screen_test.dart` disclaimer reads `tester.widget<Text>(…).data` → `tester.widget<KitText>(…).text` (KIT-1); the two "turn off" tests run in a 412x915 window (see Contract problems).
- Goldens (each opened and looked at; new files, no earlier golden of these pages):
  - `test/revamp/goldens/library_tools_loaded{,_1280x800}_{dark,light}.png`: model panel, one count line, one row panel.
  - `library_tools_detail_sheet_*`: description, Takes rows, folded Parameter schema.
  - `library_credential_management_sheet_*`, `library_credential_management_remove_sheet_*`, `library_command_auth_sheet_*`, `library_integrations_pending_auth_*`, `settings_plugins_loaded{,_1280x800}_*`, `settings_team_plugin_sheet_off_*`.
  - Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Settings.png` (row panels with section labels: matched by the Plugins page and the Tools list), `Confirm.png` (the remove question: matched, error-filled confirm naming the account). No approved render exists for Tools, the credential sheet or the sign-in cards.
- Before and after (EVID-10): `before-*.png` from `docs/qa/screen-census/` (base `7011dc46`), `after-*.png` from the new goldens: tools-loaded, tools-detail-sheet, credential-management-sheet, credential-management-sheet-remove-sheet, plugins-settings-loaded, team-plugin-sheet; after only (no before render, the census could not seed them): command-auth-sheet, integrations-pending-auth.
- Accessibility: every action is a `KitButton`/`KitMenuItem` (48 dp) with words naming its object; the account menu has a named tooltip ("Actions for Work"); status is a mark plus a word; the counts line keeps its single combined semantics label; text scale 2.0 not re-checked in this unit.
- Privacy and security: the credential sheet shows only account labels and environment variable names; API keys never reach UI copy, logs or test output (the fixtures hold no secrets; the rename runs inside the dialog and returns only fixed copy on failure). `_integrationSourceFor` still reads the profile password as a local equality token only (unchanged). No URLs are opened by these files.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_library_3_test.dart test/revamp/screen_library_3_golden_test.dart
$F test -j 1 test/plugins_screen_test.dart test/team_plugins_screen_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests not re-run (owner decision 2026-09-27); expected breakage is listed for the integrator: `test/tools_screen_test.dart` "tool search and schema use server-returned truth" (search appears only from 8 tools; the fixture has 2) and "long server descriptions keep parameter schema reachable" (the schema is folded until opened); integrator-owned goldens `test/goldens/plugins_server_{dark,light}.png` (design_standard_test) and `test/goldens/team_discover_plugins_phone_*` will change.
- The side-panel sheet reach at 800x600 (Contract problems) is not proven either way for a real pointer.
- `lib/l10n/app_localizations*.dart` were regenerated locally to build and test, and not committed (integrator regenerates, as for screen-library-1).
- Text scale 2.0 and the 320 dp overflow sizes were not rendered for these pages.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-library-3` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `0d4d1e71` |
| Deployed | No | |
| Released | No | |
