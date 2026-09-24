// The AI Team's drawings and moments (design standard §10, motion spec
// slice D, docs/design/motion-and-illustration-2026-09-25.md): the right
// drawing for each state, loops only where the person waits, a merged task
// celebrated once (remembered, and swept with the profile), a nudge on
// "Needs you" that plays once and never loops, and reduced motion showing
// the finished drawings.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_planning.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/scenes/team_scenes.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/start_run_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_agents_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_card.dart';
import 'package:opencode_mobile/ui/widgets/team_moments.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/team_golden_fixture.dart';

final _theme = AppTheme.dark();

Widget _app(Widget home, {bool reduce = false}) => MaterialApp(
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: child!,
  ),
  home: home,
);

/// The drawings under [of], as (scene, ambient, animateEntrance).
List<(KitScene, bool, bool)> _drawings(WidgetTester tester, Finder of) => [
  for (final drawing in tester.widgetList<KitIllustration>(
    find.descendant(of: of, matching: find.byType(KitIllustration)),
  ))
    (drawing.scene, drawing.ambient, drawing.animateEntrance),
];

/// Loads and lets every entrance finish. Not pumpAndSettle: a working
/// task's mark keeps spinning on the loaded home.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(KitMotion.celebration);
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// The recorded fixture with no agents at all.
class _NoAgents extends FixtureOrchestrationGateway {
  _NoAgents({required super.fixturePath});

  @override
  Future<List<OrchestrationAgent>> agents() async => const [];
}

String _fixturePath() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate.path;
    dir = dir.parent;
  }
  throw StateError('tool/qa/gascity_fixture not found');
}

