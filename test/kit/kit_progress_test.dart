// Behaviour tests for KitProgress v2 (docs/ux-system/kit-api/KitProgress.md):
// the eta words and rounding, the staged value and its asserts, the line
// join order, what a screen reader hears, and what the bar paints (K2 §2.8;
// STANDARDS.md TEST-15). Nothing here reads the framework widget the bar is
// drawn with: colour and length come from the canvas, the value from the
// semantics tree.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_progress.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';

import 'kit_harness.dart';

const _progressKey = ValueKey('kit-state-progress');

/// One instance for every pump in a test: two separately built
/// `AppTheme.dark()` calls do not compare equal, so a second pump with a
/// fresh one would animate `MaterialApp`'s own `AnimatedTheme` between
/// them — the harness moving, not the part under test.
final _theme = AppTheme.dark();
final _roles = AppTheme.rolesOf(_theme);

/// Pumps [progress] alone on a screen, in [locale], disabling animations
/// when [reduced] (the system's "remove animations").
Future<void> _pumpProgress(
  WidgetTester tester,
  KitProgress progress, {
  Locale locale = const Locale('en'),
  bool reduced = false,
}) => tester.pumpWidget(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Scaffold(
      body: Center(child: KitProgressView(progress: progress)),
    ),
  ),
);

/// The semantics of the bar keyed [key] (the default key of a
/// [KitProgressView] bar unless the progress names its own).
SemanticsData _barSemantics(WidgetTester tester, [Key key = _progressKey]) =>
    tester.getSemantics(find.byKey(key)).getSemanticsData();

/// The semantics nodes a screen reader visits (not merged into a parent)
/// whose label or value says [text].
FinderBase<SemanticsNode> _nodesSaying(String text) =>
    find.semantics.byPredicate(
      (node) =>
          !node.isMergedIntoParent &&
          (node.label.contains(text) || node.value.contains(text)),
    );

/// The start-edge segment of a bar [width] wide filled up to [fraction], as
/// `LinearProgressIndicator` paints it with the kit's corners (LTR).
RRect _filled(double width, double fraction) => RRect.fromRectAndRadius(
  Rect.fromLTRB(0, 0, width * fraction, 4),
  const Radius.circular(2),
);

