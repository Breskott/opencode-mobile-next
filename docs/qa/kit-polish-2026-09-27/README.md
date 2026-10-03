# kit-polish — follow-ups from the kit-gates findings (2026-09-27)

Unit `kit-polish`, branch `revamp/kit-polish`, base `6ea5e83c`
(feat/phone-setup-v2). Source: the findings in
`docs/qa/kit-gates-manifest-2026-09-27/README.md`.

## What changed

### 1. Text at 2.0 cut-offs (kit parts)

- **KitCapabilityExplainer** (through `KitRow.unavailable`, `lib/ui/kit/kit_row.dart`):
  - the reason line no longer truncates: it wraps in full (A11Y-8, STATE-12);
  - from 1.3× text, the enable action moves under the reason, so the reason keeps the row's width. At 1.0 the enable action stays trailing, as before.
  - Spec row updated in `docs/ux-system/kit-api/KitRow.md`.
- **KitTaskCard** (`lib/ui/kit/kit_task_card.dart`): the meta line is now a `Wrap` of pieces. Each piece is its glyph, its words and the separator after it.
  - The line wraps between pieces ("fox ·" / "12 min ago"), never inside "12 min ago" and never between a glyph and its word.
  - A piece wider than the whole line still wraps inside, so nothing truncates.
  - Side effect at 2.0: glyphs and separators are drawn at their own size. The old `WidgetSpan`s had scaled them 2× along with the text.
  - The semantics label is unchanged.
- **KitNav sidebar** (`lib/ui/kit/kit_nav.dart`, `lib/ui/kit/kit_layout.dart`): the sidebar widens with larger text.
  - The new `KitLayout.sidebarWidth(context)` is 296 × the text scale, capped at `sidebarMaxWidth` (400 dp) and at `sidebarMaxShare` (a third of the window). It is still 296 at 1.0.
  - At 2.0 on 1280×800 the sidebar is 400 dp. "New conversation" fits on one line, and the header keeps its words. `KitBottomInset` start follows the same width.
  - Spec updated in `docs/ux-system/kit-api/KitNav.md`.
  - "opencode ·" was cut by the gallery's own fixed-height stand-in header. The gallery now uses the real `KitShellControls(layout: sidebar)`, which merged after the stand-in was written.
- **Galleries:** the text-2.0 shots of all three galleries were regenerated, plus the 1.0 task-card and sidebar shots, which moved with the changes above.
- **Overflow scenes** (`test/kit/kit_overflow_scenes.dart`, appended): `KitRow/unavailable`, `KitCapabilityExplainer/default` (row, host row, state, offer), `KitTaskCard/default` (with `KitPriorityGlyph`) and `KitNav/default` (dock, rail and sidebar by window). All four pass the whole G6 matrix: 9 sizes × 1.0/1.3/2.0 × LTR/RTL.

### 2. G17 "attention roles" baseline entries removed

- `lib/ui/screens/library/integration_tiles.dart`: colours only (R18 owns the rest of the screen).
  - A needs-you state word ("Authentication required", a waiting sign-in) now reads at label weight in the primary tone.
  - The row's `KitNeedsYou` mark alone draws amber (LOOK-4, LOOK-24).
  - A failure keeps the danger tone.
- `lib/ui/screens/provider_quota_screen.dart`: "You've used 80% or more of a Codex limit" is a warning, not a request.
  - It is now a neutral `KitNotice` with the warning glyph. Before, it used `AppStatusTone.attention`.
  - The unused `AppStatusTone` import was dropped.
- Both entries were removed from `test/kit_ratchet_baseline.json`, so the baseline only shrank.

### 3. Report a problem draft key

