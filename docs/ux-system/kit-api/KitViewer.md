# KitViewer — API freeze (wave 0)

Unit: `kit-KitViewer` (wave 1, tier 1d, kind `kit-part`). Write set (work-units.json): `lib/ui/kit/kit_viewer.dart` (new), `test/kit/kit_viewer_test.dart`, `test/goldens/kit/kit_viewer_golden_test.dart`. Spec: kit-v2.md §1.14, §8.2 (`KitViewer` row), §4.6, §4.10; map proposals for file-preview-sheet (Rethink: one viewer for every entry point), files-file-viewer-sheet (merges into it), markdown-code-reader (edge-to-edge code, line numbers, wrap on by default), embedded-file-preview-body, about, voice-notices; C13, C25, C36. Rules: SEC-1, SEC-2, KIT-11, KIT-15, KIT-23, KIT-28, KIT-32, LAY-4, LOOK-35, COPY-30, STATE-1, STATE-11, PERF-2, PERF-4, A11Y-2, A11Y-8.

## Purpose

One viewer for a file, a code block opened in full, or a document (About, Privacy, open-source notices, voice notices). The frame is always the same (name, muted path, one labelled action, an overflow, Close), and the body is one of the kit's renderers: text, code, Markdown, image, PDF, SVG, delimited table, or "can't show this file".

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitViewer`): 11 elements on 8 pages.**
  - about (about-document), about-open-source-tab (open-source-notices), about-privacy-tab (privacy-policy);
  - embedded-file-preview-body (…-code: a bordered block with its own copy inside a sheet that also has copy);
  - file-preview-sheet (…-body, …-header: four unlabelled `IconButton`s over a MIME subtitle);
  - files-file-viewer-sheet (…-body, …-header: the second viewer, three accent text buttons);
  - markdown-code-reader (a `Scaffold` reader for one code fence);
  - voice-notices (voice-notices, voice-notices-body).
- **Merged proposal names:** `KitDocumentView`, `KitFileViewer`.
- **Code reach, adopted by other units (C36: `file_preview.dart` → after kit-KitViewer):**
  - `showFilePreviewSheet` and `FilePreviewBody` (`lib/ui/widgets/file_preview.dart`, 926 lines; G16 `IconButton` 4, `Icon` 6, `Text` 15, `SnackBar` 3, `Scaffold` 1, `ScaffoldMessenger` 1, `InteractiveViewer` 1, `Image` 1, `Positioned` 2, `CircularProgressIndicator` 2, `Scrollbar` 1, `SelectionArea` 1; G1 `showModalBottomSheet` 1, `showSnackBar` 3). 10 `showFilePreviewSheet` calls in 7 files and 4 `FilePreviewBody` calls in 3 files. shared-files-1 (2a) turns them into data adapters over `showKitViewer`;
  - `PdfFilePreview` (`pdf_file_preview.dart`, `InteractiveViewer` 1, `Image` 1), `SvgFilePreview` (`svg_file_preview.dart`, `InteractiveViewer` 1) and `DelimitedFilePreview` (`delimited_file_preview.dart`, G16 `Container` 2, `IntrinsicHeight` 1, `Scrollbar` 1, `SelectionArea` 1, `SingleChildScrollView` 2, `Text` 8, `TextButton` 2), also shared-files-1. Their parsing stays in `lib/domain` (`StaticSvg`, `DelimitedText`) and `lib/platform/local_pdf.dart`; only the drawing moves into this part's frames;
  - the Files viewer sheet in `files_screen.dart` (screen-files-1, which deletes files-file-viewer-sheet, C37);
  - the markdown code reader route (`widgets/markdown.dart:1186`, kit-KitMarkdown and chat-1);
  - the About documents (screen-system-1) and voice notices (screen-voice-1).
- **Widgets retired directly:** none outside the kit.

## File

- `lib/ui/kit/kit_viewer.dart`: `KitViewerContent`, `KitViewerSource`, `KitViewerKind`, `KitPdfPage`, `KitViewer`, `showKitViewer`.
- Tests: `test/kit/kit_viewer_test.dart`. Gallery: `test/goldens/kit/kit_viewer_golden_test.dart`.

## Public API

```dart
enum KitViewerKind { text, code, markdown, image, pdf, svg, delimited, binary }

