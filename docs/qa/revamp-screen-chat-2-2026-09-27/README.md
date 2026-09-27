# revamp-screen-chat-2: Revamp chat (4 files) (2026-09-27)

## 1. Scope

- Unit: `screen-chat-2` (wave 2b, screen-revamp, tier 1). Finish line: every file in the write set has a G16 count of zero, uses the VL look, and handles its pages by their map proposal (all `fix`). Non-goal: no gateway method, controller field or persistence added (the stop uses the existing `ServerGateway.abort`, the Undo uses the existing `loadSessionNote`/`saveSessionNote`).
- Files changed: `lib/ui/screens/active_context_screen.dart`, `lib/ui/screens/session_note_screen.dart`, `lib/ui/screens/session_relations_screen.dart`, `lib/ui/screens/web_sources_screen.dart`, `lib/l10n/app_en.arb` (62 new keys, English only per the owner decision of 2026-09-27; gen-l10n output not committed, the integrator regenerates), tests `test/active_context_test.dart`, `test/session_note_test.dart`, `test/session_relations_screen_test.dart`, new `test/revamp/screen_chat_2_{fixtures,test,golden_test}.dart` and 22 goldens `test/revamp/goldens/chat2_*.png`.
- Pages (map ids): active-context, active-context-message, session-note, session-note-discard-dialog, session-relations, web-sources.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-20, KIT-22, KIT-23, KIT-25, KIT-26, KIT-28, KIT-33, KIT-34, LOOK-1, LOOK-2, LOOK-5, LOOK-12, LAY-8, STATE-5, DATA-11, MAP-1; kit-v2 §9.1; visual-language §5.
- Contract problems (PROC-20): none.
- New kit parts (KIT-3): none.
- Gate counts for the four files (from `run-ratchet.txt`): every G16, G2, G7, G17 and G21 entry went to 0 (G1 had none). `test/kit_ratchet_test.dart` itself fails on the base in G17 (`lib/ui/widgets/quota_monitor_section.dart`) and G21 (kit files `kit_choice_list`, `kit_task_card`, `kit_markdown`, `kit_board_lane`, `kit_dialog`, `kit_log_panel`, `kit_checklist`); none of those rows is in this unit's files.

### Moved or removed (owner rule 2026-09-27, rethink)

| Page | Item | What happened |
|---|---|---|
| active-context | Chip row of kinds (ran off the edge) | Moved into the search field's Filter menu; the chosen kind shows as a removable chip in words |
| active-context | Engine intro "Active messages returned by the server after its latest compaction…" | Replaced by a plain one-paragraph intro |
| active-context-message | Raw message id as the first line | Moved into Details (KitDetailsFold), last on the page |
| active-context-message | Disclaimer before the content | One muted line after the parts |
| session-note | Spinner inside the disabled Save button | Progress is the screen's loading bar; Save shows why it cannot run in words |
| session-note | Byte counter always shown | Shown only from 80 % of the limit; over the limit it says by how much |
| session-note | "Delete saved note" as accent text that deleted and left the page | Red destructive action that stays on the page and offers Undo |
| session-note | Separate "Refresh saved note" text button under the form | Lives in the notice that says the note changed or failed |
| session-relations | Header row repeating the parent title and "N delegated conversations" | Removed; the group labels say it ("Started from", "3 subagents") |
| session-relations | Per-row ⋮ PopupMenuButton | Long-press/right-click KitRow menu, each item naming the conversation |
| session-relations | "N of M" position line | Removed: children are ordered by urgency (needs you, working, newest first), so a position number would mislead |
| session-relations | Pin failure snackbar | In-page notice with Try again |
| web-sources | "Refresh providers" button above a one-value dropdown | Providers are discovered on open; refresh is offered only in the notice when none are found or discovery failed; one provider is a plain row |
| web-sources | Checkbox review list with "Use selected sources (n)" | Removed the second selection step: what is added is what is returned; each added source has a named remove; pinned primary "Done · N added" |
| web-sources | "Add to review" buttons under each result | Row tap or trailing add button "Add {title} to prompt"; an "Added" mark replaces it |

