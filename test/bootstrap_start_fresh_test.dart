import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/diagnostics/app_diagnostics.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Start fresh asks first and cancellation leaves sign-ins alone', (
    tester,
  ) async {
    final diagnostics = AppDiagnosticsController();
    addTearDown(diagnostics.dispose);
    var resets = 0;
    await tester.pumpWidget(
      AppBootstrapGate(
        diagnostics: diagnostics,
        loader: () async => throw StateError('storage unavailable'),
        resetSavedSignIns: () async => resets++,
      ),
    );
    await _settle(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('start-fresh-app-bootstrap')),
    );
    await tester.tap(find.byKey(const ValueKey('start-fresh-app-bootstrap')));
    await _settle(tester);
    expect(find.text('Remove saved sign-ins?'), findsOneWidget);
    expect(
      find.textContaining(
        'Your saved servers, queued prompts and drafts are kept.',
      ),
      findsOneWidget,
    );
    expect(resets, 0);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(resets, 0);
    expect(find.text("Can't read saved servers"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('confirmed reset drains old loaders and ignores their results', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    final diagnostics = AppDiagnosticsController();
    addTearDown(diagnostics.dispose);
    final pending = Completer<AppBootstrap>();
    var attempts = 0;
    var resets = 0;
    await tester.pumpWidget(
      AppBootstrapGate(
        diagnostics: diagnostics,
        loader: () {
          attempts++;
          if (attempts == 2) return pending.future;
          return Future<AppBootstrap>.error(StateError('storage unavailable'));
        },
        resetSavedSignIns: () async => resets++,
      ),
    );
    await _settle(tester);
    final retry = tester
        .widget<KitStateView>(
          find.byKey(const ValueKey('app-bootstrap-failed')),
        )
        .retry!;
    await tester.ensureVisible(
      find.byKey(const ValueKey('start-fresh-app-bootstrap')),
    );
    await tester.tap(find.byKey(const ValueKey('start-fresh-app-bootstrap')));
    await _settle(tester);
    retry.onPressed!();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-start-fresh')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('app-bootstrap-resetting')),
      findsOneWidget,
    );
    expect(resets, 0);
    expect(attempts, 2);
    pending.complete(AppBootstrap(store));
    await _settle(tester);
    expect(resets, 1);
    expect(attempts, 3);
    expect(find.byType(OcApp), findsNothing);
    expect(find.text("Can't read saved servers"), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reset failure stays recoverable and keeps technical text in Details',
    (tester) async {
      final diagnostics = AppDiagnosticsController();
      addTearDown(diagnostics.dispose);
      var resets = 0;
      await tester.pumpWidget(
        AppBootstrapGate(
          diagnostics: diagnostics,
          loader: () async => throw StateError('storage unavailable'),
          resetSavedSignIns: () async {
            resets++;
            throw StateError('private reset reason');
          },
        ),
      );
      await _settle(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('start-fresh-app-bootstrap')),
      );
      await tester.tap(find.byKey(const ValueKey('start-fresh-app-bootstrap')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-start-fresh')));
      await _settle(tester);
      expect(resets, 1);
      expect(find.text('Sign-in reset failed'), findsOneWidget);
      expect(find.textContaining('private reset reason'), findsNothing);
      expect(
        find.byKey(const ValueKey('start-fresh-app-bootstrap')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('kit-state-details')),
      );
      await tester.tap(find.byKey(const ValueKey('kit-state-details')));
      await _settle(tester);
      expect(find.textContaining('private reset reason'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('retry-app-bootstrap')),
      );
      await tester.tap(find.byKey(const ValueKey('retry-app-bootstrap')));
      await _settle(tester);
      expect(resets, 2);
      expect(find.text('Remove saved sign-ins?'), findsNothing);
      expect(find.text('Sign-in reset failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
