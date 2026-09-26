// KitMotionParts (docs/ux-system/kit-api/KitMotionParts.md): KitSwap,
// KitSpin, KitAnimatedBox, KitDim, KitAnimatedValue. Every part shows its
// final state on the first pump(), is instant under reduced motion, and
// settles for pumpAndSettle (nothing loops).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/effects.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_motion_parts.dart';

/// One theme instance for every pump: a fresh `AppTheme.dark()` on a rebuild
/// would not compare equal and `MaterialApp`'s `AnimatedTheme` would animate
/// between the two (the harness moving, not the part under test).
final _theme = AppTheme.dark();

/// A widget with no paragraph in its render subtree, standing in for an
/// image or a drawing (KitDim dims those, never an [Icon]: an icon glyph
/// paints through a `RenderParagraph` like any other text, and dimming a
/// glyph is kit-KitIcon's job — see the Replaces table).
const Widget _mark = SizedBox.square(
  dimension: 24,
  child: ColoredBox(color: Color(0xFF3366CC)),
);

/// An app around [child] with the person's effects choices and reduced
/// motion applied the way the real app does (`KitEffectsScope` plus
/// `MediaQuery.disableAnimations`).
Widget _harness(
  Widget child, {
  KitMotionLevel motion = KitMotionLevel.full,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
}) => KitEffectsScope(
  effects: KitEffects(motion: motion),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: widget!,
    ),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('first build is final (no mount animation)', () {
    testWidgets('KitSwap', (tester) async {
      await tester.pumpWidget(
        _harness(const KitSwap(child: Text('one', key: ValueKey('one')))),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        1,
      );
    });

    testWidgets('KitSpin', (tester) async {
      await tester.pumpWidget(
        _harness(const KitSpin(turns: .25, child: Icon(Icons.star))),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        .25,
      );
    });

    testWidgets('KitSpin.chevron', (tester) async {
      await tester.pumpWidget(_harness(const KitSpin.chevron(expanded: true)));
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        .5,
      );
    });

    testWidgets('KitAnimatedBox', (tester) async {
      await tester.pumpWidget(
        _harness(
          const KitAnimatedBox(
            level: KitSurfaceLevel.surface2,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('KitDim', (tester) async {
      await tester.pumpWidget(_harness(const KitDim(child: _mark)));
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        KitTokens.disabledAlpha,
      );
    });

    testWidgets('KitAnimatedValue', (tester) async {
      double? seen;
      await tester.pumpWidget(
        _harness(
          KitAnimatedValue(
            value: .3,
            builder: (context, value) {
              seen = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(seen, .3);
    });
  });

  group('reduced motion settles after one pump() (G8, MOT-7)', () {
    Future<void> expectSettles(
      WidgetTester tester, {
      required Widget Function() before,
      required Widget Function() after,
      required bool disableAnimations,
      required KitMotionLevel motion,
    }) async {
      await tester.pumpWidget(
        _harness(
          before(),
          disableAnimations: disableAnimations,
          motion: motion,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _harness(after(), disableAnimations: disableAnimations, motion: motion),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    }

    for (final (label, disableAnimations, motion) in [
      ('system reduced motion', true, KitMotionLevel.full),
      ('Effects Animations: Off', false, KitMotionLevel.off),
    ]) {
      testWidgets('KitSwap ($label)', (tester) async {
        await expectSettles(
          tester,
          before: () => const KitSwap(child: Text('a', key: ValueKey('a'))),
          after: () => const KitSwap(child: Text('b', key: ValueKey('b'))),
          disableAnimations: disableAnimations,
          motion: motion,
        );
        expect(find.text('a'), findsNothing);
        expect(find.text('b'), findsOneWidget);
      });

      testWidgets('KitSpin ($label)', (tester) async {
        await expectSettles(
          tester,
          before: () => const KitSpin(turns: 0, child: Icon(Icons.star)),
          after: () => const KitSpin(turns: .5, child: Icon(Icons.star)),
          disableAnimations: disableAnimations,
          motion: motion,
        );
        expect(
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
          .5,
        );
      });

      testWidgets('KitSpin.chevron ($label)', (tester) async {
        await expectSettles(
          tester,
          before: () => const KitSpin.chevron(expanded: false),
          after: () => const KitSpin.chevron(expanded: true),
          disableAnimations: disableAnimations,
          motion: motion,
        );
        expect(
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
          .5,
        );
      });

      testWidgets('KitAnimatedBox ($label)', (tester) async {
        await expectSettles(
          tester,
          before: () => const KitAnimatedBox(
            level: KitSurfaceLevel.surface1,
            child: SizedBox(width: 40, height: 40),
          ),
          after: () => const KitAnimatedBox(
            level: KitSurfaceLevel.surface3,
            child: SizedBox(width: 40, height: 40),
          ),
          disableAnimations: disableAnimations,
          motion: motion,
        );
      });

      testWidgets('KitDim ($label)', (tester) async {
        await expectSettles(
          tester,
          before: () => const KitDim(dimmed: false, child: _mark),
          after: () => const KitDim(child: _mark),
          disableAnimations: disableAnimations,
          motion: motion,
        );
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          KitTokens.disabledAlpha,
        );
      });

      testWidgets('KitAnimatedValue ($label)', (tester) async {
        double? seen;
        Widget build(double value) => KitAnimatedValue(
          value: value,
          builder: (context, v) {
            seen = v;
            return const SizedBox.shrink();
          },
        );
        await expectSettles(
          tester,
          before: () => build(.2),
          after: () => build(.8),
          disableAnimations: disableAnimations,
          motion: motion,
        );
        expect(seen, .8);
      });
    }
  });

  group('KitSwap', () {
    testWidgets(
      'a keyed change cross-fades over exactly KitMotion.quick, with no '
      'scale or size animation, and the outgoing child ignores taps and '
      'has no semantics',
      (tester) async {
        final taps = <String>[];
        Widget build(String key) => KitSwap(
          child: Semantics(
            key: ValueKey(key),
            label: key,
            button: true,
            child: GestureDetector(
              onTap: () => taps.add(key),
              child: SizedBox(
                key: ValueKey('box-$key'),
                width: 300,
                height: 80,
              ),
            ),
          ),
        );
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_harness(build('a')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_harness(build('b')));
        // A little real time, not zero: right at t=0 the incoming fade's
        // opacity is 0 and FadeTransition excludes a fully transparent
        // child from semantics, which would falsely look like exclusion.
        await tester.pump(const Duration(milliseconds: 30));

        expect(tester.hasRunningAnimations, isTrue);
        // Scoped to KitSwap's own subtree: the app shell's page-transition
        // machinery (Android's default zoom route transition) legitimately
        // uses ScaleTransition/Transform elsewhere in the tree.
        final swap = find.byType(KitSwap);
        expect(
          find.descendant(of: swap, matching: find.byType(ScaleTransition)),
          findsNothing,
        );
        expect(
          find.descendant(of: swap, matching: find.byType(SizeTransition)),
          findsNothing,
        );
        expect(
          find.descendant(of: swap, matching: find.byType(Transform)),
          findsNothing,
        );

        // The outgoing ('a') is excluded from semantics while it leaves.
        expect(find.bySemanticsLabel('a'), findsNothing);
        expect(find.bySemanticsLabel('b'), findsOneWidget);

        // The outgoing ignores taps: tapping its box does not call back.
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('box-a'))),
        );
        expect(taps, isEmpty);

        // Settles after exactly KitMotion.quick (30 ms already elapsed).
        await tester.pump(
          KitMotion.quick - const Duration(milliseconds: 1 + 30),
        );
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pump(const Duration(milliseconds: 2));
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.byKey(const ValueKey('a')), findsNothing);

        semantics.dispose();
      },
    );

    testWidgets('pumpAndSettle completes (nothing loops)', (tester) async {
      await tester.pumpWidget(_harness(const KitSwap(child: Text('x'))));
      await tester.pumpWidget(
        _harness(const KitSwap(child: Text('y', key: ValueKey('y')))),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('KitSpin', () {
    testWidgets('KitSpin(turns: .5) animates', (tester) async {
      await tester.pumpWidget(
        _harness(const KitSpin(turns: 0, child: Icon(Icons.star))),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _harness(const KitSpin(turns: .5, child: Icon(Icons.star))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // AnimatedRotation.turns is the target, not the interpolated value
      // (that lives inside its own private state), so the running ticker is
      // the evidence that this is easing rather than snapping (checked
      // instant on mount and under reduced motion elsewhere).
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        .5,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('KitSpin.fixed(quarterTurns: 1) swaps width and height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const KitSpin.fixed(
            quarterTurns: 1,
            child: SizedBox(width: 100, height: 40),
          ),
        ),
      );
      final size = tester.getSize(find.byType(RotatedBox));
      expect(size.width, 40);
      expect(size.height, 100);
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final direction in TextDirection.values) {
      testWidgets(
        'KitSpin.chevron(expanded: true) points up under ${direction.name} '
        'and turns over KitMotion.standard with emphasized',
        (tester) async {
          await tester.pumpWidget(
            _harness(
              locale: direction == TextDirection.rtl
                  ? const Locale('ar')
                  : const Locale('en'),
              const KitSpin.chevron(expanded: false),
            ),
          );
          await tester.pumpAndSettle();
          final rotation = tester.widget<AnimatedRotation>(
            find.byType(AnimatedRotation),
          );
          expect(rotation.duration, KitMotion.standard);
          expect(rotation.curve, KitMotion.emphasized);
          expect(rotation.turns, 0);

          await tester.pumpWidget(
            _harness(
              locale: direction == TextDirection.rtl
                  ? const Locale('ar')
                  : const Locale('en'),
              const KitSpin.chevron(expanded: true),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<AnimatedRotation>(find.byType(AnimatedRotation))
                .turns,
            .5,
          );
        },
      );
    }

    testWidgets('pumpAndSettle completes (nothing loops)', (tester) async {
      await tester.pumpWidget(
        _harness(const KitSpin(turns: 0, child: Icon(Icons.star))),
      );
      await tester.pumpWidget(
        _harness(const KitSpin(turns: .75, child: Icon(Icons.star))),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('KitAnimatedBox', () {
    testWidgets(
      'a level change animates only the paint (RenderBox size is constant)',
      (tester) async {
        Widget build(KitSurfaceLevel level) => KitAnimatedBox(
          level: level,
          child: const SizedBox(width: 120, height: 60),
        );
        await tester.pumpWidget(_harness(build(KitSurfaceLevel.surface1)));
        await tester.pumpAndSettle();
        final before = tester.getSize(find.byType(KitAnimatedBox));

        await tester.pumpWidget(_harness(build(KitSurfaceLevel.surface3)));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.hasRunningAnimations, isTrue);
        expect(tester.getSize(find.byType(KitAnimatedBox)), before);

        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(KitAnimatedBox)), before);
      },
    );

    testWidgets('a child size change snaps in one frame', (tester) async {
      await tester.pumpWidget(
        _harness(const KitAnimatedBox(child: SizedBox(width: 80, height: 40))),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _harness(const KitAnimatedBox(child: SizedBox(width: 160, height: 90))),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(KitAnimatedBox)), const Size(160, 90));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('outlined is 1 / dpr thick', (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _harness(
          const KitAnimatedBox(
            outlined: true,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final shape = (container.decoration! as ShapeDecoration).shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape as RoundedRectangleBorder).side.width, .5);
    });

    testWidgets('pumpAndSettle completes (nothing loops)', (tester) async {
      await tester.pumpWidget(
        _harness(
          const KitAnimatedBox(
            level: KitSurfaceLevel.surface1,
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      );
      await tester.pumpWidget(
        _harness(
          const KitAnimatedBox(
            level: KitSurfaceLevel.surface3,
            outlined: true,
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('KitDim', () {
    testWidgets('over a KitText child fails its debug assert', (tester) async {
      await tester.pumpWidget(
        _harness(
          const KitDim(child: KitText('secret', role: KitTextRole.body)),
        ),
      );
      final error = tester.takeException();
      expect(
        error,
        isNotNull,
        reason: 'KitDim over text must assert (LOOK-14)',
      );
    });

    testWidgets('over an image it paints at disabledAlpha or staleAlpha', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const KitDim(child: _mark)));
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        KitTokens.disabledAlpha,
      );

      await tester.pumpWidget(
        _harness(const KitDim(level: KitDimLevel.stale, child: _mark)),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        KitTokens.staleAlpha,
      );

      await tester.pumpWidget(
        _harness(const KitDim(dimmed: false, child: _mark)),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
    });

    testWidgets('pumpAndSettle completes (nothing loops)', (tester) async {
      await tester.pumpWidget(
        _harness(const KitDim(dimmed: false, child: _mark)),
      );
      await tester.pumpWidget(_harness(const KitDim(child: _mark)));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('KitAnimatedValue', () {
    testWidgets('0.2 to 0.8 eases over standard', (tester) async {
      double? seen;
      Widget build(double value) => KitAnimatedValue(
        value: value,
        builder: (context, v) {
          seen = v;
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(_harness(build(.2)));
      await tester.pumpAndSettle();
      expect(seen, .2);

      await tester.pumpWidget(_harness(build(.8)));
      await tester.pump(const Duration(milliseconds: 125));
      expect(tester.hasRunningAnimations, isTrue);
      expect(seen, greaterThan(.2));
      expect(seen, lessThan(.8));

      await tester.pumpAndSettle();
      expect(seen, .8);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('jump: true shows the new value at once', (tester) async {
      double? seen;
      Widget build(double value, {bool jump = false}) => KitAnimatedValue(
        value: value,
        jump: jump,
        builder: (context, v) {
          seen = v;
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(_harness(build(.2)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_harness(build(.8, jump: true)));
      await tester.pump();
      expect(seen, .8);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('pumpAndSettle completes (nothing loops)', (tester) async {
      Widget build(double value) => KitAnimatedValue(
        value: value,
        builder: (context, v) => const SizedBox.shrink(),
      );
      await tester.pumpWidget(_harness(build(0)));
      await tester.pumpWidget(_harness(build(1)));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  test(
    'no Duration( literal and no Curves. in kit_motion_parts.dart (MOT-1)',
    () {
      final source = File(
        'lib/ui/kit/motion/kit_motion_parts.dart',
      ).readAsStringSync();
      expect(source.contains('Duration('), isFalse);
      expect(source.contains('Curves.'), isFalse);
    },
  );
}