void main() {
  late OrchestrationController controller;

  setUp(() {
    TeamCelebrations.forgetSession();
    TeamNeedsYouLabel.forgetSession();
  });

  tearDown(() => KitMotion.loops = false);

  Future<void> open(
    WidgetTester tester,
    TeamScene scene,
    Widget Function() home, {
    bool reduce = false,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = await teamSceneController(scene);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(home(), reduce: reduce));
    await _settle(tester);
  }

  TeamHomeScreen home() =>
      TeamHomeScreen(controller: controller, now: () => teamSceneClock);

  RunScreen run(String id) =>
      RunScreen(controller: controller, runId: id, now: () => teamSceneClock);

  testWidgets('no tasks: the team gathered at an empty board, still', (
    tester,
  ) async {
    await open(tester, TeamScene.empty, home);
    final drawings = _drawings(tester, _key('team-home-runs-empty'));
    expect(drawings, hasLength(1));
    expect(drawings.single.$1, isA<TeamBoardScene>());
    // A resting screen: it draws itself in once and does not loop.
    expect(drawings.single.$2, isFalse);
    // The one sentence still teaches.
    expect(find.text('No recent tasks'), findsOneWidget);
  });

  testWidgets('the team host starting: the team wakes, moving while it '
      'waits', (tester) async {
    await open(tester, TeamScene.starting, home);
    final drawings = _drawings(tester, _key('team-home-error'));
    expect(drawings.single.$1, isA<TeamWakingScene>());
    expect(drawings.single.$2, isTrue, reason: 'a wait: ambient');
    expect(find.text('The team host is starting'), findsOneWidget);
  });

  testWidgets('other failures keep their icon, not the team', (tester) async {
    await open(tester, TeamScene.failed, home);
    expect(_drawings(tester, _key('team-home-error')), isEmpty);
    expect(_key('kit-state-icon'), findsOneWidget);
  });

  testWidgets('planning: agents pass the card while the planner plans; one '
      'card moves, a refused one has no drawing', (tester) async {
    await open(tester, TeamScene.loaded, () => const SizedBox());
    TeamPlanningRequest request(String key, TeamPlanningStatus status) =>
        TeamPlanningRequest(
          record: MutationRecord(
            key: key,
            request: MutationRequest.message('mayor', 'Add dark mode'),
            createdAt: teamSceneClock,
            status: MutationStatus.confirmed,
          ),
          objective: 'Add dark mode',
          supervision: TeamSupervision.balanced,
          status: status,
        );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ListView(
            children: [
              TeamPlanningCard(
                key: const ValueKey('first'),
                controller: controller,
                request: request('a', TeamPlanningStatus.planning),
              ),
              TeamPlanningCard(
                key: const ValueKey('second'),
                controller: controller,
                request: request('b', TeamPlanningStatus.stillPlanning),
                ambient: false,
              ),
              TeamPlanningCard(
                key: const ValueKey('refused'),
                controller: controller,
                request: request('c', TeamPlanningStatus.refused),
              ),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    final first = _drawings(tester, _key('first'));
    expect(first.single.$1, isA<TeamPlanningScene>());
    expect(first.single.$2, isTrue);
    final second = _drawings(tester, _key('second'));
    expect(second.single.$1, isA<TeamPlanningScene>());
    expect(second.single.$2, isFalse);
    expect(_drawings(tester, _key('refused')), isEmpty);
    expect(find.text('Planning the steps…'), findsOneWidget);
  });

  testWidgets('a task given on the home: its planning card moves, and the '
      'board steps aside', (tester) async {
    await open(tester, TeamScene.empty, home);
    await tester.tap(_key('team-home-start-run'));
    await _settle(tester);
    await tester.enterText(
      _key('team-start-run-objective'),
      'Add a dark mode toggle',
    );
    await tester.pump();
    await tester.tap(_key('team-start-run-send'));
    await _settle(tester);
    expect(find.text('Planning the steps…'), findsOneWidget);
    final planning = _drawings(tester, find.byType(TeamPlanningCard));
    expect(planning.single.$1, isA<TeamPlanningScene>());
    expect(planning.single.$2, isTrue, reason: 'the one moving drawing');
    expect(_drawings(tester, _key('team-home-runs-empty')), isEmpty);
    // Let the planning request's own timers run out.
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pump(const Duration(minutes: 10));
  });

  testWidgets('a merged task celebrates once, remembered across a restart '
      'under a key the profile deletion sweeps', (tester) async {
    await open(tester, TeamScene.loaded, () => run(teamSceneMergedRunId));
    expect(_key('team-run-celebration'), findsOneWidget);
    expect(
      tester.widget<KitIllustration>(_key('team-run-celebration')).scene,
      isA<TeamMergedScene>(),
    );

    // Open it again: no second celebration.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(run(teamSceneMergedRunId)));
    await _settle(tester);
    expect(_key('team-run-objective'), findsOneWidget);
    expect(_key('team-run-celebration'), findsNothing);

    // After a restart (this session's memory gone), still not again.
    TeamCelebrations.forgetSession();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(run(teamSceneMergedRunId)));
    await _settle(tester);
    expect(_key('team-run-celebration'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final key = TeamCelebrations.keyFor(controller.profileId);
    expect(key, 'oc.orchestration.golden.celebrated');
    expect(prefs.getStringList(key), [teamSceneMergedRunId]);
    // Deleting the profile, or turning the plugin off, removes it.
    expect(
      ProfileStore(prefs: prefs).profileScopedPreferenceKeys('golden'),
      contains(key),
    );
    expect(OrchestrationStore(prefs).keysFor('golden'), contains(key));
  });

  testWidgets('a task still working does not celebrate', (tester) async {
    await open(tester, TeamScene.loaded, () => run(teamSceneRunId));
    expect(_key('team-run-objective'), findsOneWidget);
    expect(_key('team-run-celebration'), findsNothing);
  });

  testWidgets('the celebration plays once and settles, even where loops '
      'run', (tester) async {
    KitMotion.loops = true;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = await teamSceneController(TeamScene.loaded);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(run(teamSceneMergedRunId)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_key('team-run-celebration'), findsOneWidget);
    await tester.pump(KitMotion.celebration);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Needs you: the agent waves the first time, not again', (
    tester,
  ) async {
    await open(tester, TeamScene.loaded, home);
    final first = _drawings(tester, _key('team-home-needs-you'));
    expect(first.single.$1, isA<TeamNudgeScene>());
    expect(first.single.$2, isFalse, reason: 'a nudge is not a loop');
    expect(first.single.$3, isTrue, reason: 'it plays the first time');

    // Back on the home later: the agent stands still, hand up.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(home()));
    await _settle(tester);
    final again = _drawings(tester, _key('team-home-needs-you'));
    expect(again.single.$1, isA<TeamNudgeScene>());
    expect(again.single.$3, isFalse);
  });

  testWidgets('Needs you: the wave ends, even where loops run; a new '
      'question waves again', (tester) async {
    KitMotion.loops = true;
    Widget label(List<String> ids) => _app(
      Scaffold(
        body: TeamNeedsYouLabel('Needs you', profileId: 'p', gateIds: ids),
      ),
    );
    await tester.pumpWidget(label(['g1']));
    await tester.pump(KitMotion.entrance ~/ 2);
    expect(tester.hasRunningAnimations, isTrue, reason: 'it waves');
    await tester.pump(KitMotion.entrance);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse, reason: 'and stops');
    // The same question on a rebuild: still.
    await tester.pumpWidget(label(['g1']));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
    // A new one: one more wave, then still again.
    await tester.pumpWidget(label(['g1', 'g2']));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(KitMotion.entrance);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: every drawing is finished at once and '
      'nothing moves', (tester) async {
    KitMotion.loops = true;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = await teamSceneController(TeamScene.starting);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(home(), reduce: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_drawings(tester, _key('team-home-error')), isNotEmpty);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('no agents: one agent dozing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.fixture,
      url: 'http://pop-os:7000',
      city: 'bright-lights',
      enabledAt: DateTime.utc(2026, 9, 10),
    );
    controller = OrchestrationController(
      profile: ServerProfile(
        id: 'motion',
        name: 'Development PC',
        baseUrl: 'https://server.example',
        orchestration: config,
      ),
      config: config,
      store: OrchestrationStore(prefs),
      gatewayFactory: (_, _) => _NoAgents(fixturePath: _fixturePath()),
      now: () => teamSceneClock,
    );
    addTearDown(controller.dispose);
    await controller.start();
    await tester.pumpWidget(_app(TeamAgentsScreen(controller: controller)));
    await _settle(tester);
    final drawings = _drawings(tester, _key('team-home-agents-empty'));
    expect(drawings.single.$1, isA<TeamRestScene>());
    expect(drawings.single.$2, isFalse);
  });

  testWidgets('the Work tab card with nothing running: two agents at ease', (
    tester,
  ) async {
    await open(
      tester,
      TeamScene.empty,
      () => Scaffold(
        body: ListView(
          children: [TeamCard(controller: controller, onOpen: () {})],
        ),
      ),
    );
    final drawings = _drawings(tester, _key('team-card-empty'));
    expect(drawings.single.$1, isA<TeamIdleScene>());
    expect(drawings.single.$2, isFalse);
    expect(find.textContaining('Nothing running'), findsOneWidget);
  });
}
