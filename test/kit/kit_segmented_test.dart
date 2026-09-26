// KitSegmented (lib/ui/kit/kit_segmented.dart), docs/ux-system/kit-api/
// KitSegmented.md. The stacked form (KIT-24) needs kit-KitChoiceList, which
// has not merged into this integration branch (see
// docs/qa/revamp-kit-KitSegmented/README.md); its tests are not here yet.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_segmented.dart';

import 'kit_motion_still.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

List<KitSegment<String>> _segments({
  bool cDisabled = false,
  int? countB,
  Key? keyA,
  Key? keyB,
  Key? keyC,
}) => [
  KitSegment(value: 'a', label: 'Alpha', key: keyA),
  KitSegment(value: 'b', label: 'Bravo', count: countB, key: keyB),
  KitSegment(
    value: 'c',
    label: 'Charlie',
    enabled: !cDisabled,
    disabledReason: cDisabled
        ? 'Chosen at install · reinstall to change'
        : null,
    key: keyC,
  ),
];

void main() {
  kitMotionStillTests(
    'KitSegmented',
    builds: {
      'default': () => KitSegmented<String>(
        segments: _segments(),
        selected: 'a',
        onChanged: (_) {},
        semanticsLabel: 'Choice',
      ),
      'with counts': () => KitSegmented<String>(
        segments: _segments(countB: 2),
        selected: 'b',
        onChanged: (_) {},
        semanticsLabel: 'Choice',
      ),
      'disabled': () => KitSegmented<String>(
        segments: _segments(),
        selected: 'a',
        onChanged: null,
        semanticsLabel: 'Choice',
        disabledReason: 'Set by your admin',
      ),
    },
    changes: {
      'a segment becomes disabled': KitMotionChange(
        build: () => KitSegmented<String>(
          segments: _segments(),
          selected: 'a',
          onChanged: (_) {},
          semanticsLabel: 'Choice',
        ),
        act: (tester, stage) => stage.rebuild(
          KitSegmented<String>(
            segments: _segments(cDisabled: true),
            selected: 'a',
            onChanged: (_) {},
            semanticsLabel: 'Choice',
          ),
        ),
        shows: 'Chosen at install · reinstall to change',
      ),
    },
  );

  group('construction (G37)', () {
    test('fewer than 2 segments asserts', () {
      expect(
        () => KitSegmented<String>(
          segments: [const KitSegment(value: 'a', label: 'Alpha')],
          selected: 'a',
          onChanged: (_) {},
          semanticsLabel: 'Choice',
        ),
        throwsAssertionError,
      );
    });

    test('more than 4 segments asserts', () {
      expect(
        () => KitSegmented<int>(
          segments: [
            for (var i = 0; i < 5; i++) KitSegment(value: i, label: '$i'),
          ],
          selected: 0,
          onChanged: (_) {},
          semanticsLabel: 'Choice',
        ),
        throwsAssertionError,
      );
    });

    test('a selected value not among the segments asserts', () {
      expect(
        () => KitSegmented<String>(
          segments: _segments(),
          selected: 'z',
          onChanged: (_) {},
          semanticsLabel: 'Choice',
        ),
        throwsAssertionError,
      );
    });

    test('a disabled segment without disabledReason asserts', () {
      expect(
        () => KitSegment<String>(value: 'c', label: 'Charlie', enabled: false),
        throwsAssertionError,
      );
    });

    test('onChanged null without a group disabledReason asserts', () {
      expect(
        () => KitSegmented<String>(
          segments: _segments(),
          selected: 'a',
          onChanged: null,
          semanticsLabel: 'Choice',
        ),
        throwsAssertionError,
      );
    });
  });

  group('tapping (KIT-24, STATE-9)', () {
    testWidgets('tapping another segment calls onChanged exactly once', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: calls.add,
            semanticsLabel: 'Choice',
          ),
        ),
      );
      await tester.tap(find.text('Bravo'));
      await tester.pump();
      expect(calls, ['b']);
    });

    testWidgets('tapping the selected segment does not call onChanged', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: calls.add,
            semanticsLabel: 'Choice',
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('tapping a disabled segment does not call onChanged', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(cDisabled: true),
            selected: 'a',
            onChanged: calls.add,
            semanticsLabel: 'Choice',
          ),
        ),
      );
      await tester.tap(find.text('Charlie'), warnIfMissed: false);
      await tester.pump();
      expect(calls, isEmpty);
    });
  });

  group('the check and semantics (A11Y-1)', () {
    testWidgets('the selected segment shows a check glyph', (tester) async {
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'b',
            onChanged: (_) {},
            semanticsLabel: 'Choice',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('kit-segmented-check')),
        findsNWidgets(3),
      );
      final icons = tester.widgetList<Icon>(
        find.byKey(const ValueKey('kit-segmented-check')),
      );
      final opacities = tester.widgetList<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('kit-segmented-check')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(icons.length, 3);
      expect(opacities.map((o) => o.opacity).toList(), [0, 1, 0]);
    });

    testWidgets('each segment carries button, selected and group semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'b',
            onChanged: (_) {},
            semanticsLabel: 'Choice',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Alpha')),
        matchesSemantics(
          label: 'Alpha',
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          isEnabled: true,
          hasTapAction: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Bravo')),
        matchesSemantics(
          label: 'Bravo',
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          isEnabled: true,
          hasTapAction: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
      expect(
        find.bySemanticsLabel('Choice'),
        findsOneWidget,
        reason: 'the group carries its semanticsLabel',
      );
      semantics.dispose();
    });

    testWidgets('the count is included in the segment semantic label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(countB: 2),
            selected: 'a',
            onChanged: (_) {},
            semanticsLabel: 'Choice',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Bravo')),
        matchesSemantics(
          label: 'Bravo, 2',
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          isEnabled: true,
          hasTapAction: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('disabled reasons (STATE-8)', () {
    testWidgets(
      "a disabled segment's reason is visible text under the control",
      (tester) async {
        await tester.pumpWidget(
          _host(
            KitSegmented<String>(
              segments: _segments(cDisabled: true),
              selected: 'a',
              onChanged: (_) {},
              semanticsLabel: 'Choice',
            ),
          ),
        );
        expect(
          find.text('Chosen at install · reinstall to change'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a disabled whole control shows its own reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: null,
            semanticsLabel: 'Choice',
            disabledReason: 'Set by your admin',
          ),
        ),
      );
      expect(find.text('Set by your admin'), findsOneWidget);
    });
  });

  group('keyboard (LAY-10, LAY-11)', () {
    testWidgets('Tab lands on the selected segment', (tester) async {
      final before = FocusNode(debugLabel: 'before');
      addTearDown(before.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              TextButton(
                focusNode: before,
                autofocus: true,
                onPressed: () {},
                child: const Text('Before'),
              ),
              KitSegmented<String>(
                segments: _segments(),
                selected: 'b',
                onChanged: (_) {},
                semanticsLabel: 'Choice',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, before);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'kit-segmented-1',
        reason: '"b" is segments[1], the selected one',
      );
    });

    testWidgets('Arrow Right moves focus without calling onChanged', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: calls.add,
            semanticsLabel: 'Choice',
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'kit-segmented-0');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'kit-segmented-1');
      expect(calls, isEmpty, reason: 'arrows move focus only');
    });

    testWidgets('Space calls onChanged for the focused segment', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: calls.add,
            semanticsLabel: 'Choice',
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(calls, ['b']);
    });

    testWidgets('in RTL, Arrow Left moves to the next segment', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: calls.add,
            semanticsLabel: 'Choice',
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'kit-segmented-1');
      expect(calls, isEmpty);
    });
  });

  group('reduced motion (G8)', () {
    testWidgets('one pump() settles the indicator and no ticker runs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: KitSegmented<String>(
              segments: _segments(),
              selected: 'a',
              onChanged: (_) {},
              semanticsLabel: 'Choice',
            ),
          ),
        ),
      );
      // A real tap also starts Material's own ink splash, which ignores
      // reduced motion and is not this part's concern (kit_motion_still.dart
      // documents the same trap); invoke the segment's callback directly.
      final inkWell = tester.widget<InkWell>(
        find.ancestor(of: find.text('Bravo'), matching: find.byType(InkWell)),
      );
      inkWell.onTap!();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('sizing (LAY-9)', () {
    testWidgets('every segment and the control are at least 48 dp', (
      tester,
    ) async {
      // A phone width (412 dp), not the tiny default test surface: the
      // 48 dp minimum is meaningful only once the rails are realistic.
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          KitSegmented<String>(
            segments: _segments(),
            selected: 'a',
            onChanged: (_) {},
            semanticsLabel: 'Choice',
          ),
        ),
      );
      final controlHeight = tester
          .getSize(find.byType(KitSegmented<String>))
          .height;
      expect(controlHeight, greaterThanOrEqualTo(48));
      for (final label in ['Alpha', 'Bravo', 'Charlie']) {
        final size = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });
  });
}
