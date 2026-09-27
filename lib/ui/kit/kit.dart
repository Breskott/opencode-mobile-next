/// The design kit (docs/design/design-standard.md): the few parts every
/// migrated screen is built from, each used the same way everywhere.
///
/// | Part | Standard |
/// |---|---|
/// | [KitScreen] | §1 screen: header, one loading bar, body, pinned bottom |
/// | [KitLayout], [KitWindow] | kit v2 §8.1 window classes: every part adapts to phone, tablet and PC |
/// | [KitSheet], [showKitSheet], [KitSheetHeight], [KitDraft] | kit v2 §1.1 the one sheet frame, its draft and unsaved-input guard |
/// | [KitConfirmSheet], [showKitConfirm], [KitConfirmKind] | kit v2 §1.2 the one confirmation (§4.1 undo, confirm or neither) |
/// | [KitConsequences], [KitConsequence] | §5 a sheet's panel of one-line consequences |
/// | [KitTokens] | kit v2 the colours (the theme's [ThemeRoles]), radii, heights, scrim, type and spacing every part reads (a ThemeExtension) |
/// | [KitText], [KitTextRole], [KitTextTone] | visual language §2 the type roles, coloured by theme role |
/// | [KitSelectable], [KitLtr] | KitText v2 a selectable region around several texts, and a left-to-right technical block |
/// | [KitTechnicalValue] | kit v2 §1.8 a technical value shown under Details, left to right |
/// | [KitButton], [KitActionBlock], [KitAction] | §2 one button hierarchy |
/// | [KitActionStack] | §2 the same hierarchy with each rare path on its own line |
/// | [KitStateView] | §3 every not-normal state, page or inline |
/// | [KitLoadingBar], [KitSkeletonRows], [KitProgress] | §4 progress |
/// | [KitSkeletonTranscript] | §4 a conversation loading |
/// | [KitStatusLine] | §5 one status line |
/// | [KitAskLine] | §2, §5 a one-time question with its two answers |
/// | [KitRequestCard] | §2, §3 a request the person answers (permission, question) |
/// | [KitRow], [KitRowGroup], [KitRowValue], [SectionLabel] | §6 rows, rows grouped on one panel, a row's current value, and sections |
/// | [KitRowIcon], [KitRowMenu], [KitChevron], [KitSwitchRow], [KitExpandRow] | §6 a row's current mark, overflow menu, chevron, switch and unfolding group |
/// | [KitPanel] | §3 a block of content the person works with |
/// | [KitStatusMark] | §6 a step's leading state mark (waiting, working, done, failed) |
/// | [KitTaskMark] | §6 a task's leading mark: a step's four, needs you, stopped |
/// | [KitNotice] | §3 a message inside one part of a form or list |
/// | [KitMotion] | §10 the timings, curves and when things may loop |
/// | [KitHaptics] | §10, kit v2 §2.13 send, done and commit: the only vibration, obeying Settings › Vibration |
/// | [KitEffects], [KitEffectsScope] | §10 the person's glass, motion, celebration and vibration choices (Settings › Appearance) |
/// | [KitGlass] | §10 glass: a bounded surface floating over content (liquid, frosted or solid) |
/// | [KitIllustration], [KitScene], [KitDraw], [KitPortalScene] | §10 drawings in the brand's line, drawn in code, that can move |
/// | [KitSurface] | kit v2 §4 the one solid box: a surface step fill, token shape and padding, optional hairline edge |
/// | [KitDivider] | kit v2 the one separator: a pixel-snapped hairline, optionally inset to a row's words |
/// | [KitIcon], [KitIconSize], [KitBrandMark] | kit v2 §9 the one way to draw a glyph at a designed size, and the open-portal mark |
/// | [KitChip], [KitChipKind], [KitChipWrap] | kit v2 §4-§5 a small rounded label, always with a word, and its wrapping row |
/// | [KitSegmented], [KitSegment] | kit v2 §1.6 one choice among 2–4 short, always-visible options |
/// | [KitMenuItem], [showKitMenu], [KitMenuPanel] | kit v2 the one popup menu: groups, checks, disabled reasons, destructive last |
/// | [KitTerm], [showKitTerm] | K2 §1.20 a term that explains itself |
/// | [KitUndo], [showKitUndo] | K2 §1.17, §4.1 the one Undo bar |
/// | [KitBottomInset], [KitClearance] | K2 §2.12 how much of the bottom is covered by something pinned or floating |
/// | [KitSince], [KitSincePhase], [KitSinceStatus], [KitSinceTicks] | the one wait timer: slow after a while, then minute ticks |
/// | [KitImage], [KitAvatar], [KitZoom], [KitZoomController] | kit v2 sharp raster images, the one identity mark, and the one pinch/pan/zoom viewer |
/// | [KitQr] | kit v2 §5 a QR code another device can scan |
/// | [KitSwatch], [KitSwatchGrid], [KitThemePreview] | kit v2 §5 choosing a theme or accent by looking, and a theme's live preview |
/// | [KitLevelMeter] | the microphone's input level as bars (decorative) |
/// | [KitTerminalView] | kit v2 §9.2 the terminal: a live xterm session or a transcript, in the theme's colours |
/// | [KitPageRoute] | §10 a pushed page with the kit's one transition |
/// | [KitSwap], [KitSpin], [KitAnimatedBox], [KitDim], [KitAnimatedValue], [KitPace] | §10 the small motion parts: cross-fade, spin, surface change, dim, eased number |
///
/// The older shared states in `product_states.dart` are re-exported here so
/// a screen imports one library; new screens use [KitStateView] for them.
/// `test/design_standard_test.dart` checks the migrated screens.
library;

