# revamp-kit-KitLogPanel: Build KitLogPanel (2026-09-27)

## 1. Scope

- Unit: `kit-KitLogPanel` (wave 1, tier 3 in the run's numbering, `kit-part`). Finish line: `KitLogPanel`, `KitLogBuffer`, `KitLogLine`, `KitLogEnd`, `KitLogSize` and `KitLogPanel.fold` exist to the frozen API in `docs/ux-system/kit-api/KitLogPanel.md`, with behaviour tests and a gallery. Non-goal: moving screens onto it (`SetupTerminal` and the log sheets move in shared-phone-1, shared-review-1 and the other adopting units).
- Files changed: `lib/ui/kit/kit_log_panel.dart` (new), `test/kit/kit_log_panel_test.dart` (new), `test/goldens/kit/kit_log_panel_golden_test.dart` (new) plus 18 PNGs, `lib/l10n/app_en.arb` (+16 `kit`-prefixed keys) and the regenerated `lib/l10n/app_localizations*.dart`.
- Pages (map ids): none adopted. The part covers the 18 elements on 15 pages that KitLogPanel.md "Replaces" lists.
- Specs followed: KitLogPanel.md (frozen API); kit-v2 §1.11, §4.4, §8.2; G9, G12; KIT-31, KIT-32, LOOK-4, LOOK-5, LOOK-16, COPY-11, SEC-2, SEC-4, PERF-4, A11Y-3, MOT-5, MOT-7.
- Acceptance: "mono LTR, folded (does not compose KitCodeBlock)". The body is an LTR `AppMono` block in every locale, `folded` is the default size, and the part does not import KitCodeBlock.
- Contract problems (PROC-20):
  1. **Quiet ticks each second, but KitSince has only `none` and `minutes` ticks.** KitLogPanel.md "States" says the quiet header ticks each second ("Last line 12 s ago"), and "Depends on" says the quiet state must use `KitSince` (C12: no timer of the part's own). KitSince rebuilds once when the wait turns slow (8 s) and then once a minute. As built, the header reads "Last line 8 s ago" at 8 s and changes next at 1 min ("Last line 1 min ago"), so for the rest of that first minute it still says 8 s. Proposed text: "quiet: 'Last line 8 s ago' at the escalation, then per whole minute via `KitSinceTicks.minutes`", or add a `KitSinceTicks.seconds` to KitSince (another unit's part). This blocks nothing.
  2. **`AppIcons.wrap` does not exist.** The icon is `AppIconography.wrapText`, which is what the part uses.
  3. **Kit copy keys the spec leaves out.** Built with extra `kit`-prefixed keys (additive): `kitLogQuietSeconds` "Last line {seconds} s ago" (the age under a minute, since `KitSince.ageLabel` words only minutes), `kitLogFailed` "Failed" (a failure with no exit code), `kitLogWarningLine` / `kitLogErrorLine` ("Warning: …" / "Error: …" semantics prefixes), `kitWrapLines` "Wrap lines" (the spec calls it shared, but no such key existed). Following the owner decision of 2026-09-27, there are no Arabic entries (app_en.arb only).
  4. **Wrapped continuation lines are not indented.** The spec says "continuation lines are indented". Flutter's `Text` has no hanging indent, and faking one needs per-line `TextPainter` layout, which undoes the virtualisation. Lines wrap anywhere inside a long token, with no indent. Deferred to a coordinator decision.
  5. **Gallery list.** The owner decision of 2026-09-27 (later, so it wins under R15) replaces the spec's 34 PNGs (5 sizes, text 2.0, Arabic) with 412x915 and 1280x800, light and dark: each state at 412x915 and `live` at 1280x800 (`fill`), 18 PNGs. The text 2.0 and RTL rows are covered by behaviour tests 9, 12 and 15 instead.
- New kit parts (KIT-3): none beyond the unit's own `KitLogPanel` (not exported from `kit.dart`: the integrator adds it, R06).
- Map items (EVID-11): n/a: no screen adopted in this unit.
- States (STATE-20): empty, live, quiet, ended (failed), failed-to-read, scrolled-up and dropped each have a golden and a behaviour test (see §5).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitLogPanel`, base `024e97b0` (feat/phone-setup-v2); code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: only tests, goldens and renders. Device proof is part of the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_log_panel_test.dart` | passes | 17 passed | PASS |
| 2 | `test/goldens/kit/kit_log_panel_golden_test.dart` (G4, G5 in both themes) | passes | 18 passed | PASS |
| 3 | `flutter analyze` on the three new Dart files | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n and other shared suites | not run (owner decision 2026-09-27: run only your own new files) | not run | n/a |

## 5. Evidence

- Rule evidence (PROC-31), all in `test/kit/kit_log_panel_test.dart`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | G9 follow | "1 follows the newest line until scrolled up; the pill resumes" |
  | G9, PERF-4 no off-screen polling | "2 polls only while visible, never overlapping, until ended", "2b calls never overlap" |
  | Honest state: failed read | "3 a failed read keeps the lines, pauses, and Try again retries" |
  | G12, SEC-2, SEC-4 | "4 lines are redacted on screen and in Copy all" |
  | COPY-11, KitCopy (no SnackBar) | "5 Copy all copies the lines, announces once, no SnackBar" |
  | COPY-17 honest words | "6 states: empty, live, quiet, failed" |
  | LOOK-4, LOOK-5, STATE-9 | "7 levels: glyph and text1 for errors, text2 for normal" |
  | No silent loss | "8 KitLogBuffer splits chunks, keeps a partial line, drops and counts", "8b the panel shows the dropped row" |
  | Virtualisation, fixed extent per text scale | "9 2,000 lines build only the visible rows at one extent" |
  | Adaptive wrap | "10 wraps on compact, scrolls sideways wide, toggle flips" |
  | A11Y-3 | "11 the header is the only live region; lines never announce" |
  | LOOK-16, KIT-32 | "12 the body is LTR and left-aligned under RTL" |
  | MOT-7, G8 | "13 reduced motion: the pill jump settles after one pump" |
  | K2 §4.4 fold | "14 fold: collapsed under Show output, opens the panel" |
  | G6 overflow | "15 a 500-character line never overflows" (320/412 × 1.0/1.3/2.0 × LTR/RTL × folded/fill) |

- Changed test expectations (TEST-19): none (new files only).
- Goldens (new; each one opened and checked): `kit_log_panel_{empty,live,quiet,ended_failed,read_failed,scrolled_up,dropped,fold_open}_{dark,light}.png` and `kit_log_panel_live_1280x800_{dark,light}.png`. What they show: the mono LTR body, neutral warning and error glyphs in the start gutter, the error and warning lines in `text1` and ordinary `[oc]` lines in `text2` (never accent), the accent dot only while live and recent, "Failed · exit 1" with the reason as a second line, the inline "Couldn't read the output" notice with Try again, the "12 new lines" pill, the "1240 earlier lines not shown" row, and the fold opened under "Show output".
- Gallery scene note: the scenes use short lines so a folded panel shows them whole. The part keeps its vertical padding outside the scroll viewport, so the viewport is a whole number of lines tall and does not leave a line cut to a sliver at its edge when it rests at the newest end. That sliver used to trip the G5 reading-order and contrast checks.
- Accessibility: warning and error lines read "Warning: …" / "Error: …"; each line's semantics node wraps only its words; the header state words are the panel's one polite live region; Wrap is a toggle (`toggled` semantics) with a tooltip; Copy all is labelled "Copy all"; the pill is a button with words. Keyboard: Up/Down/PageUp/PageDown/Home scroll the focused body; End jumps to the newest line and resumes following. At 200 % text the fixed line extent grows with the scale (test 9) and the header wraps.
- Privacy and security: every line goes through `KitRedact.text` once and is cached per line (an `Expando`), before it is drawn or copied. Copy all copies only the redacted lines, through `KitCopy`.
- Migration: n/a: no stored format.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_log_panel_test.dart test/goldens/kit/kit_log_panel_golden_test.dart
$F analyze lib/ui/kit/kit_log_panel.dart test/kit/kit_log_panel_test.dart test/goldens/kit/kit_log_panel_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared suites (kit ratchet, design standard, l10n coverage, kit manifest, golden harness G23) were not run: owner decision 2026-09-27.
- On a desktop build, always-visible scrollbars come from the app's `AppScrollBehavior`, not from the part; no desktop render was taken.
- `SelectionArea` across lines on expanded/large windows is built but not tested.
- Panel visibility inside an enclosing scrollable (the viewport check) is not covered by its own test; tests cover TickerMode, a covering route and app pause.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitLogPanel` |
| Enabled | No: no screen uses it yet (adopting units in wave 2) | |
| Verified | Own tests and gallery only | §4 |
| Committed | Yes (local) | `revamp/kit-KitLogPanel` |
| Deployed / released | No | |
