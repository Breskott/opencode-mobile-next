import 'package:flutter/widgets.dart';

import '../app_iconography.dart';
import '../kit/kit_icon.dart';
import '../kit/kit_surface.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';

// The retired confirmation wrapper moved into the kit (R12, KIT-38); this
// re-export keeps every `import 'confirm_sheet.dart'` compiling.
export '../kit/kit_confirm_retired.dart' show showConfirmSheet;

/// The end-swipe reveal behind a list row: a `surface2` field with the
/// delete glyph at its end, in the danger tone (LOOK-5: the act loses data).
///
/// Kit only (shared-shell-1). When `KitSwipeAction` (kit-KitRow-v2) lands,
/// this becomes a forwarding wrapper over its background (C37); until then
/// it draws the same field from kit parts. A swipe is only an accelerator
/// (KIT-29): the act it leads to is also in the row's menu.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) => KitSurface(
    level: KitSurfaceLevel.surface2,
    shape: KitShape.square,
    padding: KitSurfacePadding.none,
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: EdgeInsetsDirectional.only(end: KitTokens.of(context).space6),
        child: const KitIcon(AppIconography.delete, tone: KitTextTone.danger),
      ),
    ),
  );
}
