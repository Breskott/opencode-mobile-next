# KitLogPanel — API freeze (wave 0)

> **Copy (SEC-13, coordinator 2026-09-27):** copies of technical values, logs and details use `KitCopy.copy(context, text)` (redacted). A part that also copies the person's own content passes `redact: false` for that content.

Unit: `kit-KitLogPanel` (wave 1, tier 1c, kind `kit-part`). Write set (work-units.json): `lib/ui/kit/kit_log_panel.dart` (new), `test/kit/kit_log_panel_test.dart`, `test/goldens/kit/kit_log_panel_golden_test.dart`. Acceptance: "mono LTR, folded (does not compose KitCodeBlock)". Spec: kit-v2.md §1.11, §4.4, §8.2 (`KitLogPanel` row), G9 ("KitLogPanel: follows unless scrolled up; no polling off screen"), G12; C25. Rules: KIT-31, KIT-32, LOOK-4, LOOK-5, LOOK-16, COPY-11, SEC-2, SEC-4, PERF-4, A11Y-3, MOT-5, MOT-7.

## Purpose

Live or finished output from one process (server logs, setup output, dev services, shell output, the phone team's steps). It follows new lines until the person scrolls up, polls only while it is on screen, redacts every line, and says in words whether the source is live, quiet or ended.

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitLogPanel`): 18 elements on 15 pages.**
  - builtin-server-log-sheet (inner-header, log-body: one of two sheets for one log);
  - builtin-server-setup (stop-and-log);
  - development-services-logs-sheet (log, refresh-status);
  - embedded-local-agent-onboarding-block (log);
  - embedded-setup-terminal (log-lines: wraps mid-token, accent on ordinary `[oc]` lines; panel-header: uppercase "LIVE OUTPUT" with a waveform icon);
  - local-agent-page (live-output);
  - phone-setup-progress (details);
  - shell-output (shell-output-log);
  - team-phone-onboarding-failed (failed-log), team-phone-onboarding-steps (steps-log);
  - termux-setup (last-output), termux-setup-failed (log), termux-setup-installed (last-output), termux-setup-installing (live-output);
  - termux-storage (scan-log).
- **Merged proposal names:** `KitLogFold`, `KitLogPanel`, `KitLogView`.
- **Code reach, adopted by other units:**
  - `SetupTerminal` (`lib/ui/widgets/setup_terminal.dart`, 201 lines; G16 `Container` 1, `Icon` 2, `IconButton` 1, `Scrollbar` 1, `SelectableText` 1, `SingleChildScrollView` 1, `Text` 3; 10 calls: `termux_setup_screen.dart` 3, `builtin_server_screen.dart` 2, `local_agent_onboarding.dart` 2, `team_phone_onboarding.dart` 2, `termux_storage_screen.dart` 1) becomes a wrapper over `KitLogPanel` in shared-phone-1, keeping its `setup-live-output` key on the panel (`panelKey`);
  - the dev-services log sheet and its refresh status (`development_services_screen.dart`), the shell output log (`running_work_sheet.dart`), the builtin server's `TerminalView` inside Details (`builtin_server_screen.dart`), `run_result_view.dart`'s output (shared-review-1, C36).
- **Widgets retired directly:** none outside the kit.

## File

- `lib/ui/kit/kit_log_panel.dart`: `KitLogLine`, `KitLogEnd`, `KitLogSize`, `KitLogBuffer`, `KitLogPanel`.
- Tests: `test/kit/kit_log_panel_test.dart`. Gallery: `test/goldens/kit/kit_log_panel_golden_test.dart`.

## Public API

```dart
/// What kind of line: drives the look (see Tokens), never colour alone.
enum KitLogLevel { normal, warning, error }

@immutable
class KitLogLine {
  const KitLogLine(this.text, {this.level = KitLogLevel.normal, this.at});
  final String text;          // one line, no newline; redacted by the panel
  final KitLogLevel level;
  final DateTime? at;         // when it arrived (for "Last line 12 s ago")
}

/// How the source ended.
@immutable
class KitLogEnd {
  const KitLogEnd({this.exitCode, this.failed = false, this.reason});
  final int? exitCode;        // "Ended · exit 1"
  final bool failed;          // the header word is "Failed" instead of "Ended"
  final String? reason;       // one line in words, from the caller (agentErrorWords)
}

enum KitLogSize {
  /// About 12 lines tall: the panel inside a KitDetailsFold or a card.
  folded,

  /// Fills its host: a page whose job is the log, or a full-height sheet.
  fill,
}

/// A bounded ring buffer of lines, for sources that hand over text chunks
/// (a process's stdout, SetupTerminal's `output`). Splits on newlines,
/// keeps a partial last line open until its newline arrives, drops the
/// oldest lines past [capacity] and counts them in [dropped].
class KitLogBuffer extends ValueNotifier<List<KitLogLine>> {
  KitLogBuffer({this.capacity = KitLogPanel.defaultMaxLines});
  final int capacity;
  int get dropped;
  void add(KitLogLine line);
  void appendText(String chunk, {KitLogLevel level = KitLogLevel.normal});
  void replaceText(String text);   // a source that re-sends its whole output
  void clear();
}

/// The one log view (K2 §1.11, KIT-31).
///
/// States: empty, live, quiet, ended, failed-to-read, scrolled-up (new lines).
class KitLogPanel extends StatefulWidget {
  const KitLogPanel({
    super.key,
    required this.lines,          // ValueListenable<List<KitLogLine>> (a KitLogBuffer or the caller's)
    this.title,                   // header words; null = l10n.kitLogTitle ("Output")
    this.live = false,            // the source is still writing
    this.ended,                   // the source finished
    this.onRefresh,               // polled every [pollEvery] only while visible
    this.pollEvery = KitMotion.logPoll,
    this.follow = true,           // sticks to the newest line until the person scrolls up
    this.maxLines = defaultMaxLines,
    this.emptyText,               // null = l10n.kitLogEmpty ("No output yet")
    this.size = KitLogSize.folded,
    this.wrap,                    // null = wrap on compact, scroll sideways from medium
    this.onWrapChanged,
    this.panelKey,
    this.copyAllKey,
    this.wrapKey,
  });

  final ValueListenable<List<KitLogLine>> lines;
  final String? title, emptyText;
  final bool live, follow;
  final KitLogEnd? ended;
  final Future<void> Function()? onRefresh;
  final Duration pollEvery;
  final int maxLines;
  final KitLogSize size;
  final bool? wrap;
  final ValueChanged<bool>? onWrapChanged;
  final Key? panelKey, copyAllKey, wrapKey;

  /// Lines kept on screen; older ones are dropped and counted (honest state).
  static const int defaultMaxLines = 2000;

  /// The folded panel inside the one details fold (K2 §4.4: folded under
  /// Details unless the page exists to show the log). The fold's label is
  /// l10n.kitLogShowOutput ("Show output"). A page that already has a
  /// KitDetailsFold passes a KitLogPanel as that fold's `child` instead
  /// (one fold per page, KIT-33).
  static Widget fold({
    Key? key,
    required ValueListenable<List<KitLogLine>> lines,
    bool live = false,
    KitLogEnd? ended,
    Future<void> Function()? onRefresh,
    String? label,
    Key? foldKey,
    Key? panelKey,
  });
}
```

- **Header.** Start: `title` (`label` role, `text2`, sentence case, never uppercase, LOOK-15) and the state words ("Live", "Last line 12 s ago", "Ended · exit 1", "Failed · exit 1"). A small `accent` dot precedes "Live" only while live and recent (LOOK-6: working mark). End: Wrap (`KitIconButton(selected:)`, `AppIcons.wrap`) and Copy all (`KitIconButton.copy`, tooltip "Copy all"). The header is the panel's only live region.
- **Body.** A virtualised `ListView.builder`. With wrap off, every line has the same extent (`itemExtent` = the mono line height at the current text scale, or the 20 dp glyph scaled by `iconSize`, whichever is larger), and the body scrolls sideways as one box. With wrap on, lines wrap at word boundaries (anywhere inside a long token), and continuation lines are indented.
- **Line look (LOOK-4, LOOK-5 interim B2).** `normal` lines in `text2`. `warning` lines in `text1` with the neutral warning glyph in the start gutter. `error` lines in `text1` with the neutral error glyph. The accent, attention and danger roles are never used for lines, so ordinary `[oc]` lines are never accent-coloured.
- **Follow.** While the person is at the newest end, a new line keeps the view there (a jump, not an animation). Once they scroll up more than one line, following stops and a `KitJumpPill` shows "{count} new lines" (`clearBottomInset: false`, inside the panel). Tapping it scrolls to the end and resumes following. `follow: false` never auto-scrolls.
- **Polling (PERF-4).** `onRefresh` runs every `pollEvery`, only while the panel is visible: its `TickerMode` is enabled, its route is current, the app is resumed, and the panel is at least partly inside its enclosing scrollable's viewport (checked from the render tree on each poll; no new package). It never overlaps calls: the next waits for the last. It stops when `ended` is set.
- **Failed to read.** If `onRefresh` throws, the body keeps the last lines and shows an inline `KitNotice.error` above them ("Couldn't read the output") with Try again, which calls `onRefresh` once. Polling pauses until that succeeds.
- **Compatibility.** A new part.
- **Internal keys (TEST-5):** `kit-log-panel` (default `panelKey`), `kit-log-copy-all`, `kit-log-wrap`, `kit-log-jump`, `kit-log-line-<index>`, `kit-log-dropped`, `kit-log-read-failed`.
- **Kit copy (ARB, `kit` prefix, en + ar):** `kitLogTitle` "Output", `kitLogShowOutput` "Show output", `kitLogLive` "Live", `kitLogQuiet` "Last line {age} ago", `kitLogEnded` "Ended", `kitLogEndedExit` "Ended · exit {code}", `kitLogFailedExit` "Failed · exit {code}", `kitLogEmpty` "No output yet", `kitLogNewLines` "{count, plural, =1{1 new line} other{{count} new lines}}", `kitLogDropped` "{count, plural, other{{count} earlier lines not shown}}", `kitLogReadFailed` "Couldn't read the output", plus the shared `kitCopyAll`, `kitWrapLines`, `kitTryAgain` (exists).

## States

| State | Header words | Body |
|---|---|---|
| empty | the title | `emptyText` ("No output yet") in `text3`, one line |
| live | "Live" with the dot | lines, following |
| quiet (live, no line for `KitMotion.escalateAfter` = 8 s) | "Last line 12 s ago", ticking each second while visible | lines |
| ended | "Ended" or "Ended · exit 0"; `ended.reason` as a second header line | lines; polling stopped |
| failed (`ended.failed`) | "Failed · exit 1" with the neutral error glyph | lines; the last error line is not scrolled away |
| failed to read | the title | inline `KitNotice.error` with Try again, then the last lines |
| scrolled up | unchanged | the jump pill "12 new lines" |
| dropped | unchanged | a first row "1,240 earlier lines not shown" in `text3` |

KIT-12 doc comment: "States: empty, live, quiet, ended, failed, failed-to-read, scrolled-up, dropped". Loading is the empty state (a process that has not written yet); disabled does not apply.

## Tokens

- **ThemeRoles:** `text2` (normal lines, title), `text1` (warning and error lines, state words), `text3` (empty text, dropped row, gutter glyphs meet ≥ 3:1), `accent` (the live dot only), `hairline` (header rule).
- **KitText:** `mono` for lines; `label` for the title; `caption` for the state words.
- **KitTokens (VL branch):** `detailsSurface` and `detailsRadius` (the panel surface when folded; `fill` has no radius), `space2`/`space3`, `smallIconSize` (20, gutter glyphs, grown by `iconSize` up to `maxIconScale`), `minTarget`.
- **Pre-wave seams:** `KitTokens.hairlineWidth`, `KitCopy`, `KitRedact`, `KitMotion.escalateAfter`.
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitMotion.logPoll` = 2 s: the default poll interval, a named wait in `kit_motion.dart` (MOT-1);
  - `KitTokens.logFoldedLines` = 12: the folded panel's height in lines (K2 "about 12 lines").

## Adaptive

| Window | Behaviour |
|---|---|
| compact | wraps by default; `folded` is 12 lines tall; `fill` fills the host |
| medium | scrolls sideways by default (Wrap toggles) |
| expanded / large | the same, plus mouse selection across lines (`SelectionArea` inside the kit) and always-visible scrollbars where it scrolls (desktop rule) |

- **Keyboard:** Wrap, Copy all and the jump pill are in Tab order. With the body focused: Up/Down/PageUp/PageDown scroll; End jumps to the newest line and resumes following; Home goes to the oldest.
- **Pointer:** hover tooltips on Wrap and Copy all; the wheel scrolling up stops following exactly as a drag does.
- **Short windows:** `folded` never takes more than half the window height.

## Accessibility

- The panel is not a live region (A11Y-3): lines are never announced one by one. The header's state words are one polite live region, announced once per change ("Ended, exit 1").
- The body is one scrollable semantic node with scroll actions; each line reads its text, and warning and error lines are prefixed "Warning:" / "Error:" in semantics (STATE-9: never colour alone).
- Wrap is a labelled toggle; Copy all is labelled "Copy all"; the pill is a button with its words.
- 200 % text: the line extent is recomputed from the text scale (still fixed per scale), the header wraps to two lines, and wrap on is still the compact default.

## RTL

- The body is an LTR block aligned left in both directions (COPY-30, LAY-8), including the gutter glyphs.
- The header follows the locale: title at the start, Wrap and Copy all at the end. The exit code is isolated with `KitBidi.ltr`.

## Motion and haptics

- Following jumps (no animation). The jump pill's own fade and rise (KitJumpPill). Tapping the pill scrolls on `KitMotion.standard` with `enter`, or jumps under reduced motion.
- No layout animation for new lines (MOT-5); no ticker runs while the panel is off screen.
- Reduced motion (MOT-7): settles after one `pump()`; the quiet-age tick is a timer, not an animation, and stops off screen.
- Haptics: none.

## Data safety and honest state

- **Redaction (SEC-2, SEC-4, G12).** Every line passes through `KitRedact.text` once, when it first reaches the panel (cached per line), before it is drawn or copied. Copy all copies the redacted lines on screen, plus the dropped-count line.
- **One panel per source (K2 §4.4).** Two panels for one log is a reviewer defect; the part cannot enforce it.
- **No silent loss.** Dropped lines are counted on screen. A failed read keeps the last lines and says so.
- **Never off-screen work (PERF-4).** A panel in a hidden tab, a covered route or a paused app does not poll.
- **Honest words.** "Live" only while `live` and not ended; "Last line 12 s ago" once quiet; never "Live" with an `ended` source (COPY-17).

## Depends on

- **kit-KitDetailsFold** (tier 1b): `KitLogPanel.fold`.
- **kit-KitJumpPill** (tier 1b): the "new lines" pill and `KitJumpPillLayer`.
- **kit-KitIconButton-v2** (tier 1a): Wrap and Copy all (C25).
- **Edges added** (README.md), both tier 1a, so this unit stays in tier 1c: kit-KitNotice-v2 (`KitNotice.error` for failed-to-read) and kit-KitSince (`KitSince(since: lastLineAt, builder: …)` drives the quiet state and its age, per KitSince.md; C12 exists so parts do not each build a timer). Without these edges the builder would use the v1 `KitNotice(tone: failure)` and its own timer, which C12 forbids.
- **Pre-wave seams:** `KitCopy`, `KitRedact` (KitDetailsFold.md), `KitBidi`, `KitTokens.hairlineWidth`, `KitMotion.escalateAfter`, the new `KitMotion.logPoll`.
- **Not KitCodeBlock** (acceptance: "does not compose KitCodeBlock").
- **Depended on by:** kit-KitChecklist (`log`), and in wave 2 shared-phone-1, shared-review-1, screen-chat-1, screen-phone-1, screen-work-3.

## Tests required

In `test/kit/kit_log_panel_test.dart`:

1. Follow (G9): with 200 lines and the view at the end, adding a line keeps the newest line visible. After a drag up, adding 12 lines keeps the scroll offset and shows the pill "12 new lines"; tapping it shows the newest line, hides the pill and resumes following.
2. No polling off screen (G9, PERF-4): with `onRefresh` counting calls and fake async, the count rises every `pollEvery` while visible; it stops while `TickerMode(enabled: false)`, while another route covers the panel, and after `AppLifecycleState.paused`; it resumes when visible again. Calls never overlap. It stops once `ended` is set.
3. Failed to read: an `onRefresh` that throws shows "Couldn't read the output" with Try again, keeps the lines, and pauses polling; Try again calls `onRefresh` once.
4. Redaction (G12): a line with `sk-ant-FAKE…` and one with `Authorization: Bearer FAKE…` render without the tokens, and Copy all's clipboard text has neither.
5. Copy all copies the displayed lines, joined with newlines, through `KitCopy`, announces "Copied" once and shows no `SnackBar`.
6. States: empty shows "No output yet"; `live` shows "Live"; after 8 s without a line (fake async) the header shows "Last line 8 s ago"; `KitLogEnd(exitCode: 1, failed: true)` shows "Failed · exit 1"; the live dot is absent once ended.
7. Levels: `error` lines paint `text1` with the error glyph and read "Error: …" in semantics; `normal` lines paint `text2`; no line paints `accent`, `attention` or `danger` (LOOK-4/5).
8. `KitLogBuffer`: `appendText('a\nb')` then `appendText('c\n')` yields lines `a`, `bc`; past `capacity` the oldest drop and `dropped` counts them; the panel shows the dropped row.
9. Virtualisation: 2,000 lines build only the visible rows; with wrap off, rows have one fixed extent at text 1.0 and a larger fixed extent at 2.0.
10. Wrap: on 360 dp lines wrap; on 1280 dp they scroll sideways; the toggle flips it and has `toggled` semantics.
11. Live region: the header announces once per state change, and adding lines announces nothing (semantics event count).
12. RTL: the body is LTR and left-aligned under `TextDirection.rtl`.
13. Reduced motion (G8): under `disableAnimations` and Effects Off, tapping the pill settles after one `pump()`.
14. `KitLogPanel.fold`: collapsed by default under "Show output"; opening shows the panel.
15. Overflow (G6): a 500-character line, folded and fill, at 320 and 412 dp × text 1.0/1.3/2.0 × LTR/RTL: no overflow.

## Galleries required

`test/goldens/kit/kit_log_panel_golden_test.dart`, DPR 3.0, Android, deterministic lines and clock (TEST-11), names per TEST-20.

- **Each state at 412×915, dark and light:** `empty`, `live` (with a warning and an error line), `quiet`, `ended_failed`, `read_failed`, `scrolled_up` (pill visible), `dropped`, `fold_open` (inside `KitLogPanel.fold`). 8 × 2 = 16 PNGs.
- **`live` at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000, dark and light:** 10 PNGs (size `fill` from 800 up).
- **`live` at text 2.0 and in Arabic RTL, at 412×915 and 1280×800, dark and light:** 8 PNGs.
- **Total:** 34 PNGs.

## Non-goals

- No terminal emulation, ANSI colour or input (that is `KitTerminalView`).
- No search inside the log in v2.
- No syntax colour and no KitCodeBlock.
- No persistence of the log across app restarts (the source's job).
- No screen adoption; `SetupTerminal` and the log sheets move in their own units.

## Open questions

None. The two edges (Notice-v2, Since) are in README.md's build_units list and the two tokens (`KitMotion.logPoll`, `KitTokens.logFoldedLines`) in `_new-tokens.md`; none changes a tier.
