// Gallery of slice-close-team (review-board closure, team area): the
// Start-a-task sheet when the planner is off and the host has no direct
// path, a merged task's Merge section, Task details' stage line for a task
// whose last step is still in review, a team-home question row whose answer
// is not confirmed, and a worker page whose only dependency is closed. At
// 412x915 dark and 1280x800 light, with the app's real fonts.
//
// Regenerate deliberately and look at every changed image:
//   flutter test --update-goldens test/revamp/slice_close_team_golden_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/merge_section.dart';
import 'package:opencode_mobile/ui/screens/team/start_run_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/task_details_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

final _clock = DateTime.utc(2026, 9, 28, 12, 30);
const _runId = 'oc-xru';

/// A front host over fixed lists, every control on, merge roles. Gate
/// answers are left unconfirmed (no echo), so their receipt shows.
class _Gateway implements OrchestrationGateway, OrchestrationMergeGateway {
  final runList = <OrchestrationRun>[];
  final workList = <WorkItem>[];
  final agentList = <OrchestrationAgent>[];
  final gateList = <OrchestrationGate>[];
  MergeReadiness? readiness;
  final _stream = StreamController<OrchestrationEvent>.broadcast();
  bool _closed = false;

  @override
  OrchestrationCapabilities get capabilities =>
      OrchestrationCapabilities.gascityFront;

  @override
  OrchestrationHostIdentity? get host => const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://127.0.0.1:8373',
    hostMode: OrchestrationHostMode.computer,
  );

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    await _stream.close();
  }

  @override
  Future<List<OrchestrationProject>> projects() async => const [];
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => runList;
  @override
  Future<OrchestrationRun?> run(String id) async => null;
  @override
  Future<List<WorkItem>> work({String? projectId}) async => workList;
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) async => const [];
  @override
  Future<WorkItem?> workItem(String id) async => null;
  @override
  Future<List<OrchestrationAgent>> agents() async => agentList;
  @override
  Future<OrchestrationAgent?> agent(String id) async => null;
  @override
  Future<List<OrchestrationGate>> gates() async => gateList;
  @override
  Future<OrchestrationUsage?> usage() async => null;
  @override
  Future<List<ActivityEvent>> activity({
    int? afterSeq,
    int limit = 100,
  }) async => const [];
  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => _stream.stream;

  MutationReceipt _ok(String requestId) => MutationReceipt(
    id: requestId,
    status: MutationReceiptStatus.accepted,
    upstreamStatus: 200,
  );

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) async =>
      MutationReceipt(id: requestId, status: MutationReceiptStatus.pending);
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MergeReadiness?> mergeReadiness(String runId) async => readiness;
  @override
  Future<MutationReceipt> approveMerge(
    String mergeRequestId, {
    required String requestId,
  }) async => _ok(requestId);
  @override
  Future<MutationReceipt> merge(
    String runId, {
    required String requestId,
  }) async => _ok(requestId);
}

final _run = OrchestrationRun(
  id: _runId,
  title: 'Offline-first sessions',
  state: RunState.completed,
  rawState: 'open',
  kind: RunKind.batch,
  stepCount: 2,
  completedSteps: 2,
  startedAt: _clock.subtract(const Duration(hours: 3)),
  updatedAt: _clock,
  raw: const {'id': _runId, 'issue_type': 'convoy'},
);

final _asking = OrchestrationRun(
  id: 'oc-ask',
  title: 'Add a dark mode toggle',
  state: RunState.blocked,
  rawState: 'open',
  kind: RunKind.batch,
  stepCount: 1,
  startedAt: _clock.subtract(const Duration(hours: 1)),
  updatedAt: _clock.subtract(const Duration(minutes: 3)),
  raw: const {'id': 'oc-ask', 'issue_type': 'convoy'},
);

final _askingToo = OrchestrationRun(
  id: 'oc-ask2',
  title: 'Rename the export button',
  state: RunState.blocked,
  rawState: 'open',
  kind: RunKind.batch,
  stepCount: 1,
  startedAt: _clock.subtract(const Duration(hours: 2)),
  updatedAt: _clock.subtract(const Duration(minutes: 9)),
  raw: const {'id': 'oc-ask2', 'issue_type': 'convoy'},
);

