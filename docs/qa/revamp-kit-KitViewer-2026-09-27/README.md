# revamp-kit-KitViewer: KitViewer, the one file and document viewer (2026-09-27)

## 1. Scope

- Unit: `kit-KitViewer` (wave 1, kit-part). Finish line: `KitViewer` and `showKitViewer` exist in `lib/ui/kit/kit_viewer.dart` with the frozen API, every declared state, behaviour tests and the gallery. Non-goal: no screen adoption (shared-files-1, screen-files-1, screen-system-1, screen-voice-1, chat-1 adopt it), no `kit.dart` export (integrator, R06).
- Files changed: `lib/ui/kit/kit_viewer.dart` (new), `lib/l10n/app_en.arb` (+19 `kitViewer*` keys) and the regenerated `lib/l10n/app_localizations*.dart`, `test/kit/kit_viewer_test.dart` (new), `test/goldens/kit/kit_viewer_golden_test.dart` (new) and its 44 PNGs.
- Pages (map ids): none owned; the part replaces elements on about, about-open-source-tab, about-privacy-tab, embedded-file-preview-body, file-preview-sheet, files-file-viewer-sheet, markdown-code-reader, voice-notices once the adopting units land.
- Specs followed: `docs/ux-system/kit-api/KitViewer.md` (kit-v2 §1.14, §8.2); rules SEC-1, SEC-2 (with the SEC-13 copy note), KIT-11, KIT-23, KIT-28, KIT-32, LAY-4, COPY-30, STATE-1, STATE-11, PERF-4, A11Y-2, A11Y-8.
- Contract problems (PROC-20):
  1. **Sheet presentation.** The spec says compact/medium use `showKitSheet(height: full)`. That frame cannot hold this part: its header has only title, subtitle and Close (no slot for the labelled action or More), and its body is always a `SingleChildScrollView`, which cannot hold a virtualised file (`KitCodeBlock.fill`, the PDF list, the table). `showKitViewer` therefore uses the same bottom modal `showKitSheet` builds (same `showModalBottomSheet` parameters, sheet surface, radius, scrim, 95 % height, 640 dp cap, handle, motion) with the viewer's own frame inside. Proposed: give `showKitSheet` a `header: false` / `bodyScrolls: false` option (or expose the modal presenter) and switch this part to it. Blocks nothing.
  2. **Copy contents redaction.** The body says "Copy contents copies redacted text" and test 15 says it copies "without" the secret, but the coordinator's SEC-13 note at the top of the same spec (2026-09-27, later authority) says this part copies verbatim (`KitCopy.copy(context, text, redact: false)`). Built per SEC-13: the screen is redacted (through KitCodeBlock), Copy contents is verbatim; test 15 asserts that. Proposed: edit the body paragraph and test 15 to match SEC-13.
  3. **Closing Find.** "Esc or Clear closes Find": KitSearchField's Clear only clears (and is shown only with a query), so a touch user who opened Find with an empty field had no way out. Added a "Close find" `KitIconButton` (new key `kitViewerFindClose`) beside the arrows; Esc closes Find directly (even with a query). Proposed: "Esc or Close find closes Find; Clear clears the query."
  4. **Name "wraps to two lines, never cut".** Both cannot hold for a 120-character name at 2.0 text on 320 dp (test 18). Built "never cut": the frame's top (header and truncation notice) scrolls within at most half of the viewer's height. Proposed: say so in the Header paragraph.
  5. **Path tooltip.** Tooltips come only through KitIconButton/KitTerm/KitTappable (R14), and the path is not a control; the full path is in semantics (`KitText.mono`, middle cut) but there is no hover tooltip.
  6. **QA folder name.** The unit brief says `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 says `revamp-<unit id>-<date>`. Used EVID-1.
- New kit parts (KIT-3): `KitViewer` (this unit's own part); no others.
- Map items (EVID-11): n/a: the unit owns no pages; the replaced elements move with the adopting units named above.
- States (STATE-20): loading → test 3, golden `loading`; error → test 3, golden `error`; empty → test 4; loaded → goldens `code`, `markdown`, `image`, `pdf`, `svg`, `delimited`; truncated → test 5, golden `truncated`; binary → test 12, golden `binary`; page-failed → test 10; finding → test 7, golden `finding`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitViewer`, base `8dc27c665f0b14fb2f0eea0dd47be0fe677a57ca` (feat/phone-setup-v2), code head `f4622b0e`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_viewer_test.dart` | passes | 22 passed | PASS |
| 2 | `test/goldens/kit/kit_viewer_golden_test.dart` (G4 + G5 checks in both themes) | passes | 44 passed | PASS |
| 3 | `flutter analyze --no-pub lib/ui/kit/kit_viewer.dart test/kit/kit_viewer_test.dart test/goldens/kit/kit_viewer_golden_test.dart` | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n coverage tests | pass | not run (owner decision 2026-09-27: own test files only) | n/a |

## 5. Evidence

- `run-tests.txt`: output of runs 1 and 2 (one command, 66 tests).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-11 | `test/kit/kit_viewer_test.dart` "1. frame" (Close and back complete the future) | `run-tests.txt` |
  | KIT-23 | "15. redaction" (Copy contents through KitCopy, no SnackBar) | `run-tests.txt` |
  | SEC-1 | "6. links go through openExternalLink" | `run-tests.txt` |
  | SEC-2 | "15. redaction" (secret not on screen) | `run-tests.txt` |
  | STATE-11 | "5. truncated" | `run-tests.txt` |
  | PERF-4 | "10. PDF" (only visible pages render, cancel on scroll-away) | `run-tests.txt` |
  | LAY-10 | "14. keyboard on a PC" (Esc, Ctrl+F, Tab order) | `run-tests.txt` |
  | MOT-7 | "17. reduced motion" | `run-tests.txt` |
  | A11Y-2 | "18. overflow" (320/412 dp × 1.0/1.3/2.0) | `run-tests.txt` |
  | A11Y-6 (G5) | every gallery shot, both themes | `run-tests.txt` |

- Changed test expectations (TEST-19): none (new tests only).
- Goldens (all new, each opened and looked at): `kit_viewer_{code,markdown,image,pdf,svg,delimited,binary,loading,error,truncated,finding}` at 412x915 (sheet) and `_1280x800` (page), `_dark` and `_light`. No approved VL canvas render exists for this part (EVID-12: none).
- Before and after: no before render (a new kit part, no page changed); after: `after-kit-viewer-code.png`, `after-kit-viewer-finding.png`, `after-kit-viewer-pdf-wide.png`.
- Found in other parts (not changed here):
  - KitCodeBlock: a blank line's lone line number (`text3` on `detailsSurface`) fails G5 text contrast (1.36:1 in light). The gallery's sample has no blank lines for that reason; owner kit-KitCodeBlock.
  - KitCodeBlock `.fill` with `wrap: false` has no horizontal scroller of its own (a numbered long line overflows its Row). KitViewer hosts it in one horizontal scroller sized to the longest line.
  - Buttons inside `KitZoom` (the PDF page's Try again) wait out the double-tap window before a tap lands.
  - KitMarkdown renders `#` headings at body-size weight only and its code block leaves space above the code (visible in `kit_viewer_markdown_*`).
