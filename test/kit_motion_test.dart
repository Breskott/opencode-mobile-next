// Gate G8 (docs/ux-system/kit-v2.md §7): every kit part is still under
// reduced motion — the system's "remove animations" AND Settings ›
// Appearance › Animations: Off (KitEffects.motion), which the kit reads
// only through KitMotion.reduced. A part that settles after one pump()
// leaves no ticker running.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

enum _Still { system, effectsOff }

Widget _app(Widget home, _Still still) => KitEffectsScope(
  effects: still == _Still.effectsOff
      ? const KitEffects(motion: KitMotionLevel.off)
      : KitEffects.defaults,
  child: MaterialApp(
    theme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: still == _Still.system),
      child: child!,
    ),
    home: Scaffold(body: Center(child: home)),
  ),
);

void main() {
  for (final still in _Still.values) {
    group('under ${still.name}', () {
      testWidgets('KitStatusMark working shows its still dot', (tester) async {
        await tester.pumpWidget(
          _app(const KitStatusMark(state: KitMarkState.working), still),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(AppIconography.statusDot), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('KitConfirmSheet opens and settles at once', (tester) async {
        await tester.pumpWidget(_app(const SizedBox(), still));
        final context = tester.element(find.byType(SizedBox).first);
        unawaited(
          showKitConfirm(
            context,
            title: 'Delete fox?',
            body: 'The conversation is removed from the server.',
            confirmLabel: 'Delete conversation',
            kind: KitConfirmKind.destructive,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Delete fox?'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('KitSheet opens and settles at once', (tester) async {
        await tester.pumpWidget(_app(const SizedBox(), still));
        final context = tester.element(find.byType(SizedBox).first);
        unawaited(
          showKitSheet<void>(
            context,
            title: 'Language',
            body: (_) => const Text('English'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('English'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      });
    });
  }

  testWidgets('with motion on, KitStatusMark working spins', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: KitStatusMark(state: KitMarkState.working)),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
