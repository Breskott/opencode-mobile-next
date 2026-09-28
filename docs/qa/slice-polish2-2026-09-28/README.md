# slice-polish2 — demo "/", code lines, row supporting lines (2026-09-28)

Branch `revamp/slice-polish2` from `feat/phone-setup-v2` at 8e6b5f8e.

## What changed

1. **B12, demo chat, a typed "/"** (docs/qa/emulator-qa-2026-09-28/BACKLOG.md).
   Before, typing "/" in "Just show me" showed nothing. Now the composer's
   suggestion area shows one plain line: "The demo has no commands — send the
   sample prompt to see a change reviewed." (`demoNoCommands`, app_en.arb).
   It shows when the word at the caret starts with "/", at the start ("/") or
   mid-text ("Add a welcome line /rev"). A path inside a word ("src/welcome.txt")
   does not count. Kit: `KitComposerChips.suggestions(note:)`, a new
   "note" state. It is one `secondary` line on the panel surface, a live
   region with no tap target. Rows take its place when there are rows.
   `KitComposer` shows the suggestion area for a note, and Esc hides it the
   way it hides suggestions. The chat host now handles the isolated (demo)
   case inside `_suggestions` instead of turning inline suggestions off, so
   "@" still offers nothing in the demo.
2. **Long code lines broke mid-identifier** (`getStringExt|ra`,
   kit_markdown_streaming_dark; slice-goldens-kit "Owner eyeball").
   - `KitCodeBlock.defaultWrap`: code now scrolls sideways on every window.
     The existing Wrap toggle wraps it. Output still wraps on a compact
     window, and command still scrolls sideways.
   - `KitViewer` and `FilePreviewBody` (the viewer and the Files reader) use
     `kitViewerDefaultWrap`. Source code scrolls sideways. Plain text,
     markdown source and the other kinds still wrap on a phone, so a .txt
     file is not a sideways scroll.
   - When a line wraps, `kitCodeBreakable` adds display-only zero-width break
     chances after `. , ; : ( [ { = & | /`. So a wrapped line breaks at
     "intent." / "getStringExtra(" instead of mid-word. These stay whole:
     - a run of the same mark ("::", "==", "//");
     - a closing bracket, which never starts a line;
     - a short file extension ("test.dart").

     A token with no such mark still breaks where it must. Commands keep
     their reviewed R3 wrap (spaces and "/") with no added break chances.
     Copy uses the source, and a selection (Ctrl+C, the context menu or
     Share) copies without the marks: `_CopiesSource` is a
     SelectionContainer whose delegate strips them.
3. **Row supporting lines cut at 2.0 text** ("Editing workflow fil…").
   KitRow keeps the design standard §6 rule: one line at ordinary sizes, so
   dense lists stay dense. At large text the supporting line wraps before
   the ellipsis: at least two lines from 1.3× and three from 2.0×. A caller
   asking for more keeps its count, and an unavailable row's reason still
   wraps in full. The same happens in `KitSwitchRow` and `KitExpandRow`,
   which build on KitRow. The spec is updated in KitRow.md (A11Y-8) and in
   design-standard §6.

Specs updated: KitCodeBlock.md (defaultWrap, wrapped state, adaptive table),
KitComposerChips.md (note), KitRow.md, docs/design/design-standard.md §6.

## Tests

New:
- `test/kit/kit_code_block_breaks_test.dart` (8):
  - break-chance unit rules;
  - a phone scrolls code sideways and offers Wrap;
  - wrapping never splits a word at 360 and 412, or at 2.0 text;
  - a wrapped command gets no added marks;
  - a selection copy equals the source;
  - the streaming markdown fence scrolls on a phone.
- `test/kit/kit_row_test.dart` group "supporting line at large text"
  (6): max lines 1 / 2 / 3 / 3 at 1.0 / 1.3 / 2.0 / 3.0; the 2.0 line
  wraps without cutting; a caller's own higher count wins.
- `test/kit/kit_composer_chips_test.dart`: the note state (one line, live
  region, no tap target, rows win).
- `test/demo_isolation_test.dart`: B12 in the real DemoScreen. It covers "/"
  alone, plain words, "/" mid-text and a path. Nothing touches the real
  connection, preferences or native channels.

