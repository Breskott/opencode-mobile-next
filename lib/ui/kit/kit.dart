/// The design kit (docs/design/design-standard.md): the few parts every
/// migrated screen is built from, each used the same way everywhere.
///
/// | Part | Standard |
/// |---|---|
/// | [KitScreen] | §1 screen: header, one loading bar, body, pinned bottom |
/// | [KitButton], [KitActionBlock], [KitAction] | §2 one button hierarchy |
/// | [KitActionStack] | §2 the same hierarchy with each rare path on its own line |
/// | [KitStateView] | §3 every not-normal state, page or inline |
/// | [KitLoadingBar], [KitSkeletonRows], [KitProgress] | §4 progress |
/// | [KitSkeletonTranscript] | §4 a conversation loading |
/// | [KitStatusLine] | §5 one status line |
/// | [KitAskLine] | §2, §5 a one-time question with its two answers |
/// | [KitRequestCard] | §2, §3 a request the person answers (permission, question) |
/// | [KitRow], [SectionLabel] | §6 rows and sections |
/// | [KitRowIcon], [KitRowMenu], [KitChevron], [KitSwitchRow], [KitExpandRow] | §6 a row's current mark, overflow menu, chevron, switch and unfolding group |
/// | [KitPanel] | §3 a block of content the person works with |
/// | [KitStatusMark] | §6 a step's leading state mark (waiting, working, done, failed) |
/// | [KitTaskMark] | §6 a task's leading mark: a step's four, needs you, stopped |
/// | [KitNotice] | §3 a message inside one part of a form or list |
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
export 'kit_panel.dart';
export 'kit_notice.dart';
export 'kit_progress.dart';
export 'kit_request_card.dart';
export 'kit_row.dart';
export 'kit_row_parts.dart';
export 'kit_screen.dart';
export 'kit_skeleton_transcript.dart';
export 'kit_state_view.dart';
export 'kit_status_line.dart';
export 'kit_status_mark.dart';
export 'kit_task_mark.dart';
