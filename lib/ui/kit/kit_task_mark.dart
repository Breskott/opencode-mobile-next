import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_status_mark.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// Where a task stands (docs/design/aiteam-redesign-2026-09-24.md): the four
/// states of a step, plus a task that waits on the person and one stopped
/// before it finished.
enum KitTaskState { waiting, working, done, failed, needsYou, stopped }

/// A task row's one leading mark (design standard §6): [KitStatusMark] for
/// waiting, working, done and failed, so a task and a setup step read the
/// same; [AppIconography.question] in the attention tone when the task
/// needs the person; a muted stop mark when it was cancelled. Sized for
/// [KitRow]'s leading slot.
///
/// Every mark carries its word (slice-P9.5: no state shown by colour
/// alone): in semantics always, and beside the mark as visible text when
/// [showLabel].
///
/// States: waiting, working, done, failed, paused (a waiting or working
/// modifier — KitStatusMark.md), plus needsYou and stopped.
class KitTaskMark extends StatelessWidget {
  const KitTaskMark({
    super.key,
    required this.state,
    this.paused = false,
    this.label,
    this.showLabel = false,
  });

  final KitTaskState state;

  /// Only meaningful with [KitTaskState.waiting] or [KitTaskState.working];
  /// asserted otherwise — a finished, needs-you or already-stopped task
  /// cannot be paused (STATE-11).
  final bool paused;

  /// The word this mark announces and, with [showLabel], shows. Null takes
  /// [wordFor].
  final String? label;

  /// Also draws the word as visible text after the mark, for a place that
  /// does not already show it.
  final bool showLabel;

  /// Waiting · Working · Done · Failed · Needs you · Stopped · Paused —
  /// [KitNeedsYou.mark] uses the same word for [KitTaskState.needsYou].
  static String wordFor(
    BuildContext context,
    KitTaskState state, {
    bool paused = false,
  }) {
    assert(
      !paused || state == KitTaskState.waiting || state == KitTaskState.working,
      'KitTaskMark.wordFor: paused only applies to waiting or working',
    );
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (paused) return l10n.kitMarkPaused;
    return switch (state) {
      KitTaskState.waiting => l10n.kitMarkWaiting,
      KitTaskState.working => l10n.kitMarkWorking,
      KitTaskState.done => l10n.kitMarkDone,
      KitTaskState.failed => l10n.kitMarkFailed,
      KitTaskState.needsYou => l10n.kitTaskNeedsYou,
      KitTaskState.stopped => l10n.kitTaskStopped,
    };
  }

  @override
  Widget build(BuildContext context) {
    assert(
      !paused || state == KitTaskState.waiting || state == KitTaskState.working,
      'KitTaskMark: paused only applies to waiting or working — a '
      'finished, needs-you or stopped task cannot be paused (G37, STATE-11)',
    );
    final mapped = switch (state) {
      KitTaskState.waiting => KitMarkState.waiting,
      KitTaskState.working => KitMarkState.working,
      KitTaskState.done => KitMarkState.done,
      KitTaskState.failed => KitMarkState.failed,
      KitTaskState.needsYou || KitTaskState.stopped => null,
    };
    if (mapped != null) {
      return KitStatusMark(
        state: mapped,
        paused: paused,
        label: label,
        showLabel: showLabel,
      );
    }

    final theme = Theme.of(context);
    final roles = AppTheme.rolesOf(theme);
    final tokens = KitTokens.of(context);
    final word = label ?? wordFor(context, state);
    final glyph = Icon(
      state == KitTaskState.needsYou
          ? AppIconography.question
          : AppIconography.stopCircle,
      size: tokens.iconSize(context, tokens.smallIconSize),
      color: state == KitTaskState.needsYou ? roles.attention : roles.text2,
    );
    final mark = SizedBox.square(
      dimension: KitTokens.markSlotSize,
      child: Center(child: glyph),
    );
    final content = showLabel
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(width: tokens.labelGap),
              Flexible(child: KitText(word, role: KitTextRole.secondary)),
            ],
          )
        : mark;
    return Semantics(label: word, excludeSemantics: true, child: content);
  }
}
