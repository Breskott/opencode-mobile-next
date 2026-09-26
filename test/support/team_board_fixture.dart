// A believable AI Team board for tests and goldens
// (docs/design/team-board-2026-09-26.md): one project's 16 tasks across the
// five columns — an epic with five children (two done), a task blocked by
// another, one that needs the person, one stopped with an error, urgent /
// high / low priorities, a bug and a feature — plus the host's bookkeeping
// (a session bead, an order wisp, an order-run chore, a convoy, a molecule,
// a gate bead) and a task finished ten days ago, none of which may show.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/domain/orchestration_work_edits.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:opencode_mobile/ui/screens/team/team_board_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The board's clock.
final boardClock = DateTime.utc(2026, 9, 26, 9, 41);

const boardProject = 'oc_app';
const boardOtherProject = 'website';
const boardPool = '$boardProject/gastown.polecat';

/// Titles of the host's bookkeeping beads: never on the board.
const boardBookkeepingTitles = [
  'polecat fox session',
  'order:phone-upkeep',
  'Upkeep patrol run',
  'sling-bd-7',
  'mol-refinery-patrol',
  'Approve the merge?',
  'Rotate the logs (ten days ago)',
];

enum BoardScene {
  /// The 16 tasks, every column filled.
  loaded,

  /// The host answers with nothing on the board.
  empty,

  /// The host cannot be reached.
  failed,

  /// The first answer never comes.
  connecting,

  /// [loaded] on a host that allows no writes.
  readOnly,
}

/// One edit the board sent.
class BoardEditCall {
  const BoardEditCall(this.verb, this.workId, [this.arg]);
  final String verb;
  final String workId;
  final Object? arg;

  @override
  String toString() => 'BoardEditCall($verb $workId ${arg ?? ''})';
}

DateTime _ago(Duration d) => boardClock.subtract(d);

Map<String, Object?> _raw({
  String type = 'task',
  int priority = 2,
  String? routedTo,
  String? assignee,
  List<String> labels = const [],
  bool ephemeral = false,
  Map<String, String> metadata = const {},
}) => {
  'issue_type': type,
  'priority': priority,
  'assignee': ?assignee,
  'labels': labels,
  if (ephemeral) 'ephemeral': true,
  'metadata': {'gc.routed_to': ?routedTo, 'rig': boardProject, ...metadata},
};

WorkItem _item(
  String id,
  String title,
  WorkState state, {
  Duration age = const Duration(minutes: 30),
  String? runId = 'oc-xru',
  String? parentId,
  String? sessionId,
  bool isBlocked = false,
  List<String> dependsOn = const [],
  List<String> labels = const [],
  String? closedReason,
  String project = boardProject,
  Map<String, Object?> raw = const {},
}) => WorkItem(
  id: id,
  title: title,
  state: state,
  projectId: project,
  runId: runId,
  parentId: parentId,
  sessionId: sessionId,
  isBlocked: isBlocked,
  dependsOn: dependsOn,
  labels: labels,
  closedReason: closedReason,
  updatedAt: _ago(age),
  createdAt: _ago(age + const Duration(hours: 1)),
  raw: raw,
);

