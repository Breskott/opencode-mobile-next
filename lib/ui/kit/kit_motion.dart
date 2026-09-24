import 'package:flutter/widgets.dart';

/// One set of timings and curves for every movement in the app (design
/// standard §10), so a sheet, a check that draws itself and an illustration
/// all move alike.
///
/// Two switches decide how much moves:
///
/// - the person's system setting (remove animations): nothing loops and
///   every illustration shows its finished drawing at once;
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

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Whether ambient loops may run at all; false under `flutter test`.
  static bool loops = true;

  /// The person asked for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Whether an ambient loop may run here.
  static bool loopsIn(BuildContext context) => loops && !reduced(context);
}
