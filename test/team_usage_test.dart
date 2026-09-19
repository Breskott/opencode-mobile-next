// TEAM-113: usage surfaces. The shared formatter returns null when the
// host reported neither cost nor tokens, writes tokens compactly and puts
// "est." after every cost; the run Overview's "Team today" chip and the
// agent Runtime's "Tokens / context / cost" line show over the fixture's
// `/usage` and are absent when usage is empty or the capability is off;
// the Gas City read capabilities now include `usage`.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The fixture with the usage read, the capabilities and the run / work /
/// agent lists replaceable per test.
class _Gateway implements OrchestrationGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  OrchestrationCapabilities? capabilitiesOverride;
  Future<OrchestrationUsage?> Function()? usageOverride;
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;

  @override
  OrchestrationCapabilities get capabilities =>
      capabilitiesOverride ?? inner.capabilities;
  @override
  OrchestrationHostIdentity? get host => inner.host;
  @override
  bool get isClosed => inner.isClosed;
  @override
  Future<void> close() async {
    await stream.close();
    await inner.close();
  }

  @override
  Future<List<OrchestrationProject>> projects() => inner.projects();

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async =>
      runsOverride ?? await inner.runs(projectId: projectId);

  @override
  Future<OrchestrationRun?> run(String id) => inner.run(id);

  @override
  Future<List<WorkItem>> work({String? projectId}) async =>
      workOverride ?? await inner.work(projectId: projectId);

  @override
  Future<List<WorkItem>> readyWork({String? projectId}) =>
      inner.readyWork(projectId: projectId);

  @override
  Future<WorkItem?> workItem(String id) => inner.workItem(id);

  @override
  Future<List<OrchestrationAgent>> agents() async =>
      agentsOverride ?? await inner.agents();

  @override
  Future<OrchestrationAgent?> agent(String id) => inner.agent(id);

  @override
  Future<List<OrchestrationGate>> gates() => inner.gates();

  @override
  Future<OrchestrationUsage?> usage() => usageOverride?.call() ?? inner.usage();

  @override
  Future<List<ActivityEvent>> activity({int? afterSeq, int limit = 100}) =>
      inner.activity(afterSeq: afterSeq, limit: limit);

  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => stream.stream;

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) => inner.respond(gateId, response, requestId: requestId);

  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => inner.message(agentId, text, requestId: requestId);

  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) => inner.controlAgent(agentId, action, requestId: requestId);

  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => inner.cancelRun(runId, requestId: requestId);

  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => inner.assign(workId, agentId: agentId, requestId: requestId);

  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => inner.createWork(
    title: title,
    description: description,
    projectId: projectId,
    requestId: requestId,
  );
}

/// A day's usage as the PC's Gas City reports it once agents have run:
/// `source: local_estimate`, tokens and an estimated cost.
const _richUsage = OrchestrationUsage(
  inputTokens: 9400,
  outputTokens: 3000,
  costUsd: 0.42,
  raw: {'source': 'local_estimate', 'available': true},
);

