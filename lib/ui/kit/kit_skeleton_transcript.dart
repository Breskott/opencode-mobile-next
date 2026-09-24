import 'package:flutter/material.dart';

/// Placeholder turns while a conversation loads (design standard §4, the
/// transcript's version of [KitSkeletonRows]): the shape of what is coming,
/// a prompt and a few lines of reply per turn, with no words and no motion,
/// hidden from screen readers (the screen's loading bar says it is
/// loading). It sits at the bottom, where the newest turn will appear, so
/// the first real message lands where the placeholder was.
class KitSkeletonTranscript extends StatelessWidget {
  const KitSkeletonTranscript({super.key, this.turns = 2});

  final int turns;

  static const _replyWidths = [
    [0.94, 0.88, 0.62],
    [0.9, 0.97, 0.8, 0.46],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double width, double height, Color color) =>
        FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: width,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
    final turnsColumn = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          key: const ValueKey('kit-skeleton-transcript'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var turn = 0; turn < turns; turn++) ...[
              if (turn > 0) const SizedBox(height: 28),
              // The prompt: one wide block, as prompts are drawn.
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              for (final width in _replyWidths[turn % _replyWidths.length])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: bar(width, 10, scheme.surfaceContainerHigh),
                ),
            ],
          ],
        ),
      ),
    );
    // In a short space (landscape, large text, keyboard up) the turns
    // nearest the composer show and the rest is cut off at the top, never
    // an overflow.
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) => !constraints.hasBoundedHeight
            ? Align(alignment: Alignment.bottomCenter, child: turnsColumn)
            : ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: turnsColumn,
                ),
              ),
      ),
    );
  }
}
