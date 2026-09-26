import 'package:flutter/widgets.dart';

import 'kit_effects.dart';

/// One set of timings and curves for every movement in the app (design
/// standard §10), so a sheet, a check that draws itself and an illustration
/// all move alike.
///
/// Three switches decide how much moves:
///
/// - the person's system setting (remove animations) or Animations: Off in
///   Settings › Appearance ([KitEffects.motion]): nothing loops and every
///   illustration shows its finished drawing at once;
/// - Animations: Calm: drawings still draw themselves in, nothing loops;
/// - [loops]: ambient loops (a waiting scene that breathes) run in the app
///   and are off under `flutter test` (test/flutter_test_config.dart), so a
///   screen still settles for `pumpAndSettle`. Entrances are finite and run
///   in both.
abstract final class KitMotion {
  /// A control answering a touch: a chip, a toggle, a row's state.
  static const quick = Duration(milliseconds: 150);

  /// A part appearing or changing size: a notice, a section unfolding.
  static const standard = Duration(milliseconds: 250);

  /// An illustration drawing itself in. Long enough to be seen, short
  /// enough that nobody waits for it.
  static const entrance = Duration(milliseconds: 900);

  /// A one-time moment worth marking: setup finished, a task merged.
  static const celebration = Duration(milliseconds: 1400);

  /// One breath of an ambient loop on a waiting screen.
  static const breath = Duration(seconds: 4);

  /// A wait turns into an explanation after this (KitSince.md, KitField.md,
  /// KitStateView.md; MOT-1, kit-v2 G9 "escalate after 8 s").
  static const escalateAfter = Duration(seconds: 8);

  /// How long an undo stays offered (KitReceipt.md, KitUndo.md: 8 s).
  static const undoWindow = Duration(seconds: 8);

  /// How long a copy control shows its check (KitIconButton.md,
  /// KitAction.md). No spec states a value; 2 s is this seam's choice.
  static const copiedHold = Duration(seconds: 2);

  /// A log panel's default poll interval (KitLogPanel.md).
  static const logPoll = Duration(seconds: 2);

  /// Typing counts as settled after this: the search debounce and the
  /// result-count announcement (KitSearchField.md, about 300 ms).
  static const typingSettle = Duration(milliseconds: 300);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Whether ambient loops may run at all; false under `flutter test`.
  static bool loops = true;

  /// The person asked for less motion: the system setting, or Animations:
  /// Off in Settings › Appearance.
  static bool reduced(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      KitEffects.of(context).motion == KitMotionLevel.off;

  /// Whether an ambient loop may run here (Animations: Full only).
  static bool loopsIn(BuildContext context) =>
      loops &&
      !reduced(context) &&
      KitEffects.of(context).motion == KitMotionLevel.full;
}
