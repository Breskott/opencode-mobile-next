# revamp-kit-KitMarkdown: KitMarkdown, agent Markdown in kit text (2026-09-27)

## 1. Scope

- Unit: `kit-KitMarkdown` (wave 1, tier 4, kit part). Finish line: agent Markdown renders through `KitMarkdown` in kit text, and `lib/ui/widgets/markdown.dart` is a forwarding layer at G16 zero. Non-goal: no caller migrated (callers keep `MarkdownText`), no `kit.dart` export, no agent-block or search-engine changes.
- Files changed: `lib/ui/kit/chat/kit_markdown.dart` (new), `lib/ui/widgets/markdown.dart` (forwarding layer), `lib/l10n/app_en.arb` + generated `app_localizations*.dart`, `test/kit/kit_markdown_test.dart`, `test/goldens/kit/kit_markdown_golden_test.dart` and its 26 PNGs, this record.
- Pages (map ids): `embedded-markdown-text` (link, table), `markdown-code-reader` (reader page in the wrapper).
- Specs followed: `docs/ux-system/kit-api/KitMarkdown.md` (frozen API); kit-v2 §9.1, §9.2; STANDARDS KIT-41, KIT-43, STATE-16, SEC-1, KIT-32, LOOK-6, LOOK-12, LOOK-21, A11Y-3, PERF-2, R12.
- Contract problems (PROC-20):
  1. **`@visibleForTesting` on `KitMarkdown.debugParseCount`** (spec, Public API). The same spec says `MarkdownText.debugParseCount` forwards to it from `lib/`, which the annotation forbids (`invalid_use_of_visible_for_testing_member`, a warning), and no suppression may be added. Built without the annotation; the doc comment says tests only. Proposed text: drop `@visibleForTesting` from the kit static, or let the wrapper keep its own counter. Blocks: nothing.
  2. **`CodeBlock` → `KitCodeBlock(wrap: initialWrap)`** (Compatibility). A non-null `wrap` freezes KitCodeBlock's own Wrap toggle (`_effectiveWrap` returns `widget.wrap` first, and without `onWrapChanged` the toggle changes nothing). Built as: the reader preference when a `ReaderPreferencesScope` exists, else `true` when `initialWrap`, else null (the block's own default and toggle). A caller passing `initialWrap: true` without the scope still gets a frozen wrap; KitCodeBlock has no "initial wrap" parameter. Proposed: KitCodeBlock gains `initialWrap`. Blocks: nothing.
  3. **Tokens: `surface3` inline code background** (Tokens). Gate G5's text-contrast check samples a node at one pixel per logical pixel; a `surface3` run beside 14 px prose becomes the second colour and the paragraph fails (1.33:1 measured on `kit_markdown_secondary`). Inline code and path chips draw without the tint; the mono face marks them. Proposed: drop `surface3` from the token list. Blocks: nothing.
  4. **Manifest vs. spec on `disabled`** (KIT-12 vs. KitMarkdown.md States). `test/kit/kit_manifest_test.dart` requires a `disabled` state for a part with a nullable `on…` callback (`onCodeWrapChanged`, `onOpenCode`); the spec says "no disabled". Left as the spec says; the integrator decides.
- New kit parts (KIT-3): `KitMarkdown` (with `KitMarkdownFileLinks`, `KitMarkdownBlockBuilder`, `KitMarkdownHighlighter`) in `lib/ui/kit/chat/kit_markdown.dart`. Not exported from `kit.dart` (R06: the integrator adds it).
- Map items (EVID-11):
  - `embedded-markdown-text-link` → done: test 6 (link through `openExternalLink`, bare URL, non-interactive), golden `kit_markdown_default_*`.
  - `embedded-markdown-text-table` → done: test 8, golden `kit_markdown_table_*` (statesMissing "very wide table": scrolls inside its box; owner Fix "table first-column sizing": the first column never drops below its longest word).
  - `embedded-markdown-text-code` → KitCodeBlock's (rendered through it; owner Fix "code right-edge fade/wrap" is KitCodeBlock's edge fade and window-default wrap).
  - `embedded-markdown-text-agent-choice` → shared-shell-1 (KitChoiceList in KitRequestCard), reached through `blockBuilder`; the wrapper still builds `AgentChoicesBlock` (test 10).
  - `markdown-code-reader` → the wrapper's reader page is `KitScreen` + `KitTopBar` (Wrap, Copy code) + `KitCodeBlock.fill`; no golden of it in this unit (the page is a screen, and its migration belongs to the chat chain link).
