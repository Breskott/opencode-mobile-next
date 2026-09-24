// Scenes for the AI Team golden renders (test/goldens/team_golden_test.dart)
// and the QA before/after captures
// (tool/capture/aiteam_design_standard_test.dart): one controller per scene,
// the recorded Gas City fixture with its runs, work, agents and questions
// replaced by a small believable team, and a pinned clock.
//
// Only APIs that already existed before the design-standard migration are
// used here, so the same scenes render the old screens for "before".
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/agent_output_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The scenes' clock.
final teamSceneClock = DateTime.utc(2026, 9, 11, 9, 41);

/// The run every run-screen scene opens.
const teamSceneRunId = 'oc-xru';

enum TeamScene {
  /// A blocked batch that needs you, a working formula run, and a finished
  /// merged batch under Completed.
  loaded,

  /// Nothing run yet (or the host no longer lists it): the teaching empty
  /// state, and Start a run.
  empty,

  /// The host could not be reached at all.
  failed,

  /// The probe never answers: connecting, then after 8 s not answering.
  connecting,
}

class _SceneGateway extends FixtureOrchestrationGateway {
  _SceneGateway({required super.fixturePath, required this.scene});

  final TeamScene scene;

  DateTime _ago(Duration d) => teamSceneClock.subtract(d);

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async =>
      scene == TeamScene.empty
      ? const []
      : [
          OrchestrationRun(
            id: teamSceneRunId,
            title: 'Offline-first sessions',
            state: RunState.working,
            kind: RunKind.batch,
            stepCount: 5,
            completedSteps: 1,
            startedAt: _ago(const Duration(hours: 3, minutes: 12)),
            updatedAt: _ago(const Duration(minutes: 4)),
          ),
          OrchestrationRun(
            id: 'mol-upgrade',
            title: 'Upgrade the HTTP client and fix what breaks',
            state: RunState.working,
            kind: RunKind.formula,
            formula: 'mol-upgrade',
            stepCount: 4,
            completedSteps: 2,
            startedAt: _ago(const Duration(minutes: 48)),
            updatedAt: _ago(const Duration(minutes: 2)),
          ),
          OrchestrationRun(
            id: 'ma-lqw',
            title: 'Create hello.py that prints Hello from the AI Team',
            state: RunState.completed,
            kind: RunKind.batch,
            stepCount: 1,
            completedSteps: 1,
            merged: true,
            startedAt: _ago(const Duration(hours: 5, minutes: 20)),
            updatedAt: _ago(const Duration(hours: 5)),
            finishedAt: _ago(const Duration(hours: 5)),
          ),
        ];

  @override
  Future<List<WorkItem>> work({String? projectId}) async =>
      scene == TeamScene.empty
      ? const []
      : [
          WorkItem(
            id: 'w-storage',
            title: 'Storage layer',
            state: WorkState.completed,
            runId: teamSceneRunId,
            assignee: 'fox',
            updatedAt: _ago(const Duration(hours: 2)),
          ),
          WorkItem(
            id: 'w-sync',
            title: 'Sync engine',
            state: WorkState.working,
            runId: teamSceneRunId,
            assignee: 'fox',
            dependsOn: const ['w-storage'],
            updatedAt: _ago(const Duration(minutes: 5)),
          ),
          WorkItem(
            id: 'w-conflict',
            title: 'Conflict policy',
            state: WorkState.blocked,
            runId: teamSceneRunId,
            isBlocked: true,
            dependsOn: const ['w-sync'],
            updatedAt: _ago(const Duration(hours: 1)),
          ),
          WorkItem(
            id: 'w-schema',
            title: 'Schema for offline drafts',
            state: WorkState.needsInput,
            runId: teamSceneRunId,
            assignee: 'wolf',
            updatedAt: _ago(const Duration(minutes: 12)),
          ),
          WorkItem(
            id: 'w-tests',
            title: 'Tests for reconnect',
            state: WorkState.queued,
            runId: teamSceneRunId,
            dependsOn: const ['w-sync'],
            updatedAt: _ago(const Duration(hours: 3)),
          ),
          WorkItem(
            id: 'w-hello',
            title: 'Create hello.py that prints Hello from the AI Team',
            state: WorkState.completed,
            runId: 'ma-lqw',
            assignee: 'mole',
            updatedAt: _ago(const Duration(hours: 5)),
          ),
        ];

  @override
  Future<List<OrchestrationAgent>> agents() async => [
    OrchestrationAgent(
      id: 'gastown.mayor',
      name: 'mayor',
      state: AgentState.idle,
      sessionId: 'ma-1',
      pool: 'gastown.mayor',
      sessionStartedAt: _ago(const Duration(hours: 6)),
    ),
    if (scene != TeamScene.empty) ...[
      OrchestrationAgent(
        id: 'fox',
        name: 'fox',
        state: AgentState.working,
        sessionId: 'bl-5qc',
        pool: 'gastown.polecat',
        currentWorkId: 'w-sync',
        contextPercent: 63,
        lastActivity: _ago(const Duration(minutes: 1)),
        sessionStartedAt: _ago(const Duration(hours: 3)),
      ),
      OrchestrationAgent(
        id: 'wolf',
        name: 'wolf',
        state: AgentState.waiting,
        sessionId: 'bl-7wr',
        pool: 'gastown.polecat',
        currentWorkId: 'w-schema',
        contextPercent: 41,
        lastActivity: _ago(const Duration(minutes: 12)),
        sessionStartedAt: _ago(const Duration(hours: 1)),
      ),
    ],
  ];