/// One page of a PDF, already rendered by the caller's renderer
/// (lib/platform/local_pdf.dart); the kit only lays pages out.
@immutable
class KitPdfPage {
  const KitPdfPage({required this.bytes, required this.width, required this.height});
  final Uint8List bytes;   // an encoded bitmap (PNG) at the requested pixel width
  final int width, height; // in pixels
}

/// What the viewer shows. Every constructor is data only: parsing,
/// sanitising and file reading stay with the caller.
@immutable
class KitViewerContent {
  const KitViewerContent.text(String text, {bool truncated = false, int? totalLines});
  const KitViewerContent.code(String text, {String? language, bool truncated = false, int? totalLines, int? initialLine});
  const KitViewerContent.markdown(String source, {bool truncated = false});
  const KitViewerContent.image(Uint8List bytes, {String? semanticsLabel});
  const KitViewerContent.pdf({
    required int pageCount,
    required Future<KitPdfPage> Function(int index, int widthPx) renderPage, // called only for visible pages
    void Function(int index)? cancelPage,                                   // a page scrolled away before it rendered
  });
  const KitViewerContent.svg(String safeSource, {String? original, bool truncated = false}); // already sanitised (StaticSvg)
  const KitViewerContent.delimited(List<List<String>> rows, {String? original, bool header = true, bool truncated = false});
  const KitViewerContent.binary({String? mimeType, int? byteLength});

  KitViewerKind get kind;

  /// The whole text for Copy and Find (text, code, markdown source, svg and
  /// delimited originals); null for image, pdf and binary.
  String? get copyText;
}

/// Where the content comes from.
@immutable
class KitViewerSource {
  const KitViewerSource(KitViewerContent content);                // already in hand
  const KitViewerSource.load(Future<KitViewerContent> Function() load); // loading and error built in
}

/// Opens the viewer (KIT-11). Returns when it closes.
Future<void> showKitViewer(
  BuildContext context, {
  required String name,                 // "README.md": the title
  required KitViewerSource source,
  String? path,                         // muted subtitle, LTR, middle ellipsis
  KitAction? primary,                   // at most one labelled action: "Add to prompt"
  List<KitMenuItem> more = const [],    // Copy path, Save, Share, Open in Files, Open in Review
  bool? asPage,                         // null = auto (see Adaptive)
  bool interactive = true,              // Markdown links and path chips open (through openExternalLink, SEC-1); false: inert text
  VoidCallback? onOpenAll,              // "Open all" for a truncated source
  bool? wrap,                           // null = wrap on compact, scroll from medium
  ValueChanged<bool>? onWrapChanged,    // the reader preference (ReaderPreferencesStore)
  bool? showSource,                     // markdown, svg, delimited: start on the source
  ValueChanged<bool>? onShowSourceChanged,
  Key? viewerKey,
});

/// The same frame and body as a widget: a two-pane detail (Files on a PC),
/// an About tab, and the goldens.
class KitViewer extends StatefulWidget {
  const KitViewer({
    super.key,
    required this.name,
    required this.source,
    this.path,
    this.primary,
    this.more = const [],
    this.onClose,                        // null: no Close (an embedded pane or tab)
    this.interactive = true,
    this.onOpenAll,
    this.wrap,
    this.onWrapChanged,
    this.showSource,
    this.onShowSourceChanged,
    this.showHeader = true,              // false inside a host that has its own top bar (an About tab)
    this.viewerKey,
  });