/// The 16 tasks and the bookkeeping.
List<WorkItem> boardWork() => [
  // Backlog
  _item(
    'bd-dark',
    'Dark mode for the settings screens',
    WorkState.queued,
    age: const Duration(days: 2),
    runId: null,
    raw: _raw(type: 'feature', priority: 3),
  ),
  _item(
    'bd-crash',
    'Crash when a photo is over 20 MB',
    WorkState.queued,
    age: const Duration(hours: 3),
    runId: null,
    raw: _raw(type: 'bug', priority: 1),
  ),
  _item(
    'bd-epic',
    'Offline drafts',
    WorkState.queued,
    age: const Duration(hours: 1),
    runId: null,
    raw: _raw(type: 'epic'),
  ),
  _item(
    'bd-tests',
    'Tests for reconnect',
    WorkState.blocked,
    age: const Duration(hours: 5),
    runId: null,
    isBlocked: true,
    dependsOn: const ['bd-sync'],
    raw: _raw(),
  ),
  // Ready
  _item(
    'bd-rename',
    'Rename the Work tab to Home',
    WorkState.ready,
    age: const Duration(minutes: 8),
    raw: _raw(routedTo: boardPool),
  ),
  _item(
    'bd-conflict',
    'Conflict policy for offline edits',
    WorkState.ready,
    age: const Duration(minutes: 20),
    parentId: 'bd-epic',
    raw: _raw(routedTo: boardPool, priority: 1),
  ),
  // Working
  _item(
    'bd-sync',
    'Sync engine for offline drafts',
    WorkState.working,
    age: const Duration(minutes: 2),
    parentId: 'bd-epic',
    sessionId: 'bl-5qc',
    raw: _raw(routedTo: boardPool, assignee: 'fox'),
  ),
  _item(
    'bd-schema',
    'Schema for offline drafts',
    WorkState.needsInput,
    age: const Duration(minutes: 12),
    parentId: 'bd-epic',
    sessionId: 'bl-7wr',
    raw: _raw(routedTo: boardPool, assignee: 'wolf'),
  ),
  _item(
    'bd-http',
    'Upgrade the HTTP client and fix what breaks',
    WorkState.working,
    age: const Duration(minutes: 4),
    runId: 'mol-upgrade',
    sessionId: 'bl-9mo',
    raw: _raw(routedTo: boardPool, assignee: 'mole', priority: 0),
  ),
  _item(
    'bd-cold',
    'Speed up cold start',
    WorkState.failed,
    age: const Duration(minutes: 40),
    sessionId: 'bl-2ow',
    raw: _raw(
      routedTo: boardPool,
      assignee: 'owl',
      metadata: {'last_error': 'usage limit reached'},
    ),
  ),
  // Review
  _item(
    'bd-voice',
    'Voice notes in the composer',
    WorkState.review,
    age: const Duration(minutes: 25),
    labels: const ['needs-review'],
    raw: _raw(type: 'feature', assignee: 'oc_app/gastown.refinery'),
  ),
  _item(
    'bd-pull',
    'Pull to refresh on All conversations',
    WorkState.review,
    age: const Duration(hours: 2),
    labels: const ['needs-review'],
    raw: _raw(assignee: 'oc_app/gastown.refinery'),
  ),
  // Done
  _item(
    'bd-hello',
    'Create hello.py that prints Hello from the AI Team',
    WorkState.completed,
    age: const Duration(hours: 5),
    runId: 'ma-lqw',
    raw: _raw(),
  ),
  _item(
    'bd-storage',
    'Storage layer for offline drafts',
    WorkState.completed,
    age: const Duration(hours: 20),
    parentId: 'bd-epic',
    raw: _raw(),
  ),
  _item(
    'bd-model',
    'Draft model and migrations',
    WorkState.completed,
    age: const Duration(days: 1, hours: 2),
    parentId: 'bd-epic',
    raw: _raw(),
  ),
  _item(
    'bd-flaky',
    'Old flaky test cleanup',
    WorkState.cancelled,
    age: const Duration(days: 2),
    runId: null,
    closedReason: 'cancelled',
    raw: _raw(type: 'chore'),
  ),
  // Another project's task: only on its own board.
  _item(
    'site-hero',
    'New hero image on the landing page',
    WorkState.queued,
    project: boardOtherProject,
    runId: null,
    raw: _raw(),
  ),
  // The host's bookkeeping: never on the board.
  _item(
    'bk-session',
    boardBookkeepingTitles[0],
    WorkState.working,
    raw: _raw(type: 'session', labels: const ['gc:session']),
  ),
  _item(
    'bk-order',
    boardBookkeepingTitles[1],
    WorkState.working,
    runId: null,
    raw: _raw(type: 'task', ephemeral: true),
  ),
  _item(
    'bk-order-run',
    boardBookkeepingTitles[2],
    WorkState.queued,
    runId: null,
    labels: const ['order-run:phone-upkeep-42'],
    raw: _raw(labels: const ['order-run:phone-upkeep-42']),
  ),
  _item(
    'bk-convoy',
    boardBookkeepingTitles[3],
    WorkState.working,
    raw: _raw(type: 'convoy'),
  ),
  _item(
    'bk-molecule',
    boardBookkeepingTitles[4],
    WorkState.working,
    raw: _raw(type: 'molecule'),
  ),
  _item(
    'bk-gate',
    boardBookkeepingTitles[5],
    WorkState.queued,
    raw: _raw(type: 'gate'),
  ),
  _item(
    'bk-old',
    boardBookkeepingTitles[6],
    WorkState.completed,
    age: const Duration(days: 10),
    runId: null,
    raw: _raw(),
  ),
];

/// The board's data over the recorded fixture.
class BoardData extends FixtureOrchestrationGateway {
  BoardData({required super.fixturePath, required this.scene});

  final BoardScene scene;

  @override
  OrchestrationCapabilities get capabilities => scene == BoardScene.readOnly
      ? OrchestrationCapabilities.gascityRead
      : OrchestrationCapabilities.fixture;