- States per page (STATE-20): default → golden `kit_markdown_default_*`; streaming → test 3, golden `kit_markdown_streaming_*`; non-interactive → test 6; empty → test "empty data renders nothing", golden `kit_markdown_empty_*`; secondary role → golden `kit_markdown_secondary_*`; validated path → test 7, golden `kit_markdown_path_link_*`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitMarkdown-v3` (the names `revamp/kit-KitMarkdown` and `-v2` were already held by other worktrees), base `eebd79d4` (feat/phone-setup-v2), code head `79d941e4`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part | n/a | n/a |
| 2 | `test/kit/kit_markdown_test.dart` | passes | 16 passed | PASS |
| 3 | `test/goldens/kit/kit_markdown_golden_test.dart` (G5 inside every shot) | passes | 26 passed | PASS |
| 4 | Ratchet, design-standard, l10n, glossary, ledger, manifest tests | pass | not run (owner decision 2026-09-27: run only the unit's own files) | NOT RUN |
| 5 | `flutter analyze --no-pub lib/ui test/kit/kit_markdown_test.dart test/goldens/kit/kit_markdown_golden_test.dart` | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_markdown_test.dart` + `--plain-name`) or golden |
  |---|---|
  | LOOK-12 role table | "1. blocks render in the role table" |
  | PERF-2 parse once | "2. streaming parses once per change and reuses earlier blocks" |
  | honest streaming | "3. an unclosed fence is unhighlighted until it closes" |
  | C24 block builder | "4. blockBuilder claims fences, once per closed fence" |
  | search highlight | "5. the highlighter decorates without changing the text" |
  | SEC-1 | "6. a link goes through openExternalLink; non-interactive is text" |
  | path links | "7. a path chip lights up only after validate says true" |
  | wide table | "8. a 12-column table scrolls inside its box at 320 dp" |
  | codeLanguage, onOpenCode | "9. codeLanguage and onOpenCode" |
  | KIT-43 wrapper | "10. the MarkdownText wrapper forwards to the kit" |
  | A11Y header/link, A11Y-3 | "11. semantics: header and link nodes, no live region" |
  | direction | "12. an English paragraph in an RTL app reads LTR" |
  | G6 | "13. 200 % text at 320.0 dp / 412.0 dp does not overflow" |
  | G5 | every gallery shot (`kitGalleryShot` runs tap target, labelled target, contrast, reading order in both themes) |

- Changed test expectations (TEST-19): none edited. Shared tests in this unit's tests list that are expected to fail (not run, owner decision): see "NOT proven".
- Goldens (all new, each opened and looked at): `kit_markdown_{default,table,streaming,secondary,path_link,empty}_{dark,light}.png`, the same at `_1280x800_`, and `kit_markdown_default_text2_{dark,light}.png`. Default: heading, emphasis, link, list with inline code, quote stroke, fenced dart. Table at 412: scrolls, clipped at the box edge, mono addresses on the text baseline. Streaming: plain unhighlighted kotlin. Path link: accent underlined mono. Text 2.0: everything wraps, the marker column grows with the scale.
- Accessibility: headings have header semantics; links are link nodes (TextSpan recognizers) with accent + underline; path links are link nodes with the `kitMarkdownOpenFile` hint and are focusable (Enter opens, accent focus ring); tables announce `kitMarkdownTable` and read one merged node per row; list markers are merged with their item; no live region. 200 % text checked at 320 and 412 dp (LTR only; Arabic dropped by the owner).
- Privacy and security: links open only through `openExternalLink` (no link callback exists); paths open only after `validate` returned true; fences copy their exact source through KitCodeBlock (KitCopy, `redact: false` per SEC-13 of the spec header).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_markdown_test.dart
$F test -j 1 test/goldens/kit/kit_markdown_golden_test.dart
$F analyze lib/ui test/kit/kit_markdown_test.dart test/goldens/kit/kit_markdown_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The shared test files were not run (owner decision). Expected to break on the new render tree (the integrator fixes, R08/TEST-19): `test/markdown_reading_test.dart` (old CodeBlock toolbar: PopupMenu, copy SnackBars, reader route), `test/markdown_streaming_test.dart:75` and `test/chat_live_events_test.dart:3820` (`CodeBlock` inside `MarkdownText` is now `KitCodeBlock`), `test/markdown_agent_blocks_test.dart:69,134` (same; also an unclosed agent fence is now a code block until it closes, as the spec says), `test/code_highlight_test.dart:16,46` (KitCodeBlock does not use `SelectableText`), `test/reader_preferences_test.dart:142,256,278` (code options PopupMenu is gone), `test/chat_transcript_lens_test.dart:313`, `test/transcript_search_test.dart:259,273` (paragraphs are no longer `SelectableText`; one `KitSelectable` region per reply), `test/chat_live_events_test.dart:2217` (`DataTable` is gone). Also the shared gates: `test/kit/kit_manifest_test.dart` (KitMarkdown not exported, no kit.dart doc row, not named in the motion/keyboard/overflow tests, the `disabled` question above) and the ratchet baseline for `markdown.dart` (counts drop to zero; the integrator regenerates).
- Find-in-conversation no longer marks matches inside fenced code: KitCodeBlock takes no highlighter (only `.fill` has `marks`). Paragraph matches still highlight.
- Keyboard focus of inline Markdown links: TextSpan links are not Tab stops (only path chips and a scrolling table are). Link spans carry no `kitMarkdownOpenLink` hint (a span cannot carry a hint); the key exists for the next pass.
- Link and path targets are the glyph box, not 48 dp (LAY-9): an inline span cannot grow its hit area without moving the text.
- Inline code has no `surface3` tint (contract problem 3).
- Arabic/RTL galleries and review: dropped by the owner's 2026-09-27 decision; test 12 checks only that an English paragraph stays LTR under RTL.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitMarkdown-v3` |
| Enabled | Yes: every `MarkdownText` caller renders through it | |
| Verified | Own tests and goldens only | this record |
| Committed | Yes | code head `79d941e4` |
| Deployed | No | |
| Released | No | |
