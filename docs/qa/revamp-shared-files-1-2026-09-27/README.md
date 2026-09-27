# revamp-shared-files-1: Revamp files (2026-09-27)

## 1. Scope

- Unit: `shared-files-1` (wave 2a, tier 1, shared). Finish line: every file preview (the sheet opened from chat, tool cards, the composer, the context capsule and the terminal, and the body embedded in Files and the skill sheets) is a data adapter over `KitViewer`, and the four files construct nothing outside the kit. Non-goal: changing the callers (they keep their current calls; the new optional parameters wait for their screen units).
- Files changed: `lib/ui/widgets/file_preview.dart`, `lib/ui/widgets/pdf_file_preview.dart`, `lib/ui/widgets/svg_file_preview.dart`, `lib/ui/widgets/delimited_file_preview.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/common_file_preview_test.dart`, `test/local_pdf_test.dart`, `test/product_ui_regression_test.dart` (the five Files preview tests only), new `test/revamp/shared_files_1_golden_test.dart` and its 16 goldens under `test/revamp/goldens/`.
- Pages (map ids): `file-preview-sheet`, `embedded-file-preview-body`.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-11, KIT-23, KIT-34, KIT-43 (no `@Deprecated`), SEC-1, SEC-13, STATE-11, STATE-13, LAY-8, COPY-30; kit-api/KitViewer.md (Compatibility: adopters pass `wrap`/`onWrapChanged`); kit-v2 §1.14, §8.2, §9.1.
- Contract problems (PROC-20):
  - The task names the record folder `docs/qa/revamp-shared-files-1/`; EVID-1 asks for the dated folder. This record follows EVID-1.
  - The task's R12 line ("a file a kit part replaces becomes a thin @Deprecated wrapper") and its acceptance line ("no @Deprecated (KIT-43)") disagree. The acceptance line was followed: the public classes stay, undeprecated, as thin adapters.
  - `KitViewer` has no slot for a caller's notice, and `showKitViewer` has no way to explain a load failure without offering Try again. So the sheet (not the embedded body) cannot say "Line 5 is outside this preview", "This file has incomplete quoting" or "Only the first 200 pages can be previewed", and a missing attachment shows "Couldn't open x" with a Try again that cannot help (the reason is in Details). Proposed: `KitViewer.notices` (a list of strings shown as `KitNotice` lines under the header) and a non-retryable `KitViewerContent.unavailable(String reason)`. Blocks: the sheet's copy of those three states only.
  - `KitViewer(showHeader: false)` has no More button, so an embedded body cannot reach Find (touch). Proposed: keep More in the header-less frame, or a `KitViewerController.openFind()`. Wrap and the mode switch were added above the embedded body instead.
  - `KitViewerContent.code` has no `original`, so laid-out JSON and a capped excerpt copy what is shown. The sheet adds "Copy original file" to More only when the shown text differs from the file.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - file-preview-sheet, actionsMissing "open in Files at its folder" → done (API): `onOpenInFiles` on `showFilePreviewSheet`, test "the sheet has Close, one labelled action and More; attach closes it"; wiring the callers → deferred to screen-files-1 / chat-1 / shared-chat-1 (callers outside this write set).
  - file-preview-sheet, actionsMissing "open in Review if changed" → done (API): `onOpenInReview`; wiring → deferred to the same caller units.
  - file-preview-sheet, statesMissing "remote path failed to load" → done: `showFilePreviewSheetLoading` (loading, failure with Try again that runs the fetch again), test "a fetch that fails says so and Try again fetches again"; tool-card adoption → deferred to shared-chat-1.
  - file-preview-sheet, statesMissing "too large" → done: KitViewer's truncation notice ("Showing the first 2,000 of N lines" / "Showing part of this file"), test "a partial CSV never becomes a table and says so".
  - file-preview-sheet, infoMissing "folder and size" → path: done (`path` parameter, golden `file_preview_sheet_markdown_*`); size: shown in the binary state only (golden `file_preview_sheet_binary_*`); callers passing `path` → deferred to the caller units.
  - embedded-file-preview-body, actionsMissing "wrap toggle" → done: Wrap lines button over code and source, test "CSV is an inert table with a Source view beside it", golden `embedded_file_preview_body_json_*`.
  - embedded-file-preview-body, actionsMissing "find in file" → partial: Ctrl+F and right-click More (kit); a touch entry needs the KitViewer change above → no owner (coordinator contract).
  - embedded-file-preview-body, statesMissing "unsupported binary in plain words" → done: "Can't show this file · type · size", test "missing and unknown files say what happened in words".
  - couldBeAutomatic: none on either page.
