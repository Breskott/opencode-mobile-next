import 'dart:ui';

import '../../../../l10n/app_localizations.dart';
import '../kit_live_style.dart';
import 'kit_live_toolkit.dart';

class KitLiveAurora extends KitLiveStyle {
  const KitLiveAurora();

  @override
  String get id => 'aurora';

  @override
  String label(AppLocalizations l10n) => l10n.liveStyleAurora;

  @override
  void paint(Canvas canvas, Size size, KitLiveFrame f) {
    final p = f.palette;
    // Calibrated so text keeps its contrast at the strongest moment
    // (test/kit/kit_live_background_test.dart).
    final a = strengthOf(f) * .95;
    final run = f.running;
    final t = f.t;
    final tt = t * .03 * (1 + run * .8);
    final teal = rgb(p.teal), blue = rgb(p.blue), glow = rgb(p.glow);
    paintField(canvas, size, f, 'f', 7, (u, v) {
      final n = fbm(u * 1.6 + tt, v * 1.6 - tt * .7);
      final m = fbm(u * 1.1 - tt * .5 + 3, v * 1.3 + tt * .4 + 7);
      final c = mixRgb(mixRgb(teal, blue, m), glow, run * .7);
      return packArgb(c[0], c[1], c[2], smooth(.38, .82, n) * .16 * a);
    }, every: .04);
  }
}