/// `/status` counts only: not [OrchestrationUsage.isEmpty], but nothing to
/// price.
const _countsOnly = OrchestrationUsage(
  activeAgents: 2,
  workOpen: 3,
  raw: {'source': 'unavailable'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  final arabicIndicDigits = RegExp('[٠-٩]');

  group('teamUsageLabel', () {
    test('is null when the host reported neither cost nor tokens', () {
      expect(teamUsageLabel(en, null), isNull);
      expect(teamUsageLabel(en, const OrchestrationUsage()), isNull);
      expect(teamUsageLabel(en, _countsOnly), isNull);
      expect(teamUsageCostLabel(en, _countsOnly), isNull);
      expect(teamUsageTokensLabel(en, _countsOnly), isNull);
      expect(teamUsageTokens(_countsOnly), isNull);
    });

    test('writes tokens compactly', () {
      expect(teamCompactCount(0), '0');
      expect(teamCompactCount(980), '980');
      expect(teamCompactCount(1000), '1.0k');
      expect(teamCompactCount(12400), '12.4k');
      expect(teamCompactCount(1200000), '1.2M');
      expect(teamUsageTokens(_richUsage), 12400);
      expect(teamUsageTokensLabel(en, _richUsage), '12.4k tokens');
      // Either side alone still counts.
      expect(
        teamUsageTokensLabel(en, const OrchestrationUsage(outputTokens: 12)),
        '12 tokens',
      );
    });

    test('every cost carries "est." (05-beads TEAM-113)', () {
      expect(teamUsageCostLabel(en, _richUsage), r'$0.42 est.');
      expect(
        teamUsageCostLabel(en, const OrchestrationUsage(costUsd: 0)),
        r'$0.00 est.',
      );
      expect(
        teamUsageCostLabel(en, const OrchestrationUsage(costUsd: 0.004)),
        r'$0.004 est.',
      );
      expect(
        teamUsageCostLabel(en, const OrchestrationUsage(costUsd: 12.5)),
        r'$12.50 est.',
      );
      // A figure without an estimate source still says est.: the plugin
      // never shows a cost as if it were a bill.
      expect(
        teamUsageCostLabel(
          en,
          const OrchestrationUsage(costUsd: 1, raw: {'source': 'billing'}),
        ),
        r'$1.00 est.',
      );
      for (final l10n in [en, ar]) {
        expect(
          teamUsageLabel(l10n, _richUsage),
          contains(l10n.teamUiUsageCostEstimated(r'$0.42')),
        );
      }
    });

    test('joins cost and tokens, either alone', () {
      expect(teamUsageLabel(en, _richUsage), r'$0.42 est. · 12.4k tokens');
      expect(
        teamUsageLabel(en, const OrchestrationUsage(costUsd: 0.42)),
        r'$0.42 est.',
      );
      expect(
        teamUsageLabel(en, const OrchestrationUsage(inputTokens: 500)),
        '500 tokens',
      );
    });

    test('Arabic keeps Latin figures and the suffix after the amount', () {
      final label = teamUsageLabel(ar, _richUsage)!;
      expect(label, contains(r'$0.42'));
      expect(label, contains('12.4k'));
      expect(label, isNot(matches(arabicIndicDigits)));
      expect(
        label,
        '${ar.teamUiUsageCostEstimated(r'$0.42')}'
        '$teamUsageSeparator${ar.teamUiUsageTokens('12.4k')}',
      );
      expect(ar.teamUiUsageCostEstimated(r'$0.42'), startsWith(r'$0.42 '));
      expect(ar.teamUiUsageChip(label), contains(label));
      expect(ar.teamUiUsageChip(label), isNot(en.teamUiUsageChip(label)));
    });
  });

  group('capabilities', () {
    test('Gas City read path includes usage; the front keeps it', () {
      expect(OrchestrationCapabilities.gascityRead.usage, isTrue);
      expect(OrchestrationCapabilities.gascityFront.usage, isTrue);
      expect(OrchestrationCapabilities.fixture.usage, isTrue);
      expect(OrchestrationCapabilities.none.usage, isFalse);
    });
  });

  group('surfaces', () {
    late String fixturePath;
    late OrchestrationStore store;
    late DateTime clock;

    setUp(() async {
      fixturePath = _findFixtureRoot().path;
      SharedPreferences.setMockInitialValues({});
      store = OrchestrationStore(await SharedPreferences.getInstance());
      clock = DateTime.utc(2026, 9, 11, 9, 41);
    });

    OrchestrationRun run({Map<String, Object?> extraRaw = const {}}) =>
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions',
          state: RunState.working,
          rawState: 'open',
          kind: RunKind.batch,
          stepCount: 3,
          completedSteps: 1,
          startedAt: clock.subtract(const Duration(hours: 3)),
          updatedAt: clock,
          raw: {'id': 'oc-xru', 'issue_type': 'convoy', ...extraRaw},
        );

    OrchestrationAgent fox({int? context = 63}) => OrchestrationAgent(
      id: 'fox',
      name: 'fox',
      state: AgentState.working,
      rawState: 'active',
      sessionId: 'bl-5qc',
      pool: 'gastown.polecat',
      provider: 'opencode',
      currentWorkId: 'w2',
      contextPercent: context,
      workDir: '/home/eslam/city/.gc/worktrees/ocproof/polecats/fox',
      branch: 'polecat/oc-cq6',
      sessionStartedAt: clock.subtract(const Duration(hours: 3)),
      raw: const {'id': 'bl-5qc'},
    );

    Future<(OrchestrationController, _Gateway)> boot({
      OrchestrationUsage? usage = _richUsage,
      OrchestrationCapabilities? capabilities,
      OrchestrationRun? runOverride,
      int? context = 63,
      bool fixtureUsage = false,
    }) async {
      final gateway = _Gateway(
        FixtureOrchestrationGateway(fixturePath: fixturePath),
      );
      gateway
        ..capabilitiesOverride = capabilities
        ..usageOverride = fixtureUsage ? null : (() async => usage)
        ..runsOverride = [runOverride ?? run()]
        ..workOverride = const [
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
        ]
        ..agentsOverride = [fox(context: context)];
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
        gatewayFactory: (_, _) => gateway,
        now: () => clock,
      );
      addTearDown(controller.dispose);
      await controller.start();
      return (controller, gateway);
    }

    Widget app(Widget home, {Locale locale = const Locale('en')}) =>
        MaterialApp(
          theme: AppTheme.dark(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        );

    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      Locale locale = const Locale('en'),
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(home, locale: locale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Finder key(String name) => find.byKey(ValueKey(name));

    String text(WidgetTester tester, Finder finder) => tester
        .widget<Text>(find.descendant(of: finder, matching: find.byType(Text)))
        .data!;

    group('run Overview chip', () {
      testWidgets('after the count chips with the fixture usage', (
        tester,
      ) async {
        final (controller, _) = await boot(fixtureUsage: true);
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        );
        // The recorded `/usage` counted nothing yet but reported it: an
        // honest zero, still estimated.
        expect(controller.snapshot.usage, isNotNull);
        expect(controller.snapshot.usage!.isEstimated, isTrue);
        expect(key('team-run-usage'), findsOneWidget);
        expect(
          text(tester, key('team-run-usage')),
          r'Team today · $0.00 est. · 0 tokens',
        );
        expect(
          tester.getTopLeft(key('team-run-usage')).dy,
          greaterThan(tester.getBottomLeft(key('team-run-counts')).dy - 1),
        );
        expect(
          tester.getTopLeft(key('team-run-usage')).dy,
          lessThan(tester.getTopLeft(key('team-run-batch')).dy),
        );
      });

      testWidgets('names the team, the estimated cost and the tokens', (
        tester,
      ) async {
        final (controller, _) = await boot();
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        );
        expect(
          text(tester, key('team-run-usage')),
          r'Team today · $0.42 est. · 12.4k tokens',
        );
      });

      testWidgets('is absent when /usage returned nothing', (tester) async {
        final (controller, _) = await boot(usage: null);
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        );
        expect(controller.snapshot.usage, isNull);
        expect(key('team-run-counts'), findsOneWidget);
        expect(key('team-run-usage'), findsNothing);
        expect(find.textContaining('est.'), findsNothing);
      });

      testWidgets('is absent when usage carries only counts', (tester) async {
        final (controller, _) = await boot(usage: _countsOnly);
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        );
        expect(key('team-run-usage'), findsNothing);
        expect(find.textContaining('est.'), findsNothing);
      });

      testWidgets('is absent when the usage capability is off', (tester) async {
        final (controller, _) = await boot(
          capabilities: const OrchestrationCapabilities(
            projects: true,
            runs: true,
            runSteps: true,
            workGraph: true,
            agents: true,
            gatesInteractions: true,
            gatesBeads: true,
          ),
        );
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        );
        expect(controller.capabilities.usage, isFalse);
        expect(key('team-run-usage'), findsNothing);
      });

      testWidgets('prefers a per-run figure when the run carries one', (
        tester,
      ) async {
        final (controller, _) = await boot(
          runOverride: run(
            extraRaw: const {
              'usage': {
                'input_tokens': 700,
                'output_tokens': 250,
                'cost_usd_estimate': 0.07,
              },
            },
          ),
        );
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        );
        expect(text(tester, key('team-run-usage')), r'$0.07 est. · 950 tokens');
        expect(find.textContaining('Team today'), findsNothing);
      });

      testWidgets('Arabic: the chip reads right to left with Latin figures', (
        tester,
      ) async {
        final (controller, _) = await boot();
        await pump(
          tester,
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
          locale: const Locale('ar'),
        );
        final label = text(tester, key('team-run-usage'));
        expect(label, ar.teamUiUsageChip(teamUsageLabel(ar, _richUsage)!));
        expect(label, contains(r'$0.42'));
        expect(label, isNot(matches(arabicIndicDigits)));
        expect(
          Directionality.of(tester.element(key('team-run-usage'))),
          TextDirection.rtl,
        );
        // The chip sits at the start edge: on the right in RTL.
        final chip = tester.getRect(
          find.descendant(
            of: key('team-run-usage'),
            matching: find.byType(Container),
          ),
        );
        final counts = tester.getRect(key('team-run-counts'));
        expect(chip.right, moreOrLessEquals(counts.right, epsilon: 1));
      });
    });

    group('agent Runtime line', () {
      testWidgets('tokens · context · cost with the hint', (tester) async {
        final (controller, _) = await boot();
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        );
        expect(key('team-agent-usage-row'), findsOneWidget);
        expect(find.text('Tokens / context / cost'), findsOneWidget);
        expect(
          find.text(r'12.4k tokens · ctx 63% · $0.42 est.'),
          findsOneWidget,
        );
        expect(key('team-agent-usage-hint'), findsOneWidget);
        // Inside Runtime, after the branch row, before Current work.
        expect(
          find.descendant(
            of: key('team-agent-runtime'),
            matching: key('team-agent-usage'),
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(key('team-agent-usage')).dy,
          greaterThan(tester.getTopLeft(key('team-agent-context-row')).dy),
        );
        expect(
          tester.getTopLeft(key('team-agent-usage')).dy,
          lessThan(tester.getTopLeft(key('team-agent-work')).dy),
        );
      });

      testWidgets('skips the context part when the agent has none', (
        tester,
      ) async {
        final (controller, _) = await boot(context: null);
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        );
        expect(find.text(r'12.4k tokens · $0.42 est.'), findsOneWidget);
      });

      testWidgets('with the fixture usage: an honest zero', (tester) async {
        final (controller, _) = await boot(fixtureUsage: true);
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        );
        expect(find.text(r'0 tokens · ctx 63% · $0.00 est.'), findsOneWidget);
      });

      testWidgets('is absent when /usage returned nothing', (tester) async {
        final (controller, _) = await boot(usage: null);
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        );
        expect(key('team-agent-context-row'), findsOneWidget);
        expect(key('team-agent-usage'), findsNothing);
        expect(key('team-agent-usage-hint'), findsNothing);
        expect(find.textContaining('est.'), findsNothing);
      });

      testWidgets('is absent when usage carries only counts', (tester) async {
        final (controller, _) = await boot(usage: _countsOnly);
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        );
        expect(key('team-agent-usage'), findsNothing);
        expect(find.textContaining('est.'), findsNothing);
      });

      testWidgets('is absent when the usage capability is off', (tester) async {
        final (controller, _) = await boot(
          capabilities: const OrchestrationCapabilities(
            projects: true,
            runs: true,
            agents: true,
            agentOutput: true,
          ),
        );
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        );
        expect(key('team-agent-usage-row'), findsNothing);
      });

      testWidgets('Arabic: the line and its hint are translated', (
        tester,
      ) async {
        final (controller, _) = await boot();
        await pump(
          tester,
          AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
          locale: const Locale('ar'),
        );
        expect(find.text(ar.teamUiUsageRuntimeLabel), findsOneWidget);
        expect(find.text(ar.teamUiUsageRuntimeHint), findsOneWidget);
        final value = tester
            .widget<Text>(
              find
                  .descendant(
                    of: key('team-agent-usage'),
                    matching: find.byType(Text),
                  )
                  .last,
            )
            .data!;
        expect(value, contains(r'$0.42'));
        expect(value, contains(ar.teamUiAgentContextShort(63)));
        expect(value, isNot(matches(arabicIndicDigits)));
      });
    });
  });
}
