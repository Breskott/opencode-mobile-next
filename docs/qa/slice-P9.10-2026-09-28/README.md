# slice-P9.10 — G16 goes absolute (2026-09-28)

Finish line: the G16 baseline is empty and the gate fails on any framework widget outside the §9.1 allowlist; `MaterialPageRoute` is off the allowlist. Non-goal: none beyond the gate.

Branch `revamp/slice-P9.10`, merged with `feat/phone-setup-v2` at `73b15550` (tap feedback) before the final checks.

## What the gate does now

- **G1, G15 and G16 are absolute** (`test/kit_ratchet_test.dart`, `_kitOnlyProblems`). They have no baseline and no per-file allowance; `test/kit_ratchet_baseline.json` no longer holds them, and a test fails if a `G1`/`G15`/`G16` section reappears. Write mode never writes them.
- **The failure message says what to do.** Each hit names the kit part to use instead (`_kitOnlyFix`: `Text` → `KitText`, `showModalBottomSheet(` → `showKitSheet`, or `showKitFramedSheet` for a self-framed body, `MaterialPageRoute` → `KitPageRoute`/`pushKitPage`, and about 70 more). The last line explains the rule: arrange kit parts with the §9.1 widgets only. If no part fits, add one to `lib/ui/kit/` (export, doc row, spec, test, gallery; `kit_manifest_test` lists what is missing). There is no baseline to regenerate and no allowlist to extend.
- **KIT-7 self-test reworked.** It now uses fixtures only: `MaterialPageRoute(` and `PageRouteBuilder(` in a `lib/ui` fixture and in a `lib/voice` fixture fail with the KitPageRoute advice, with no baseline to lean on, and a `Text` outside `lib/ui` is not G16's. It no longer needs a baselined row. A new fixture test checks that every G1 entry point and every counted route has a named replacement.
- **KIT-6.** The `_scrollbarHome` exception is gone (`ratchet-tighten: G16 Scrollbar`). A fixture proves `Scrollbar` counts in `desktop_interaction.dart` too.
- **Allowlist.** `NotificationListener` joined §9.1's scrolling row. It only hears notifications, draws nothing and takes no input. Routes: none (kit-v2 §9.1 and §9.3 updated).
- **G2 retired names (leftover sliceAddition).** `_retiredApis` now lists `TerminalView`, `stripAnsi`, `TerminalKeyBar`, `KitNotice.card`, `NudgeCard`, `AppScrollBehavior`, `DesktopScrollbarArea`, `OwnScrollbar`, `DesktopSelectionArea`, `ContextMenuRegion`, `ContextMenuAction` and `showContextMenu`, each as an **absolute** row. The KIT-38 wrappers (`ProductErrorState(`, `ProductEmptyState(`, `ProductInlineEmpty(`, `showConfirmSheet(`, `KitSecretField(`) are absolute too, since all of them reached zero. `_uses` now treats a no-argument constructor (`const Name();`) as a declaration.
- **Rows whose "ratchet until…" note had come true are absolute:** `Curves. in kit`, `HapticFeedback. in kit`, the G15x widths, `KitGlass(/GlassSurface(`, `disableAnimationsOf`, `Transform.scale in kit`, `metal|chrome`. `_kitLookDeferrals` is empty, because slice-R4 has merged.

## Every former baseline entry and how it was resolved

Baseline at `ca043f36` (58 file entries, `allow` excluded). The `allow` section (KIT-5 frozen exemption keys) is structural and unchanged.