  @override
  Future<List<OrchestrationProject>> projects() async => const [
    OrchestrationProject(id: boardProject, name: 'oc_app'),
    OrchestrationProject(id: boardOtherProject, name: 'website'),
  ];

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async =>
      scene == BoardScene.empty
      ? const []
      : [
          OrchestrationRun(
            id: 'oc-xru',
            title: 'Offline-first sessions',
            state: RunState.working,
            kind: RunKind.batch,
            startedAt: _ago(const Duration(hours: 3)),
          ),
        ];

  @override
  Future<List<WorkItem>> work({String? projectId}) async =>
      scene == BoardScene.empty ? const [] : boardWork();

  @override
  Future<List<OrchestrationAgent>> agents() async => [
    if (scene != BoardScene.empty)
      for (final (name, work, state) in [
        ('fox', 'bd-sync', AgentState.working),
        ('wolf', 'bd-schema', AgentState.waiting),
        ('mole', 'bd-http', AgentState.working),
      ])
        OrchestrationAgent(
          id: name,
          name: name,
          state: state,
          pool: 'gastown.polecat',
          currentWorkId: work,
        ),
  ];

  @override
  Future<List<OrchestrationGate>> gates() async => scene == BoardScene.empty
      ? const []
      : [
          OrchestrationGate(
            id: 'req-schema-1',
            kind: GateKind.choice,
            title: 'Keep drafts in SQLite or in plain files?',
            workId: 'bd-schema',
            runId: 'oc-xru',
            choices: const ['SQLite', 'Plain files'],
            createdAt: _ago(const Duration(minutes: 12)),
          ),
        ];
}

/// A host that edits beads: records each edit, refuses all when [refuse]
/// is set.
class BoardGateway extends BoardData implements OrchestrationWorkEditGateway {
  BoardGateway({required super.fixturePath, required super.scene});

  /// When set, every bead edit is refused with this message.
  String? refuse;

  final edits = <BoardEditCall>[];

  MutationReceipt _edit(BoardEditCall call, String requestId) {
    edits.add(call);
    final no = refuse;
    return no == null
        ? MutationReceipt(
            id: requestId,
            status: MutationReceiptStatus.accepted,
            upstreamStatus: 200,
          )
        : MutationReceipt.rejected(requestId, no);
  }

  @override
  Future<MutationReceipt> setWorkPriority(
    String workId,
    WorkPriority priority, {
    required String requestId,
  }) async => _edit(BoardEditCall('priority', workId, priority), requestId);

  @override
  Future<MutationReceipt> unassignWork(
    String workId, {
    required String requestId,
  }) async => _edit(BoardEditCall('unassign', workId), requestId);

  @override
  Future<MutationReceipt> cancelWork(
    String workId, {
    required String requestId,
  }) async => _edit(BoardEditCall('cancel', workId), requestId);

  @override
  Future<MutationReceipt> reopenWork(
    String workId, {
    required String requestId,
  }) async => _edit(BoardEditCall('reopen', workId), requestId);
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

/// A started controller for [scene] and its gateway.
Future<(OrchestrationController, BoardData)> boardController(
  BoardScene scene,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: 'http://127.0.0.1:8472',
    city: 'phone',
    hostMode: OrchestrationHostMode.phone,
    hostKind: OrchestrationHostKind.phone,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final path = _fixtureRoot().path;
  // A read-only host has no bead edits and no controls.
  final BoardData gateway = scene == BoardScene.readOnly
      ? BoardData(fixturePath: path, scene: scene)
      : BoardGateway(fixturePath: path, scene: scene);
  final controller = OrchestrationController(
    profile: ServerProfile(
      id: 'board',
      name: 'This phone',
      baseUrl: 'http://127.0.0.1:4097',
      orchestration: config,
    ),
    config: config,
    store: OrchestrationStore(prefs),
    gatewayFactory: (_, _) => gateway,
    probe: switch (scene) {
      BoardScene.failed => (_) async => const ProbeUnreachable(
        error: 'Connection refused (http://127.0.0.1:8472)',
      ),
      BoardScene.connecting => (_) => Completer<ProbeVerdict>().future,
      _ => null,
    },
    now: () => boardClock,
  );
  if (scene == BoardScene.connecting) {
    unawaited(controller.start());
  } else {
    await controller.start();
  }
  return (controller, gateway);
}

/// The board on a phone-sized screen.
Widget boardApp(
  OrchestrationController controller, {
  ThemeData? theme,
  ValueChanged<TeamBoardCard>? onOpenCard,
  GlobalKey? boundary,
  bool disableAnimations = true,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: boundary == null
        ? child!
        : RepaintBoundary(key: boundary, child: child),
  ),
  home: TeamBoardScreen(
    controller: controller,
    now: () => boardClock,
    onOpenCard: onOpenCard,
  ),
);
