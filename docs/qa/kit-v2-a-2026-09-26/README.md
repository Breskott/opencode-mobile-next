# Kit v2 step A: one sheet, one confirmation, adaptive from the start (2026-09-26)

## Scope

Programme P9.1 plus the KitSheet half of P9.2 (`docs/ux-system/programmes.json`),
built to `docs/ux-system/kit-v2.md` §1.1, §1.2, §2.13, §4.1, §4.2, §4.7, §7 and §8.
The owner's note: "Ideally I would build this first and it should support tablet,
PC, phones etc." So every part here adapts to the window from its first commit.

| Part | What it does | Files |
|---|---|---|
| `KitLayout`, `KitWindow` (§8.1) | Material 3 window classes measured on the window (compact < 600, medium < 840, expanded < 1200, large). A window shorter than 480 dp keeps the bottom sheet (a phone in landscape). Also `finePointer`, the reading/list/pane widths, and the modal widths and height shares. | `lib/ui/kit/kit_layout.dart` |
| `showKitSheet`, `KitSheet`, `KitSheetHeight`, `KitDraft` (§1.1) | The frame: a handle, a header (title, subtitle, close), the one loading bar, a scrolling body and a pinned `KitActionBlock`. `KitDraft` keeps typed text under `oc.draft.<target>.<profileId>`, and a swipe, back, Esc or close keeps it without asking. `dirty` makes the frame own its swipe, back and Esc, and asks the discard question in place. `RequestRoutes` closes the sheet when its request is answered elsewhere. `dismissible: false` is for an irreversible step. | `lib/ui/kit/kit_sheet.dart` |
| `showKitConfirm`, `KitConfirmSheet`, `KitConfirmKind` (§1.2, §4.1, §4.2) | Four kinds: neutral, stop, destructive and discard. Each sets its tone, icon and cancel word, and the confirm is error-filled only for stop, destructive and discard. It also supports consequences, a typed-name guard with a visible reason, an alternative, and `details` in a small private fold. An optional in-sheet `action` shows a working state, and on failure the question stays open with a notice and Try again. Raised from a KitSheet (from the body or from a pinned action), it swaps in place and adds no route (§4.7). | `lib/ui/kit/kit_confirm_sheet.dart` (part of `kit_sheet.dart`) |
| §8.2 adaptation | **showKitSheet:** a bottom sheet on compact, a bottom sheet capped at 640 dp on medium, a centred panel of up to 560 dp on expanded and large. `full` height becomes an end-side sheet of 400–480 dp (the start side in RTL). **showKitConfirm:** a bottom sheet, capped at 560 dp on medium, and a centred 480 dp dialog on expanded and large. **Keys:** Esc closes and obeys draft/dirty. Enter confirms only a neutral question. Tab reaches every action. | same |
| `KitHaptics.commit` (§2.13) | A firm tick on a confirmed stop, delete or discard. It obeys Settings › Vibration. | `lib/ui/kit/motion/kit_haptics.dart` |
| `KitTokens` | A ThemeExtension that holds every colour, radius, elevation, scrim, type style and spacing the modal parts use. When no extension is set, it is derived from the theme. The new visual language lands here, not in the parts. | `lib/ui/kit/kit_tokens.dart` |
| Leading icons grow with text | `KitTokens.iconSize` scales with the text scaler, clamped at 1.5×. It is used by the confirmation's mark and by `KitNotice`. | `kit_tokens.dart`, `kit_notice.dart` |
| `KitTechnicalValue` | The data shape from §1.8, used by the confirmation's details. | `lib/ui/kit/kit_technical_value.dart` |
| KitStatusMark bug | It read only `MediaQuery.disableAnimationsOf`. It now reads `KitMotion.reduced`, so Animations: Off also shows the still dot. | `lib/ui/kit/kit_status_mark.dart` |
| `showConfirmSheet` | Now a thin wrapper over `showKitConfirm` (§2.14). The signature is kept, so its 70 calls in 37 files get the kit confirmation. The raw `HapticFeedback.mediumImpact` is gone. | `lib/ui/widgets/confirm_sheet.dart` |
| AlertDialog confirmations | 15 dialogs in 13 files now use `showKitConfirm` (list below). | screens, `external_link.dart`, `voice_ui.dart` |
| Ratchet G1, G15, G16 | Per-file baseline that only shrinks. | `test/kit_ratchet_test.dart`, `test/kit_ratchet_baseline.json`, `test/kit_ratchet_flutter_widgets.json`, `tool/kit/flutter_widget_names.dart` |
| Copy | 14 kit strings (en and ar), plus `sessionNoteDiscardDetail`, `usageBudgetClearTitle` and `quotaBudgetClearTitle`. | `lib/l10n/app_en.arb`, `app_ar.arb` |

### Migrated AlertDialogs (P9.1)

Each entry gives the file, the kind it now uses, and the reason.

- `running_work_sheet.dart`: stop, because it ends a running command.
- `profile_monitor_screen.dart`: neutral, because a switch loses nothing.
- `session_note_screen.dart`: discard.
- `activity_screen.dart` (question dismiss): destructive, with `routes`.
- `session_destination_sheet.dart`, the move and the organization switch: neutral. "Move only" is the alternative.
- `usage_screen.dart` and `provider_quota_screen.dart` (clear): destructive.
- `project_health_screen.dart` (git init): neutral.
- `saved_permissions_screen.dart` (revoke): destructive. Its action and resource moved under Details.
- `managed_workspaces_screen.dart` (remove) and `worktrees_screen.dart` (remove): destructive, with a typed name.
- `worktrees_screen.dart` (reset): destructive.
- `external_link.dart`: neutral. The host stays in the body because the person checks it before anything opens, and the HTTP warning is a consequence line.
- `voice_ui.dart` (pack delete): destructive.