Before/after check: with the fix reverted (`kitCodeBreakable` returning its
input, defaultWrap as before), all 7 tests then in the breaks file failed.
The eighth (a wrapped command gets no added marks) came after that check and
was not run against the revert.

Existing tests updated to the new default:
- kit_code_block_test 4 (code scrolls on compact; output wraps);
- kit_code_block_r3 (the "on" glyph shown with output);
- kit_viewer_test 9 (the phone starts unwrapped for code);
- markdown_reading_test (RTL code starts scrolled, no toggle needed);
- reader_preferences_test (refused save keeps the unwrapped default).

Runs (affected files only, through `tool/qa/machine_lock.sh`), all green:
- kit_row, kit_row_parts, kit_row_group;
- kit_composer_chips, kit_composer, composer_layout;
- demo_isolation;
- kit_code_block, kit_code_block_r3, kit_code_block_breaks;
- kit_markdown, markdown_streaming, markdown_reading;
- reader_preferences, kit_viewer, kit_viewer_r1;
- common_file_preview, chat_attachment_reader;
- chat_live_events, product_ui_regression, transcript_search,
  code_highlight, design_standard;
- text_scale_overflow, kit_surface, termux_setup_v2_words,
  team_phone_onboarding;
- gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text,
  kit_manifest, kit_draft_manifest, architecture_boundaries,
  golden_harness, kit_motion, kit_motion_app, l10n_coverage.

`flutter analyze` (whole project): no issues.

## Goldens (reviewed)

I ran every golden file that shows a code block or renders at ≥1.3× text:
77 files in 9 serial chunks. 29 goldens failed, all pixel diffs with no
overflow and no exceptions. Every one is explained by this slice. After the
command-kind correction below, `--update-goldens` on those files changed
exactly 27 PNGs:

- **Code scrolls sideways on a phone (18):**
  - `kit_markdown_streaming_{dark,light}`, the owner's case;
  - `kit_markdown_default_{dark,light}` (only the Wrap glyph);
  - `kit_code_block_code_header{,_text2}_{dark,light}`;
  - `kit_code_block_fill_find_{dark,light}`;
  - `kit_viewer_code{,_text2}_{dark,light}`;
  - `kit_viewer_finding_{dark,light}`;
  - `embedded_file_preview_body_json_{dark,light}` (only the Wrap glyph).
- **Supporting line wraps at 2.0 (9):**
  - `kit_foundation_work_text2_{dark,light}`;
  - `kit_arrival_marked_text2_{dark,light}`;
  - `kit_section_label_page_text2_{dark,light}`;
  - `kit_sliver_row_group_default_text2_{dark,light}`;
  - `p310_settings_hub_text200_dark`.
- **New (2):** `chat_demo_slash_{dark,light}` (screen_chat_1, B12).

The first run also changed `kit_request_sheet_permission_1280x800_*`: the
command "offline_queue_test.dart" broke before ".dart". I judged that worse.
Commands now keep their R3 wrap, and a short extension stays with its name.
That golden is unchanged in the commit.

Contact sheets (before | after, from the committed goldens):
- `demo-slash-note.png`: B12, phone, dark and light.
- `code-scrolls-sideways-phone.png`: streaming reply, reply, header block,
  find block.
- `code-scrolls-sideways-text2-viewer.png`: 2.0 text, the viewer, Find, the
  JSON preview.
- `code-wide-unchanged.png`: 1280x800 (already sideways; unchanged).
- `row-supporting-text2.png`: work list, settings, section label, sliver
  group, settings hub at 200 %.

## Still needs a device

- Selecting across a wrapped code block and pasting it into another app. The
  test covers the in-app copy path; the Android selection toolbar's Share is
  the same `getSelectedContent`.
- Sideways scrolling of a code block inside the transcript on a real phone
  (touch drag, edge fade) and TalkBack on the demo note (live region).
- Find in a code file whose match sits past the right edge of an unwrapped
  line on a phone. The viewer scrolls to the line, not sideways to the
  match. That is today's wide-window behaviour, now also the phone default.
