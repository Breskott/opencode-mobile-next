import 'dart:ui';

import '../../../l10n/app_localizations.dart';

/// One look of the live background (Settings › Appearance › Live background).
///
/// A style only paints one frame over the flat ground; the machinery around
/// it (the page ground, the frame clock capped at 24 fps, pausing when the
/// app is not in front or motion is reduced, the brighten while a reply
/// runs) is [KitLiveBackground]'s and is the same for every style. Rules:
///
/// - no blur of what is under it, nothing see-through that a card relies on
///   (no glass); cards, rows and sheets stay solid on top;
/// - at [KitLiveFrame.strength] 1 the look stays within the alpha ceilings
///   ([KitLivePalette.ceiling]: 6 % dark, 4.5 % light) so text keeps its
///   contrast (test/kit_live_background_test.dart checks every style);
/// - never red; amber is not used;
/// - a style that keeps state (particles, a trail) keeps it in
///   [KitLiveFrame.memory], never in fields, so one const instance can serve
///   many tiles at once.
abstract class KitLiveStyle {
  const KitLiveStyle();

  /// Stable storage key (`oc.effectsLiveStyle`); never renamed.
  String get id;

  /// The name shown in the picker.
  String label(AppLocalizations l10n);

  /// Paints one frame over the ground, which is already drawn.
  void paint(Canvas canvas, Size size, KitLiveFrame frame);

  /// How far past [KitLivePalette.ceiling] this look may go. Sparse looks
  /// (thin lines, glyphs, a few dots covering little area) override it, up
  /// to 2.0, so they can be seen; the contrast test paints each look at
  /// strength `ceilingFactor` and still demands AA text contrast.
  double get ceilingFactor => 1.0;

  /// Loads whatever the style needs (a [FragmentProgram]); called once before
  /// the first frame. Until it completes the page shows the flat ground.
  Future<void> warmUp() async {}
}

/// What a style is given for one frame.
class KitLiveFrame {
  const KitLiveFrame({
    required this.t,
    required this.running,
    required this.strength,
    required this.palette,
    required this.memory,
  });

  /// Seconds on the shared clock. Styles loop on their own period; the clock
  /// never resets, so a page change carries on where the last one was.
  final double t;

  /// 0 idle .. 1 a reply is running, eased (about 600 ms either way).
  final double running;

  /// 1 = the strength that ships. Previews may differ; styles scale their
  /// alpha by it and never exceed [KitLivePalette.ceiling] at 1.
  final double strength;

  final KitLivePalette palette;
  final KitLiveMemory memory;
}

/// The theme's colours a style may use.
class KitLivePalette {
  const KitLivePalette({
    required this.ground,
    required this.ink,
    required this.green,
    required this.teal,
    required this.blue,
    required this.glow,
    required this.dark,
  });

  final Color ground;

  /// Primary text colour.
  final Color ink;

  /// The theme's accent: the composer glow's hue.
  final Color green;
  final Color teal;
  final Color blue;

  /// The running glow's colour (the composer's).
  final Color glow;
  final bool dark;

  /// The most any single layer may be opaque at strength 1.
  double get ceiling => dark ? 0.06 : 0.045;
}

/// Per-style mutable state for one painted surface (particles, trails).
class KitLiveMemory {
  final Map<String, Object?> _slots = {};

  /// The value kept under [key], made by [make] the first time.
  T of<T>(String key, T Function() make) =>
      (_slots.putIfAbsent(key, make)) as T;

  void clear() => _slots.clear();
}
