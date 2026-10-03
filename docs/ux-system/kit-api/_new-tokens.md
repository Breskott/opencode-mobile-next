# Pre-wave named tokens

The names the frozen wave-1 specs call "pre-wave" (STANDARDS §0.5 step 2).
The coordinator adds them before wave 1, so no wave-1 unit edits
`kit_tokens.dart`, `kit_layout.dart` or `kit_motion.dart`. Every value is
checked in `test/kit/kit_pre_wave_tokens_test.dart`.

The `KitTokens` numbers are `static const` because the visual language fixes
them in every theme. Read them as `KitTokens.chipHeight`, not
`tokens.chipHeight`. `shapeOf`, `fillOf` and `segmentFills` read theme
values, so they are instance members.

## KitTokens (`lib/ui/kit/kit_tokens.dart`)

| Token | Value | Used by |
|---|---|---|
| `hairlineWidth(context)` | 1 physical px (`1 / dpr`) | KitDivider, KitField, KitRow, KitSheet, KitStatusLine, KitChecklist, KitCodeBlock, KitDiffView, KitMenu, KitMarkdown, KitMessage, KitQueuedMessage, KitSurface, KitMotionParts, most wave-1 parts |
| `focusRingWidth(context)` | 2 physical px (`2 / dpr`; at least 1 logical when dpr ≤ 1) | KitAction, KitChip, KitTappable, KitField, KitIconButton, KitMenu, KitRow, KitComposer, KitNav, KitTurn, KitTerm, KitSegmented, KitSheet |
| `spinnerStroke` | 2 (logical) | KitAction (`KitButton`), KitIconButton, KitStatusMark |
| `chipHeight` | 32 | KitChip |
| `choiceRowMinHeight` | 56 | KitChoiceList, KitRowParts |
| `composerActionSize` | 40 | KitComposer |
| `composerStopSquare` | 14 | KitComposer |
| `crumbMaxWidth` | 160 | KitBreadcrumb |
| `detailsLabelColumn` | 160 | KitDetailsFold |
| `disabledAlpha` | 0.38 | KitMotionParts |
| `staleAlpha` | 0.6 | KitMotionParts |
| `duotoneWash` | 0.2 | KitIcon |
| `fieldRadius` | 14 | KitField |
| `monogramMaxTextScale` | 1.3 | KitImage |
| `popoverRadius` | 14 | KitIconButton, KitMenu, KitTerm |
| `bubbleRadius` | 20 | KitMessage, KitQueuedMessage |
| `bubbleTailRadius` | 6 | KitMessage, KitQueuedMessage |
| `logFoldedLines` | 12 (int) | KitLogPanel |
| `termBubbleMaxHeight` | 0.4 (share of window height) | KitTerm |
| `statusLineMinHeight` | 52 | KitStatusLine, KitAskLine |
| `loadingBarHeight` | 2 | KitProgress, KitChecklist |
| `progressBarHeight` | 4 | KitProgress, KitChecklist, KitProgressRow |
| `progressBarRadius` | 2 | KitProgress, KitProgressRow |
| `navLabelMaxScale` | 2.0 | KitNav |
| `meterBars` | 9 (int) | KitLevelMeter |
| `meterBarWidth` | 6 | KitLevelMeter |
| `meterBarMin` / `meterBarMax` | 12 / 20 | KitLevelMeter |
| `badgeHeight` / `badgeMinWidth` | 18 / 18 | KitNeedsYou |
| `badgeTextScaleMax` | 1.3 | KitNeedsYou |
| `badgeOffset` | 6 (`badgeHeight / 3`) | KitNeedsYou |
| `qrInk` / `qrPaper` | `graphiteLight.text1` / `graphiteLight.surface1` | KitQr |
| `qrMaxSize` | 240 | KitQr |
| `qrQuietModules` | 4 (int) | KitQr |
| `needsYouRingWidth` / `needsYouRingAlpha` | 4 / 0.06 | KitRequestCard |
| `requestTileSize` / `requestTileRadius` | 36 / 10 | KitRequestCard |
| `requestMaxHeightShare` | 0.45 | KitRequestCard |
| `scannerWindow` / `scannerBracket` | 240 / 28 | KitScanner |
| `sceneWashAlpha` | 0.12 | KitScenes |
| `illustrationPage` / `illustrationInline` | 160 / 88 | KitScenes, KitStateView |
| `stateVerticalPadding` | 32 | KitStateView |
| `markSlotSize` / `markRingSize` / `markDotSize` | 32 / 10 / 12 | KitStatusMark |
| `swatchMinWidth` / `swatchPreviewHeight` / `swatchDot` | 112 / 56 / 12 | KitSwatch |
| `terminalMaxTextScale` / `terminalKeyMaxTextScale` | 2.0 / 1.3 | KitTerminalView |
| `graphNodeWidth` | 156 | KitWorkGraph |
| `graphColumnGap` / `graphRowGap` | 24 / 48 | KitWorkGraph |
| `graphMaxLanes` | 6 (int) | KitWorkGraph |
| `graphDash` | 4 | KitWorkGraph |
| `shapeOf(KitShape)` | a `ShapeBorder` from the kit radii | KitSurface, KitTappable, KitImage, KitMotionParts |
| `fillOf(KitSurfaceLevel)` | `ground`, `surface1`–`surface3` | KitSurface, KitTappable, KitMotionParts |
| `segmentFills` | `accent`, `text2`, `text3`, `surface3` | KitProgressRow |

