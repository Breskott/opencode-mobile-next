# revamp-screen-chat-3: Revamp chat, Export conversation (2026-09-27)

## 1. Scope

- Unit: `screen-chat-3` (wave 2b, screen-revamp, tier 1). Finish line: `lib/ui/screens/session_export_screen.dart` is built from kit parts only (G1, G16, G7, G17, G21 all 0 for the file), looks like the visual language, and handles its map record (`proposal: fix`) with the "save failed" state and the missing redaction info. Non-goal: no gateway call, controller field, persistence or native channel is added (so "share instead of save" is deferred).
- Files changed: `lib/ui/screens/session_export_screen.dart`, `lib/l10n/app_en.arb` (new `sessionExport*` keys only; generated `app_localizations*.dart` are not staged, integrator regenerates), `test/session_export_test.dart`, new `test/revamp/screen_chat_3_golden_test.dart` + 14 goldens under `test/revamp/goldens/chat_session_export_*`, this record.
- Pages (map ids): `session-export`.
- Specs followed: STANDARDS.md MAP-1, KIT-1, STATE-8, STATE-12, STATE-21, TEST-10, TEST-19, TEST-20, EVID-1 to EVID-12; kit-v2 §9.1; KitChoiceList.md (`single`, `actsOnTap: false`), KitRow.md (`KitSwitchRow`, `KitRowGroup`), KitNotice.md, KitProgress.md, KitAction.md, KitScreen.md (`width: reading`, bottom primary); visual language §5.
- Contract problems (PROC-20): none. Two task-text conflicts were settled by the later owner decisions: Arabic entries (app_ar.arb) are **not** added (owner decision 2026-09-27, Arabic dropped), and the failing-first `.txt` for the one fix (TEST-2) was not recorded (owner decision 2026-09-27: run only own tests once).
- New kit parts (KIT-3): none.
- Map items (EVID-11), `session-export`:
  - statesMissing "save failed" → done: `test/session_export_test.dart` "a file the device cannot write says so and allows retry"; golden `chat_session_export_save_failed_{dark,light}.png`.
  - actionsMissing "share instead of save" → deferred, no owner. There is no outgoing file-share path in the app (the `oc/share` channel only receives text, is a single-owner MethodChannel, and a file share needs a FileProvider on the Kotlin side). Adding it is native work outside this unit's write set and against the screen-revamp non-goal.
  - infoMissing "what survives redaction" → done: the switch's supporting line "Keeps who wrote each message; the words become placeholders. Not a backup." (`sessionExportRedactKeeps`, from `docs/verification/export-beta-18600.md`: sanitize replaces all text with placeholders, message list kept). Test "redaction says what it keeps and belongs to JSON only".
  - couldBeAutomatic `session-export-redact` "yes: default off for Markdown" → done: the switch and its warning exist only for the complete JSON copy; the transcript is never redacted (same test).
  - couldBeAutomatic `session-export-format`, `session-export-save`: "no" → n/a.
  - whenMissing `server.oc2` "explains" → done: on a server without the export endpoint the JSON choice stays visible, disabled, with "This server can't send a complete copy. Save the readable transcript instead."; the page starts on the transcript. Test "a server without the complete copy explains it and starts on the transcript"; golden `chat_session_export_unsupported_*`.
  - rationale "one choice-row style" → done: one `KitChoiceList.single` replaces the tinted cards with radios.
- States per page (STATE-20), `session-export`: choice (loaded) → golden `choice` (412x915 and 1280x800); unredacted warning → golden `unredacted`; downloading with Cancel download → golden `downloading`, test "progress from transport is clamped before rendering"; saved → golden `saved`; export failed (auth, missing, other) → test "failed export keeps options and allows retry"; save failed → golden `save_failed`; server without the complete copy → golden `unsupported`; server/project changed → tests "scope change while destination picker is open…" and "cancel and changed connection never open a save dialog". No loading/empty state: the page has nothing to fetch before the person acts.
- Deferred states (STATE-21): none.

### Rethink (owner rule 2026-09-27)

- Kept: intro line, format choice, redaction switch (JSON only), unredacted warning, primary, cancel download, progress, verdicts.
- Changed: the primary now names what it saves ("Save complete conversation" / "Save readable transcript", was "Save file"). The redaction explanation moved from a loose paragraph under a `SwitchListTile` into the switch row's supporting line; the "Privacy" and "Format" section labels were added. The JSON choice is no longer hidden on a server without it: it stays with its reason (STATE-12), and the page starts on the transcript, so Save works at once (before, Save was disabled until the person tapped the only visible choice).
- Moved or removed: nothing moved to another page. The unredacted warning is now a neutral `KitNotice` with a warning glyph, not red text (LOOK-5). A mid-run `SessionExportUnsupported` switches the choice to the transcript.