void main() {
  group('KitProgress.staged line', () {
    testWidgets('joins the step, the label and the eta with " · "', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      const progress = KitProgress.staged(
        step: 3,
        of: 5,
        label: 'Installing',
        eta: Duration(minutes: 2),
      );
      expect(
        progress.line(context),
        'Step 3 of 5 · Installing · about 2 min left',
      );
    });

    testWidgets('uses the caption ahead of the eta when both are given', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      const progress = KitProgress.staged(
        step: 2,
        of: 4,
        label: 'Downloading',
        stepValue: 0.4,
        caption: '12 of 30 MB',
      );
      expect(progress.line(context), 'Step 2 of 4 · Downloading · 12 of 30 MB');
    });

    testWidgets('uses the locale plural forms in Arabic', (tester) async {
      final context = await pumpKitHost(tester, locale: const Locale('ar'));
      const progress = KitProgress.staged(
        step: 3,
        of: 5,
        label: 'Installing',
        eta: Duration(minutes: 2),
      );
      expect(
        progress.line(context),
        'الخطوة 3 من 5 · Installing · بقيت دقيقتان تقريبًا',
      );
    });

    test('value is (step - 1 + stepValue) / of, or (step - 1) / of', () {
      const measured = KitProgress.staged(
        step: 3,
        of: 5,
        label: 'Installing',
        stepValue: 0.5,
      );
      expect(measured.value, closeTo(2.5 / 5, 1e-9));
      const unmeasured = KitProgress.staged(
        step: 3,
        of: 5,
        label: 'Installing',
      );
      expect(unmeasured.value, closeTo(2 / 5, 1e-9));
      expect(measured.isStaged, isTrue);
    });

    test('asserts step within 1..of and of at least 1', () {
      expect(
        () => KitProgress.staged(step: 6, of: 5, label: 'x'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => KitProgress.staged(step: 0, of: 5, label: 'x'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => KitProgress.staged(step: 1, of: 0, label: 'x'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts stepValue within 0..1', () {
      expect(
        () => KitProgress.staged(step: 5, of: 5, label: 'x', stepValue: 1.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => KitProgress.staged(step: 2, of: 4, label: 'x', stepValue: -0.1),
        throwsA(isA<AssertionError>()),
      );
      // Both ends are allowed, and step 5 of 5 fully measured is the whole
      // bar, never past it.
      expect(
        KitProgress.staged(step: 5, of: 5, label: 'x', stepValue: 1).value,
        1,
      );
      expect(
        KitProgress.staged(step: 2, of: 4, label: 'x', stepValue: 0).value,
        closeTo(1 / 4, 1e-9),
      );
    });
  });

  group('KitProgress.known value', () {
    test('asserts value within 0..1', () {
      expect(() => KitProgress.known(1.2), throwsA(isA<AssertionError>()));
      expect(() => KitProgress.known(-0.1), throwsA(isA<AssertionError>()));
      expect(KitProgress.known(0).value, 0);
      expect(KitProgress.known(1).value, 1);
    });
  });

  group('KitProgressView never goes backwards within a job (debug)', () {
    KitProgress downloading(double stepValue) => KitProgress.staged(
      step: 2,
      of: 4,
      label: 'Downloading',
      stepValue: stepValue,
    );

    testWidgets('the same step and label dropping its value asserts', (
      tester,
    ) async {
      await _pumpProgress(tester, downloading(0.6), reduced: true);
      expect(tester.takeException(), isNull);
      await _pumpProgress(tester, downloading(0.3), reduced: true);
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('moving forward, or holding, is fine', (tester) async {
      await _pumpProgress(tester, downloading(0.3), reduced: true);
      await _pumpProgress(tester, downloading(0.3), reduced: true);
      await _pumpProgress(tester, downloading(0.6), reduced: true);
      await _pumpProgress(
        tester,
        const KitProgress.staged(step: 3, of: 4, label: 'Installing'),
        reduced: true,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the step going back may lower the bar', (tester) async {
      await _pumpProgress(
        tester,
        const KitProgress.staged(step: 3, of: 4, label: 'Installing'),
        reduced: true,
      );
      await _pumpProgress(tester, downloading(0.2), reduced: true);
      expect(tester.takeException(), isNull);
      expect(_barSemantics(tester).value, '30'); // (2 - 1 + 0.2) / 4
    });

    testWidgets('a different job (another "of") starts over', (tester) async {
      await _pumpProgress(tester, downloading(0.8), reduced: true);
      await _pumpProgress(
        tester,
        const KitProgress.staged(
          step: 2,
          of: 3,
          label: 'Downloading',
          stepValue: 0.1,
        ),
        reduced: true,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('known has no job identity: a host may start a new job lower '
        '(SetupProgressView re-runs on the same bar)', (tester) async {
      await _pumpProgress(tester, const KitProgress.known(1), reduced: true);
      await _pumpProgress(tester, const KitProgress.known(0.2), reduced: true);
      expect(tester.takeException(), isNull);
      expect(_barSemantics(tester).value, '20');
    });
  });

  group('KitProgress.known line and eta rounding', () {
    testWidgets('joins the caption and the eta words', (tester) async {
      final context = await pumpKitHost(tester);
      const progress = KitProgress.known(
        0.62,
        caption: '29 of 30 MB',
        eta: Duration(seconds: 50),
      );
      expect(progress.line(context), '29 of 30 MB · about 50 s left');
    });

    testWidgets('an eta of zero or less is never shown', (tester) async {
      final context = await pumpKitHost(tester);
      const zero = KitProgress.known(
        0.62,
        caption: '29 of 30 MB',
        eta: Duration.zero,
      );
      expect(zero.line(context), '29 of 30 MB');
      const negative = KitProgress.known(
        0.62,
        caption: '29 of 30 MB',
        eta: Duration(seconds: -5),
      );
      expect(negative.line(context), '29 of 30 MB');
    });

    testWidgets('under a minute rounds up to the nearest 10 s', (tester) async {
      final context = await pumpKitHost(tester);
      const progress = KitProgress.known(0.1, eta: Duration(seconds: 41));
      expect(progress.line(context), 'about 50 s left');
    });

    testWidgets('under an hour rounds whole minutes up', (tester) async {
      final context = await pumpKitHost(tester);
      const progress = KitProgress.known(
        0.1,
        eta: Duration(minutes: 1, seconds: 1),
      );
      expect(progress.line(context), 'about 2 min left');
    });

    testWidgets('an hour or more rounds whole hours up, never down', (
      tester,
    ) async {
      final context = await pumpKitHost(tester);
      String words(Duration eta) =>
          KitProgress.known(0.1, eta: eta).line(context);
      // The boundary the words must not under-state: nearly 3 h is 3 h.
      expect(words(const Duration(hours: 2, minutes: 54)), 'about 3 h left');
      expect(words(const Duration(hours: 2, minutes: 20)), 'about 3 h left');
      expect(words(const Duration(hours: 2)), 'about 2 h left');
      expect(words(const Duration(hours: 1)), 'about 1 h left');
      expect(
        words(const Duration(minutes: 59, seconds: 59)),
        'about 60 min left',
      );
    });
  });

  group('KitProgressView semantics', () {
    testWidgets('carries the line and the percentage for known', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(
        tester,
        const KitProgress.known(
          0.62,
          caption: '29 of 30 MB',
          eta: Duration(seconds: 50),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final node = _barSemantics(tester);
      // The line is the label: `SemanticsRole.progressBar` (Flutter's own
      // determinate-progress role) requires `value` to be a bare number or
      // an "NN%" string, so the sentence cannot live there — a screen
      // reader still hears both, one after the other. The percentage is
      // the framework's own default for a determinate bar.
      expect(node.label, '29 of 30 MB · about 50 s left');
      expect(node.value, '62');
      semantics.dispose();
    });

    testWidgets('the line is read once: the bar and its words are one node', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(
        tester,
        const KitProgress.known(
          0.62,
          caption: '29 of 30 MB',
          semanticsLabel: 'Setup progress',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // Seen on screen, heard once — as the bar's label.
      expect(find.text('29 of 30 MB'), findsOneWidget);
      expect(_nodesSaying('29 of 30 MB'), findsOne);
      expect(_barSemantics(tester).label, 'Setup progress, 29 of 30 MB');

      await _pumpProgress(
        tester,
        const KitProgress.waiting(caption: 'Reaching the server'),
      );
      await tester.pump();
      expect(_nodesSaying('Reaching the server'), findsOne);
      expect(_barSemantics(tester).label, 'Reaching the server');

      await _pumpProgress(
        tester,
        const KitProgress.staged(
          step: 3,
          of: 5,
          label: 'Installing',
          eta: Duration(minutes: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_nodesSaying('Installing'), findsOne);
      semantics.dispose();
    });

    testWidgets('inside a KitStateView the bar stays its own node: the '
        'title is not folded into it, the line is not read twice', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: KitStateView(
              icon: Icons.download,
              title: 'Downloading the base',
              body: 'Keep the app open.',
              progress: KitProgress.known(0.62, caption: '29 of 30 MB'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = _barSemantics(tester);
      expect(node.label, '29 of 30 MB');
      expect(node.value, '62');
      expect(node.role, SemanticsRole.progressBar);
      expect(_nodesSaying('29 of 30 MB'), findsOne);
      semantics.dispose();
    });

    testWidgets('carries the line for staged; the framework still adds its '
        'own percentage to any determinate bar', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(
        tester,
        const KitProgress.staged(
          step: 3,
          of: 5,
          label: 'Installing',
          eta: Duration(minutes: 2),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final node = _barSemantics(tester);
      expect(node.label, 'Step 3 of 5 · Installing · about 2 min left');
      expect(node.value, '40'); // (3 - 1) / 5 = 0.4 -> 40, Flutter's default.
      semantics.dispose();
    });

    testWidgets('carries the semanticsLabel for waiting', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(
        tester,
        const KitProgress.waiting(semanticsLabel: 'Setup progress'),
      );
      await tester.pump();
      final node = _barSemantics(tester);
      expect(node.label, 'Setup progress');
      expect(node.role, SemanticsRole.loadingSpinner);
      expect(node.value, isEmpty);
      semantics.dispose();
    });

    testWidgets('waiting under reduced motion is still indeterminate: no '
        'value and no percentage, the same as with motion', (tester) async {
      final semantics = tester.ensureSemantics();
      const waiting = KitProgress.waiting(
        caption: 'Reaching the server',
        semanticsLabel: 'Connection progress',
      );
      await _pumpProgress(tester, waiting, reduced: true);
      await tester.pump();
      final still = _barSemantics(tester);
      expect(still.label, 'Connection progress, Reaching the server');
      expect(still.value, isEmpty);
      expect(still.role, isNot(SemanticsRole.progressBar));
      expect(still.role, SemanticsRole.loadingSpinner);
      expect(still.minValue, isNull);
      expect(still.maxValue, isNull);
      // Nothing anywhere on the screen claims a percentage for it.
      expect(_nodesSaying('30'), findsNothing);

      await _pumpProgress(tester, waiting);
      await tester.pump();
      final moving = _barSemantics(tester);
      expect(moving.label, still.label);
      expect(moving.value, still.value);
      expect(moving.role, still.role);
      semantics.dispose();
    });
  });

  group('KitProgressView motion (MOT-5, G8)', () {
    testWidgets('an indeterminate bar settles after one pump() under reduced '
        'motion, as a still 30 % segment at the start', (tester) async {
      await _pumpProgress(tester, const KitProgress.waiting(), reduced: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      final width = tester.getSize(find.byKey(_progressKey)).width;
      expect(
        find.byKey(_progressKey),
        paints
          ..rrect(color: _roles.surface3)
          ..rrect(color: _roles.accent, rrect: _filled(width, 0.3)),
      );
    });

    testWidgets('without reduced motion the waiting bar keeps moving', (
      tester,
    ) async {
      await _pumpProgress(tester, const KitProgress.waiting());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('a determinate change applies immediately under reduced '
        'motion', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(tester, const KitProgress.known(0.2), reduced: true);
      await tester.pump();
      await _pumpProgress(tester, const KitProgress.known(0.8), reduced: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_barSemantics(tester).value, '80');
      final width = tester.getSize(find.byKey(_progressKey)).width;
      expect(
        find.byKey(_progressKey),
        paints
          ..rrect(color: _roles.surface3)
          ..rrect(color: _roles.accent, rrect: _filled(width, 0.8)),
      );
      semantics.dispose();
    });

    testWidgets('a determinate change eases there with motion', (tester) async {
      await _pumpProgress(tester, const KitProgress.known(0.2));
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpProgress(tester, const KitProgress.known(0.8));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
      final width = tester.getSize(find.byKey(_progressKey)).width;
      expect(
        find.byKey(_progressKey),
        paints
          ..rrect(color: _roles.surface3)
          ..rrect(color: _roles.accent, rrect: _filled(width, 0.8)),
      );
    });
  });

  group('KitProgress existing API keeps compiling (KIT-43)', () {
    testWidgets('waiting renders an indeterminate bar with its caption', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(
        tester,
        const KitProgress.waiting(caption: 'Connecting'),
      );
      await tester.pump();
      expect(find.text('Connecting'), findsOneWidget);
      final node = _barSemantics(tester);
      expect(node.role, SemanticsRole.loadingSpinner);
      expect(node.value, isEmpty);
      semantics.dispose();
    });

    testWidgets('known renders a determinate bar with its caption', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(tester, const KitProgress.known(0.4, caption: '40%'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('40%'), findsOneWidget);
      final node = _barSemantics(tester);
      expect(node.role, SemanticsRole.progressBar);
      expect(node.value, '40');
      semantics.dispose();
    });
  });

  group('KitProgressView tone (LOOK-5 interim)', () {
    testWidgets('running is the accent; stopped (neutral) and failed paint '
        'text3 and text1, not the danger role', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                KitProgressView(
                  progress: KitProgress.known(
                    0.4,
                    key: ValueKey('running-bar'),
                  ),
                ),
                KitProgressView(
                  progress: KitProgress.known(
                    0.4,
                    key: ValueKey('stopped-bar'),
                    tone: AppStatusTone.neutral,
                  ),
                ),
                KitProgressView(
                  progress: KitProgress.known(
                    0.4,
                    key: ValueKey('failed-bar'),
                    tone: AppStatusTone.failure,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // The value segment (after the track) carries the tone.
      PaintPattern fill(Color color) => paints
        ..rrect(color: _roles.surface3)
        ..rrect(color: color);
      expect(find.byKey(const ValueKey('running-bar')), fill(_roles.accent));
      expect(find.byKey(const ValueKey('stopped-bar')), fill(_roles.text3));
      expect(find.byKey(const ValueKey('failed-bar')), fill(_roles.text1));
      expect(_roles.text1, isNot(_roles.danger));
    });
  });
}
