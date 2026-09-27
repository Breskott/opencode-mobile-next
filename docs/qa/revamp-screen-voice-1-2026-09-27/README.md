# revamp-screen-voice-1: Voice setup and notices (2026-09-27)

## 1. Scope

- Unit: `screen-voice-1` (wave 2b, screen-revamp, tier 1). Finish line: both files in the write set are built from `lib/ui/kit/` parts only (G1, G16, G2, G7, G17, G21 at 0), each page is handled by its map proposal, and the look is the visual language. Non-goal: no controller field, persistence or gateway call; the voice-composer sheet is only restyled (slice-P10.3 deletes it) and the setup sheet's new structure waits for slice-P10.4.
- Files changed: `lib/voice/voice_ui.dart`, `lib/voice/notices.dart`, `lib/l10n/app_en.arb` (+16 keys, additive) and the regenerated `lib/l10n/app_localizations*.dart`, `test/voice_model_localization_test.dart`, new `test/revamp/screen_voice_1_test.dart`, `test/revamp/screen_voice_1_golden_test.dart`, `test/revamp/screen_voice_1_fixtures.dart`, 26 goldens under `test/revamp/goldens/voice_*.png`, two census anchors in `tool/capture/census/areas/d_chat_sheets.dart` (TEST-17).
- Pages (map ids): voice-composer-sheet (redesign → restyle), voice-model-setup-sheet (redesign → kit-only rebuild), voice-model-setup-sheet-delete-dialog (fix), voice-notices (fix).
- Specs followed: STANDARDS.md MAP-1, KIT-1, KIT-4, LOOK-1, LOOK-4, STATE-1, STATE-8, SEC-1, COPY-1 (English only, owner decision 2026-09-27), TEST-5, TEST-6, TEST-7, TEST-20; kit-v2 §9.1; visual language §5 (sheets and confirmations).
- Contract problems (PROC-20):
  - The task list says `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 says `docs/qa/revamp-<unit id>-<date>/`. The record follows EVID-1 like the other revamp records.
  - The task list's copy rule asks for real Arabic in `app_ar.arb`; the later owner decision (2026-09-27) drops Arabic. No Arabic entries were added, so `app_localizations_ar.dart` falls back to English for the 16 new keys.
  - `formatModelBytes` (`lib/voice/model_manifest.dart`, outside the write set) prints MiB. The map says newcomers don't understand MiB. The sheet keeps MiB so every voice size reads the same. Owner: slice-P10.4.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rethink rule):
  - Download again and Delete now show only for the selected model and name it ("Download Balanced again", "Delete Balanced"). Before, both showed on every downloaded model's card. To remove a model that isn't selected, select it first. Full model management moves to Settings › Voice in slice-P10.4.
  - The "Default" and "Optional" badge boxes are gone: each model's description already says which is recommended and which is optional. "Installed" is a word in the model's second line.
  - During a download the pinned Download is replaced by the progress at the top of the body, with its own Cancel download. Before, a disabled Download button stood in for the progress below the fold.
  - On the voice licenses page, the build provenance prose (pubspec.lock and pub-cache paths) is gone. It stays in `THIRD_PARTY_NOTICES.md` in the repository, and `loadVoiceNotices` is kept for it. The page lists the four parts, and each row opens its license.
  - The voice input sheet's model line ("Balanced model · Auto detect") is hidden while the recorder is busy instead of disabled without a reason.
- Map items (EVID-11):
  - voice-notices: actionsMissing "open each licence link" → done: `screen_voice_1_test.dart` "a part opens its license text and its website action" (primary "Open the ONNX Runtime website" through `openExternalLink`); "copy" → done: KitViewer's Copy contents in its menu (golden `voice_notices_license_*`). statesMissing "loading" → done: the license loads inside `showKitViewer` (`KitViewerSource.load`, which has its own loading and Try again); the list itself loads nothing. infoMissing "which models, who made them, licence, link" → done: golden `voice_notices_loaded_*`.
  - voice-model-setup-sheet (redesign): actionsMissing "download in background and keep using the chat" → deferred to slice-P10.4. statesMissing "download paused by network loss / metered network", "app killed mid-download", "storage full" → deferred to slice-P10.4 (they need manager fields; STATE-21). couldBeAutomatic "choose the pack from total RAM" → deferred to slice-P10.4; "auto-detect is already default" → kept (Auto detect is the first segment).
  - voice-model-setup-sheet-delete-dialog (fix): "Error-coloured Delete, neutral Keep, full model name" → done: golden `voice_setup_delete_confirm_*`, test "delete asks with the model name, and Keep keeps it".
  - voice-composer-sheet (redesign, restyle only): actionsMissing "keep talking past 30 s", "append another recording", "unsent transcript kept as draft" and statesMissing "speaking longer than 30 s", "slow transcription after 8 s", "audio focus lost" → deferred to slice-P10.3.
- States per page (STATE-20):
  - voice-model-setup-sheet: not installed, installed, downloading, failed → goldens `voice_setup_not_installed_*`, `voice_setup_installed_*`, `voice_setup_downloading_*`, `voice_setup_error_*`, plus tests. Model not supported (RAM gate) → KitChoice disabled with its reason, and the pinned Download shows the same reason (code path kept, no golden).
  - voice-model-setup-sheet-delete-dialog: confirm → golden `voice_setup_delete_confirm_*`.
  - voice-composer-sheet: listening, draft, microphone blocked → goldens `voice_composer_listening_*`, `voice_composer_draft_*`, `voice_composer_mic_denied_*`. Transcribing and loading use the KitProgressView waiting bar; interrupted uses a KitNotice with "Close voice input" (code kept, no golden).
  - voice-notices: loaded → golden `voice_notices_loaded_*`; license open → golden `voice_notices_license_*`.
- Deferred states (STATE-21): the setup-sheet network, metered, process-death and storage states need manager data. Owner: slice-P10.4.

## 2. Builds

- Branch `revamp/screen-voice-1`, base `7011dc46` (feat/phone-setup-v2), code head `83af7522`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first run | n/a | This unit rebuilds pages. The fixes (delete names the model, licenses list) are new code checked by new tests, so there is no failing-first run. | n/a |
| 2 | `test/revamp/screen_voice_1_test.dart` + `test/revamp/screen_voice_1_golden_test.dart` | pass | 41 passed (`run-1.txt`) | PASS |
| 3 | `test/voice_model_localization_test.dart` | voice setup cases pass | 4 voice-setup cases passed; the 2 `model picker *-2.5x` cases fail at the "Close model selector" tooltip in `ModelCatalogView` (`lib/ui/widgets/pickers.dart`, which this unit did not change). Not re-run on the base. (`run-2.txt`) | PASS for this unit's cases; 2 unrelated failures listed |
| 4 | Ratchet counts (`KIT_RATCHET_WRITE=1 flutter test test/kit_ratchet_test.dart`, baseline file then restored) | write-set files at 0 for G1, G16, G2, G7, G17, G21 | `voice_ui.dart` and `notices.dart` are gone from every gate except G48 (`voice_ui.dart` 1, unchanged: the transcript field has no KitDraft until P10.3) | PASS |
| 5 | `flutter analyze --no-pub lib/voice` + this unit's test files | no issues | No issues found | PASS |
| 6 | Hardcoded-string scan (l10n coverage regex) on both files | 0 | 0 (was 1 and 27) | PASS |

The owner decision (2026-09-27) says to run only this unit's own test files, so the design-standard, l10n-coverage, glossary, ledger and other shared suites were not run. The integrator regenerates the ratchet and l10n baselines (the counts dropped).

## 5. Evidence

- `run-1.txt`, `run-2.txt`: outputs of runs 2 and 3.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | MAP-1 fix (delete dialog) | `test/revamp/screen_voice_1_test.dart` "delete asks with the model name, and Keep keeps it" | `run-1.txt` |
  | STATE-1 (no stand-in button) | same file, "a running download shows its progress and its Cancel" | `run-1.txt` |
  | SEC-1 | same file, "a part opens its license text and its website action" (the action calls `openExternalLink`) | `run-1.txt` |
  | LAY-4 overflow | same file, "fits a phone and a PC window with no overflow" (360x800, 412x915, 915x412, 1280x800) | `run-1.txt` |

- Changed test expectations (TEST-19): `test/voice_model_localization_test.dart` finds the sheet by `kit-sheet-content` instead of `BottomSheet` (KIT-1: the sheet is now the kit frame).
- Shared tests likely broken (not run, per the owner decision; for the integrator):
  - `test/voice_composer_test.dart` "exported voice notices view renders bundled license texts": the license texts now open in the viewer from each row. They are no longer inline on the page (map fix for voice-notices).
  - `test/voice_composer_test.dart` "voice draft actions stack at 320dp with 2x text": it expects Cancel above Insert. The kit's action block stacks the primary first (VL §5; the map notes the old order as wrong).
- Goldens added (each opened and looked at). The approved canvases compared are `docs/design/visual-language-2026-09-26/Confirm.png` for the confirmation and the sheet frame, and `Settings.png` for the list rows.
  - `voice_setup_not_installed_{dark,light}`, `_1280x800_{dark,light}`: kit sheet with icon tile, subtitle, privacy notice, radio model list, segmented language, pinned "Download Balanced (153.2 MiB)" and "Not now". Differences from Confirm.png: none in the frame; the body has more content.
  - `voice_setup_installed_*`: "Use Balanced", then "Download Balanced again" and "Delete Balanced" (destructive tertiary).
  - `voice_setup_downloading_*`: progress row "Downloading Balanced", "61.3 MiB of 153.2 MiB", Cancel download, and model rows disabled with "Available after the download".
  - `voice_setup_error_*`: failure notice with Technical details folded, and Download kept as the retry.
  - `voice_setup_delete_confirm_*`: matches Confirm.png (danger tile, question title, red Delete Balanced, neutral Keep Balanced). There is no consequences panel because the body already says what is removed and that it can be downloaded again.
  - `voice_composer_listening_*` (phone and 1280x800), `voice_composer_draft_*`, `voice_composer_mic_denied_*`.
  - `voice_notices_loaded_*` (phone and 1280x800), `voice_notices_license_*`.
- Before and after: `before-<page>-<state>.png` copied from base `docs/qa/screen-census/d-chat-sheets/*.png`, and `after-<page>-<state>.png` copied from the new dark goldens (setup not-installed, installed, downloading, delete dialog; composer listening, draft, mic-denied; notices loaded). `after-voice-model-setup-sheet-error.png` and `after-voice-notices-license.png` have no before render.
- Accessibility:
  - Each model row is a radio in one group, with its disabled reason in words.
  - The language control has the "Transcription language" label.
  - Download progress is a live region that announces tens of percent.
  - The voice status line is a live region with the listening hint.
  - Every action is a 48 dp kit button.
  - Keys kept (TEST-5): `voice-model-{id}`, `voice-model-primary-action`, `voice-model-secondary-action`, `voice-redownload-{id}`, `voice-delete-{id}`, `voice-draft-field`, `insert-voice-draft`, `insert-voice-draft-send`, `stop-voice-recording`, `voice-composer-cancel`, `voice-recording-cap`.
  - The 2.5x text cases in `voice_model_localization_test.dart` pass for the setup sheet at 320 dp.
- Privacy and security: external project links go through `openExternalLink` (SEC-1). The URLs are app-authored constants. Local pub-cache paths are no longer shown (map security-privacy vertical). No credentials or stored data changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_voice_1_test.dart test/revamp/screen_voice_1_golden_test.dart
$F test -j 1 test/voice_model_localization_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze lib/voice test/revamp/screen_voice_1_test.dart
```

## 7. NOT proven

- Not run on a device or emulator. The real download, microphone permission and recording were not exercised; the tests use scripted managers and controllers.
- Shared suites were not run (owner decision 2026-09-27): `test/voice_composer_test.dart`, `test/read_aloud_test.dart`, `test/voice_reply_pipeline_test.dart`, design-standard, l10n coverage, glossary, ledger. Two expected breaks are listed in §5.
- The census was not re-rendered (coordinator work, TEST-17). Only two anchors were updated.
- The 2 `model picker *-2.5x` failures in `test/voice_model_localization_test.dart` were not re-run on the base to confirm they already failed there.
- The full `flutter analyze` over the whole tree was not run; only `lib/voice` and this unit's test files were analyzed.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-voice-1` |
| Enabled | Yes | voice input entry points (chat composer tools, Settings › Voice, search) |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `83af7522` |
| Deployed | No | |
| Released | No | |