- `app_diagnostics_screen.dart` now keys its draft with `KitDraft.appWide`, a new documented constant in `lib/ui/kit/kit_sheet.dart`, so the key is `oc.draft.report-problem.app`. Before, it fell back from `profile?.id` to the literal `'app'`.
  - Why app-wide: the report is about the app, and the page also opens with no server (a failure's details).
  - So there is one draft for every entry point, cleared when the report is sent. No profile sweep needs to own it.
  - Before, a draft typed with a server was keyed to that server, and one typed without a server was never swept.
- **G10** (`test/kit/kit_draft_manifest_test.dart`):
  - a `profileId` that falls back to a literal (`?? 'app'`) is now a problem;
  - `KitDraft.appWide` is allowed only for targets listed with a reason in `_appWideDrafts`;
  - a new test checks that each listed target uses it and that no profile sweep takes its key;
  - fixture tests prove the checks.
- `test/app_diagnostics_screen_test.dart` now checks the key is written and then cleared after sending.
- STANDARDS DATA-4 now describes the app-wide case.

### 4. SEC-13 vs KitCodeBlock.md

The docs now match the code: `KitCodeBlock` redacts both on screen and in the copy, through the default `redact: true`. The following were updated:

- `KitCodeBlock.md`: the header note and the "Exact copy" rule;
- the SEC-13 row in `docs/ux-system/revamp/STANDARDS.md`;
- the SEC-13 notes in `KitAction.md` and `KitIconButton.md`, which had said code blocks copy verbatim.

The code did not change.

## Tests

- **New:**
  - `kit_row_test`: the 2.0 reason wraps and enable moves under it; at 1.0 enable stays trailing.
  - `kit_task_card_test` 12: the pieces stay whole at 2.0, at 320 and 412 dp. It failed with the old single-paragraph meta line: "12 min ago" broke at 320 dp.
  - `kit_nav_test`: the sidebar is 400 at 2.0, 325.6 at 1.1 and 300 at 900 dp wide, and the primary sits on one line.
  - G10: the fallback, app-wide and fixture checks. The fallback check was confirmed to fail on the old `?? 'app'` line.
  - `app_diagnostics_screen_test`: the draft key.
  - The 4 G6 scenes.
- **Gates** (run once): kit_ratchet, redaction, ui_glossary, kit_manifest, kit_draft_manifest (26), kit_draft and no_raw_error_text all pass.
- **Existing tests for the changed files:**
  - kit tests (row, task card, nav, board lane, r6, capability explainer, top bar r1, bottom inset, screen, pre-wave tokens, keyboard);
  - library/integrations, provider quota, usage, bug report, failed-job report, home navigation and text_scale_overflow;
  - all 150 golden test files (`test/goldens/**`, `test/revamp/*golden*`).
- **Comparison with base `6ea5e83c`** (in a second worktree, same files, same runner): the failing sets match exactly, so there are no new failures. The base failures are all older than this unit:
  - stale goldens across many screens;
  - `home_navigation_test`;
  - `library_integrations_test`;
  - `provider_quota_screen_test` previews;
  - the G6 manifest problems (KitScrollBehavior, KitNumberFormatter, KitLogBuffer);
  - `kit_top_bar_r1` sidebar_296;
  - `kit_screen` and `kit_board_lane loaded 1280 dark`.
- **Goldens this unit regenerated**, the ones that passed on base and changed here:
  - the kit galleries: capability explainer text2 ×4, task card ×12, nav sidebar ×4 and board lane text2 ×4;
  - `team_board_working_1280x800` ×2;
  - `library_integrations_{loaded, loaded_1280x800, mcp, mcp_menu, sign_in_sheet}` ×10;
  - `slice_p54_codex_alert` ×2.
- `flutter analyze`: no issues.

## Images

- `text2-phone-before-after.png`: the capability explainer and task card at 412 dp, text 2.0.
- `text2-wide-sidebar-before-after.png`: the sidebar at 1280×800, text 2.0.
- `text2-wide-explainer-taskcard-before-after.png`: the same two parts at 1280×800, text 2.0.
- `sidebar-real-header-1x-before-after.png`: the real header in the sidebar at 1.0.
- `task-card-1x-phone-before-after.png`: the task card at 1.0 on a phone.
- `g17-colours-phone-before-after.png` and `g17-integrations-wide-before-after.png`: the needs-you word colour and the quota warning.

## Still needs a device

- A PC or tablet window at a large system font: check that the wider sidebar reads well beside a two-pane screen.
- The team board at 2.0 on a phone: check that the smaller meta glyphs read well.
