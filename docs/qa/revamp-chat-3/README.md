# revamp-chat-3: Chat parts, the composer (2026-09-27)

## 1. Scope

- Unit: `chat-3` (wave 2c, tier 3, screen-revamp). Finish line: the chat's composer, its "+" sheet, the prompt editor, the history and saved-prompt sheets and the model shortcuts are built from kit parts only (G1, G16, G7, G2, G17, G21, G48 all 0 for the write set), with the P4.3, P6.6, P7.5, P7.7 and P7.1 items handled where this write set can reach them. Non-goal: changing `chat_screen.dart` (host logic, sheet presentation, queue withdraw calls) or `command_launcher.dart`.
- Files changed: `lib/ui/kit/chat/kit_composer.dart` (additive `hasAttachments`; keyed field slot), `lib/ui/screens/chat/composer.dart`, `prompt_editor.dart`, `prompt_history.dart`, `prompt_stash.dart`, `lib/ui/widgets/model_shortcuts.dart`, `lib/l10n/app_en.arb` (26 new keys, English only per the owner decision of 2026-09-27), `docs/design/ui-ledger/parts/c-chat-compose.json`; tests: `test/composer_desktop_enter_test.dart`, `composer_layout_test.dart`, `composer_paste_test.dart`, `model_shortcuts_test.dart`, `prompt_shelf_test.dart`, `session_draft_test.dart`, new `test/revamp/chat_3_test.dart`, `chat_3_support.dart`, `chat_3_golden_test.dart` and 24 goldens under `test/revamp/goldens/chat_3_*`.
- Pages (map ids): embedded-composer, embedded-model-shortcuts, prompt-editor, prompt-editor-discard-sheet, prompt-history-sheet, prompt-stash-delete-sheet, prompt-stash-sheet, prompt-tools-sheet.
- Specs followed: STANDARDS KIT-1, KIT-2, KIT-8, KIT-15, KIT-20, KIT-25–KIT-28, KIT-33, KIT-34, STATE-7, STATE-8, DATA-1, DATA-11, LAY-8, COPY-30; kit-api KitComposer.md, KitComposerChips.md, KitQueuedMessage.md, KitSheet, KitMenu; visual-language §5 (the glass composer pill), §6.
- Contract problems (PROC-20):
  1. The task's copy rule (R04: en and ar) contradicts the owner decision of 2026-09-27 (Arabic dropped). The later owner decision was followed: `app_en.arb` only.
  2. `KitField.composer` puts `fieldKey` on a `TextFormField`, so every test that reads `tester.widget<TextField>(find.byKey(Key('chat-composer-field')))` casts wrongly. My tests read the inner `TextField`; shared tests are listed in the build record.
  3. `KitSearchField` uses `AppLocalizations.of(context)` (needs the delegates); every other kit part uses `lookupAppLocalizations`. Test apps without delegates crash when the history or saved-prompt sheet opens. My tests add the delegates.
- New kit parts (KIT-3): none. `KitComposer` gained one optional parameter (`hasAttachments`, R11 additive) and a keyed field slot (bug fix below).
- Map items (EVID-11):
  - embedded-composer: one trailing control (mic when empty and idle, Send with text, Stop while busy, Stop + Send) → done, `KitComposer`; `chat_3_composer_*` goldens, `composer_layout_test` "typing updates Send…". Offline Send says it queues → done, `chat_3_test` "offline, Send says…", `session_draft_test` "sending clears the persisted draft". "Choose model" identical to server default → done: `signInNeeded` / `serverDefault` states, `chat_3_test` "with no model signed in…", golden `chat_3_composer_sign_in_*`. Plain Steer/Queue words → done (kit "Send after" / "Add to this turn"; OpenCode 1 says "Sends after this reply", golden `chat_3_composer_busy_*`). Presented model name → done (chip). Mic in the send slot → done. Text-only server "+" rows → done: `KitRow.unavailable` "This server takes text only". Paste-image affordance on phones → deferred (no host signal in this write set).
  - prompt-tools-sheet: most used first (attach, photos, camera, voice), plain names ("Commands and agents", "Save prompt for later", "Notes for this conversation", "More tools") → done, golden `chat_3_tools_sheet_*`. Voice model not installed → deferred to chat-5 (voice state lives in the voice host).
  - prompt-editor: calm editor, Done pinned ("Use in draft") above the keyboard, attachments above the field → done, golden `chat_3_prompt_editor_*`, `chat_3_test` "the prompt editor asks…". Send from the editor → deferred: needs `chat_screen.dart` to act on the result (owner of chat_screen).
  - prompt-editor-discard-sheet: keep → `showKitConfirm`, `chat_3_test`.
  - prompt-history-sheet: one-line intro, whole-row tap, no-match state → done, `chat_3_test` "the history sheet…". "Added to draft · Undo" → deferred: the append happens in `chat_screen.dart` `_reusePrompt` (outside the write set).
  - prompt-stash-sheet: row tap restores, Delete in the row menu with Undo, real empty state, newest first, "Saved prompts" → done, `prompt_shelf_test` "deleting a saved prompt happens at once with Undo…". "Save the current prompt from the empty state" → deferred: the sheet has no save callback from the host.
  - prompt-stash-delete-sheet: remove → done (no sheet; Undo instead).
  - embedded-model-shortcuts: shortcut discovery on screen → done: the menu items show F2 / Shift+F2 and say why they are unavailable; the composer folds them into the model chip's menu. `model_shortcuts_test`.