## KitShape and KitSurfaceLevel (`lib/ui/kit/kit_shape.dart`)

The file is exported from `kit_tokens.dart`, so importing the tokens is
enough.

| Shape | Resolves to | Used by |
|---|---|---|
| `square` | 0 | KitImage, KitTappable |
| `tile` | `iconTileRadius` (9) | KitComposerChips, KitSurface |
| `code` | `codeRadius` (14) | KitSurface |
| `button` | `buttonRadius` (14) | KitAskLine, KitSurface |
| `panel` | `panelCornerRadius` (18) | KitMotionParts, KitSurface |
| `card` | `cardRadius` (22) | KitSurface (needs-you and request cards) |
| `dialog` | `panelRadius` (24) | KitSurface |
| `sheet` | `sheetRadius` (30), top corners | KitSurface |
| `pill` | stadium | KitChip, KitAgentStrip, KitJumpPill, KitTabSwitcher, KitLevelMeter, KitNeedsYou, KitWorkLine |
| `circle` | circle | KitIconButton |

`KitSurfaceLevel` is `ground`, `surface1`, `surface2`, `surface3` (KIT-42).

## KitLayout (`lib/ui/kit/kit_layout.dart`)

| Token | Value | Used by |
|---|---|---|
| `paneListWidth` | 296 (was 360, LAY-5) | KitScreen, KitNav |
| `paneDetailMaxWidth` | 700 | KitScreen, KitMarkdown, KitAskLine, KitComposer, KitMessage, KitTurn, KitRequestCard |
| `paneSideWidth` | 340 | KitScreen |
| `pcListPane` / `pcDetailPane` / `pcSidePane` | 296 / 700 / 340 | KitScreen (PC three panes) |
| `railWidth` | 80 | KitNav, KitBottomInset |
| `undoMaxWidth` | 480 | KitUndo |
| `popoverMinWidth` / `popoverMaxWidth` | 200 / 320 | KitMenu, KitTerm |
| `bubbleMaxShare` | 0.85 | KitMessage, KitQueuedMessage |
| `composerMaxShare` | 0.4 | KitComposer |
| `laneMaxWidth` / `lanePeek` / `laneMinWidth` | 400 / 20 / 296 | KitBoardLane |
| `stateMaxWidth` | 440 | KitStateView |

## KitMotion (`lib/ui/kit/kit_motion.dart`)

| Token | Value | Used by |
|---|---|---|
| `escalateAfter` | 8 s | KitSince, KitField, KitChecklist, KitLogPanel, KitReceipt, KitStateView, KitStatusLine, KitTurn |
| `undoWindow` | 8 s | KitReceipt, KitUndo, KitSwipeAction |
| `copiedHold` | 2 s (no spec states a value; chosen here) | KitAction, KitIconButton, KitCodeBlock |
| `logPoll` | 2 s | KitLogPanel |
| `typingSettle` | 300 ms | KitSearchField |

## AppIconography (`lib/ui/app_iconography.dart`)

| Glyph | Value | Used by |
|---|---|---|
| `wrapText` | Phosphor regular `text-align-justify` (U+E482) | KitCodeBlock, KitLogPanel, KitViewer, KitDiffView |

## Not added here

- (Added 2026-09-27 as `KitTokens.toneFor`, `glyphFor` and `toneColor`.) `KitTokens.toneFor` / `toneColor(AppStatusTone)` (README.md decision D12;
  KitNotice, KitReceipt, KitStateView, KitStatusLine, KitStatusMark): the
  tone map needs the D12 table, which is not in the mention list.
- The `AppIcons.wrap` registry entry (KitCodeBlock, a PROC-13 append).
- `KitAsserts`, `KitCopy`, `KitBidi`, `KitRedact`: separate seams, not tokens.
- `accentKeepsMeaning` in `theme_roles.dart` (KitSwatch): §0.5 step 1 theme
  work.