final _work = [
  WorkItem(
    id: 'oc-w1',
    title: 'Storage layer',
    state: WorkState.completed,
    runId: _runId,
    assignee: 'a-wolf',
    createdAt: _clock.subtract(const Duration(hours: 3)),
    updatedAt: _clock.subtract(const Duration(hours: 1)),
  ),
  WorkItem(
    id: 'oc-w2',
    title: 'Sync engine',
    state: WorkState.working,
    runId: _runId,
    assignee: 'a-wolf',
    dependsOn: const ['oc-w1'],
    createdAt: _clock.subtract(const Duration(hours: 3)),
    updatedAt: _clock.subtract(const Duration(minutes: 20)),
  ),
  WorkItem(
    id: 'oc-a1',
    title: 'Add a dark mode toggle',
    state: WorkState.needsInput,
    runId: 'oc-ask',
    assignee: 'a-fox',
    createdAt: _clock.subtract(const Duration(hours: 1)),
    updatedAt: _clock.subtract(const Duration(minutes: 3)),
  ),
  WorkItem(
    id: 'oc-b1',
    title: 'Rename the export button',
    state: WorkState.needsInput,
    runId: 'oc-ask2',
    assignee: 'a-fox',
    createdAt: _clock.subtract(const Duration(hours: 2)),
    updatedAt: _clock.subtract(const Duration(minutes: 9)),
  ),
];

final _wolf = OrchestrationAgent(
  id: 'a-wolf',
  name: 'ocproof/polecat-1',
  state: AgentState.working,
  sessionId: 'bl-5qc',
  currentWorkId: 'oc-w2',
);

OrchestrationAgent _mayor() => const OrchestrationAgent(
  id: 'gastown.mayor',
  name: 'gastown.mayor',
  state: AgentState.stopped,
  rawState: 'suspended',
);

final _gate = OrchestrationGate(
  id: 'req-safe',
  kind: GateKind.confirmation,
  rawKind: 'confirmation',
  title: 'Keep the old toggle?',
  prompt: 'The settings screen already has a theme switch.',
  agentId: 'a-fox',
  workId: 'oc-a1',
  runId: 'oc-ask',
  createdAt: _clock.subtract(const Duration(minutes: 3)),
  raw: const {'request_id': 'req-safe', 'session_id': 'bl-7'},
);

final _gateToo = OrchestrationGate(
  id: 'req-name',
  kind: GateKind.choice,
  rawKind: 'choice',
  title: 'Which name should it use?',
  prompt: 'Export or Share.',
  agentId: 'a-fox',
  workId: 'oc-b1',
  runId: 'oc-ask2',
  createdAt: _clock.subtract(const Duration(minutes: 9)),
  raw: const {'request_id': 'req-name', 'session_id': 'bl-8'},
);

MergeReadiness _merged() => MergeReadiness(
  runId: _runId,
  ready: true,
  rig: 'ocproof',
  targetBranch: 'main',
  lines: const [
    MergeReadinessLine(key: 'work', ok: true, detail: '2/2 work items'),
    MergeReadinessLine(key: 'tests', ok: true, detail: 'passed'),
    MergeReadinessLine(key: 'build', ok: true, detail: 'passed'),
    MergeReadinessLine(key: 'review', ok: true, detail: 'approved'),
    MergeReadinessLine(key: 'conflicts', ok: true, detail: 'merges cleanly'),
  ],
  files: 14,
  additions: 841,
  deletions: 203,
  changes: const [],
  boundaries: const [],
  mergeRequest: const MergeRequestInfo(
    id: 'gc-mr-14',
    title: 'Offline-first sessions',
  ),
  branches: const [],
  mergeCommit: '4f9c2a1d07b3e',
);