- States per page (STATE-20): composer idle empty / with text / busy / busy with text / offline / read-only ("Getting your prompt ready…", "Answer the question about this draft first") / sign-in → goldens and `chat_3_test`, `session_draft_test`; history loaded / empty / no match → `chat_3_test`; stash loaded / empty / no match / error / migration pending → code (error and migration via `KitNotice`), delete and Undo tested; editor clean / dirty → `chat_3_test`.
- Deferred states (STATE-21): stash empty-state "Save current prompt" → needs a host callback, owner chat_screen's unit.

### Acceptance items

| Item | Status |
|---|---|
| P4.3: withdrawing a queued message returns its text to the draft with Undo | Composer half built: `returnWithdrawnToDraft(context, composer:, text:, focus:, onUndo:)` in `composer.dart`, tested in `chat_3_test`. **Not wired**: `_editQueuedPrompt` and `_cancelInboxSend` live in `chat_screen.dart` (not in this write set) and must call it (onUndo re-queues). |
| P7.7: a "Sign in to a model" chip before the first send | Done (catalog loaded with no models → `signInNeeded`). The chip opens the model picker (the host's `onChooseModel`); a direct provider-row door needs a host callback. |
| P6.6: Queue is the default over Steer (composer.dart:52) | The default at composer.dart is now `PromptDelivery.queue`, and without an inbox the pill always says "Sends after this reply". **Gap**: `chat_screen.dart:396` still initialises `_delivery = PromptDelivery.steer` and passes it explicitly, so OpenCode 2 opens on "Add to this turn" until that line changes. |
| P7.5: never "Choose model" while a model answers | Done: busy with no pick shows the server default; `chat_3_test`. |
| P7.1 draft carry | The composer keeps the host's DraftStore flow (`session_draft_test` "composer text survives leaving and reopening a chat" passes); the pill never clears text (KitComposer DATA-1); the prompt editor asks before discarding. |
| G1, G16, G7 and look patterns 0 | Done for all eight files (ratchet test in write mode showed no entry for any of them; baseline restored, not staged). |

### Moved or removed (owner rethink rule)

- The separate model-cycle button beside the chip → folded into the model chip's menu (long-press, right-click, custom actions), with shortcuts shown.
- The activity ring, the "working" mark and the context meter line → removed (LOOK-20; Stop is the working signal, the chip carries "· 85 %").
- The "Delete saved prompt?" sheet → removed; Delete is immediate with Undo.
- The Steer/Queue segmented button and the OpenCode 1 queue hint → the kit's "Send after · Add to this turn" segments and note line.
- "Advanced" fold → "More tools"; "Context capsule" → "Notes for this conversation"; "Stash current prompt" → "Save prompt for later"; "Commands" → "Commands and agents".

## 2. Builds

- Branch `revamp/chat-3`, base `670bfd68`, code head: see the commit on this branch.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2c checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fix only (field re-created when a note or attachment appears): `chat_3_test` "KitComposer: …" without the keyed slot | fails | failed: `failing-first.txt` | PASS |
| 2 | `test/composer_desktop_enter_test.dart test/composer_layout_test.dart test/composer_paste_test.dart test/model_shortcuts_test.dart` | pass | 33 passed | PASS |
| 3 | `test/prompt_shelf_test.dart test/session_draft_test.dart test/revamp/chat_3_test.dart test/revamp/chat_3_golden_test.dart` | pass | 61 passed | PASS |
| 4 | `test/kit/kit_composer_test.dart` (the changed kit part) | pass | passed | PASS |
| 5 | `KIT_RATCHET_WRITE=1 flutter test test/kit_ratchet_test.dart`, then restore the baseline | no entry for the write set | none | PASS |
| 6 | `flutter analyze` on the chat library, the widget, the kit chat parts and the unit's tests | no issues in changed files | 3 warnings outside the write set (below) | PARTIAL |

Analyzer warnings outside the write set, caused by this unit's removals: `_InlineCommandSuggestions` and `_InlineAgentSuggestions` in `lib/ui/screens/chat/command_launcher.dart` are no longer referenced (the composer builds `KitComposerChips.suggestions`; chat-4 owns that file), and `lib/ui/screens/chat_screen.dart:104` imports `states_working_scene.dart`, which only the removed working mark used.

## 5. Evidence

- `failing-first.txt`: output of step 1.
- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-2 / KIT-15 (no `showModalBottomSheet`, `showConfirmSheet`) | ratchet write-mode run | step 5 |
  | KIT-34 / DATA-11 (Undo, not confirm) | `test/prompt_shelf_test.dart` "deleting a saved prompt happens at once with Undo…" | step 3 |
  | STATE-8 (disabled says why) | `test/model_shortcuts_test.dart` "a shortcut that cannot run says why…"; `session_draft_test` read-only reason | step 2, 3 |
  | DATA-1 (field kept) | `chat_3_test` "KitComposer: … keeps the field" | step 3 |

- Changed test expectations (TEST-19): Stop tooltip "Stop" → "Stop the reply" (KitComposer copy); remove target "Remove attachment X" → "Remove X" (`kitChipRemove`); model shortcut labels drop the "· F2" suffix (shown as the item's shortcut instead); busy composer "activity ring" tests → "Stop in the pill" (LOOK-20); empty idle trailing control is the mic, not a disabled Send; offline Send tooltip "Send when back online"; read-only draft field is now disabled with a visible reason; tools rows are `KitRow`s.
- Goldens changed (each opened and looked at): new `test/revamp/goldens/chat_3_{composer_text,composer_busy,composer_sign_in,tools_sheet,history_sheet,prompt_editor}[_1280x800]_{dark,light}.png` (24). The pill matches the canvas's glass composer pill (solid here because goldens run with animations disabled, KitGlass's rule); busy shows Stop (text1 circle) and Send 8 dp apart; the editor centres at the reading width on wide windows.
- Before and after: n/a — the base's composer is covered by the integrator's `chat_*` goldens; after renders are the goldens above.
- Accessibility: every control is labelled by the kit (Send / Send when back online / Stop the reply / Talk instead of typing / Attach and more); remove targets 48 dp with "Remove {name}"; the history and saved rows are whole-row targets; the stash row menu is a semantic custom action. 200 % text: `prompt_shelf_test` at 320 dp and 1.7×, `composer_layout_test` at 2.5×.
- Privacy and security: n/a — no credentials, links or notifications changed. Saved prompts are removed from the device when the Undo window closes (app killed within the window keeps the entry, the safe direction).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/composer_desktop_enter_test.dart test/composer_layout_test.dart test/composer_paste_test.dart test/model_shortcuts_test.dart
$F test -j 1 test/prompt_shelf_test.dart test/session_draft_test.dart test/revamp/chat_3_test.dart test/revamp/chat_3_golden_test.dart
$F analyze lib/ui/screens/chat lib/ui/widgets/model_shortcuts.dart lib/ui/kit/chat
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests outside the unit's test write set were not run (owner decision 2026-09-27); the likely breakages are listed in the build record.
- P4.3 withdraw-with-Undo, the Queue default on OpenCode 2 and history "Added to draft · Undo" need `chat_screen.dart` changes.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (host wiring in `chat_screen.dart` pending, PROC-32) | `revamp/chat-3` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