## 2. Builds

- Branch `revamp/screen-chat-3`, base `7011dc46` (feat/phone-setup-v2), code head `2320433f`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fix only (JSON unsupported preselects transcript): the test on the base | fails with an assertion | not run (owner decision 2026-09-27); the new copy it asserts does not exist on the base | n/a |
| 2 | `test/session_export_test.dart` + `test/revamp/screen_chat_3_golden_test.dart` | pass | 38 passed, see `run-1.txt` | PASS |
| 3 | `test/kit_ratchet_test.dart` (read for this file only) | 0 G16/G17/G21 in `session_export_screen.dart` | every count `-> 0`; the suite's other failures are in files this unit does not touch (see gaps) | PASS for this file |
| 4 | `flutter analyze` on the three changed Dart files | no issues | No issues found | PASS |

## 5. Evidence

- `run-1.txt`: output of step 2.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-12 | `test/session_export_test.dart` "a server without the complete copy explains it" | `run-1.txt` |
  | STATE-21 (save failed) | `test/session_export_test.dart` "a file the device cannot write says so and allows retry" | `run-1.txt` |
  | LAY-4 overflow | `test/session_export_test.dart` "lays out at …" (360x800, 412x915, 915x412, 800x1280, 1280x800, 1600x1000, while downloading) | `run-1.txt` |

- Changed test expectations (TEST-19), all type (1), visible behaviour unchanged:
  - `'Save file'` → `'Save complete conversation'` / `'Save readable transcript'` (COPY-8: an action names what it acts on).
  - `find.byType(LinearProgressIndicator)` `.value` → `find.byType(KitProgressView)` `.progress.value` plus the visible "Downloading complete conversation…" (KIT-1).
  - `find.byType(SwitchListTile)` → `find.byType(KitSwitchRow)` (KIT-1).
  - The fake gateway gained a `supported` flag for the new tests.
- Goldens added (each opened and looked at), `test/revamp/goldens/`:
  - `chat_session_export_choice_{dark,light}.png`, `chat_session_export_choice_1280x800_{dark,light}.png`: the page on a server with the complete copy; reading width centred on wide.
  - `chat_session_export_unredacted_{dark,light}.png`: switch off, warning notice under it.
  - `chat_session_export_downloading_{dark,light}.png`: 40 % bar with its caption, working primary, "Cancel download".
  - `chat_session_export_saved_{dark,light}.png`: ok notice above the primary.
  - `chat_session_export_save_failed_{dark,light}.png`: the save-failed error notice.
  - `chat_session_export_unsupported_{dark,light}.png`: JSON disabled with its reason, transcript chosen.
  - Approved render: no VL canvas shows this page; the closest, `docs/design/visual-language-2026-09-26/Settings.png`, shares the section labels and grouped `surface1` panels. Differences: none beyond content.
- Before and after: `before-session-export-choice.png` (from base `docs/qa/screen-census/k-session-misc/session-export.png`); `after-session-export-choice.png`, `after-session-export-choice-1280x800.png`, `after-session-export-downloading.png`, `after-session-export-save_failed.png`, `after-session-export-unsupported.png`.
- Accessibility: the format list is one semantics group named "Format" with radio rows (KitChoiceRow); section labels are headers; the whole switch row toggles, and its disabled reason is its hint (STATE-8); verdicts are KitNotice live regions; the primary's disabled reason is its hint. Tap targets are 48 dp or more (kit). No 200 % text golden (owner decision 2026-09-27: galleries at two sizes only).
- Privacy and security: redaction stays on by default; the unredacted warning is unchanged in words. No credentials, links, storage keys or notifications changed. Error notices get no raw details.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/session_export_test.dart test/revamp/screen_chat_3_golden_test.dart
$F analyze lib/ui/screens/session_export_screen.dart test/session_export_test.dart test/revamp/screen_chat_3_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; the real Android save picker (FilePicker) and its failure modes were only faked.
- The failing-first run for the transcript preselection fix was not recorded (TEST-2), by owner decision.
- The full suite, design-standard, l10n coverage, glossary and ledger tests were not run (owner decision: own tests only). `session_export_screen.dart` is not yet in `_migrated` (integrator, R10).
- "Share instead of save" is not built.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (share deferred) | `revamp/screen-chat-3` |
| Enabled | Yes | reached from the chat menu, as before |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `2320433f` |
| Deployed | No | |
| Released | No | |
