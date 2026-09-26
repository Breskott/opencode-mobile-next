import 'package:flutter/widgets.dart';

import '../kit/kit_text.dart';

/// Retired by shared-shell-1: use [KitLtr] (KitText v2).
///
/// Isolates actual code, commands, paths and URLs from surrounding RTL
/// chrome. Do not wrap user prose, server descriptions or whole
/// mixed-content cards. It forwards to [KitLtr], so the one forced
/// left-to-right block lives in the kit.
class TechnicalDirection extends StatelessWidget {
  const TechnicalDirection({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => KitLtr(child: child);
}
