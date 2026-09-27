# revamp-screen-library-4: Revamp library (4 files) (2026-09-27)

## 1. Scope

- Unit: `screen-library-4` (wave 2b, screen-revamp). Finish line: every file in the write set has a G16 count of zero with its goldens, each page is handled by its map proposal with the wave-2 missing states and actions, and the look is VL. Non-goal: no gateway method, controller field or persistence added; nothing planned for wave 3.
- Files changed: `lib/ui/screens/library/commands_screen.dart`, `references_screen.dart`, `skill_activation.dart`, `skills_screen.dart`; `lib/l10n/app_en.arb` (25 new keys, English only); `lib/ui/screens/library_screen.dart` (two now-unused imports removed, see Contract problems); new `test/revamp/screen_library_4_test.dart`, `test/revamp/screen_library_4_golden_test.dart` and 20 goldens under `test/revamp/goldens/library_{commands,references,skills,skill_sheet}_*`.
- Pages (map ids): `commands` (fix), `references` (fix), `skill-activation-sheet` (fix), `skills` (keep), `skills-preview-sheet` (merge-into:skill-activation-sheet).
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-20, KIT-23, KIT-26, KIT-27, KIT-28, KIT-32, KIT-33, LOOK-1, LOOK-2, LOOK-12, LOOK-21, LAY-6, STATE-3, STATE-8, MAP-1; kit-v2 §9.1; visual-language §5 (rows in a surface1 panel, sheets with icon tile and start-aligned title).
- Contract problems (PROC-20):
  - `lib/ui/screens/library_screen.dart` is not in the write set, but it is the library root of the four part files: once they stopped using `Clipboard` and `FilePreviewBody`, its imports of `package:flutter/services.dart` and `../widgets/file_preview.dart` became unused (analyzer warning). The only change there is deleting those two import lines. Proposed: screen units whose files are `part of` a library get the library root in their write set for import-only edits.
  - The task text asks for `app_ar.arb` entries (R04); the owner decision of 2026-09-27 (later, wins) drops Arabic, so new copy is in `app_en.arb` only.
  - `skills-preview-sheet` is `merge-into:skill-activation-sheet`, but `work-units.json` names no slice that owns the merge (G30 gap). Both pages' files are in this unit, so the merge was done here (one sheet) instead of leaving a `// revamp:` marker.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rule 2026-09-27, rethink):
  - References: the path left the row (it was the second line under every name) and now sits under Details in the reference sheet; a bare tap no longer copies silently with a snackbar, it opens the reference (browse) or adds it to the prompt (picker); "Copy @name" and "Copy path" moved into the row menu and the sheet's primary.
  - Commands: the trailing play icon was removed (it repeated the leading lightning; one run metaphor); "Copy /name" added to the row menu.
  - Skills: the two sheets for one skill became one; the heading that only repeated the sheet title and the YAML front matter are stripped from the formatted view (Raw still shows the whole file).
- Map items (EVID-11):
  - commands: actionsMissing "run in the current conversation directly" → deferred, no owner: this page is the Library tab and has no conversation; running inside a conversation belongs to the conversation's command launcher (`command-launcher-sheet`, owner redesign). statesMissing "empty" → done: `screen_library_4_test.dart` "empty says where commands come from"; "loading skeleton" → done: `KitSkeletonRows` + KitScreen loading bar (`commands-loading`). infoMissing "which agent" → done: "runs with {agent}" in the supporting line, golden `library_commands_loaded_*`; "arguments" → not available in `CommandInfo` (no field), not done.
  - references: actionsMissing "preview the file" → done as the reference sheet (`reference-sheet`, test "say what a reference is and open its details", golden `library_references_sheet_*`). A reference is a folder (OpenCode adds it as a directory part, `docs/opencode-sdk-coverage.md:49`), so a file preview does not apply; browsing its files needs Files to accept a start folder → deferred, no owner. statesMissing "empty with what references are" → done: test "empty says what a reference is", golden `library_references_empty_*`; "loading skeleton" → done (`references-loading`). infoMissing "what a reference is" → done: intro line `references-intro`.
  - skill-activation-sheet: statesMissing "add failed" → done: test "a failed add stays in the sheet and says why", golden `library_skill_sheet_add_failed_*`. Elements: view toggle → KitSegmented (check marks the chosen view; fixes the inverted accent), run-now → KitSwitchRow, add → pinned sheet primary with working state.
  - skills (keep): statesMissing "empty", "loading skeleton" → done (`skills-empty`, `skills-loading`); actionsMissing "ask an agent to write a skill" → deferred, no owner (keep: no behaviour change).
  - skills-preview-sheet (merge): actionsMissing "Use in a conversation" → partly done: "Copy /name" for skills that are slash commands (test "preview: no repeated heading, raw source, copy command"); "Use in a new conversation" (create a conversation, then add the skill) → deferred, no owner (needs a create-then-activate flow with its own failure states).
  - couldBeAutomatic: every element of these pages is "no".