- States per page (STATE-20):
  - file-preview-sheet: loaded markdown (golden `file_preview_sheet_markdown_*`, phone and 1280x800), can't show (golden `file_preview_sheet_binary_*`), unavailable (golden `file_preview_sheet_unavailable_*`), loading and load failed (test "a fetch that fails…"), attach failed (test "a failed attach keeps the sheet and says so").
  - embedded-file-preview-body: table (golden `embedded_file_preview_body_table_*`), JSON/code (golden `embedded_file_preview_body_json_*`), malformed table (golden `embedded_file_preview_body_malformed_*`), empty, partial, SVG drawn and refused, Markdown rendered/source, line outside preview, unavailable, binary (tests in `test/common_file_preview_test.dart`), PDF pages, background cancel, isolated, desktop, encrypted (tests in `test/local_pdf_test.dart`).
- Deferred states (STATE-21): the sheet's notices listed under Contract problems → needs `KitViewer.notices`, owner: coordinator.

## 2. Builds

- Branch `revamp/shared-files-1`, base `2cec35ca` (feat/phone-setup-v2 when the unit started), code head: the commit this record is committed with.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/common_file_preview_test.dart` | passes | 14 passed | PASS |
| 2 | `test/local_pdf_test.dart` | passes | 6 passed | PASS |
| 3 | `test/product_ui_regression_test.dart --name` the five Files preview tests | pass | 5 passed | PASS |
| 4 | `test/revamp/shared_files_1_golden_test.dart --update-goldens`, then each PNG opened | 16 renders, no exceptions | 16 passed, looked at | PASS |
| 5 | Ratchet counts for the four files (a throwaway copy of `test/kit_ratchet_test.dart` printing current counts, deleted after) | G1, G2, G7, G16, G17, G21 all 0 | no entries for any of the four files | PASS |
| 6 | `flutter analyze lib/ui/widgets lib/ui/screens/files_screen.dart lib/ui/screens/chat_screen.dart lib/ui/screens/library` + the four test files | no issues | No issues found | PASS |

Per the owner's 2026-09-27 speed decision, no other suite was run.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-11 (one viewer, Close + one labelled action + More) | `test/common_file_preview_test.dart` "the sheet has Close, one labelled action and More; attach closes it" | run 1 |
  | SEC-13 (verbatim copy of the person's file) | `test/common_file_preview_test.dart` "laid-out JSON offers a verbatim copy of the original" | run 1 |
  | STATE-11 (honest truncation) | `test/common_file_preview_test.dart` "a partial CSV never becomes a table and says so" | run 1 |
  | STATE-13 (no dead end for binaries) | golden `file_preview_sheet_binary_dark.png` (caller's action in the state) | run 4 |
  | PERF-4 / lifecycle (PDF work cancelled off screen) | `test/local_pdf_test.dart` "backgrounding cancels PDF work and a late page never lands", "disposing a PDF view cancels a held page" | run 2 |
  | KIT-2 / KIT-34 (no SnackBar; failures through `showKitAlert`) | `test/common_file_preview_test.dart` "a failed attach keeps the sheet and says so" | run 1 |

- Changed test expectations (TEST-19):
  - `test/common_file_preview_test.dart`: rewritten against the adapters (was `CodeBlock`/`TextButton`/SnackBar retry): table finders use the kit table key; the clipboard-refusal SnackBar retry test is gone (KIT-23/KIT-34: copy is `KitCopy`, no SnackBar).
  - `test/local_pdf_test.dart`: Previous/Next/Cancel paging replaced by the kit's stacked pages; the page cap, background cancel, late-page, dispose, isolated, desktop and encrypted cases kept against the new UI.
  - `test/product_ui_regression_test.dart`: "Preview unavailable" → "Can't show this file" (binary); "Pinch to zoom"/`InteractiveViewer` → `kit-viewer-image` with KitZoom controls; "Column 1" → the kit table (the first row is the header); "Only part of this file" → the kit truncation notice; `file-preview-focused-source`/`file-preview-target-line` → `file-preview-text` and `KitCodeBlock.initialLine == 42`; the five tests gained the app's localization delegates.
- Goldens changed (each opened and looked at): 16 new PNGs under `test/revamp/goldens/` (`file_preview_sheet_{markdown,markdown_1280x800,unavailable,binary}_{dark,light}`, `embedded_file_preview_body_{table,table_1280x800,json,malformed}_{dark,light}`). There is no approved VL canvas render for these two pages (`docs/design/visual-language-2026-09-26/` has none), so EVID-12 has nothing to compare; the frame is KitViewer's, whose own gallery carries the look.
- Before and after (EVID-10): `before-file-preview-sheet-markdown.png` (census `docs/qa/screen-census/f-files-review-terminal/file-preview-sheet--markdown.png`) → `after-file-preview-sheet-markdown.png`; `before-embedded-file-preview-body-json.png` (census `embedded-file-preview-body.png`) → `after-embedded-file-preview-body-json.png`. Visible changes: the four unlabelled icon buttons and the MIME subtitle are gone; the header has the name, the muted path, "Attach to prompt", More and Close; the code block's own frame and second Copy are gone (edge-to-edge code with line numbers); the Rendered/Raw text-button pair is a left-aligned segmented control.
- Accessibility: every action is labelled (More, Close, Wrap lines, Attach to prompt, the segmented group "Show file as"); 48 dp targets come from the kit; the image and PDF pages have KitZoom's visible zoom controls instead of a "Pinch to zoom" pill; the PDF page caption and semantics come from KitViewer. Text scale and RTL were not re-checked here (owner decision: Arabic dropped; KitViewer's own G6 matrix covers the frame).
- Privacy and security: no credentials or stored formats change. Links in Markdown open only through KitMarkdown's `openExternalLink` path; an isolated view (`MarkdownInteractionScope(enabled: false)`) keeps links inert and never calls the PDF renderer. Copy of the person's file is verbatim (SEC-13); the screen text is redacted by KitCodeBlock. Save still uses the system picker with the original bytes.
- Migration: n/a: no stored format changed. The reader preference `wrapCode` is read and written as before.

### Shared tests likely broken (not run, per the owner's speed decision)

- `test/chat_live_events_test.dart` (≈2100, 2216, 4643, 4828): expects `file-preview-image`/`file-preview-text` inside the sheet, `file-preview-download` without opening More, `file-preview-raw-mode` in the sheet, "Pinch to zoom", and the "Close preview" tooltip.
- `test/reader_preferences_test.dart` (≈402–417): expects `file-preview-target-line`.
- `test/library_skills_test.dart` (≈70) and `test/tool_card_test.dart` (66, 383, 473): pump without `AppLocalizations` delegates; the kit parts now in `FilePreviewBody`/`SmartTextPreview` read `AppLocalizations.of`.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/common_file_preview_test.dart test/local_pdf_test.dart
$F test -j 1 test/product_ui_regression_test.dart --name "unsupported binary files show preview|image files open as a zoomable|project CSV uses table|chat file viewer can attach the original|symbol search opens the exact"
$F test -j 1 test/revamp/shared_files_1_golden_test.dart
$F analyze lib/ui/widgets test/common_file_preview_test.dart test/local_pdf_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; the PDF renderer was faked over its method channel.
- The full suite, the ratchet/design-standard/l10n gates and the shared tests listed above were not run.
- No caller passes `path`, `onOpenInFiles`, `onOpenInReview` or uses `showFilePreviewSheetLoading` yet.
- 200 % text and screen-reader order were not checked on these pages.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (sheet notices partial, see Contract problems) | `revamp/shared-files-1` |
| Enabled | Yes (every existing caller now gets the kit viewer) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
