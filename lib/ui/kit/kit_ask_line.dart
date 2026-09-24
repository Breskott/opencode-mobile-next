import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_buttons.dart';

/// A one-time question on an otherwise working screen, with its two
/// answers in view (design standard §2, §5): an icon, the question, then
/// [decline] (muted) and [accept] as text buttons at the end of the line.
/// When the question and both answers do not fit on one line (long words,
/// large text) the answers move under the question, start-aligned.
///
/// It is not a status line (§5 is for conditions): it asks, once, and
/// leaves when answered. It sits where the question belongs (in the chat,
/// just above the composer), not under the top bar with the status line.
class KitAskLine extends StatelessWidget {
  const KitAskLine({
    super.key,
    required this.icon,
    required this.question,
    required this.accept,
    required this.decline,
    this.semanticsLabel,
  });

  final IconData icon;
  final String question;
  final KitAction accept;
  final KitAction decline;

  /// The fuller explanation a screen reader gives instead of [question].
  final String? semanticsLabel;

  bool _stacks(BuildContext context, double width) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final buttons =
        measure(accept.label, theme.textTheme.labelLarge) +
        measure(decline.label, theme.textTheme.labelLarge) +
        4 * KitButton.tertiaryInset;
    // Room for the question on at most two lines beside the answers.
    final question = measure(this.question, theme.textTheme.bodyMedium) / 2;
    return 16 + 18 + 12 + question + buttons + 8 > width ||
        scaler.scale(1) > 1.5;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget answer(KitAction action, {bool muted = false}) => TextButton(
      key: action.key,
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: KitButton.tertiaryInset,
        ),
        foregroundColor: muted ? AppTheme.mutedOf(theme) : null,
      ),
      child: Text(action.label),
    );
    final answers = [answer(decline, muted: true), answer(accept)];
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = _stacks(context, constraints.maxWidth);
          // Two lines at most, even at large text: the question never takes
          // the screen from what it sits on; [semanticsLabel] says it all.
          final text = Text(
            question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          );
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 8, 2),
              child: Row(
                crossAxisAlignment: stacked
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: stacked ? 15 : 0),
                    child: Icon(
                      icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: stacked
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                text,
                                KitInset(
                                  child: Wrap(
                                    spacing: 4,
                                    children: answers.reversed.toList(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : text,
                  ),
                  if (!stacked) ...answers,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