export '../widgets/product_states.dart'
    show
        LoadingList,
        ProductEmptyState,
        ProductErrorState,
        ProductInlineEmpty,
        SectionLabel;
export 'kit_action_stack.dart';
export 'kit_ask_line.dart';
export 'kit_buttons.dart';
export 'kit_effects.dart';
export 'kit_icon_button.dart';
export 'kit_illustration.dart';
export 'kit_layout.dart';
export 'kit_motion.dart';
export 'kit_panel.dart';
export 'kit_notice.dart';
export 'kit_progress.dart';
export 'kit_request_card.dart';
export 'kit_row.dart';
export 'kit_row_parts.dart';
export 'kit_screen.dart';
export 'kit_secret_field.dart';
export 'kit_sheet.dart';
export 'kit_skeleton_transcript.dart';
export 'kit_state_view.dart';
export 'kit_status_line.dart';
export 'kit_status_mark.dart';
export 'kit_bidi.dart';
export 'kit_copy.dart';
export 'kit_redact.dart';
export 'kit_technical_value.dart';
export 'kit_text.dart';
export 'kit_tokens.dart';
export 'kit_task_mark.dart';
export 'kit_bottom_inset.dart';
export 'kit_chip.dart';
export 'kit_code_block.dart';
export 'kit_divider.dart';
// The retired AppGlyph and AppBrandMark stay reachable only through
// app_iconography.dart (KitIcon.md), so new code reaches for KitIcon.
export 'kit_icon.dart' hide AppBrandMark, AppGlyph;
export 'kit_image.dart';
export 'kit_level_meter.dart';
export 'kit_menu.dart';
export 'kit_page_route.dart';
export 'kit_qr.dart';
export 'kit_segmented.dart';
export 'kit_since.dart';
export 'kit_surface.dart';
export 'kit_swatch.dart';
export 'kit_term.dart';
export 'kit_terminal_view.dart';
export 'kit_undo.dart';
export 'scenes/portal_scene.dart';
export 'motion/kit_animated_rows.dart';
export 'motion/kit_haptics.dart';
export 'motion/kit_motion_parts.dart';
export 'motion/kit_page_transitions.dart';
export 'motion/kit_refresh.dart';
export 'motion/kit_reveal.dart';
export 'motion/kit_tab_switcher.dart';
export 'glass/kit_glass.dart';
export 'chat/kit_tool_row.dart';
export 'kit_viewer.dart';
export 'kit_capability_explainer.dart';
export 'kit_checklist.dart';
export 'kit_diff_view.dart';
export 'kit_board_lane.dart';
export 'kit_swipe_action.dart';
export 'chat/kit_markdown.dart';
export 'kit_status_slot.dart';
export 'kit_breadcrumb.dart';
export 'kit_choice_list.dart';
export 'kit_details_fold.dart';
export 'kit_field.dart';
export 'kit_jump_pill.dart';
export 'kit_nav.dart';
export 'kit_needs_you.dart';
export 'kit_progress_row.dart';
export 'kit_receipt.dart';
export 'kit_search_field.dart';
export 'kit_tappable.dart';
export 'kit_top_bar.dart';
export 'kit_task_card.dart';
export 'kit_log_panel.dart';
export 'kit_work_graph.dart';
export 'chat/kit_agent_strip.dart';
export 'chat/kit_composer.dart';
export 'chat/kit_composer_chips.dart';
export 'chat/kit_work_line.dart';
export 'chat/kit_queued_message.dart';
export 'kit_dialog.dart';
