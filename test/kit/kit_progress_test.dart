// Behaviour tests for KitProgress v2 (docs/ux-system/kit-api/KitProgress.md):
// the eta words and rounding, the staged value and its asserts, the line
// join order, and the semantics value (K2 §2.8; STANDARDS.md TEST-15).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_harness.dart';

const _progressKey = ValueKey('kit-state-progress');

/// One instance for every pump in a test: two separately built
/// `AppTheme.dark()` calls do not compare equal, so a second pump with a
/// fresh one would animate `MaterialApp`'s own `AnimatedTheme` between
/// them — the harness moving, not the part under test.
final _theme = AppTheme.dark();

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

    testWidgets('an hour or more drops to whole hours', (tester) async {
      final context = await pumpKitHost(tester);
      const progress = KitProgress.known(
        0.1,
        eta: Duration(hours: 2, minutes: 20),
      );
      expect(progress.line(context), 'about 2 h left');
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
      final node = tester.getSemantics(find.byKey(_progressKey));
      // The line is the label: `SemanticsRole.progressBar` (Flutter's own
      // determinate-progress role) requires `value` to be a bare number or
      // an "NN%" string, so the sentence cannot live there — a screen
      // reader still hears both, one after the other. The percentage is
      // the framework's own default for a determinate bar.
      expect(node.label, '29 of 30 MB · about 50 s left');
      expect(node.value, '62');
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
      final node = tester.getSemantics(find.byKey(_progressKey));
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
      final node = tester.getSemantics(find.byKey(_progressKey));
      expect(node.label, 'Setup progress');
      semantics.dispose();
    });
  });

  group('KitProgressView motion (MOT-5, G8)', () {
    testWidgets(
      'an indeterminate bar settles after one pump() under reduced motion',
      (tester) async {
        await _pumpProgress(tester, const KitProgress.waiting(), reduced: true);
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
        final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(_progressKey),
        );
        expect(bar.value, isNotNull, reason: 'a still 30 % track segment');
      },
    );

    testWidgets('a determinate change applies immediately under reduced '
        'motion', (tester) async {
      await _pumpProgress(tester, const KitProgress.known(0.2), reduced: true);
      await tester.pump();
      await _pumpProgress(tester, const KitProgress.known(0.8), reduced: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(_progressKey),
      );
      expect(bar.value, 0.8);
    });
  });

  group('KitProgress existing API keeps compiling (KIT-43)', () {
    testWidgets('waiting renders an indeterminate bar with its caption', (
      tester,
    ) async {
      await _pumpProgress(
        tester,
        const KitProgress.waiting(caption: 'Connecting'),
      );
      await tester.pump();
      expect(find.text('Connecting'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(_progressKey),
      );
      expect(bar.value, isNull);
    });

    testWidgets('known renders a determinate bar with its caption', (
      tester,
    ) async {
      await _pumpProgress(tester, const KitProgress.known(0.4, caption: '40%'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('40%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(_progressKey),
      );
      expect(bar.value, 0.4);
    });
  });

  group('KitProgressView tone (LOOK-5 interim)', () {
    testWidgets('stopped (neutral) and failed use text3 and text1, not the '
        'danger role', (tester) async {
      final theme = AppTheme.dark();
      final roles = AppTheme.rolesOf(theme);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
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
      final stopped = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('stopped-bar')),
      );
      final failed = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('failed-bar')),
      );
      expect(stopped.color, roles.text3);
      expect(failed.color, roles.text1);
      expect(failed.color, isNot(roles.danger));
    });
  });
}
