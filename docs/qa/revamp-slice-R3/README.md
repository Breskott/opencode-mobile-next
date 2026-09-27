# revamp-slice-R3: R3 KitCodeBlock and KitLogPanel, no empty header bands, commands readable (2026-09-27)

## 1. Scope

- Unit: `slice-R3` (wave 3, kit-change). Finish line: a code block or command with nothing to say in a header has no header band (Copy trails its first line), Wrap appears only when a line overflows, long commands stay readable, and the log panel's header controls keep their inset and take one host action. Non-goal: changing callers (Keep it running sheet, setup failure host); they adopt `wrap: true` / `headerAction` in their own units.
- Files changed: `lib/ui/kit/kit_code_block.dart`, `lib/ui/kit/kit_log_panel.dart`, `test/kit/kit_code_block_r3_test.dart` (new), `test/kit/kit_log_panel_r3_test.dart` (new), `test/goldens/kit/kit_code_block_golden_test.dart`, `test/goldens/kit/kit_log_panel_golden_test.dart`, their goldens.
- Pages (map ids): none (kit part change; every page that shows a code block or log panel picks it up).
- Specs followed: leftover-units.json `slice-R3` acceptance; STANDARDS.md KIT (additive only, R11), LOOK (theme roles, KitText roles, integer sizes), §15 goldens, §16 evidence.
- Contract problems (PROC-20): none.
- New kit parts (KIT-3): none. New optional parameter: `KitLogPanel.headerAction` (`KitAction?`). `KitCodeBlock.wrap` is now honoured for `KitCodeKind.command` (was ignored). No public API removed.
- Map items (EVID-11): n/a, no pages in this unit.
- States per part: KitCodeBlock default, capped, wrapped, scrolling, copied, empty, command short, commands labelled, command wrapped → `kit_code_block_golden_test.dart`; KitLogPanel empty, live, quiet, ended failed, read failed, scrolled up, dropped, fold open, failed report (phone and wide) → `kit_log_panel_golden_test.dart`.
- Deferred states (STATE-21): none.

### What moved (owner rule: rethink, not restyle)

- KitCodeBlock: the header band that held only a Copy icon (and sometimes Wrap) is gone; Copy moved to the end of the first line, Wrap under it. A header now exists only when it has words (caption, file name, counts, or a copy label on a multi-line block).
- KitCodeBlock: Wrap is removed whenever no line overflows (it did nothing there). Its on state moved from a filled circle to an accent glyph.
- KitCodeBlock: a caller's copy label ("Copy commands") is now shown as the button's words in the header instead of only a tooltip on a floating icon.
- KitLogPanel: the host's "Copy failure report" moved inside the panel header (via `headerAction`); on a phone it takes its own header line under Copy all rather than being cut short.

## 2. Builds

- Branch `revamp/slice-R3`, base `643a5104`, code head `e55a23f9`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_code_block_r3_test.dart` | passes | 6 passed | PASS |
| 2 | `test/kit/kit_log_panel_r3_test.dart` | passes | 4 passed | PASS |
| 3 | `test/kit/kit_code_block_test.dart`, `test/kit/kit_log_panel_test.dart` (tests write set, unchanged) | pass | 32 + 17 passed | PASS |
| 4 | `test/goldens/kit/kit_code_block_golden_test.dart` | pass after regenerating the two looked-at `wrapped` phone goldens | 40 passed | PASS |
| 5 | `test/goldens/kit/kit_log_panel_golden_test.dart` | pass after regenerating (header inset changed every shot) | 24 passed | PASS |
| 6 | `flutter analyze` on the six changed Dart files | no issues | no issues | PASS |

Ratchet, design-standard and l10n suites were not run (owner decision 2026-09-27: run only the unit's own tests); no copy keys were added.

## 5. Evidence

- Rule evidence (PROC-31):

  | Acceptance | Test (`file` + `--plain-name`) or golden |
  |---|---|
  | Copy trails a one-line command, centred, no header, one line tall | `kit_code_block_r3_test.dart` "a one-line command has no header: Copy sits on its line"; golden `kit_code_block_command_short_*` |
  | Wrap hidden until overflow; on = accent glyph, no filled circle | "Wrap is hidden until a line overflows; on is an accent glyph" |
  | Command `wrap: true` hangs continuation past `$` | "a command with wrap: true wraps, continuation hangs past $"; golden `kit_code_block_command_wrapped_*` |
  | Overflowing command shows the edge fade | "an overflowing command shows the edge fade; a short one not"; golden `kit_code_block_commands_labelled_*` |
  | Copy label read in the header | "a copy label on several lines is read in the header" |
  | Log panel Wrap inset and pressed state | `kit_log_panel_r3_test.dart` "Wrap keeps the standard inset and shows a pressed state" |
  | Log panel extra header action | "wide: the extra header action sits beside Copy all", "phone: the action takes its own header line, words whole"; golden `kit_log_panel_failed_report_*` |

- Changed test expectations (TEST-19): none in shared tests.
- Goldens changed (each opened and looked at):
  - `kit_code_block_command_*`, `copied_*`, `output_capped_*`, `wrapped_*`: header band removed, Copy on the first line.
  - `kit_code_block_code_header_*`: Wrap on state is an accent glyph, no filled circle.
  - New: `kit_code_block_command_short_*`, `commands_labelled_*`, `command_wrapped_*`, `kit_log_panel_failed_report_*` (phone and 1280x800).
  - `kit_log_panel_*`: header controls inset by space1 top/bottom and space2 at the end; Wrap's pressed fill no longer touches the card edge.
  - No approved VL canvas render exists for these states (EVID-12: none).
- Before and after (EVID-10): `before-kit_code_block-command.png` / `after-kit_code_block-command.png`; `before-kit_log_panel-ended_failed.png` / `after-kit_log_panel-ended_failed.png`; new-state renders `after-kit_code_block-command_short.png`, `after-kit_code_block-commands_labelled.png`, `after-kit_log_panel-failed_report.png`.
- Accessibility: Copy keeps its 48 dp target and its label (the copy label, or "Copy command/code/output"); Wrap is a toggled button labelled "Wrap lines" with a 48 dp target; the log panel action is a labelled KitButton with a 48 dp minimum. The inline Copy layout scales its line inset with the text scaler; the log panel moves its action to its own line whenever the measured row cannot hold it (so larger text also falls back). 200 % text was not rendered for the new scenes.
- Privacy and security: n/a, no credentials, stored data, links or notifications changed (SEC-4 command placeholder assert unchanged).
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_code_block_r3_test.dart test/kit/kit_log_panel_r3_test.dart
$F test -j 1 test/kit/kit_code_block_test.dart test/kit/kit_log_panel_test.dart
$F test -j 1 test/goldens/kit/kit_code_block_golden_test.dart
$F test -j 1 test/goldens/kit/kit_log_panel_golden_test.dart
$F analyze lib/ui/kit/kit_code_block.dart lib/ui/kit/kit_log_panel.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The Keep it running sheet (`lib/ui/widgets/team_phone_section.dart`) still uses the default command form (sideways scroll with the edge fade); it does not pass `wrap: true`. That caller is outside this unit's write set.
- No host yet passes `KitLogPanel.headerAction`; the setup failure screen's "Copy failure report" still sits where its host puts it until that host adopts the parameter.
- Screens whose goldens show a code block or log panel (integrator-owned goldens) were not regenerated and will differ.
- Full suite, ratchet, design-standard and l10n gates not run in this unit.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R3` |
| Enabled | Yes (kit default; `headerAction` and command `wrap: true` are opt-in for hosts) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `e55a23f9` |
| Deployed | No | |
| Released | No | |
