import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_status_mark.dart';

/// Where a task stands (docs/design/aiteam-redesign-2026-09-24.md): the four
/// states of a step, plus a task that waits on the person and one stopped
/// before it finished.
enum KitTaskState { waiting, working, done, failed, needsYou, stopped }

/// A task row's one leading mark (design standard §6): [KitStatusMark] for
/// waiting, working, done and failed, so a task and a setup step read the
/// same; a question mark in the attention tone when the task needs the
/// person; a muted stop mark when it was cancelled. Sized for [KitRow]'s
/// leading slot. The row's supporting line says the state in words, so the
/// mark is never the only sign (never colour-only).
class KitTaskMark extends StatelessWidget {
  const KitTaskMark({super.key, required this.state});

  final KitTaskState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget icon(IconData data, Color color) => SizedBox.square(
      dimension: 32,
      child: Center(child: Icon(data, size: 20, color: color)),
    );
    return switch (state) {
      KitTaskState.waiting => const KitStatusMark(state: KitMarkState.waiting),
      KitTaskState.working => const KitStatusMark(state: KitMarkState.working),
      KitTaskState.done => const KitStatusMark(state: KitMarkState.done),
      KitTaskState.failed => const KitStatusMark(state: KitMarkState.failed),
      KitTaskState.needsYou => icon(
        AppIconography.question,
        AppTheme.statusColor(theme, AppStatusTone.attention),
      ),
      KitTaskState.stopped => icon(
        AppIconography.stopCircle,
        AppTheme.mutedOf(theme),
      ),
    };
  }
}
