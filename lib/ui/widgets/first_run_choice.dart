import 'package:flutter/widgets.dart';

import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_surface.dart';
import '../kit/kit_tokens.dart';

/// One answer to a first-run question: a whole-row target with a plain title
/// and one line saying what happens next. Every answer has the same weight,
/// because none of them is the "right" one.
///
/// Kit only (shared-shell-1): a [KitRow] on its own `surface1` panel, with
/// the icon in its tile and a chevron (VL §5). The detail may take two lines,
/// because it explains the choice (KIT-27).
class FirstRunChoice extends StatelessWidget {
  const FirstRunChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;

  /// Null while another answer is being acted on: the row dims.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: tokens.space1,
        bottom: tokens.space1,
      ),
      child: KitSurface(
        shape: KitShape.panel,
        padding: KitSurfacePadding.none,
        child: KitRow(
          leading: KitRow.icon(context, icon),
          title: title,
          titleMaxLines: 2,
          supporting: TextSpan(text: detail),
          supportingMaxLines: 3,
          trailing: const KitChevron(),
          enabled: onTap != null,
          onTap: onTap,
        ),
      ),
    );
  }
}
