import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// Where one step of a list stands. Paused is not a fifth value: see
/// [KitStatusMark.paused] (KitStatusMark.md "Why paused is a flag").
enum KitMarkState { waiting, working, done, failed }

/// A row's leading state mark (design standard §6: "a leading icon or status
/// dot"): a hollow ring waiting, a small spinner working (a still dot under
/// reduced motion), a check done, the neutral error glyph failed, or
/// [AppIconography.pause] when [paused]. Sized to sit in [KitRow]'s leading
/// slot. It is a state, not the screen's progress: the one bar (§4) says how
/// far the whole thing is.
///
/// Every mark carries its word (slice-P9.5: no state shown by colour alone):
/// in semantics always, and beside the mark as visible text when
/// [showLabel].
///
/// States: waiting, working, done, failed, paused (a waiting or working
/// modifier, never its own value — KitStatusMark.md).
class KitStatusMark extends StatelessWidget {
  const KitStatusMark({
    super.key,
    required this.state,
    this.paused = false,
    this.label,
    this.showLabel = false,
  });

  final KitMarkState state;

  /// A heat pause, or a force stop the app can resume. Only meaningful with
  /// [KitMarkState.waiting] or [KitMarkState.working]; asserted with
  /// [KitMarkState.done] or [KitMarkState.failed] — a finished step cannot
  /// be paused (STATE-11).
  final bool paused;

  /// The word this mark announces and, with [showLabel], shows. Null takes
  /// [wordFor].
  final String? label;

  /// Also draws the word as visible text after the mark, for a place that
  /// does not already show it (outside a [KitRow], whose own supporting
  /// line already carries the word).
  final bool showLabel;

  /// The default word for a state, the same word a [KitRow]'s supporting
  /// line starts with: Waiting · Working · Done · Failed · Paused.
  static String wordFor(
    BuildContext context,
    KitMarkState state, {
    bool paused = false,
  }) {
    assert(
      !paused || state == KitMarkState.waiting || state == KitMarkState.working,
      'KitStatusMark.wordFor: paused only applies to waiting or working',
    );
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (paused) return l10n.kitMarkPaused;
    return switch (state) {
      KitMarkState.waiting => l10n.kitMarkWaiting,
      KitMarkState.working => l10n.kitMarkWorking,
      KitMarkState.done => l10n.kitMarkDone,
      KitMarkState.failed => l10n.kitMarkFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    assert(
      !paused || state == KitMarkState.waiting || state == KitMarkState.working,
      'KitStatusMark: paused only applies to waiting or working — a '
      'finished step cannot be paused (G37, STATE-11)',
    );
    final theme = Theme.of(context);
    final roles = AppTheme.rolesOf(theme);
    final tokens = KitTokens.of(context);
    // The system setting and Animations: Off in Settings (KitEffects).
    final reduceMotion = KitMotion.reduced(context);
    final word = label ?? wordFor(context, state, paused: paused);
    double glyphSize() => tokens.iconSize(context, tokens.smallIconSize);
    final Widget glyph = paused
        ? Icon(AppIconography.pause, size: glyphSize(), color: roles.text2)
        : switch (state) {
            KitMarkState.done => Icon(
              AppIconography.check,
              size: glyphSize(),
              color: AppTheme.successOf(theme),
            ),
            KitMarkState.working =>
              reduceMotion
                  ? Icon(
                      AppIconography.statusDot,
                      size: KitTokens.markDotSize,
                      color: roles.accent,
                    )
                  : SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: roles.accent,
                      ),
                    ),
            KitMarkState.failed => Icon(
              AppIconography.error,
              size: glyphSize(),
              color: roles.text1,
            ),
            KitMarkState.waiting => Container(
              width: KitTokens.markRingSize,
              height: KitTokens.markRingSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: roles.text3,
                  width: KitTokens.hairlineWidth(context),
                ),
              ),
            ),
          };
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