Future<OrchestrationController> _controller(
  OrchestrationStore store, {
  List<WorkItem>? work,
}) async {
  final gateway = _Gateway()
    ..runList.addAll([_run, _asking, _askingToo])
    ..workList.addAll(work ?? _work)
    ..agentList.addAll([_wolf, _mayor()])
    ..gateList.addAll([_gate, _gateToo])
    ..readiness = _merged();
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.gascity,
    url: 'http://127.0.0.1:8373',
    city: 'bright-lights',
    front: true,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final controller = OrchestrationController(
    profile: ServerProfile(
      id: 'srv-1',
      name: 'Workstation',
      baseUrl: 'https://server.example:4096',
      orchestration: config,
    ),
    config: config,
    store: store,
    gatewayFactory: (_, _) => gateway,
    probe: (_) async => ProbeFound(
      host: gateway.host!,
      front: true,
      identityAllowed: true,
      capabilities: OrchestrationCapabilities.gascityFront,
    ),
    now: () => _clock,
  );
  await controller.start();
  return controller;
}

enum _Scene { plannerOff, merged, stage, receipt, agent }

Future<void> _golden(
  WidgetTester tester,
  String name, {
  required Size size,
  required bool light,
  required OrchestrationController controller,
  Widget? body,
  Future<void> Function(BuildContext context)? open,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final host = GlobalKey();
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
          home: body ?? Scaffold(key: host, body: const SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    if (open != null) {
      unawaited(open(host.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.stop();
    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  late OrchestrationStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  for (final (size, light) in const [
    (Size(412, 915), false),
    (Size(1280, 800), true),
  ]) {
    final sized = size.width == 412
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    final mode = light ? 'light' : 'dark';
    for (final scene in _Scene.values) {
      final name = 'close_team_${scene.name}${sized}_$mode';
      testWidgets(name, (tester) async {
        final controller = await _controller(
          store,
          // Task details: the last step waits in review, the first merged.
          work: scene == _Scene.merged
              ? [
                  _work[0],
                  WorkItem(
                    id: 'oc-w2',
                    title: 'Sync engine',
                    state: WorkState.completed,
                    runId: _runId,
                    assignee: 'a-wolf',
                    dependsOn: const ['oc-w1'],
                    createdAt: _clock.subtract(const Duration(hours: 3)),
                    updatedAt: _clock.subtract(const Duration(minutes: 20)),
                  ),
                ]
              : scene == _Scene.stage
              ? [
                  _work[0],
                  WorkItem(
                    id: 'oc-w2',
                    title: 'Sync engine',
                    state: WorkState.review,
                    runId: _runId,
                    assignee: 'a-wolf',
                    dependsOn: const ['oc-w1'],
                    createdAt: _clock.subtract(const Duration(hours: 3)),
                    updatedAt: _clock.subtract(const Duration(minutes: 20)),
                  ),
                ]
              : null,
        );
        if (scene == _Scene.receipt) {
          // Both answers go unconfirmed: the carded question and the
          // question row under it.
          await controller.answerGate(
            'req-safe',
            const GateResponse.confirmation(confirmed: true),
          );
          await controller.answerGate(
            'req-name',
            const GateResponse.choice('Share'),
          );
        }
        switch (scene) {
          case _Scene.plannerOff:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              controller: controller,
              open: (context) => showStartRunSheet(context, controller),
            );
          case _Scene.merged:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              controller: controller,
              body: Scaffold(
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      TeamMergeSection(
                        controller: controller,
                        run: _run,
                        now: () => _clock,
                      ),
                    ],
                  ),
                ),
              ),
            );
          case _Scene.stage:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              controller: controller,
              open: (context) => showTeamTaskDetails(
                context,
                controller,
                _runId,
                now: () => _clock,
              ),
            );
          case _Scene.receipt:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              controller: controller,
              body: TeamHomeScreen(controller: controller, now: () => _clock),
            );
          case _Scene.agent:
            await _golden(
              tester,
              name,
              size: size,
              light: light,
              controller: controller,
              body: AgentScreen(
                controller: controller,
                agentId: 'a-wolf',
                now: () => _clock,
              ),
            );
        }
      });
    }
  }
}
