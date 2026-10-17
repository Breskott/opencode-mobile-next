// KitLiveBackground: the calm drifting colour on every page's ground.
// It must stop moving when the person turned it off, asked for less motion,
// or the app is not in front; it brightens while a reply runs; and it never
// costs text its contrast.
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _app({
  KitEffects effects = const KitEffects(),
  bool reduce = false,
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: KitEffectsScope(
      effects: effects,
      child: const KitLiveBackground(child: SizedBox.expand()),
    ),
  ),
);

bool _ticking(WidgetTester tester) =>
    (tester.state(find.byType(KitLiveBackground)) as dynamic).ticking as bool;

void main() {
  kitMotionStillTests(
    'KitLiveBackground',
    builds: {
      'default': () => const KitLiveBackground(child: Text('Page')),
      'reply running': () => KitLiveBackground(
        replyRunning: ValueNotifier(true),
        child: const Text('Page'),
      ),
    },
    changes: {
      'the look changes': KitMotionChange(
        build: () => KitLiveBackground(
          style: kitLiveStyleById('aurora'),
          child: const Text('Page'),
        ),
        act: (tester, stage) => stage.rebuild(
          KitLiveBackground(
            style: kitLiveStyleById('mesh'),
            child: const Text('Page'),
          ),
        ),
        shows: 'Page',
      ),
    },
  );

  setUp(() => KitMotion.loops = true);
  tearDown(() {
    KitMotion.loops = false;
    KitLiveBackground.paintWithoutLoops = false;
    KitLiveBackground.running.value = 0;
  });

  testWidgets('moves by default', (tester) async {
    await tester.pumpWidget(_app());
    expect(_ticking(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the page above keeps its state when the look finishes loading', (
    tester,
  ) async {
    var inits = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: KitLiveBackground(child: _Probe(onInit: () => inits++)),
      ),
    );
    expect(inits, 1);
    // The look's warm-up finishes later; the page is not rebuilt from scratch.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(
        of: find.byType(KitLiveBackground),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
      reason: 'the look is painted by now',
    );
    expect(inits, 1);
  });

  testWidgets('Live background off: no ticker, no fields', (tester) async {
    await tester.pumpWidget(
      _app(effects: const KitEffects(liveBackground: false)),
    );
    expect(_ticking(tester), isFalse);
    expect(
      find.descendant(
        of: find.byType(KitLiveBackground),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('reduced motion: no ticker', (tester) async {
    await tester.pumpWidget(_app(reduce: true));
    expect(_ticking(tester), isFalse);
  });

  testWidgets('Animations: Calm: no ticker', (tester) async {
    await tester.pumpWidget(
      _app(effects: const KitEffects(motion: KitMotionLevel.calm)),
    );
    expect(_ticking(tester), isFalse);
  });

  testWidgets('app paused stops the ticker, resumed starts it', (tester) async {
    await tester.pumpWidget(_app());
    expect(_ticking(tester), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_ticking(tester), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_ticking(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('under flutter test (loops off) only the flat ground paints', (
    tester,
  ) async {
    KitMotion.loops = false;
    await tester.pumpWidget(_app());
    expect(_ticking(tester), isFalse);
    expect(
      find.descendant(
        of: find.byType(KitLiveBackground),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('a running reply brightens the fields and settling dims them', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final lift = _liftOf(tester);
    expect(lift.value, 0);
    KitLiveBackground.running.value = 1;
    await tester.pump();
    await tester.pump(KitLiveBackground.brighten);
    expect(lift.value, 1);
    KitLiveBackground.running.value = 0;
    await tester.pump();
    await tester.pump(KitLiveBackground.brighten);
    expect(lift.value, 0);
    await tester.pumpWidget(const SizedBox());
  });

  test('the default look is aurora, an unknown id falls back to it', () {
    expect(kitLiveDefaultStyleId, 'aurora');
    expect(kitLiveStyleById(null).id, 'aurora');
    expect(kitLiveStyleById('nope').id, 'aurora');
    expect(kitLiveStyles.map((s) => s.id).toSet().length, kitLiveStyles.length);
  });

  testWidgets('every look keeps text readable at its strongest', (
    tester,
  ) async {
    final fails = <String>[];
    for (final b in Brightness.values) {
      final theme = b == Brightness.dark ? AppTheme.dark() : AppTheme.light();
      final tokens = KitTokens.fallback(theme);
      final roles = tokens.roles;
      final palette = KitLiveBackground.paletteOf(tokens);
      for (final style in kitLiveStyles) {
        await tester.runAsync(style.warmUp);
        final memory = KitLiveMemory();
        // The lightest and darkest pixel over a few moments of the loop,
        // idle and with a reply running.
        for (final running in [0.0, 1.0]) {
          for (final t in [1.0, 9.0, 21.0, 40.0]) {
            final recorder = PictureRecorder();
            final canvas = Canvas(recorder);
            const size = Size(120, 260);
            canvas.drawRect(Offset.zero & size, Paint()..color = roles.ground);
            style.paint(
              canvas,
              size,
              KitLiveFrame(
                t: t,
                running: running,
                strength: style.ceilingFactor,
                palette: palette,
                memory: memory,
              ),
            );
            final pic = recorder.endRecording();
            final bytes = await tester.runAsync(() async {
              final img = await pic.toImage(120, 260);
              final data = await img.toByteData();
              img.dispose();
              return data!;
            });
            for (final text in [roles.text2, roles.text3]) {
              final before = contrastRatio(text, roles.ground);
              var worst = 100.0;
              // Text is read against the look averaged over a few pixels:
              // one thin dot or line under a letter does not change how the
              // letter reads, so the grid is checked in 4x4 blocks.
              for (var by = 0; by < 260; by += 4) {
                for (var bx = 0; bx < 120; bx += 4) {
                  var r = 0, g = 0, bl = 0;
                  for (var y = by; y < by + 4; y++) {
                    for (var x = bx; x < bx + 4; x++) {
                      final i = (y * 120 + x) * 4;
                      r += bytes!.getUint8(i);
                      g += bytes.getUint8(i + 1);
                      bl += bytes.getUint8(i + 2);
                    }
                  }
                  final px = Color.fromARGB(255, r ~/ 16, g ~/ 16, bl ~/ 16);
                  final c = contrastRatio(text, px);
                  if (c < worst) worst = c;
                }
              }
              if (worst < (before >= 4.5 ? 4.5 : before - .2)) {
                fails.add(
                  '${style.id} ${b.name} t=$t run=$running text '
                  '${before.toStringAsFixed(2)} -> ${worst.toStringAsFixed(2)}',
                );
              }
            }
          }
        }
      }
    }
    expect(fails, isEmpty);
  });
}

_Lift _liftOf(WidgetTester tester) => _Lift(tester);

class _Lift {
  _Lift(this.tester);
  final WidgetTester tester;
  double get value =>
      (tester.state(find.byType(KitLiveBackground)) as dynamic).lift as double;
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit});
  final VoidCallback onInit;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
