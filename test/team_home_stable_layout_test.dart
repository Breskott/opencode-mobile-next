// Stable team home (2026-09-13): on a compact phone the section selector
// and the run filters stay easy to choose at every text size, and the
// run list keeps its space. Boots the plain fixture gateway, the same
// data the QA captures use: one waiting convoy, a handful of agents.

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
  const segments = ValueKey('team-home-segments');
  const segmentsMenu = ValueKey('team-home-segments-menu');
  const filterMenu = ValueKey('team-home-filter-menu');
  Finder filter(String name) => find.byKey(ValueKey('team-home-filter-$name'));

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

  testWidgets('390dp normal text: segments and all four filters on one row', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(390, 844));

    // The segmented button as before, inside the screen.
    expect(find.byKey(segments), findsOneWidget);
    expect(find.byKey(segmentsMenu), findsNothing);
    expect(tester.getRect(find.byKey(segments)).right, lessThanOrEqualTo(390));

    // Every chip fully on screen, all on the same row, no menu.
    expect(find.byKey(filterMenu), findsNothing);
    final tops = <double>{};
    for (final name in ['active', 'blocked', 'completed', 'all']) {
      final rect = tester.getRect(filter(name));
      expect(rect.left, greaterThanOrEqualTo(0), reason: name);
      expect(rect.right, lessThanOrEqualTo(390), reason: name);
      tops.add(rect.top);
    }
    expect(tops, hasLength(1), reason: 'one row of chips');

    // They still filter: the waiting convoy is not completed.
    expect(find.byKey(run), findsOneWidget);
    await tester.tap(filter('completed'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(filter('completed')).selected, isTrue);
    expect(find.byKey(run), findsNothing);
    await tester.tap(filter('all'));
    await tester.pumpAndSettle();
    expect(find.byKey(run), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp normal text: the chip row scrolls, the last chip works', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(320, 740));
    expect(find.byKey(segments), findsOneWidget);
    expect(find.byKey(filterMenu), findsNothing);
    final all = filter('all');
    await Scrollable.ensureVisible(tester.element(all), alignment: .5);
    await tester.pump();
    expect(all.hitTestable(), findsOneWidget);
    await tester.tap(filter('completed'));
    await tester.pumpAndSettle();
    expect(find.byKey(run), findsNothing);
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(all).selected, isTrue);
    expect(find.byKey(run), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 2.5x: one menu each for sections and filters; the run '
      'row and Start a run stay on screen', (tester) async {
    await pumpHome(tester, size: const Size(320, 740), scale: 2.5);

    // No segmented button, no chips: two compact menu buttons instead.
    expect(find.byKey(segments), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    final sections = find.byKey(segmentsMenu);
    final filters = find.byKey(filterMenu);
    expect(sections.hitTestable(), findsOneWidget);
    expect(filters.hitTestable(), findsOneWidget);
    for (final finder in [sections, filters]) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    // The run is reachable without scrolling; the FAB is still offered.
    expect(find.byKey(run).hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('team-home-start-run')).hitTestable(),
      findsOneWidget,
    );

    // Pick a filter from the menu: it reads on the button and applies.
    await tester.tap(filters);
    await tester.pumpAndSettle();
    for (final name in ['active', 'blocked', 'completed', 'all']) {
      expect(filter(name).hitTestable(), findsOneWidget, reason: name);
    }
    await tester.tap(filter('completed'));
    await tester.pumpAndSettle();
    expect(filter('completed'), findsNothing, reason: 'menu closed');
    expect(
      find.descendant(
        of: filters,
        matching: find.text(l10n.teamUiHomeFilterCompleted),
      ),
      findsOneWidget,
    );
    expect(find.byKey(run), findsNothing);
    expect(
      find.byKey(const ValueKey('team-home-runs-empty-filtered')),
      findsOneWidget,
    );

    // Pick a section from the menu: Agents, then Needs you, then Runs,
    // which kept its filter.
    Future<void> section(String name, String list) async {
      await tester.tap(sections);
      await tester.pumpAndSettle();
      final item = find.byKey(ValueKey('team-home-segment-$name'));
      expect(item.hitTestable(), findsOneWidget);
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(list)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await section('agents', 'team-home-agents');
    expect(find.byKey(filterMenu), findsNothing);
    await section('needs-you', 'team-home-needs-you');
    await section('runs', 'team-home-runs');
    expect(
      find.descendant(
        of: filters,
        matching: find.text(l10n.teamUiHomeFilterCompleted),
      ),
      findsOneWidget,
      reason: 'filter kept across sections',
    );
  });
}
