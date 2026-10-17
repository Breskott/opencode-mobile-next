// Golden renders of the Continue with… sheet (docs/design/agent-handoff-
// contract.md): the choice of models and agents with an agent that needs
// signing in, a model of the same server, the prepared record with its first
// message, the record preview unfolded, and an unconfirmed result, at 412x915,
// dark and light, with the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/continue_with_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/continue_with.dart';
import 'package:opencode_mobile/ui/widgets/continue_with_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/continue_with_fakes.dart';

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required bool light,
  required FakeContinueWithHost Function(SharedPreferences prefs) host,
  Future<void> Function(WidgetTester tester)? then,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final scaffold = GlobalKey();
  final prefs = await FakeContinueWithHost.prefsWithProfiles();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            key: scaffold,
            body: const SafeArea(child: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showContinueWithSheet(scaffold.currentContext!, host: host(prefs)),
    );
    await tester.pumpAndSettle();
    if (then != null) await then(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('$name${light ? '_light' : '_dark'}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pickAgent(WidgetTester tester) async {
  await tester.tap(find.text('Opus 5.5'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('choose · signed-out agent · $mode', (tester) async {
      await _golden(
        tester,
        'handoff_sheet_choose',
        light: light,
        host: (prefs) => FakeContinueWithHost(
          prefs,
          agentBlock: ContinueWithBlock.needsSignIn,
        ),
      );
    });

    testWidgets('choose · ready agent · $mode', (tester) async {
      await _golden(
        tester,
        'handoff_sheet_agents',
        light: light,
        host: FakeContinueWithHost.new,
      );
    });

    testWidgets('model of this server · $mode', (tester) async {
      await _golden(
        tester,
        'handoff_sheet_model',
        light: light,
        host: FakeContinueWithHost.new,
        then: (tester) async {
          await tester.tap(find.text('GPT-6 Terra'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('record and first message · $mode', (tester) async {
      await _golden(
        tester,
        'handoff_sheet_record',
        light: light,
        host: FakeContinueWithHost.new,
        then: _pickAgent,
      );
    });

    testWidgets('record preview unfolded · $mode', (tester) async {
      await _golden(
        tester,
        'handoff_sheet_preview',
        light: light,
        host: FakeContinueWithHost.new,
        then: (tester) async {
          await _pickAgent(tester);
          await tester.tap(find.byKey(const ValueKey('handoff-record-toggle')));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('unconfirmed result · $mode', (tester) async {
      await _golden(
        tester,
        'handoff_sheet_unconfirmed',
        light: light,
        host: (prefs) =>
            FakeContinueWithHost(prefs)
              ..target.promptError = StateError('private'),
        then: (tester) async {
          await _pickAgent(tester);
          await tester.tap(find.byKey(const ValueKey('continue-with-start')));
          await tester.pumpAndSettle();
        },
      );
    });
  }
}