### Map items (EVID-11)

- active-context · statesMissing "no matches for search" → done: `screen_chat_2_test.dart` "a search with no match says so and clears". infoMissing "plain intro" → done: golden `chat2_active_context_*`. actionsMissing: none. couldBeAutomatic: none.
- active-context-message · proposal "drop the id above Details, disclaimer as one muted line at the end" → done: golden `chat2_active_context_message_*`, `active_context_test.dart` "search, type filter, full preview and copy…" (asserts the id is not shown above the parts). Missing items: none.
- session-note · statesMissing "save failed" → done: `screen_chat_2_test.dart` "a failed save keeps the draft and Try again repeats it"; "too long" → done: "the size shows only near the limit, and too long says by how much". actionsMissing "undo delete" → done: "delete offers Undo, and Undo writes the words back". couldBeAutomatic: none.
- session-note-discard-dialog · infoMissing "body" → done (body and Keep editing): golden `chat2_session_note_discard_*`, `session_note_test.dart` "compact large text scrolls…". Discard is the error-toned confirm (KitConfirmKind.discard).
- session-relations · statesMissing "child needs approval (surface it here)" → done in code (KitNeedsYou mark + "Needs you · open to answer", ranked first from `permissionForSession`/`questionForSession`); not covered by a test or golden (no fixture for a pending permission). infoMissing "child status" → done: `screen_chat_2_test.dart` "one list by urgency…", golden `chat2_session_relations_*`. actionsMissing "stop a child" → done: "a working subagent is stopped by name after a question", "a subagent that is done has no stop".
- web-sources · statesMissing "search failed with retry" and "no results" → done: `screen_chat_2_test.dart` "no results says so; a failed search offers Search again". infoMissing "an 'Added' mark on a result" → done: "a result is added to the prompt, marked Added, and Done returns it", golden `chat2_web_sources_*`. couldBeAutomatic "discover providers on open; hide the picker with one provider" → done (KitPickerRow's single-option form; discovery already ran on open).

### States per page (STATE-20)

- active-context: loading (KitStateView with 8 s escalation; code), loaded (golden), filtered (`active_context_test.dart`), no match (test), empty (`active_context_test.dart` "failed refresh…"), refresh failed over kept rows (same test), changed (`active_context_test.dart` "late context…").
- active-context-message: loaded (golden), changed (`active_context_test.dart`).
- session-note: loading (code), load failed (code), saved (golden), stale review (`session_note_test.dart` "repository replacement…"), save failed (test), near limit / too long (test), deleted with Undo (test), discard (golden).
- session-relations: loading (code), loaded (golden), empty (code: KitStateView inline once), error (code), row menu (golden), stop question (test).
- web-sources: discovering / searching (loading bar), no provider (notice, code), results with Added (golden, test), no results (test), search failed (test), paste-only (test), connection changed (blocked KitStateView; `web_search_test.dart` asserts it, see sharedTestsBroken).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/screen-chat-2`, base `7011dc46` (feat/phone-setup-v2), code head `e2543231`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_chat_2_test.dart` | passes | 10 passed (`run-behaviour.txt`) | PASS |
| 2 | `test/revamp/screen_chat_2_golden_test.dart --update-goldens`, then each image opened | 22 renders, no exceptions | 22 passed (`run-goldens.txt`) | PASS |
| 3 | `test/active_context_test.dart` | passes | 11 passed, 1 skipped (preview capture) (`run-active-context.txt`) | PASS |
| 4 | `test/session_note_test.dart test/session_relations_screen_test.dart` | passes | 22 passed (`run-note-relations.txt`) | PASS |
| 5 | `test/kit_ratchet_test.dart` rows for the four files | every count drops to 0, none rises | all rows `-> 0`; the file fails only on base rows in other files (`run-ratchet.txt`) | PASS |
| 6 | `flutter analyze lib test` | no issues in changed paths | 0 in changed paths; 5 pre-existing `unnecessary_import` infos in other units' tests | PASS |

Not run (owner decision 2026-09-27: only the unit's own files): design-standard, l10n coverage, glossary, ledger tests, `test/web_search_test.dart`.

## 5. Evidence

- Run logs: `run-behaviour.txt`, `run-goldens.txt`, `run-active-context.txt`, `run-note-relations.txt`, `run-ratchet.txt`.
- Changed test expectations (TEST-19):
  - `active_context_test.dart`: count line "2 of 3 messages" → the search field's "2 results"; the kind filter is opened from the Filter menu; `SelectableText` finders → text finders; copy tooltip "Copy" → "Copy Tool output · read" (KIT-22, a named copy); "1 of 1 messages"/"3 of 3 messages" → "1 message"/"3 messages".
  - `session_note_test.dart`: `TextField.readOnly` → `TextFormField.enabled` (KitField), `FilledButton` → `KitButton`; the compact large-text test scrolls to the field first (it now starts below the fold at 1.6x text).
  - `session_relations_screen_test.dart`: title "Subagent conversations" → "Subagents"; "N of M" subtitle → urgency order and "This conversation"; `ListTile` → `KitRow`; the ⋮ menu → long-press menu.
- Goldens (each opened and looked at): `test/revamp/goldens/chat2_active_context{,_1280x800}_{dark,light}.png`, `chat2_active_context_message_{dark,light}.png`, `chat2_session_note{,_1280x800}_{dark,light}.png`, `chat2_session_note_discard_{dark,light}.png`, `chat2_session_relations{,_1280x800}_{dark,light}.png`, `chat2_session_relations_menu_{dark,light}.png`, `chat2_web_sources{,_1280x800}_{dark,light}.png`. Approved render (EVID-12): no canvas in `docs/design/visual-language-2026-09-26/` shows these pages; the rows, panels, top bar and pinned primary follow `Settings.png` and the discard question follows `Confirm.png`: differences none beyond content.
- Before and after (EVID-10, before from the base's screen census): `before-active-context-loaded.png` / `after-active-context-loaded.png`, `before-active-context-message-loaded.png` / `after-…`, `before-session-note-saved.png` / `after-…`, `before-session-note-discard-dialog-confirm.png` / `after-…`, `before-session-relations-loaded.png` / `after-…`, `before-web-sources-reviewed.png` / `after-…`.
- Accessibility: every icon-only control is a KitIconButton with a naming tooltip ("Copy Tool output · read", "Add Testing Flutter apps to prompt", "Remove Release notes from prompt"); every row menu has a label naming its row and its items are semantic custom actions (KitRow); state is a mark plus a word (Working, Done, Needs you, Added); disabled Save carries its reason as visible text; the compact 1.6x/2.0x text tests pass for note and subagents; no Arabic or RTL review (owner decision 2026-09-27).
- Privacy and security: external links still open only through `openExternalLink` (web sources, guarded by the scope check); no credentials, storage keys or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_chat_2_test.dart test/revamp/screen_chat_2_golden_test.dart
$F test -j 1 test/active_context_test.dart test/session_note_test.dart test/session_relations_screen_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The needs-you row on Subagents (a child waiting on a permission or question) has no test or golden.
- The Stop on a subagent was proven against a fake transport only, not a live OpenCode server.
- `test/web_search_test.dart` was not run; it looks for the old widgets ("Add to review", "Use selected sources (1)", a `FilledButton` "Search") and will fail until the integrator updates it.
- `_migrated` in `test/design_standard_test.dart`, the l10n `_baseline` and the ratchet baseline were not updated (shared files, integrator-owned).
- gen-l10n output is not committed; the branch needs `flutter gen-l10n` before it compiles.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-chat-2` |
| Enabled | Yes (pages gated as before by the server's capabilities) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `e2543231` |
| Deployed | No | |
| Released | No | |
