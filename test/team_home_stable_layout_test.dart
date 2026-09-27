// Stable team home (2026-09-13, redesigned 2026-09-24): on a compact phone
// the task list keeps its space at every text size. A short list carries
// no controls at all (no sections, chips or search); the task, the board
// button and "Give the team a task" stay on screen. Boots the plain
// fixture gateway, the same data the QA captures use: one waiting convoy,
// a handful of agents.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

Directory _findFixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'tool/qa/gascity_fixture not found from ${Directory.current}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These assertions concern painted widths, so use the app's Android fonts.
  setUpAll(loadCaptureFonts);

  late String fixturePath;
  late OrchestrationStore store;
  final clock = DateTime.utc(2026, 9, 13, 9, 41);
  final l10n = lookupAppLocalizations(const Locale('en'));

  const run = ValueKey('team-home-run-oc-xru');
  const start = ValueKey('team-home-start-run');
  // The top bar's one action beside the menu.
  const info = ValueKey('team-home-board');

  /// Nothing to choose before the list: no sections, chips or search.
  void noControls(WidgetTester tester) {
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(SegmentedButton<Object>), findsNothing);
    expect(find.byKey(const ValueKey('team-home-filter-menu')), findsNothing);
    expect(find.byKey(const ValueKey('team-home-search-open')), findsNothing);
  }

  void onScreen(WidgetTester tester, ValueKey<String> key, double width) {
    final finder = find.byKey(key);
    expect(finder.hitTestable(), findsOneWidget, reason: key.value);
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(0), reason: key.value);
    expect(rect.right, lessThanOrEqualTo(width), reason: key.value);
  }

  setUp(() async {
    fixturePath = _findFixtureRoot().path;
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
  });

  Future<OrchestrationController> boot() async {
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.fixture,
      url: fixturePath,
      city: 'bright-lights',
      enabledAt: DateTime.utc(2026, 9, 10),
    );
    final controller = OrchestrationController(
      profile: ServerProfile(
        id: 'srv-1',
        name: 'Development PC',
        baseUrl: 'https://server.example:4096',
        orchestration: config,
      ),
      config: config,
      store: store,
      gatewayFactory: (_, _) =>
          FixtureOrchestrationGateway(fixturePath: fixturePath),
      now: () => clock,
    );
    addTearDown(controller.dispose);
    await controller.start();
    return controller;
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await boot();
    await tester.pumpWidget(
      MaterialApp(
        theme: captureTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: TeamHomeScreen(controller: controller, now: () => clock),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('team-home-data')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('team-home'))).width,
      size.width,
    );
  }

  testWidgets('390dp normal text: a short list has no controls; the task '
      'and Give the team a task are on screen', (tester) async {
    await pumpHome(tester, size: const Size(390, 844));
    noControls(tester);
    for (final key in [run, start, info]) {
      onScreen(tester, key, 390);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp normal text: the same, nothing pushed sideways', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(320, 740));
    noControls(tester);
    for (final key in [run, start, info]) {
      onScreen(tester, key, 320);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 2.5x: the task and Give the team a task stay on '
      'screen; Technical details open', (tester) async {
    await pumpHome(tester, size: const Size(320, 740), scale: 2.5);
    noControls(tester);
    // The team's Now line heads the list and names the task with what
    // happens next (docs/qa/team-discover-2026-09-25); at 2.5x the task's
    // own row is one scroll below it, never pushed sideways.
    for (final key in [const ValueKey('team-home-now-stuck'), start, info]) {
      onScreen(tester, key, 320);
    }
    await tester.scrollUntilVisible(
      find.byKey(run),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('team-home-runs')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    onScreen(tester, run, 320);
    // Technical details open from the page's "how it runs" row (P3.4).
    const host = ValueKey('team-home-host-row');
    await tester.scrollUntilVisible(
      find.byKey(host),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('team-home-runs')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(host));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-home-host-sheet')), findsOneWidget);
    expect(
      find.text(l10n.teamUiTechnicalDetails),
      findsWidgets,
      reason: 'the sheet names itself',
    );
    expect(tester.takeException(), isNull);
  });
}
