/// The design kit (docs/design/design-standard.md): the few parts every
/// migrated screen is built from, each used the same way everywhere.
///
/// | Part | Standard |
/// |---|---|
/// | [KitScreen] | §1 screen: header, one loading bar, body, pinned bottom |
/// | [KitButton], [KitActionBlock], [KitAction] | §2 one button hierarchy |
/// | [KitStateView] | §3 every not-normal state, page or inline |
/// | [KitLoadingBar], [KitSkeletonRows], [KitProgress] | §4 progress |
/// | [KitStatusLine] | §5 one status line |
/// | [KitRow], [SectionLabel] | §6 rows and sections |
/// | [KitStatusMark] | §6 a step's leading state mark (waiting, working, done, failed) |
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
export 'kit_buttons.dart';
export 'kit_progress.dart';
export 'kit_row.dart';
export 'kit_screen.dart';
export 'kit_state_view.dart';
export 'kit_status_line.dart';
export 'kit_status_mark.dart';