  @override
  Future<List<OrchestrationGate>> gates() async => scene == TeamScene.empty
      ? const []
      : [
          OrchestrationGate(
            id: 'req-schema-1',
            kind: GateKind.choice,
            title: 'Keep drafts in SQLite or in plain files?',
            prompt:
                'Drafts must survive a restart. SQLite is safer; plain '
                'files are easier to inspect.',
            workId: 'w-schema',
            runId: teamSceneRunId,
            agentId: 'bl-7wr',
            choices: const ['SQLite', 'Plain files'],
            createdAt: _ago(const Duration(minutes: 12)),
          ),
        ];
}

Directory _fixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError('tool/qa/gascity_fixture not found');
}

/// A started controller for [scene]. Dispose it after the render.
Future<OrchestrationController> teamSceneController(TeamScene scene) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final path = _fixtureRoot().path;
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: 'http://pop-os:7000',
    city: 'bright-lights',
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final controller = OrchestrationController(
    profile: ServerProfile(
      id: 'golden',
      name: 'Development PC',
      baseUrl: 'https://server.example',
      orchestration: config,
    ),
    config: config,
    store: OrchestrationStore(prefs),
    gatewayFactory: (_, _) => _SceneGateway(fixturePath: path, scene: scene),
    probe: switch (scene) {
      TeamScene.failed => (_) async => const ProbeUnreachable(
        error: 'Connection refused (http://pop-os:7000)',
      ),
      TeamScene.connecting => (_) => Completer<ProbeVerdict>().future,
      // The fixture provider's own probe finds the recorded city.
      TeamScene.loaded || TeamScene.empty => null,
    },
    now: () => teamSceneClock,
  );
  if (scene == TeamScene.connecting) {
    unawaited(controller.start());
  } else {
    await controller.start();
  }
  return controller;
}

/// One picture of the AI Team: the scene it needs and what to open.
enum TeamShot {
  homeLoaded(TeamScene.loaded, 'team_home_loaded'),
  homeEmpty(TeamScene.empty, 'team_home_empty'),
  homeError(TeamScene.failed, 'team_home_error'),
  homeNotAnswering(TeamScene.connecting, 'team_home_not_answering'),
  runOverview(TeamScene.loaded, 'team_run_overview'),
  runWork(TeamScene.loaded, 'team_run_work'),
  startRun(TeamScene.loaded, 'team_start_run'),
  card(TeamScene.loaded, 'team_card'),
  agentOutput(TeamScene.loaded, 'team_agent_output');

  const TeamShot(this.scene, this.fileName);

  final TeamScene scene;

  /// The golden and capture file name.
  final String fileName;
}

/// Pumps [shot] at 412x915 under [boundary] and leaves it on screen.
/// Returns the controller; dispose it after the picture.
Future<OrchestrationController> pumpTeamShot(
  WidgetTester tester,
  TeamShot shot, {
  required bool light,
  required GlobalKey boundary,
  required ThemeData Function({bool light}) theme,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  final controller = await teamSceneController(shot.scene);
  DateTime now() => teamSceneClock;
  final Widget home = switch (shot) {
    TeamShot.runOverview || TeamShot.runWork => RunScreen(
      controller: controller,
      runId: teamSceneRunId,
      now: now,
    ),
    TeamShot.agentOutput => AgentOutputScreen(
      controller: controller,
      agentId: 'fox',
    ),
    TeamShot.card => Scaffold(
      body: SafeArea(
        child: ListView(
          children: [TeamCard(controller: controller, onOpen: () {})],
        ),
      ),
    ),
    _ => TeamHomeScreen(controller: controller, now: now),
  };
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme(light: light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: RepaintBoundary(key: boundary, child: child),
      ),
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  switch (shot) {
    case TeamShot.homeLoaded:
      // The finished run: "Done · merged · Finished 5h ago" under Completed.
      await tester.tap(find.byKey(const ValueKey('team-home-completed-group')));
    case TeamShot.homeNotAnswering:
      // Past the 8 s rule (design standard §4).
      await tester.pump(const Duration(seconds: 9));
    case TeamShot.runWork:
      await tester.tap(find.byKey(const ValueKey('team-run-tab-work')));
    case TeamShot.startRun:
      await tester.tap(find.byKey(const ValueKey('team-home-start-run')));
    case TeamShot.homeEmpty ||
        TeamShot.homeError ||
        TeamShot.runOverview ||
        TeamShot.card ||
        TeamShot.agentOutput:
      break;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return controller;
}
