// Golden renders of the AI Team agent detail on the design kit
// (docs/design/design-standard.md §8): 412x915, dark and light, the app's
// real fonts, a pinned clock and the recorded Gas City fixture.
//
// team_agent: the short status page (status line, a question waiting, the
// primary — Live output here, no OpenCode server to find its conversation
// on — then Message, two text buttons, the rest under More, and Technical
// details folded).
// team_agent_controls: Technical details opened, scrolled to its end.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/team_agent_golden_test.dart
// and look at every changed image before committing it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

final _clock = DateTime.utc(2026, 9, 11, 9, 41);

/// The recorded fixture with the agent, work and question the page shows.
class _Gateway extends FixtureOrchestrationGateway {
  _Gateway({required super.fixturePath});

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => [
    OrchestrationRun(
      id: 'oc-xru',
      title: 'Offline-first sessions',
      state: RunState.working,
      kind: RunKind.batch,
      stepCount: 3,
      completedSteps: 1,
      startedAt: _clock.subtract(const Duration(hours: 3)),
      updatedAt: _clock,
    ),
  ];

  @override
  Future<List<WorkItem>> work({String? projectId}) async => const [
    WorkItem(
      id: 'w1',
      title: 'Storage layer',
      state: WorkState.completed,
      runId: 'oc-xru',
    ),
    WorkItem(
      id: 'w2',
      title: 'Sync engine',
      state: WorkState.working,
      runId: 'oc-xru',
    ),
    WorkItem(
      id: 'w4',
      title: 'Conflict policy',
      state: WorkState.ready,
      runId: 'oc-xru',
    ),
  ];

  @override
  Future<List<OrchestrationAgent>> agents() async => [
    OrchestrationAgent(
      id: 'fox',
      name: 'fox',
      state: AgentState.working,
      rawState: 'active',
      sessionId: 'bl-5qc',
      sessionName: 'ocproof--polecat--fox',
      pool: 'gastown.polecat',
      provider: 'opencode',
      model: 'openai/gpt-x',
      harness: 'OpenCode',
      currentWorkId: 'w2',
      lastActivity: _clock.subtract(const Duration(minutes: 12)),
      contextPercent: 63,
      workDir: '/home/eslam/city/.gc/worktrees/ocproof/polecats/fox',
      branch: 'polecat/oc-cq6',
      sessionStartedAt: _clock.subtract(const Duration(hours: 3, minutes: 14)),
    ),
  ];

  @override
  Future<List<OrchestrationGate>> gates() async => [
    OrchestrationGate(
      id: 'g1',
      kind: GateKind.choice,
      title: 'Which persistence strategy?',
      workId: 'w2',
      agentId: 'bl-5qc',
      choices: const ['SQLite', 'Filesystem'],
      createdAt: _clock,
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

Future<OrchestrationController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final path = _fixtureRoot().path;
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: path,
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
    gatewayFactory: (_, _) => _Gateway(fixturePath: path),
    now: () => _clock,
  );
  await controller.start();
  return controller;
}

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required bool light,
  Future<void> Function()? before,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = await _controller();
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: captureTheme(light: light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: RepaintBoundary(key: boundary, child: child),
        ),
        home: AgentScreen(
          controller: controller,
          agentId: 'fox',
          now: () => _clock,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await before?.call();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('${name}_${light ? 'light' : 'dark'}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('agent · top · $mode', (tester) async {
      await _golden(tester, 'team_agent', light: light);
    });

    testWidgets('agent · controls · $mode', (tester) async {
      await _golden(
        tester,
        'team_agent_controls',
        light: light,
        before: () async {
          await tester.tap(find.byKey(const ValueKey('team-agent-technical')));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('team-agent-work-chip')),
            300,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('team-agent-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pump(const Duration(milliseconds: 300));
        },
      );
    });
  }
}
