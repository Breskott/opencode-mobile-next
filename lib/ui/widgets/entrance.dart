import 'package:flutter/material.dart';

/// A one-shot staggered list entrance: items fade in and rise slightly, with
/// the stagger capped so long lists settle as fast as short ones.
///
/// Purely ticker-driven ([TweenAnimationBuilder]), so it is safe when a test
/// disposes the tree mid-flight, and it renders the final state immediately
/// when animations are disabled.
class EntranceReveal extends StatefulWidget {
  const EntranceReveal({super.key, required this.index, required this.child});

  /// Position in the list; delays are capped at [staggerCap] items.
  final int index;
  final Widget child;

  static const staggerCap = 8;
  static const _stepMs = 28;
  static const _revealMs = 190;

  @override
  State<EntranceReveal> createState() => _EntranceRevealState();
}

class _EntranceRevealState extends State<EntranceReveal> {
  /// Decided once, when the row first mounts, so a later rebuild never
  /// swaps the wrapper in or out and remounts the row underneath.
  bool? _reveal;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    if (!(_reveal ??= _listAtRest(context))) return widget.child;
    final delayMs =
        widget.index.clamp(0, EntranceReveal.staggerCap) *
        EntranceReveal._stepMs;
    final totalMs = delayMs + EntranceReveal._revealMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      builder: (context, t, child) {
        final elapsedMs = t * totalMs;
        final raw = ((elapsedMs - delayMs) / EntranceReveal._revealMs).clamp(
          0.0,
          1.0,
        );
        final eased = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 8),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }

  /// Lazy lists build rows as they scroll into view. Those rows are not
  /// arriving, and fading each one in (invisible through its stagger delay)
  /// costs a composited layer per row mid-fling, so only rows mounted while
  /// the list rests at its start get the entrance.
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
