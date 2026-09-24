import 'package:flutter/material.dart';

/// The screen's one loading indicator (design standard §4): a 2 dp bar
/// directly under the top bar or header while anything on the screen loads
/// for the first time. It always takes its 2 dp, so the page does not jump
/// when loading starts or ends, and it carries a label for screen readers.
class KitLoadingBar extends StatelessWidget {
  const KitLoadingBar({super.key, required this.loading, required this.label});

  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: loading
        ? Semantics(
            key: const ValueKey('kit-loading-bar'),
            label: label,
            child: const LinearProgressIndicator(minHeight: 2),
          )
        : null,
  );
}

/// Placeholder rows while a list loads (§4): the shape of the rows to come,
/// with no words and no motion, hidden from screen readers (the loading bar
/// already says the screen is loading). Matches [KitRow]'s geometry.
class KitSkeletonRows extends StatelessWidget {
  const KitSkeletonRows({super.key, this.count = 4});

  final int count;

  static const _titleWidths = [0.72, 0.56, 0.64, 0.48, 0.6];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double height, Color color) => Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return ExcludeSemantics(
      child: Column(
        key: const ValueKey('kit-skeleton-rows'),
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 32,
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width:
                                  constraints.maxWidth *
                                  _titleWidths[i % _titleWidths.length],
                              child: bar(12, scheme.surfaceContainerHigh),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: constraints.maxWidth * 0.28,
                              child: bar(9, scheme.surfaceContainer),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Progress inside a [KitStateView] (§4): indeterminate while waiting, or
/// determinate with one line under it ("29 of 30 MB · about 1 min left").
class KitProgress {
  const KitProgress.waiting({this.caption, this.key}) : value = null;
  const KitProgress.known(double this.value, {this.caption, this.key});

  /// 0..1, or null while the amount is unknown.
  final double? value;
  final String? caption;

  /// Key of the bar itself, for tests.
  final Key? key;
}

/// Renders a [KitProgress]: a 4 dp rounded bar and its optional caption.
class KitProgressView extends StatelessWidget {
  const KitProgressView({super.key, required this.progress});

  final KitProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = progress.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          key: progress.key ?? const ValueKey('kit-state-progress'),
          value: progress.value,
          minHeight: 4,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
