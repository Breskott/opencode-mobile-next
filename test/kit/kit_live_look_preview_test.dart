// KitLiveLookPreview: the chosen look in a short wide tile; it follows the
// Live background switch and Intensity, opens the picker on tap, cross-fades
// on a change, and rests when motion is reduced or the tile is scrolled away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _tile({
  String style = 'aurora',
  KitLiveIntensity intensity = KitLiveIntensity.normal,
  bool enabled = true,
  VoidCallback? onTap,
}) => KitLiveLookPreview(
  style: kitLiveStyleById(style),
  intensity: intensity,
  enabled: enabled,
  onTap: onTap ?? () {},
);

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: child),
  ),
);

bool _ticking(WidgetTester tester) =>
    (tester.state(find.byType(KitLiveBackground)) as dynamic).ticking as bool;

bool _tickersOn(BuildContext c) => TickerMode.valuesOf(c).enabled;

void main() {
  kitMotionStillTests(
    'KitLiveLookPreview',
    builds: {'on': () => _tile(), 'off': () => _tile(enabled: false)},
    changes: {
      'switched off': KitMotionChange(
        build: () => _tile(),
        act: (tester, stage) => stage.rebuild(_tile(enabled: false)),
        shows: 'Off',
      ),
    },
  );

  tearDown(() => KitMotion.loops = false);

  testWidgets('is a short wide tile', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_tile()));
    final size = tester.getSize(find.byType(KitLiveLookPreview));
    expect(size.height, inInclusiveRange(96, 120));
    expect(size.width, 412);
  });

  testWidgets('on: shows the look; off: flat ground with "Off"', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_tile()));
    expect(find.byType(KitLiveBackground), findsOneWidget);
    expect(find.text('Off'), findsNothing);
    await tester.pumpWidget(_app(_tile(enabled: false)));
    await tester.pumpAndSettle();
    expect(find.byType(KitLiveBackground), findsNothing);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('follows the look and the Intensity', (tester) async {
    await tester.pumpWidget(_app(_tile()));
    KitLiveBackground bg() =>
        tester.widget<KitLiveBackground>(find.byType(KitLiveBackground));
    expect(bg().style!.id, 'aurora');
    expect(bg().strength, KitLiveIntensity.normal.strength);
    await tester.pumpWidget(
      _app(_tile(style: 'topo', intensity: KitLiveIntensity.bold)),
    );
    await tester.pumpAndSettle();
    expect(bg().style!.id, 'topo');
    expect(bg().strength, KitLiveIntensity.bold.strength);
  });

  testWidgets('a change cross-fades: both looks are there mid-fade', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_tile()));
    await tester.pumpWidget(_app(_tile(style: 'topo')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(KitLiveBackground), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.byType(KitLiveBackground), findsOneWidget);
  });

  testWidgets('reduced motion: no fade and no ticker', (tester) async {
    KitMotion.loops = true;
    await tester.pumpWidget(_app(_tile(), reduce: true));
    await tester.pumpWidget(_app(_tile(style: 'topo'), reduce: true));
    await tester.pump();
    expect(find.byType(KitLiveBackground), findsOneWidget);
    expect(_ticking(tester), isFalse);
  });

  testWidgets('moves while visible', (tester) async {
    KitMotion.loops = true;
    await tester.pumpWidget(_app(_tile()));
    expect(_ticking(tester), isTrue);
    expect(_tickersOn(tester.element(find.byType(KitLiveBackground))), true);
  });

  testWidgets('rests while scrolled out of sight', (tester) async {
    KitMotion.loops = true;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ListView(
          controller: controller,
          children: [_tile(), const SizedBox(height: 3000)],
        ),
      ),
    );
    await tester.pump();
    expect(_tickersOn(tester.element(find.byType(KitLiveBackground))), isTrue);
    controller.jumpTo(300);
    await tester.pump();
    await tester.pump();
    expect(
      _tickersOn(
        tester.element(find.byType(KitLiveBackground, skipOffstage: false)),
      ),
      isFalse,
    );
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(_tickersOn(tester.element(find.byType(KitLiveBackground))), isTrue);
  });

  testWidgets('tap calls back', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(_tile(onTap: () => taps++)));
    await tester.tap(find.byType(KitLiveLookPreview));
    expect(taps, 1);
  });
}
