# revamp-kit-KitTerminalView: KitTerminalView (2026-09-26)

## 1. Scope

- Unit: `kit-KitTerminalView` (wave 1, tier 1a, kit-part). Finish line: `KitTerminalView` exists in `lib/ui/kit/kit_terminal_view.dart` with its frozen API (live and output forms, `themeOf`, `selectedText`, `KitTerminalText`), the key bar has the kit look, 48 dp keys and the two server keys, the old `TerminalView` forwards to it, and the galleries and behaviour tests exist. Non-goal: no new terminal behaviour (no font size, paste, rename, stop, reconnect or exited state), no call site outside the kit changes, `kit.dart` untouched (R06).
- Files changed (code head `ea832084`):
  - `lib/ui/kit/kit_terminal_view.dart` (new part: `KitTerminalView`, `KitTerminalText`);
  - `lib/ui/kit/terminal_key_bar.dart` (kit look, 48 dp caps, `interrupt`/`endOfInput`, `extraRow`, `interruptKeys`, `disabledReason`, `KitTerminalKeyBar` typedef, no haptics);
  - `lib/ui/widgets/terminal_view.dart` (forwarding wrapper, "Retired by kit-KitTerminalView");
  - `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` and the generated `app_localizations*.dart`;
  - `test/kit/kit_terminal_view_test.dart` (new), `test/goldens/kit/kit_terminal_view_golden_test.dart` (new) and 34 PNGs;
  - `test/terminal_key_bar_test.dart`, `test/terminal_view_test.dart` (changed expectations, TEST-19, listed in §5).
- Pages (map ids): `terminal-surface` (elements `terminal-surface-view`, `terminal-surface-keys`), through the part only; no screen was migrated.
- Specs followed: `docs/ux-system/kit-api/KitTerminalView.md`; STANDARDS rules KIT-1, KIT-3, KIT-9, KIT-12, KIT-22, KIT-23, KIT-32, KIT-43, LOOK-1, LOOK-4, LOOK-5, LOOK-6, LOOK-8, LOOK-12, LOOK-16, LOOK-21, LAY-4, LAY-8, LAY-9, LAY-10, MOT-5, MOT-11, COPY-1, COPY-30, SEC-2, SEC-4, A11Y-1, A11Y-2, A11Y-8, TEST-5, TEST-9, TEST-15, TEST-19, TEST-20; kit-v2 §8.2, §8.4, §9.2; visual-language §3.
- Contract problems (PROC-20):
  1. **KitTerminalView.md "Tests required" 14 and "File"** say `test/terminal_view_test.dart` and `test/terminal_key_bar_test.dart` "must keep passing unchanged". The same spec's tokens make that impossible: dimmed folders are `text3` (the old test expects `AppTheme.mutedOf` = `text2`), errors and `-n` counts are `text1` semibold, never `danger` (LOOK-5; the old test expects `colorScheme.error`), and the new `interrupt`/`endOfInput` enum values show only with `interruptKeys` (the old test expects every `TerminalBarKey.values` in the default bar). Evidence: `base-expectations-on-new-code.txt` (4 failures, all look or key-set assertions). Resolution applied: TEST-19 (1), expectations changed, listed in §5. Proposed text: "…keep passing, with the look expectations TEST-19 (1) changes".
  2. **KIT-12 doc line.** The spec's "States: live, read-only (disabled), empty; output: tail, all, too long" fails gate G4 (`test/kit/kit_manifest_test.dart` accepts only loading, empty, error, disabled, working, answered). The part declares `States: disabled, empty.` and describes its own states on the next line. G4 then requires `kit_terminal_view_disabled_*` and `kit_terminal_view_empty_*` goldens, so the spec's `live_readonly` shot is named `disabled`, and an `empty` shot was added: 34 PNGs, not 32 (under the 60 cap).
  3. **Gallery `keys_compact` "412×915 with a 300 dp keyboard inset".** By the spec's own rule (compact when the window left above the keyboard is under 480 dp), 412×915 with 300 dp of keyboard leaves 615 dp: two rows, not compact. The `keys_compact` shot is 915×412 with a 200 dp keyboard; the 412×915 + 300 dp case is a behaviour test ("one row only when the room above the keyboard is short").
  4. **"2 rows × 48 dp" and "48 × 48 at 320 dp wide" (tests required 1).** Eight 48 dp keys and seven `space1` gaps need 412 dp. Below that the two rows scroll sideways together (columns stay where a keyboard has them); from 412 dp they fill the width, capped at `KitLayout.readingWidth` and centred. At 360 dp, PgUp and PgDn are one swipe away.
  5. **Task acceptance vs STANDARDS.** The unit task says `terminal_view.dart` "becomes a @Deprecated wrapper or is git mv-ed with a re-export (R12)"; STANDARDS KIT-43 (and the frozen spec) forbid `@Deprecated`. Followed KIT-43: a forwarding wrapper marked "Retired by kit-KitTerminalView: use KitTerminalView.output". The task also names the record `docs/qa/revamp-<unit id>/README.md`; EVID-1 adds the date, which this folder follows.
  6. **KIT-43 G2 pattern.** KIT-43 asks the unit to add the retired names (`TerminalView(`, `stripAnsi(`) as G2 ratchet patterns; `test/kit_ratchet_test.dart` is outside this unit's write set (R10, KIT-44). Not added; kit-gates or the integrator.
  7. **256-colour and true-colour in the output form.** The spec says a program's own 256/true colours are "shown as sent". The live view (xterm) does; the output form keeps today's behaviour (the colour is skipped, the text keeps the base colour) because building a `Color` from the stream inside the kit trips G17 (`Color.fromARGB`, LOOK-1). The 16 ANSI colours map to roles in both forms.
