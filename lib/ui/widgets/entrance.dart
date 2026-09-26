import 'package:flutter/widgets.dart';

import '../kit/kit_motion.dart';
import '../kit/motion/kit_reveal.dart';

/// Retired by shared-shell-1: use [KitEntrance].
///
/// A list row arriving: it fades in and rises into place through the kit's
/// one entrance ([KitEntrance], `KitMotion.standard`, `KitMotion.enter`), so
/// every row in the app moves the same way (MOT-1). The old per-index
/// stagger is gone: the kit owns durations and curves, and a list settles in
/// one standard beat. [index] is kept so call sites still compile.
///
/// It renders the final state at once when motion is reduced, and rows that
/// scroll into view later are not animated (see [_listAtRest]).
class EntranceReveal extends StatefulWidget {
  const EntranceReveal({super.key, required this.index, required this.child});

  /// Position in the list. Kept for existing call sites; the kit entrance
  /// does not stagger.
  final int index;
  final Widget child;

  /// Kept for existing readers; there is no stagger any more.
  static const staggerCap = 8;

  @override
  State<EntranceReveal> createState() => _EntranceRevealState();
}

class _EntranceRevealState extends State<EntranceReveal> {
  /// Decided once, when the row first mounts, so a later rebuild never
  /// swaps the wrapper in or out and remounts the row underneath.
  bool? _reveal;

  @override
  Widget build(BuildContext context) {
    if (KitMotion.reduced(context)) return widget.child;
    if (!(_reveal ??= _listAtRest(context))) return widget.child;
    return KitEntrance(child: widget.child);
  }

  /// Lazy lists build rows as they scroll into view. Those rows are not
  /// arriving, and fading each one in costs a composited layer per row
  /// mid-fling, so only rows mounted while the list rests at its start get
  /// the entrance.
  static bool _listAtRest(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    // No content dimensions yet means the list's very first layout.
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return true;
    }
    return position.pixels == position.minScrollExtent &&
        !position.isScrollingNotifier.value;
  }
}