| Gate | File | Entry | Resolution |
|---|---|---|---|
| G1 | screens/chat_screen.dart | showModalBottomSheet( x2 | Timeline and command sheets open through the new kit opener `showKitFramedSheet` (same route, handle, 720 cap). **Chat library** |
| G1 | screens/project_folder_actions.dart | showModalBottomSheet( x2 | Folder browser through `showKitFramedSheet` (same look) |
| G1 | widgets/completion_digest.dart | SnackBar( x2, showSnackBar( x2 | Copy is `KitCopy.copy` with the "Digest copied" announcement; a refused clipboard is a `showProductError` alert titled "Could not copy digest" |
| G1 | widgets/local_agent_onboarding.dart | SnackBar(, showSnackBar(, showModalBottomSheet( | Dead `_copyLog` removed (SetupTerminal's own Copy all is the one copy); project sheet is `showKitSheet` with a pinned Continue |
| G1 | widgets/session_handoff.dart | AlertDialog(, SnackBar(, showDialog(, showSnackBar( | Stale: already 0 (P3.11a merged the dialog into the kit sheet) |
| G1 | widgets/team_phone_onboarding.dart | SnackBar(, showModalBottomSheet(, showSnackBar( | Stale: already 0 (P3.4) |
| G16 | ui/app_theme.dart | AppBarTheme, InputDecorationTheme | The theme passes the data classes `AppBarThemeData`/`InputDecorationThemeData` (Flutter 3.47's non-widget forms; same values) |
| G16 | screens/attention_overview_screen.dart | 17 widgets, MaterialPageRoute | Stale: file deleted |
| G16 | screens/chat_screen.dart | NotificationListener | Allowlisted (§9.1 scrolling plumbing, draws nothing) |
| G16 | screens/manage_project_screen.dart | 39 widgets, MaterialPageRoute x5 | Stale: file deleted |
| G16 | widgets/completion_digest.dart | Icon x2, SnackBar x2, Text x12, TextButton x5 | `KitText` roles, `KitButton.tertiary` with icons, KitTokens spacing |
| G16 | widgets/local_agent_onboarding.dart | 68 widgets | Kit-only restyle of "Claude Code on this phone": `KitSurface.panel`, `KitText`, `KitRowMenu`/`KitMenuItem`, `KitChecklist` steps, `KitNotice`, `KitActionBlock`, `KitIcon.status`, `KitLtr`; connecting is the Connect button's `working` state; project sheet is `showKitSheet` + `KitChoiceList.single` + `KitField(kind: path)` |
| G16 | widgets/session_handoff.dart | 12 widgets | Stale: already 0 |
| G16 | widgets/team_phone_onboarding.dart | 53 widgets | Stale: already 0 |
| G17 | diagnostics/app_diagnostics.dart | Color(0x x2 | The failed-build box's two fixed colours are named in `ThemeRoles` (`bootErrorGround`, `bootErrorText`) |
| G17 | screens/team/team_home_screen.dart | attention roles x1 | **Open**, see below |
| G17 | screens/team/team_states.dart | attention roles x5 | **Open**, see below |
| G17 | widgets/app_exit_notice.dart | attention roles x1 | Notice line is neutral, like its `KitStatus` twin (LOOK-4); the line is only mounted by tests |
| G17 | widgets/completion_digest.dart | .textTheme x2 | KitText roles |
| G17 | widgets/local_agent_onboarding.dart | .colorScheme x7, .textTheme x18, attention roles x3 | KitText roles; notices neutral with the warning glyph (LOOK-4: warnings never amber) |
| G17 | widgets/saved_server_connection_card.dart | attention roles x2 | "Not answering" and "stopped" state views neutral (degraded states, LOOK-4) |
| G17 | widgets/team_board_card.dart | attention roles x2 | **Open**, see below |
| G17 | widgets/team_phone_onboarding.dart | attention roles x1 | "Android stopped the team" notice neutral, like Claude Code's |
| G17 | widgets/team_vocabulary.dart | attention roles x11 | **Open**, see below |
| G17 | widgets/thermal_notice.dart | attention roles x1 | Neutral, like its `KitStatus` twin; the line is only mounted by tests |
| G2 | feedback/bug_report.dart | launchUrl( | Stale: already 0 |
| G2 | kit/scenes/*.dart (12 files) | Curves. in kit x46 | New `KitMotion.land` (= easeOutBack) and `KitMotion.steady` (= linear); `easeOutCubic` → `KitMotion.enter`. Same curves, no visual change; row now absolute |
| G2 | screens/attention_overview_screen.dart | ProductEmptyState( | Stale: file deleted |
| G2 | screens/library/integrations_screen.dart | launchUrl( | The guarded auth launcher calls `launchExternalUri` in external_link.dart (still inside `openExternalLink`, SEC-1) |
| G2 | widgets/completion_digest.dart | Clipboard.setData( | `KitCopy.copy` |
| G2 | widgets/local_agent_onboarding.dart | Clipboard.setData( | Dead `_copyLog` removed |
| G2 | widgets/session_handoff.dart, team_phone_onboarding.dart | Clipboard.setData( | Stale: already 0 |
| G21 | diagnostics/app_diagnostics.dart | EdgeInsets numeric, TextStyle( | `KitTokens.panelPadding`, `KitText.styleFor(body)` |
| G21 | diagnostics/perf_trace.dart | .toUpperCase() | Dropped: Dio already upper-cases the method when it composes the request |
| G21 | main.dart | text scale clamp | `KitText.appScaler(…, max: AppTheme.maxTextScale)`; same behaviour. **main.dart (single owner)** |
| G21 | kit/kit_row.dart | SizedBox numeric x2 | New `KitTokens.rowLineGap` (2) |
| G21 | kit/kit_row_parts.dart | EdgeInsets numeric | `EdgeInsetsDirectional.only` (the literal was a 0) |
| G21 | screens/managed_workspaces_screen.dart, project_health_screen.dart | EdgeInsets numeric | Same: a 0 literal written as `only`/`symmetric` |
| G21 | screens/settings/server_plugins_section.dart | .toUpperCase() x2, TextStyle( x2 | Acronyms map to their written form; first letter via `KitText.sentenceCase`; danger spans via `KitText.styleOf(secondary, danger)` |
| G21 | screens/team/work_sheet.dart | .toUpperCase() | Stale: already 0 |
| G21 | widgets/app_exit_notice.dart, thermal_notice.dart | EdgeInsets numeric | KitTokens gutter/space2/space1 (16/8/4, unchanged) |
| G21 | widgets/completion_digest.dart | EdgeInsets numeric, SizedBox numeric x2 | KitTokens |
| G21 | widgets/local_agent_onboarding.dart | 44 look literals | Kit parts and KitTokens |
| G48 | voice/voice_ui.dart | sheet multiline without draft | Cleared by slice-P10.3 (merged from feat/phone-setup-v2) |

### Open: 19 G17 "attention roles" hits in the team page

`team_vocabulary.dart` (11), `team_states.dart` (5), `team_board_card.dart` (2) and `team_home_screen.dart` (1) pass `AppStatusTone.attention` for team states. They fall into two groups:

- **Degraded states that LOOK-4 says must never be amber (about 10):** not answering, stale, refresh failed, heat hold, plain-HTTP refused, unreachable, blocked, context 75 %. These become neutral.
- **Real "needs you" states (about 9):** needs input, an agent waiting, the choice/confirmation/free-text gates, and the board's needs-you flag. Per LOOK-24 these become the `KitNeedsYou` / `KitTaskMark` needs-you mark rather than a raw attention tone.

This is a visual redesign of the team page, and the team closure slice has started on those files. The four rows stay in the baseline, so the G17 section is not `{}` yet. G1, G15 and G16 (the slice's acceptance) and every other gate are empty.

## New kit API (additive, KIT-43)

- `showKitFramedSheet<T>(context, {builder, maxWidth, useSafeArea, sheetKey})` in kit_sheet.dart. It opens a body that draws its own `KitSheet(handle: false)` frame on the theme's bottom sheet route, with no slide under reduced motion. It is in the kit.dart table and the KitSheet.md spec, tested in `test/kit/kit_sheet_test.dart` (route handle, width cap, result, dismissal, reduced-motion stills), and has an overflow scene.
- `KitMotion.land`, `KitMotion.steady`; `KitTokens.rowLineGap`; `KitText.appScaler`, `KitText.sentenceCase` (tests in `test/kit/kit_text_test.dart`); `ThemeRoles.bootErrorGround`/`bootErrorText`; `launchExternalUri` (external_link.dart).

## Before / after (intended visual changes)

Captured from a temporary gallery run in this worktree and in a base worktree at `73b15550`, dark, phone 412×915 and 1280×800. Left is before, right is after.

- Claude Code block: `local_agent_{offer,steps,signin,ready,failed}[_1280x800]__before_left_after_right.png`; the project sheet: `local_agent_project_sheet[_1280x800]__…png`.
- Completion digest: `completion_digest[_1280x800]__…png`.

Other intended changes, not captured:

- The saved-server "not answering" and "stopped" icons, and the team phone "Android stopped the team" notice, are now neutral instead of amber.
- The failed-build box uses the body role (16 pt instead of 14).

Everything else is identical by construction: the same curves, the same token values, and the same sheet route.

## Tests

- New or changed tests:
  - `test/kit_ratchet_test.dart`: 37 tests; absolute G1/G15/G16, fixture KIT-7, failure-message test, Scrollbar fixture, retired-forwarder fixture.
  - `test/kit/kit_sheet_test.dart`: `showKitFramedSheet` tests and stills.
  - `test/kit/kit_text_test.dart`: `appScaler` and `sentenceCase`.
  - `test/kit/kit_overflow_scenes.dart`: a `showKitFramedSheet` scene.
  - `test/completion_digest_card_test.dart`: the copy is announced, never a SnackBar; failure is a kit alert without platform text.
- Gates: `kit_ratchet`, `redaction`, `ui_glossary`, `no_raw_error_text`, `kit/kit_manifest`, `kit/kit_draft_manifest`, `architecture_boundaries`, `kit_motion`, `text_scale_overflow`: all pass. `flutter analyze`: no issues.
- Affected files (119, listed from the changed symbols): run on the slice and on the base worktree. With the two new-opener coverage failures fixed, the slice's failures equal the base's (133 pre-existing, mostly golden drift and layout tests, all failing on the base too).
- `test/local_agent_onboarding_test.dart` (all keys kept) passes unchanged.

## Still needs a device

Claude Code on this phone (Termux + Paseo) end to end with the new block: the sign-in round trip, the project sheet, and Connect.