Skipped, for `KitDialog` and pickers later: text entry and rename dialogs, pickers, info and close-only dialogs, integrations' "Open authorization page?" (it shows a one-time code), session handoff, and the provider-quota enroll threshold.

Left for the chat library's owner: `chat/permission_sheet.dart:197`, the permission "always" confirmation.

## Builds

Branch `feat/kit-v2-a` from `ebbc1a71`. No APK, no Gradle, no emulator, no adb, no push.

## Runs

`F` is the pinned Flutter 3.47.1 (AGENTS.md). All runs use `--no-pub -j 2` or `-j 1`.

| # | Command | Result |
|---|---|---|
| 1 | `$F test test/kit_motion_test.dart` with the KitStatusMark fix reverted | **Fails** "under effectsOff KitStatusMark working shows its still dot" (`status-mark-fails-without-fix.txt`) |
| 2 | The same with the fix | `+7: All tests passed!` (`status-mark-passes-with-fix.txt`) |
| 3 | `$F test test/kit/ test/kit_motion_test.dart`. Covers G9 (KitConfirmSheet contract), G10 (drafts and the profile sweep), G14 (keyboard with `debugPlatformCapabilities` set to desktop), the §8.2 shapes, and the tokens. | `+67: All tests passed!` |
| 4 | `$F test --update-goldens test/goldens/kit/`, then a normal run | `+58: All tests passed!` |
| 5 | Tests that touch the 37 `showConfirmSheet` files (keys and labels): 30 files | 237 + 417 tests pass after finder updates in 4 files |
| 6 | The other 98 tests that import those files, in 4 chunks | `+326 ~1`, `+266`, `+286`, `+369 ~3`: all pass |
| 7 | Tests of the migrated screens, 20 files | `+329 ~1: All tests passed!` |
| 8 | design_standard, ui_glossary, l10n_coverage, accessibility_guidelines, text_scale_overflow, external_link, profile_deletion, appearance_effects, kit_motion_app | `+111: All tests passed!` |
| 9 | Existing goldens that show confirm sheets or notices: folder_browser, team_sheets, team_board, work_tab, chat_states, team_discover | Only `team_board_cancel_confirm` (dark and light) changed. It was re-rendered and reviewed. |
| 10 | `KIT_RATCHET_WRITE=1 $F test test/kit_ratchet_test.dart`, then a normal run | `+9: All tests passed!` |
| 11 | `$F analyze` (whole worktree) | `No issues found!` |

## Galleries (G4, §8.4)

58 renders are in `test/goldens/kit/` (`kit_confirm_*.png`, `kit_sheet_*.png`):

- **KitConfirmSheet, destructive:** at 360×800, 412×915, 800×1280, 1280×800 and 1600×1000, in light and dark. It shows the consequence, the typed name, the alternative and Details.
- **KitConfirmSheet at 412 and 1280:** at 2.0 text, and in Arabic at 1.3× with Details open.
- **KitConfirmSheet states at 412:** neutral, stop working, failed, discard, and typed name ready.
- **KitSheet, default:** at the same five sizes, in light and dark.
- **KitSheet at 412 and 1280:** at 2.0 text, and in Arabic.
- **KitSheet states at 412:** loading, disabled primary, discard asked in place, half, and full.
- **KitSheet full at 1280:** the end-side sheet.

Arabic renders with Noto Sans Arabic from `test/fixtures/fonts` (OFL), used as the fallback, as on Android.

The visual design is not final. A new visual language will arrive as `KitTokens`.

## Ratchet baseline (`test/kit_ratchet_baseline.json`)

| Gate | Files | Count | Notes |
|---|---|---|---|
| G1 modal and toast entry points | 118 | 472 (was 502) | showSnackBar 127, SnackBar 127, showModalBottomSheet 78, showConfirmSheet 70, AlertDialog 30 (was 46), showDialog 30 (was 46), MaterialBanner 5, DraggableScrollableSheet 5 |
| G15 width literals | 11 | 19 | |
| G16 non-kit Flutter widgets in lib/ui | 189 | 5118 (was 5233) | Top: Text, Icon, TextButton, IconButton, ListTile |

## Left for the coordinator

- **Emulator proof at phone and tablet sizes**, not run here (not allowed in this slice):
  - one `showConfirmSheet` flow, for example removing a server;
  - a migrated dialog, for example removing a worktree with its typed name;
  - Esc and Tab on a desktop build;
  - on a tablet in landscape: the centred panel, and the end-side sheet.
- Four migrated confirmations still open on top of sheets that are not kit sheets yet: running work, question, session destination and voice setup. They stack until those parents move to `showKitSheet` (§4.7).
- §4.1 review:
  - The organization switch and git init may not need a confirmation.
  - `team_board_cancel_confirm` cancels something the host can reopen, so §4.1 asks for Undo there.
  - Two confirm labels do not name the thing: "Switch", and "Delete" on the voice pack.
- The external link's host is shown as body text, not mono. Isolating it LTR is a follow-up for `KitDetailsFold`/`KitTechnicalValue` in step B.
- Not built in this slice:
  - the G4 manifest test;
  - the G5 accessibility guidelines on galleries;
  - `KitReceipt` after a `RequestRoutes` close;
  - `KitAction.disabledReason` (§2.7). The confirmation shows its own reason line.
- `kit-v2.md` §9 (the G16 rule and its allowlist) is the coordinator's to add. This worktree does not edit `kit-v2.md`.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 2 test/kit/ test/kit_motion_test.dart test/kit_ratchet_test.dart test/goldens/kit/
$F analyze
```