  /// Text sources show at most this many lines; beyond it the viewer says
  /// "Showing the first 2,000 of 5,210 lines · Open all" (K2 §1.14).
  static const int maxLines = 2000;
}
```

- **Header.** `name` (`headline`, wraps to two lines, never cut), `path` under it (`secondary`, `text2`, mono, LTR, middle ellipsis on one line, full value in semantics and a tooltip). At the end: the `primary` as a labelled `KitButton` (tertiary on compact, secondary from medium), one overflow `KitIconButton` ("More") that opens `showKitMenu` with the kit's items then `more`, and Close (a `KitIconButton`, "Close"). There is never a second Copy or an unlabelled icon (map: four unlabelled buttons).
- **Kit menu items (first, in this order, only when they apply):** Find in file (text, code, markdown source), Copy contents (`KitMenuItem.copy` of `copyText`, redacted), Wrap lines (checked; text and code), Show source (checked; markdown, svg, delimited with an `original`). Then the caller's `more`, with destructive items last after a divider (KitMenu).
- **Find.** "Find in file" (and Ctrl+F on a fine pointer) opens a `KitSearchField` under the header. Matches are counted ("3 of 12"), the previous and next `KitIconButton`s move between them, and they are shown as `marks` on `KitCodeBlock.fill`. Esc or Clear closes Find.
- **Renderers.**
  - `text`, `code`: `KitCodeBlock.fill` (line numbers on for code, off for text), no Copy of its own (the header has it). `initialLine` scrolls there and marks it.
  - `markdown`: `KitMarkdown(source, interactive: interactive)` reflowed as prose (no hard wraps, no literal backticks), code fences through `KitCodeBlock`. Links open only through KitMarkdown's own `openExternalLink` path (SEC-1; KitMarkdown has no link callback, so no caller can route around it); with `interactive: false` they are inert, selectable text. Show source swaps to `KitCodeBlock.fill(language: 'markdown')`.
  - `image`: `KitImage(source: KitImageSource.memory(bytes), semanticsLabel: semanticsLabel ?? name)`, decoded at the device pixel ratio, inside `KitZoom(label: name, mode: KitZoomMode.fit)` with its visible zoom controls (the A11Y-5 twin of pinch). There is no floating "Pinch to zoom" pill (map: `Positioned` pill over the image).
  - `pdf`: pages stacked inside one `KitZoom(label: name, resetKey: <the source>)`, each page a `KitImage(source: KitImageSource.memory(page.bytes), semanticsLabel: "Page 3 of 12")` of `renderPage(index, widthPx)` with `widthPx` = the page box's width × DPR. A page renders only while visible, `cancelPage` runs when it scrolls away first, and each page has its own skeleton and error ("Couldn't show page 3 · Try again"). A caption shows "Page 3 of 12".
  - `svg`: the sanitised picture (`flutter_svg`, no network) in `KitZoom(label: name)`; Show source swaps to XML code.
  - `delimited`: a table with a sticky header row, virtualised rows, one horizontal scroller, each cell isolated with `KitBidi.auto`, and cell text cut at 2 lines with the full value in semantics. Show source swaps to the raw text.
  - `binary`: an inline `KitStateView` "Can't show this file" with the MIME type and size in words, and the caller's `primary` (for example Share or Save) as its action.
- **Compatibility.** A new part. The reader preferences (`wrapCode`, `sourceFirst` in `lib/state/reader_preferences.dart`) stay the caller's: adopters pass `wrap`/`onWrapChanged` and `showSource`/`onShowSourceChanged`. The kit reads no app state.
- **Internal keys (TEST-5):** `kit-viewer` (default `viewerKey`), `kit-viewer-more`, `kit-viewer-close`, `kit-viewer-primary`, `kit-viewer-find`, `kit-viewer-find-next`, `kit-viewer-find-previous`, `kit-viewer-open-all`, `kit-viewer-retry`, `kit-viewer-page-<index>`, `kit-viewer-image`, `kit-viewer-table`. Adopters keep `file-preview-image` and `file-preview-text` by passing them through their wrappers' own keys, not by kit parameters.
- **Kit copy (ARB, `kit` prefix, en + ar):** `kitViewerFind` "Find in file", `kitViewerFindCount` "{index} of {count}", `kitViewerFindPrevious` "Previous match", `kitViewerFindNext` "Next match", `kitViewerCopyContents` "Copy contents", `kitViewerShowSource` "Show source", `kitViewerEmpty` "This file is empty", `kitViewerTruncated` "Showing the first {shown} of {total} lines", `kitViewerPartial` "Showing part of this file", `kitViewerOpenAll` "Open all", `kitViewerCantShow` "Can't show this file", `kitViewerCantShowBody` "{type} · {size}", `kitViewerLoadFailed` "Couldn't open {name}", `kitViewerPage` "Page {page} of {count}", `kitViewerPageFailed` "Couldn't show page {page}", plus the shared `kitMore` (KitAction.md), `kitWrapLines` (KitCodeBlock.md), `kitSheetClose` (exists), `kitTryAgain` (exists).

## States

| State | Body |
|---|---|
| loading (`.load` pending) | skeleton lines (`KitSkeletonRows` shaped as text lines); the header already shows name and path |
| error (`.load` threw) | inline `KitStateView` "Couldn't open README.md" with Try again (re-runs `load`); the error text goes into its Details (redacted) |
| empty | inline "This file is empty" (`text3`), Copy disabled |
| loaded | the renderer |
| truncated | a `KitNotice` line above the body: "Showing the first 2,000 of 5,210 lines" with "Open all" when `onOpenAll` is set; "Showing part of this file" when the total is unknown (STATE-11) |
| can't show (`binary`) | inline `KitStateView` with the type and size in words and the caller's action |
| page failed (pdf) | that page's inline error with Try again; other pages unaffected |
| finding | the search field, the match count, and the marks |

KIT-12 doc comment: "States: loading, error, empty, loaded, truncated, binary, page-failed, finding". Disabled applies to the `primary` (`KitAction.disabledReason`, shown under it).

## Tokens

- **ThemeRoles:** `surface2` (sheet body) or `ground` (page body), `text1` (name, prose), `text2` (path, captions), `text3` (empty text, line numbers), `hairline` (header rule, table grid), code roles through KitCodeBlock, `accent` only for links in prose (LOOK-6) and the find mark's current match outline.
- **KitText:** `headline` (name), `secondary` (path caption, notices), `mono` (path, code, table cells in source view), `body` (prose via KitMarkdown), `caption` (page caption, zoom hint), `label` (table header row).
- **KitTokens (VL branch):** `gutter` (16, prose rails), `space2`–`space4`, `minTarget`, `detailsSurface` (code surface through KitCodeBlock), `rowHeight` (54, the table's minimum row), `panelCornerRadius` (18, the page frame of an image or PDF page on a PC), `smallIconSize`.
- **Layout names:** `KitLayout.readingWidth` (720) caps prose documents; code, images, PDF pages and tables use the full width.
- **Pre-wave seams:** `KitTokens.hairlineWidth`, `KitBidi`, `KitCopy`, `KitRedact`.
- **No new tokens.**

## Adaptive

| Window | Presentation (`asPage: null`) | Body |
|---|---|---|
| compact | `showKitSheet(height: full)`: a bottom sheet at 95 % | code and text wrap by default; the table scrolls sideways; prose on the 16 dp rails |
| medium | the same sheet, capped at 640 dp wide and centred (`KitLayout.sheetMaxWidth`) | code scrolls sideways by default; Wrap toggles |
| expanded / large | a pushed page (`KitPageRoute`, `fullscreenDialog: true`, Close at the end) so code and tables get the width; prose centred at `readingWidth` | mouse text selection; scrollbars always visible where a box scrolls; PDF pages and images centred at their natural width up to the window |

- `asPage: true` always pushes a page (long documents: About, Privacy, notices); `asPage: false` always uses the sheet. `KitViewer` as a widget fills whatever pane holds it (the Files detail pane from expanded, `KitScreen.twoPane`).
- **Keyboard (LAY-10):** Esc closes the viewer (or Find first, when open). Ctrl+F opens Find; Enter and Shift+Enter move to the next and previous match; Ctrl+C copies the selection; Ctrl+plus/minus/0 zoom images, SVG and PDF. Tab order: primary, More, Close, then the body.
- **Pointer:** hover tooltips on More, Close and the find arrows; right-click in the body opens the same More menu (KIT-28 twin); Ctrl+wheel zooms.

## Accessibility

- The route is named by `name` (`namesRoute`); focus starts on the name. The path is read in full.
- More, Close, Find's arrows and Wrap are labelled 48 dp controls (A11Y-1, LAY-9).
- The match count is a polite live region, announced once when typing settles ("3 of 12").
- Prose reflows at 200 % (A11Y-2); code follows the text scale; the table's cells wrap to 2 lines and carry their full value; the image and PDF pages carry `semanticsLabel` / "Page 3 of 12".
- Contrast: prose and code meet LOOK-8 on `surface2` and `ground`.

## RTL

- The frame follows the locale: name and path at the start, More and Close at the end; Close never mirrors, the find arrows do not mirror (up and down).
- Code, text, paths and source views are LTR blocks aligned left (COPY-30). Prose follows the locale (Markdown in Arabic reads RTL).
- The delimited table keeps the file's column order left to right (it shows the file), with each cell isolated by `KitBidi.auto` so Arabic cell text shapes correctly.

## Motion and haptics

- Only the sheet or page transition (`KitMotion.standard`; instant under reduced motion). Find opens with `KitReveal`. Zoom is KitZoom's (it follows the gesture, and its control steps obey `KitMotion.reduced`).
- No layout animation while scrolling (MOT-5); PDF rendering happens only for visible pages (PERF-4).
- Haptics: none.

## Data safety and honest state

- **Links (SEC-1).** A Markdown link opens only through `openExternalLink`, inside KitMarkdown. The kit never calls `launchUrl`; with `interactive: false`, links are inert.
- **Redaction (SEC-2, G12).** Text, code and source views render through KitCodeBlock, which redacts; Copy contents copies redacted text. Saving or sharing the file is the caller's `more` item and uses the caller's bytes, not the screen text.
- **SVG.** Only an already-sanitised source is accepted; the kit renders it with no network access and no scripts.
- **Honest truncation (STATE-11).** A truncated source always says so, with the counts when known; "Open all" appears only with a real handler.
- **No dead ends (STATE-13).** "Can't show this file" always offers the caller's action (Share, Save or Open in Files), or says there is none.

## Depends on

- **From C25:** kit-KitCodeBlock (tier 1b: `.fill`, marks), kit-KitMarkdown (tier 1c: prose), kit-KitSearchField (tier 1c: Find), kit-KitIconButton-v2 (tier 1a), kit-KitImage (tier 1a: `KitImage`, `KitImageSource.memory`, `KitZoom` with its controls, per KitImage.md), kit-KitMenu (tier 1a: More and right-click).
- **kit-KitPageRoute** (tier 1a; edge added, README.md) for the page presentation. The unit stays in tier 1d.
- **Existing kit parts:** `showKitSheet` / `KitSheet`, `KitStateView` (inline; the v1 API suffices, and v2 is additive), `KitNotice`, `KitSkeletonRows`, `KitButton`, `KitReveal`, `KitLayout`.
- **Packages:** `flutter_svg` (already a dependency).
- **Pre-wave seams:** `KitBidi`, `KitCopy`, `KitRedact`, `KitTokens.hairlineWidth`.
- **Depended on by (C36):** shared-files-1, screen-files-1, screen-system-1, screen-voice-1, chat-1 (the code reader), shared-chat-1 (tool attachments).

## Tests required

In `test/kit/kit_viewer_test.dart`:

1. Frame: `showKitViewer(name: 'README.md', path: '/repo/README.md', primary: Add to prompt, more: [Copy path])` shows the name, the path, one labelled primary, More and Close; there is no second Copy in the body. Close and back complete the future.
2. More menu order: Find, Copy contents, Wrap lines, Show source (when applicable), then the caller's items; a destructive caller item is last after a divider.
3. Loading and error: a `.load` that is pending shows skeleton lines; one that throws shows "Couldn't open README.md" with Try again, which calls `load` once more; success shows the content.
4. Empty text shows "This file is empty" and Copy contents is disabled.
5. Truncated: `.code(…, truncated: true, totalLines: 5210)` shows "Showing the first 2,000 of 5,210 lines"; "Open all" appears only with `onOpenAll` and calls it once.
6. Links (SEC-1): tapping a Markdown link reaches `openExternalLink` once with the exact URL (a fake url_launcher platform records it); with `interactive: false` tapping does nothing; `launchUrl` is never reached outside `external_link.dart` (the G2 ratchet).
7. Find: typing "foo" in a 3-match text shows "1 of 3"; next moves to 2, wraps from 3 to 1; Esc closes Find first, then the viewer.
8. Show source: markdown with `showSource: false` renders prose; the checked item swaps to source and calls `onShowSourceChanged(true)`.
9. Wrap: `onWrapChanged` is called from the menu's Wrap item; with `wrap: null` a 360 dp window wraps code and a 1280 dp window does not.
10. PDF: with 12 pages and a fake `renderPage`, only visible pages are requested; scrolling away before completion calls `cancelPage`; a throwing page shows its own Try again while others render.
11. Delimited: 3 columns × 500 rows builds only visible rows; the header row stays visible while scrolling; an Arabic cell is wrapped in an FSI isolate.
12. Binary: shows "Can't show this file" with the type and size, and the caller's action.
13. Adaptive: `asPage: null` opens a bottom sheet at 412 dp and a pushed `KitPageRoute` at 1280 dp; `asPage: true` pushes a page at 412 dp.
14. Keyboard (G14): with desktop capabilities, Esc closes, Ctrl+F opens Find, Tab reaches primary, More and Close in order.
15. Redaction (G12): code containing `sk-ant-FAKE…` renders and copies (Copy contents) without it.
16. RTL: under Arabic, code blocks are LTR and left-aligned, while Markdown prose is RTL.
17. Reduced motion (G8): opening and Find settle after one `pump()`.
18. Overflow (G6): a 120-character name and a 300-character path at 320 and 412 dp × text 1.0/1.3/2.0 × LTR/RTL: no overflow.

## Galleries required

`test/goldens/kit/kit_viewer_golden_test.dart`, DPR 3.0, Android, deterministic content (TEST-11), names per TEST-20.

- **Each state at 412×915, dark and light:** `code` (Dart with line numbers), `markdown`, `image`, `pdf` (2 fake pages), `svg`, `delimited`, `binary`, `loading`, `error`, `truncated`, `finding`. 11 × 2 = 22 PNGs.
- **`code` at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000, dark and light:** 10 PNGs (a sheet up to 800, a page from 1280).
- **`code` and `markdown` at text 2.0 and in Arabic RTL, at 412×915 and 1280×800, dark and light:** 16 PNGs.
- **Total:** 48 PNGs.

## Non-goals

- No file reading, MIME sniffing, SVG sanitising, CSV parsing or PDF rendering: those stay in `lib/domain`, `lib/platform` and the caller.
- No editing, saving or sharing inside the kit (the caller's `more` items do it).
- No reader-preference persistence in the kit.
- No diff view (KitDiffView) and no log view (KitLogPanel).
- No screen adoption.

## Open questions

None. The kit-KitPageRoute edge is in README.md's build_units list (tier-1a, no tier change). `KitImage`, `KitImageSource` and `KitZoom` are as frozen in KitImage.md, and KitMarkdown as frozen in KitMarkdown.md (`interactive`, no link callback).
