# slice-fix-chat — chat/markdown/request test failures (2026-09-28)

Base: full-suite re-run on `feat/phone-setup-v2` @ `7954e980`
(`behaviour-failures.txt`). Branch `revamp/slice-fix-chat`, merged
`feat/phone-setup-v2` @ `2be7843c` (slice-fix-team) before the final runs.
Every failing test got one verdict. Pixel-only golden diffs are left for the
reviewed refresh.

## Product bugs fixed (each test failed before the fix and passes after)

| Test | Bug | Fix |
|---|---|---|
| kit/kit_terminal_view "10. too long: Open all…" and "…nowhere to open…" | Merge `1882e079` (KitUndo, kit tier 1) dropped `"format": "decimalPattern"` from `terminalShowEarlier` / `terminalOpenFull`, so the buttons read "Open all 2500 lines" | `lib/l10n/app_en.arb`: format restored, gen-l10n |
| markdown_reading "clipboard failure is recoverable and retries the exact snapshot" | A refused clipboard left an unhandled `PlatformException` and said nothing (the failure line was lost in 79d941e4, its strings swept in 4316dc8c) | `KitIconButton.copy` takes `onCopyFailed` (no host: the error is rethrown as before); `KitCodeBlock` shows "Could not copy code. Try again." (per kind) with Try again, which copies the same snapshot. New copy: `kitCodeCopyFailedCode/Command/Output` |
| markdown_reading "RTL code starts at the beginning…", "wrap and reader preserve parent scroll offset…" | The code reader (`KitCodeBlock.fill`, unwrapped) overflowed by ~5,900 px: no sideways scroller | `lib/ui/kit/kit_code_block.dart`: an unwrapped `.fill` wider than its host scrolls sideways (one scroller for the block) |
| markdown_reading "open reader retires controls when source becomes inert", "reader stays local and retires after source row is removed" | 79d941e4 lost the reader's retire contract: an open reader kept Copy/Wrap/selection after its source went inert or left the tree | `lib/ui/widgets/markdown.dart`: the reader follows the source's live state and retires on inert or dispose |
| motion_adopt "send ticks; a finished reply confirms with KitHaptics.done" (coordinator) | One send fired the send haptic twice (KitComposer and the chat screen's send path) | `lib/ui/screens/chat_screen.dart`: the composer owns the tick; the duplicate call removed |

## Stale tests (updated to the new intended behaviour)

| Test(s) | Replaced by | Change |
|---|---|---|
| message_delete_transport "declared message delete errors…", sync_transport "declared steal errors…" | `0436b230` server prose stays out of product messages | assert the authored message and the server text in `cause` (also a stale comment in `product_repository.dart`) |
| code_highlight ×3 | `79d941e4` fences are KitCodeBlock `Text.rich`, not `SelectableText` | helpers read the block's spans; keyword weight, plain unknown fence, diff colours kept |
| markdown_streaming "rebuilds only its streaming tail" | `79d941e4` block widgets renamed | widget names only |
| markdown_reading ×10 (toolbar row ×2, fence cases 3/5, CRLF copy, inert code, tables ×2, path chips, snapshot across streaming) | `79d941e4` (KitMarkdown/KitCodeBlock), `4316dc8c` (snapshot note string) | finders and layout facts of the kit parts; every behaviour assertion kept |
| chat_empty_start "tapping a starter…", "Arabic…" | `a1410445`/`0b6c298c` the composer field is a KitField (`TextFormField`) | read the field as `TextFormField` / inner `TextField` |
| chat_empty_start "320dp at 2.5x text fits, keyboard up or down…" | `e28442b0` (chat-3 composer rebuild; proven in a temporary worktree: passes at `e28442b0^`, fails at `e28442b0`) — the taller composer leaves 68 dp for a 70 dp row, and the empty chat's rule gives the composer every pixel | keyboard down: row, 48 dp chips, sideways scroll; keyboard up: no overflow, composer above the keyboard, a shown row sits above it |
| chat_form "a 400 invalid answer…", chat_permission "a failed reply…", request_sheet_lifecycle "…recoverable error preserve the question draft", form_renderer "send failure shows the error notice…" | `6cdfca4e`, `a65dcea9` errors in plain words; server prose only under Details | assert the category copy and that the raw text is absent (fixtures carry a real status: 400 / 503) |
| form_renderer "external https field confirms with the real host first" | `06102116` link gate body "Opens {host} outside this app." | host asserted inside the body sentence |
| session_skill "uncertain activation…" | `cf8f5eda` Skills rebuilt on KitButton | cast to `KitButton` |
| kit/kit_ask_line ×2 (dark, light) | `4e49ccde` R5: enabled tertiary answers use the accent (KitAskLine.md updated) | answers asserted `accent`; glyph/question roles and opacity kept |
| e7_session_approvals_layout ×6 | `9bcf3cca` automatic approval needs the server's automation policy; KitSheet header scrolls away at 2.5x; `3d64653c` controller-owned 8 s connection clock | boot sets the policy (as the controller test does), scroll to the search field, and the paused test runs past the grace period (the indicator stays paused) |
| return_brief_widget ×5 | `08a7741e` KitRow v2, `23b2efb5` Work tab from kit parts | row menu opened by long-press |
| revamp/screen_chat_1 | `253a6919` R16 (Leave demo, Reset demo on the status line) | asserts the new one way out; set-up on the finish stays covered by demo_isolation_test |
| revamp/screen_chat_2 ×2 | `00cafa13` ("Continue {title} on computer"), `253a6919` (count line removed) | copy and the three rows back after Clear |
| v2_transcript_rows "classic scope…" | `531bb6ab` "Use {model}" | expects "Use GPT-5.6 Sol" |
| web_search ×3 | `e28442b0`, `e2543231`, `531bb6ab`, `a1410445` | tools row by key, KitIconButton search, tooltips, `TextFormField` |
| goldens/chat_states "chat · disconnected" ×2 (non-pixel) | `3d64653c` one controller-owned status in the app status slot | harness hosts `AppConditionsScope` + `connectionKitStatus` like main.dart |

Counts (54 listed failures): product bug 7 tests (4 bugs) plus the
coordinator's haptic test (1 bug); stale 47 tests; gate/inventory 0.

## Still failing

`test/goldens/chat_states_golden_test.dart`: 14 cases, pixel diffs only
(empty/loading/transcript/model error/disconnected 0.4–2.9 %; find 22–30 %,
permission sheet 20 %). Left for the reviewed golden refresh; the large find
and permission-sheet diffs deserve a look in that review.

## Checks

- All 20 owned files plus motion_adopt, kit_composer, kit_code_block(_r3),
  kit_copy, kit_icon_button, kit_markdown, kit_viewer: pass (goldens above
  excepted).
- Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text,
  kit_manifest, kit_draft_manifest, architecture_boundaries — pass.
- `flutter analyze`: no issues.
- Product edits outside the chat library: `lib/api/product_repository.dart`
  (comment only), `lib/ui/kit/kit_icon_button.dart`,
  `lib/ui/kit/kit_code_block.dart`, `lib/ui/widgets/markdown.dart`,
  `lib/l10n/app_en.arb` (+ generated).
