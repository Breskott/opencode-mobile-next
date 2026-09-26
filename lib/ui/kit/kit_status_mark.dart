import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_motion.dart';

/// Where one step of a list stands.
enum KitMarkState { waiting, working, done, failed }

/// A row's leading state mark (design standard §6: "a leading icon or status
/// dot"): a hollow dot waiting, a small spinner working (a still dot under
/// reduced motion), a check done, an error mark failed. Sized to sit in
/// [KitRow]'s leading slot. It is a state, not the screen's progress: the
/// one bar (§4) says how far the whole thing is.
class KitStatusMark extends StatelessWidget {
  const KitStatusMark({super.key, required this.state});

  final KitMarkState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The system setting and Animations: Off in Settings (KitEffects).
    final reduceMotion = KitMotion.reduced(context);
    final Widget mark = switch (state) {
      KitMarkState.done => Icon(
        AppIconography.check,
        size: 20,
        color: AppTheme.statusColor(theme, AppStatusTone.ok),
      ),
      KitMarkState.working =>
        reduceMotion
            ? Icon(
                AppIconography.statusDot,
                size: 12,
                color: theme.colorScheme.primary,
              )
            : const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      KitMarkState.failed => Icon(
        AppIconography.error,
        size: 20,
        color: AppTheme.statusColor(theme, AppStatusTone.failure),
      ),
      KitMarkState.waiting => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.mutedOf(theme), width: 1.5),
        ),
      ),
    };
    return SizedBox.square(dimension: 32, child: Center(child: mark));
  }
}
