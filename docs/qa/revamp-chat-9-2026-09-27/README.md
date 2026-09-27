# revamp-chat-9: Chat screen build on kit parts (2026-09-27)

## 1. Scope

- Unit: `chat-9` (wave 2c, the last chat unit). Finish line: the chat screen's `build` is a `KitScreen` page (the kit's "KitScaffold") with a `KitTopBar`, the one status line and loading bar, the transcript under a floating glass composer (`KitComposer.layer`), and `KitJumpPill`s; `chat_screen.dart` has no G2, G7, G17 or G21 counts left and one G16 count (`NotificationListener`, the transcript's scroll listener). Non-goal: no gateway, controller or stored-format change; the session menu's own redesign (slice-P10.2) and the status line joining the `KitScreen` slot stay out.
- Files: `lib/ui/screens/chat_screen.dart` (build region, the `_continueOnComputer` host, the session menu switch, `_chatSizeTransition` and the title-bar constants deleted), `lib/ui/screens/chat/{attention_card,composer,message_view}.dart`, `lib/ui/kit/chat/kit_composer.dart` (`layer` takes `above` and any composer widget, and caps the field by the layer's own height), `lib/ui/widgets/session_handoff_sheets.dart` (`exportAvailable` and `continueOnComputerExport` removed), `lib/l10n/app_en.arb` (+2 keys) and generated files, `docs/ux-system/kit-api/KitComposer.md`, `docs/ux-system/revamp/after-chat9.md`, `test/kit_ratchet_baseline.json` (chat_screen lowered only).
- Tests changed on purpose: `stable_chat_layout_test` (AppBar → KitTopBar; a rotated phone is short, so the Tasks shortcut stays an icon), `calm_chat_disclosure_test` (title is the bar's), `chat_transcript_lens_test` (the prose now fills the 700 dp conversation, so the in-progress menu is read from the turn's actions instead of a long-press past the words), the handoff sheet tests (no `exportAvailable`), `goldens/chat_states_golden_test` (+ `chat · find`, all 24 images regenerated after review).

## 2. What changed for the person

- Top bar: `KitTopBar` with the conversation title (up to two lines) and the server as its subtitle when there is more than one. Actions, most urgent first: Stop reading aloud, Tasks · n running, Review changes (demo), Conversation menu. A phone shows the first and puts the rest in the overflow; a PC shows them with words.
- The composer floats: the transcript scrolls under the glass pill, the only glass on the page. Requests, notes, the queue, the draft-save error and the notification offer sit solid on the ground above it.
- The conversation is capped at 700 dp with the 16 dp gutter (VL §5), so prose and composer line up on a PC.
- Find moved from under the bar to over the composer, by the keyboard it is typed with (owner review note); same parts, no new controls.
- Jump to latest / Earlier messages are `KitJumpPill`s that stay mounted and fade (kit motion), clear of the composer.
- Conversation menu: "Export this conversation" on every server. Continue on computer offers Reload when the folder is unknown and reopens with fresh details.
- Draft not saved: "Copy draft" copies the words as written (`KitCopy`, no redaction). Pending photo is a `KitRow`; the note receipt a `KitNotice`.

## 3. Runs (base `e1ccfc42` in a second worktree vs this branch)

| File | Base | After |
|---|---|---|
| `test/chat_start_rules_test.dart` | 14 pass | 14 pass |
| `test/stable_chat_layout_test.dart` | 3 pass, 7 fail | 3 pass, 7 fail (same tests; pre-existing `IconButton`/`TextField` casts and the session-menu "Results" reach) |
| `test/goldens/chat_states_golden_test.dart` | 8 pass, 14 fail | 24 pass (regenerated) |
| `test/kit_ratchet_test.dart` | G17, G21 fail | G17, G21 fail, same entries (other files) |
| `test/calm_chat_disclosure_test.dart` | 3 pass, 1 fail | 3 pass, 1 fail (same) |
| `test/chat_transcript_lens_test.dart` | 11 pass | 11 pass |
| `test/session_handoff_sheet_layout_test.dart` | 8 pass | 8 pass |
| `test/revamp/shared_chat_1_test.dart` | 14 pass | 14 pass |
| `test/chat_menu_hierarchy_test.dart` | 1 pass, 1 fail | 1 pass, 1 fail (same) |
| `test/session_draft_test.dart` | 20 pass | 20 pass |
| `test/transcript_search_test.dart` | 8 pass, 1 fail | same set |
| `test/team_agent_chat_test.dart` | 4 pass, 1 fail | same set |
| `test/composer_layout_test.dart` | 20 pass | 20 pass |
| `test/chat_live_events_test.dart` | 72 pass, 33 fail | same set |
| `flutter analyze` | | no issues |

## 4. Evidence

- `sheet-phone-before-after.png`: transcript dark and light, permission request, and find over the composer (before | after pairs).
- `sheet-1280x800-before-after.png`: the wide window, dark and light.
- Single images: `before-*` (base renders) and `after-*` (this branch's goldens).

## 5. Not done / noted

- The status line still draws itself in the page header; moving it into the `KitScreen` slot changes keys seven test files use (`connection-status-banner`, `chat-status-*`).
- On a PC `KitTopBar` draws itself as a glass toolbar (kit behaviour, VL §6); the chat does not add any other glass.
- KitGlass's shadow renders as a hard offset band in the test renderer (visible under the composer in the 1280 light golden); a kit look matter, unchanged here.
- Not run on a device.