- States per page (STATE-20):
  - commands: loading (skeleton + bar), empty, no match, first load failed (explains, Try again, Report a problem), refresh failed with cached rows (`product-refresh-failed` notice), loaded → tests + goldens `library_commands_loaded_*`, `library_commands_failed_*`.
  - references: loading, empty, first load failed, refresh failed, loaded, details sheet → tests + goldens.
  - skills: loading, empty, first load failed, location changed (chat-scoped), refresh failed, loaded → goldens `library_skills_loaded_*`; skill sheet: preview, add, adding (working primary, switch says why it waits), add failed, unknown result (locked with reason), added elsewhere → tests + goldens.
- Deferred states (STATE-21): none beyond the items above.

## 2. Builds

- Branch `revamp/screen-library-4`, base `7011dc46d22de18f70748c05c466d816647f75ab` (feat/phone-setup-v2), code head `cf8f5eda`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_library_4_test.dart` | passes | 10 passed | PASS |
| 2 | `test/revamp/screen_library_4_golden_test.dart` (after `--update-goldens`, every image opened) | passes | 20 passed | PASS |
| 3 | `test/kit_ratchet_test.dart`, this unit's four files | G1, G2, G7, G16, G17, G21, G48 at 0 | every row for the four files is "-> 0" (`ratchet.txt`) | PASS |
| 4 | `test/kit_ratchet_test.dart`, whole gate | passes | 2 failures, none in this unit's files: G17 `quota_monitor_section.dart`, G21 kit files (`kit_markdown`, `kit_board_lane`, `kit_checklist`, `kit_choice_list`, `kit_dialog`, `kit_log_panel`, `kit_nav`, `kit_task_card`), already on the base | FAIL (not this unit) |
| 5 | `dart analyze` on `library_screen.dart`, `library/`, `lib/l10n`, the two new tests | no issues | No issues found | PASS |

Owner decision 2026-09-27 (speed): no other suites were run.

## 5. Evidence

- `ratchet.txt`: the ratchet lines for this unit's files and the gate results.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-23 (copy without snackbar) | `test/revamp/screen_library_4_test.dart` "say what a reference is and open its details" | run 1 |
  | STATE-3 (error explains, retries) | same file, "a failed first load explains itself and retries" | run 1 |
  | STATE-8 (disabled says why) | same file, "a failed add stays in the sheet and says why" | run 1 |
  | KIT-33 (technical values last, folded) | goldens `library_references_sheet_*`, `library_skill_sheet_*` | run 2 |

- Changed test expectations (TEST-19): none in shared tests (not edited, R08). Shared tests expected to break are listed in the build record's `sharedTestsBroken` (not run: owner decision 2026-09-27).
- Goldens (new, each opened and looked at):
  - `test/revamp/goldens/library_commands_loaded{,_1280x800}_{dark,light}.png`: kit rows with lightning tiles, agent in the supporting line; approved render `docs/design/visual-language-2026-09-26/Settings.png` (row panel reference): differences — no section label and no largeTitle (the pushed page uses the KitTopBar headline title).
  - `library_commands_failed_*`: inline error state with Try again.
  - `library_references_{loaded,empty,sheet}_*`: intro line, rows with chevrons; the sheet with icon tile, start title, Details unfolded with the path, "Copy @platform-docs" primary; approved render `Confirm.png` (sheet reference): differences — no consequences panel (nothing is at stake).
  - `library_skills_loaded{,_1280x800}_*`, `library_skill_sheet_preview_*`, `library_skill_sheet_add_failed_*`: the one skill sheet as preview and as add with the busy failure under the switch.
- Before and after (EVID-10): `before-commands-default.png`, `before-references-default.png`, `before-skills-default.png`, `before-skill-activation-sheet-default.png`, `before-skills-preview-sheet-default.png` (from `docs/qa/screen-census/j2-library/` at base); `after-commands-default.png`, `after-references-default.png`, `after-references-sheet.png`, `after-skills-default.png`, `after-skill-activation-sheet-add-failed.png`, `after-skills-preview-sheet-default.png`.
- Accessibility: every row is a KitRow (48 dp tap target, menu items exposed as semantic custom actions, menu names "Command actions" / "Reference actions"); the Rendered/Raw choice has the semantic name "How to show the skill" and marks the chosen view with a check, not colour; the run-now switch and the disabled primary say why they cannot change ("Adding the skill…", "Check the conversation before trying again."); errors are live regions (KitNotice / KitStateView). Large text: not rendered in goldens this round (not proven).
- Privacy and security: copying goes through KitCopy (redacts known secrets); markdown links in a skill go through KitMarkdown's `openExternalLink` path; no credentials, stored data or notifications changed.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get --offline
$F test -j 1 test/revamp/screen_library_4_test.dart
$F test -j 1 test/revamp/screen_library_4_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/dart analyze lib/ui/screens/library_screen.dart lib/ui/screens/library
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests that touch these screens were not run (owner decision 2026-09-27); `test/library_skills_test.dart` and `test/session_skill_test.dart` are expected to need updates; `test/library_commands_test.dart`, `test/library_refresh_test.dart` and the Skills group of `test/teaching_empty_states_test.dart` should still pass but were not run (see the build record).
- `flutter analyze` on the whole `lib/` and `test/` was not run; only the changed paths.
- 200 % text and the 1280x800 sheet layouts were not rendered.
- The design-standard `_migrated` list and the ratchet baseline were not updated (integrator-owned, R05/R10).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-library-4` |
| Enabled | Yes | no flag |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `cf8f5eda` |
| Deployed | No | |
| Released | No | |
