import 'package:flutter/material.dart';

import '../kit_motion.dart';

/// The shell's destinations, kept alive, switched with a fade-through
/// (design standard §10): the tab being left fades out in the first third of
/// [KitMotion.standard], then the chosen one fades in and settles from 97 %
/// to full size. The two are never both half-visible, so the switch reads as
/// one clean change instead of two lists blending into each other.
///
/// Every destination keeps its state (a draft, a scroll position). The
/// chosen one responds at once: it takes touches, focus and screen-reader
/// traversal from the first frame. The one being left is picture only: no
/// focus, no touches, no semantics, and its tickers stop as soon as the
/// selection changes. A quick change of mind starts from what is painted
/// now, so nothing queues or flashes.
///
/// Paint and transform only (opacity and scale over each destination's own
/// repaint boundary). With [reduceMotion] or the system's "remove
/// animations" the chosen destination shows in the next frame.
class KitTabSwitcher extends StatefulWidget {
  const KitTabSwitcher({
    super.key,
    required this.index,
    required this.children,
    this.reduceMotion = false,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;
  final bool reduceMotion;

  /// The share of the switch the old destination takes to fade out.
  static const fadeOutShare = .35;

  /// The size the arriving destination settles from.
  static const settleFrom = .97;

  @override
  State<KitTabSwitcher> createState() => _KitTabSwitcherState();
}

class _KitTabSwitcherState extends State<KitTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KitMotion.standard,
    value: 1,
  );
  late List<double> _starts = _target(widget.index);
  late int _targetIndex = widget.index;

  List<double> _target(int index) => [
    for (var i = 0; i < widget.children.length; i++) i == index ? 1 : 0,
  ];

  double _opacity(int index) {
    final t = _controller.value;
    final start = _starts[index];
    if (index == _targetIndex) {
      // Waits for the old destination to clear, unless it was already
      // partly showing (a quick change of mind), then fades in.
      final begin = KitTabSwitcher.fadeOutShare * (1 - start);
      final p = t <= begin
          ? 0.0
          : KitMotion.enter.transform(((t - begin) / (1 - begin)).clamp(0, 1));
      return start + (1 - start) * p;
    }
    final p = KitMotion.exit.transform(
      (t / KitTabSwitcher.fadeOutShare).clamp(0.0, 1.0),
    );
    return start * (1 - p);
  }

  @override
  void didUpdateWidget(KitTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduced = widget.reduceMotion || KitMotion.reduced(context);
    if (reduced || oldWidget.children.length != widget.children.length) {
      _starts = _target(widget.index);
      _targetIndex = widget.index;
      _controller.value = 1;
    } else if (oldWidget.index != widget.index) {
      _starts = [for (var i = 0; i < widget.children.length; i++) _opacity(i)];
      _targetIndex = widget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _destination(i, _opacity(i)),
      ],
    ),
  );

  Widget _destination(int i, double opacity) {
    final selected = i == widget.index;
    const from = KitTabSwitcher.settleFrom;
    return Offstage(
      offstage: !selected && opacity == 0,
      child: TickerMode(
        enabled: selected,
        child: ExcludeFocus(
          excluding: !selected,
          child: ExcludeSemantics(
            excluding: !selected,
            child: IgnorePointer(
              ignoring: !selected,
              child: Opacity(
                opacity: opacity,
                alwaysIncludeSemantics: selected,
                child: Transform.scale(
                  scale: opacity >= 1 ? 1 : from + (1 - from) * opacity,
                  child: RepaintBoundary(child: widget.children[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