- Decisions recorded for the coordinator (no rule decides them):
  - Hover and pressed fill of a key: `surface3` is the top surface step, so there is no KitTappable step above it; the cap takes `hairline` blended over `surface3` (roles only).
  - Hardware keys only: with a fine pointer on a wide window (spec), and also on every desktop build (today's `terminal_screen.dart` behaviour, so a keystroke never arrives twice). An Android tablet with a mouse and no keyboard at expanded width also loses the key bar and the IME under the spec's rule; flagged for wave 2.
  - The framed block's fill `detailsSurface` is `ground` in light: on a ground page in light the frame does not show (it reads on sheets and cards). The gallery hosts the output form in a `KitSheet`. Wave-2 callers on the ground choose `framed: false` or a surface.
  - Spoken names: `/ - | ~ Home End` had their caps as their spoken names ("not its cap", A11Y-1). New keys `kitTerminalViewKey{Slash,Dash,Pipe,Tilde,Home,End}` ("Slash key", …) replace them in the bar. The old `localTerminalKeyHome`/`End` keys stay (R04).
- New kit parts (KIT-3): `KitTerminalView` and `KitTerminalText` (this unit's part), `KitTerminalKeyBar` (typedef, the NAME-1 name for `TerminalKeyBar`). `kit.dart` rows are the integrator's (R06); with them added locally, G4 and G8x pass (verified, then reverted).
- Map items (EVID-11), `terminal-surface` (proposal `fix`):
  - actionsMissing "rename / stop from here" → deferred to screen-terminal-1 (spec non-goal);
  - actionsMissing "paste" → deferred to screen-terminal-1;
  - actionsMissing "font size" → deferred to screen-terminal-1;
  - statesMissing "process exited (restart/remove here)" → deferred to screen-terminal-1;
  - statesMissing "reconnecting status line instead of PID" → deferred to screen-terminal-1;
  - couldBeAutomatic: none in the record.
- States per page (STATE-20): n/a, no page migrated. The part's states: live, disabled (read-only), keys latched, keys compact, output tail, all, too long, empty → the goldens in §5 and the tests in `test/kit/kit_terminal_view_test.dart`.
- Deferred states (STATE-21): none for the part; loading and error are the host's (spec).

## 2. Builds

- Branch `revamp/kit-KitTerminalView`, base `b67e3276` (feat/phone-setup-v2 when the branch was cut), code head `ea832084`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Base `test/terminal_view_test.dart` and `test/terminal_key_bar_test.dart` against the new code | the 4 look/key-set assertions the spec changes fail; the rest pass | 11 passed, 4 failed (the 4 named in §1 problem 1): `base-expectations-on-new-code.txt` | PASS |
| 2 | `test/kit/kit_terminal_view_test.dart`, `test/terminal_key_bar_test.dart`, `test/terminal_view_test.dart` | pass | 90 passed: `run-part-tests.txt` | PASS |
| 3 | Callers in the tests write set: `local_terminal_screen_test`, `local_terminal_test`, `phone_server_card_test`, `phone_setup_progress_screen_test` | pass unchanged | 89 passed: `run-caller-tests.txt` | PASS |
| 4 | Gallery `test/goldens/kit/kit_terminal_view_golden_test.dart` (compare, three chunks) | 34 shots match, G5 clean | 16 + 10 + 8 passed: `run-gallery-1.txt`, `run-gallery-2.txt`, `run-gallery-3.txt` | PASS |
| 5 | Ratchet, golden harness, l10n, glossary, ledger, design-standard, kit motion gates | pass (counts may only drop) | 259 passed; G2, G16, G17, G21 report drops for this unit's files: `run-gates.txt` | PASS |
| 6 | `test/kit/kit_manifest_test.dart` (G4) | only the integrator's `kit.dart` rows missing (R06) | fails on "exported" and "docRow" for KitTerminalView only: `run-manifest.txt`; with the two rows added locally all 181 manifest and motion tests pass (reverted) | PASS (expected until integration) |
| 7 | Other `TerminalView` callers' tests: `tool_card_test`, `chat_transcript_lens_test`, `run_result_screen_test`, `release_blockers_test`, `product_ui_regression_test`, `motion_states_test` | pass unchanged | all passed (console runs, not saved) | PASS |
| 8 | `dart analyze lib`, `dart analyze test` | no issues | No issues found (both) | PASS |

## 5. Evidence

- `base-expectations-on-new-code.txt`: step 1.
- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_terminal_view_test.dart` unless named) or golden | Output |
  |---|---|---|
  | LAY-9 | "1. two rows / compact / with Ctrl-C and Ctrl-D: every key is 48 x 48, apart, reachable at 320 dp" | `run-part-tests.txt` |
  | KIT-43, latch | "2. Ctrl latches for one key, with toggled semantics"; `test/terminal_key_bar_test.dart` | `run-part-tests.txt` |
  | spec keys | "3. Ctrl-C and Ctrl-D reach the terminal as 0x03 and 0x04", "3. a server bar leads with Ctrl-C, which sends 0x03" | `run-part-tests.txt` |
  | MOT-11 | "4. no key vibrates" | `run-part-tests.txt` |
  | A11Y-1, STATE-8 | "5. disabled keys ignore taps and say why" | `run-part-tests.txt` |
  | behaviour kept | "6. in application cursor mode the up arrow sends ESC O A" | `run-part-tests.txt` |
  | LAY-10, G14 | "7. Tab reaches the shell; Ctrl+Tab leaves the terminal", "7. a PC window: hardware keys only, and no key bar" | `run-part-tests.txt` |
  | kit-v2 §8.2 | "adaptive: the bar is capped and centred on a medium window", "adaptive: one row only when the room above the keyboard is short" | `run-part-tests.txt` |
  | honest state | "8. read-only drops typed input and disables the keys" | `run-part-tests.txt` |
  | A11Y-1 | "the view is one labelled node; the grid is not read" | `run-part-tests.txt` |
  | KIT-23 | "selectedText returns only the selection" | `run-part-tests.txt` |
  | LOOK-1, LOOK-6 | "9. the palette …" (themeOf, painted-colour scan of the live and output scenes, dark and light) | `run-part-tests.txt` |
  | spec states | "10. the tail first …", "10. too long: …", "10. too long with nowhere to open …", "empty: only the command, or nothing at all" | `run-part-tests.txt` |
  | SEC-2, SEC-4 | "11. secrets are masked on screen and in the full text" | `run-part-tests.txt` |
  | LOOK-4, LOOK-5 | "12. tints: errors text1 semibold, warnings not amber, ANSI red" | `run-part-tests.txt` |
  | COPY-30, KIT-32 | "13. in Arabic the block stays left to right, buttons at start" | `run-part-tests.txt` |
  | R12, KIT-43 | "14. the old TerminalView forwards to KitTerminalView.output" | `run-part-tests.txt` |
  | G6, A11Y-2 | "15. overflow (G6) …" (320×640, 412×915, 915×412 × text 1.0, 1.3, 2.0 × en, ar × live, output) | `run-part-tests.txt` |
  | G8, MOT-5 | "KitTerminalView (MOT-7) …" (live, output, show earlier, latch × system, effectsOff) | `run-part-tests.txt` |
  | TEST-9, G5 | gallery, every shot checked in both themes | `run-gallery-*.txt` |

- Changed test expectations (TEST-19):
  - `test/terminal_view_test.dart` "the program stands out of its path": folder colour `AppTheme.mutedOf` (text2) → `rolesOf(theme).text3` (KitTerminalView.md tokens: "`$` and dimmed folders `text3`").
  - `test/terminal_view_test.dart` "output keeps its colours": `Error: something` `colorScheme.error` → `text1` with `FontWeight.w600`; ` -1` `colorScheme.error` → `text1` (LOOK-5, B2 interim).
  - `test/terminal_key_bar_test.dart` "has every key the spec lists" and "every key is at least 44 by 48 on a phone": iterate `TerminalBarKey.rows` instead of `TerminalBarKey.values` (the new `extraRow` keys show only with `interruptKeys`; they are covered in the new test file).
- Goldens added (each opened and looked at), all under `test/goldens/kit/`:
  - declared states, dark and light: `kit_terminal_view_live`, `_disabled`, `_keys_latched` (a server bar: ^C and ^D lead, Ctrl latched in accent), `_keys_compact_915x412` (one row above a 200 dp keyboard), `_output_tail`, `_output_all`, `_output_too_long` (last 2,000 lines, "Open all 2,500 lines"), `_empty` (the command alone);
  - `live` dark and light at 360×800 (the rows scroll: PgUp/PgDn one swipe away), 915×412, 800×1280 (bar capped at 720 and centred), 1280×800 and 1600×1000 (desktop: no key bar);
  - `live` and `output_tail` at text 2.0 and in Arabic, dark, at 412×915 and 1280×800 (Arabic: the sheet mirrors, "Show earlier" at the start (right) edge, the block stays LTR; the key bar stays LTR; a touch tablet at 1280 keeps its keys).
  - Approved VL canvas render (EVID-12): none exists for the terminal.
- Before and after (EVID-10):
  - `before-terminal-surface-connected.png` (base census `docs/qa/screen-census/f-files-review-terminal/terminal-surface--connected.png`: literal `#0A0C0F` ground, 8 outlined keys with Material glyph boxes for the arrows) → `after-terminal-surface-keys.png` and `after-terminal-surface-live.png` (the part; the screen itself moves in screen-terminal-1).
  - `before-phone-setup-progress-details-open.png` (base census of a `TerminalView` caller) → `after-output-tail.png` (the output form in the gallery). The census is re-rendered by the coordinator (TEST-17).
- Accessibility: the live view is one node labelled `semanticsLabel` with the grid excluded; the bar is one container "Terminal keys"; each key is a button with a spoken name (new: "Slash key", "Dash key", "Pipe key", "Tilde key", "Home key", "End key"; new keys "Interrupt, Control C", "End of input, Control D"), Ctrl and Alt toggled, disabled keys carry the reason as hint; caps are at least 48 × 48 dp with no overlap; caps clamp at 1.3× text, the terminal face at 2.0×; the selectable output block is at least 48 dp tall; the output buttons are Tab stops; focus ring 2 physical px in accent. G5 (tap targets, labels, text contrast, reading order) passed for every gallery shot in both themes.
- Privacy and security: output lines and the command pass through `KitRedact.text` before display and before `onOpenFull` (tested with a fake provider key and a bearer header); the live shell is not redacted and never copied by the kit (`selectedText` returns the selection to the host). No stored data, links or notifications changed.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get --offline
$F test -j 1 test/kit/kit_terminal_view_test.dart test/terminal_key_bar_test.dart test/terminal_view_test.dart
$F test -j 1 test/local_terminal_screen_test.dart test/local_terminal_test.dart test/phone_server_card_test.dart test/phone_setup_progress_screen_test.dart
$F test -j 1 test/goldens/kit/kit_terminal_view_golden_test.dart --name 'live · (dark|light)$|disabled|keys latched|keys compact|output (tail|all|too long) · (dark|light)$|empty'
$F test -j 1 test/goldens/kit/kit_terminal_view_golden_test.dart --name 'live · [0-9]+x[0-9]+ ·'
$F test -j 1 test/goldens/kit/kit_terminal_view_golden_test.dart --name '2.0 text|· ar ·'
$F test -j 1 test/kit_ratchet_test.dart test/golden_harness_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart test/design_standard_test.dart test/kit_motion_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart   # passes once kit.dart exports the part (R06)
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/dart analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator: no proof that the soft keyboard, IME deletes, a Bluetooth keyboard or a mouse behave on Android with the new bar and view.
- The screens (`terminal_screen.dart`, `local_terminal_screen.dart`) still draw their own view and strip; nothing here shows them on the part (screen-terminal-1, wave 2).
- `kit.dart` does not export the part yet, so G4 fails on this branch until the integrator adds the rows (verified locally, then reverted).
- The ratchet baselines still hold the old counts for `terminal_view.dart` and `terminal_key_bar.dart`; the gates pass on drops, and the integrator regenerates them.
- The output form's 256-colour and true-colour runs are not coloured (§1 problem 7).
- Hover and focus-ring renders are not in a golden (no pointer in the gallery); they are covered only by code and the G14 focus test.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTerminalView` |
| Enabled | Partly: the key bar's new look reaches `LocalTerminalView` and the output form reaches every `TerminalView` caller through the wrapper; `KitTerminalView.live` has no caller until wave 2 | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `ea832084` |
| Deployed | No | |
| Released | No | |