- Accessibility: More, Close, Find's arrows and Close find are labelled 48 dp `KitIconButton`s; the name is a header and names the route when presented; the path's full value is in semantics; the find count is announced once when typing settles; table cells carry their full value; PDF pages and images carry "Page n of m" / the name; text 1.0/1.3/2.0 at 320 and 412 dp: no overflow. Arabic and RTL not checked (owner decision 2026-09-27).
- Privacy and security: links open only through KitMarkdown's `openExternalLink`; nothing calls `launchUrl`; SVG is rendered from the caller's sanitised source (flutter_svg, no network); error details are redacted; Copy contents is verbatim per SEC-13.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get --offline
$F test -j 1 test/kit/kit_viewer_test.dart test/goldens/kit/kit_viewer_golden_test.dart
$F analyze --no-pub lib/ui/kit/kit_viewer.dart test/kit/kit_viewer_test.dart test/goldens/kit/kit_viewer_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The repository-wide gates (kit ratchet, design standard, l10n coverage) and the full suite were not run (owner decision 2026-09-27); `kit_viewer.dart` is a new file, so the ratchet baseline needs the integrator's regeneration.
- Arabic copy and RTL layout are not provided or checked (owner decision 2026-09-27); `app_ar.arb` has no `kitViewer*` keys, so Arabic falls back to English.
- No screen uses the part yet; real PDF rendering (`lib/platform/local_pdf.dart`) and real reader preferences are exercised only by fakes.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitViewer` |
| Enabled | No: no screen adopts it yet, and `kit.dart` does not export it (integrator) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `f4622b0e` |
| Deployed | No | |
| Released | No | |
