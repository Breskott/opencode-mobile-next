// Shared by slice-P4.1c's behaviour test and gallery: a Gas City front
// fake that records every write (and can refuse them), and a controller
// booted on one failed task with its worker fox.
import 'dart:async';

import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';

class P41cCall {
  const P41cCall(this.verb, this.target, {this.arg});

  final String verb;
  final String target;
  final Object? arg;
}

class P41cGateway
    implements OrchestrationGateway, OrchestrationAgentOutputGateway {
  P41cGateway({required this.capabilities});

  @override
  final OrchestrationCapabilities capabilities;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  final calls = <P41cCall>[];
  List<OrchestrationRun> runList = const [];
  List<WorkItem> workList = const [];
  List<OrchestrationAgent> agentList = const [];
  List<OrchestrationGate> gateList = const [];
  bool _closed = false;

  @override
  OrchestrationHostIdentity? get host => const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://127.0.0.1:8373',
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.computer,
  );

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    await stream.close();
  }

  /// When set, the host refuses every write with these words.
  String? refuse;

  Future<MutationReceipt> _call(P41cCall call, String requestId) {
    calls.add(call);
    final refusal = refuse;
    if (refusal != null) {
      return Future.value(MutationReceipt.rejected(requestId, refusal));
    }
    return Future.value(
      MutationReceipt(
        id: requestId,
        status: MutationReceiptStatus.accepted,
        correlationId: 'corr-$requestId',
        upstreamStatus: 202,
      ),
    );
  }

  @override
  Future<List<OrchestrationProject>> projects() async => const [
    OrchestrationProject(id: 'ocproof', name: 'ocproof', rig: 'ocproof'),
  ];
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => runList;
  @override
  Future<OrchestrationRun?> run(String id) async {
    for (final r in runList) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<WorkItem>> work({String? projectId}) async => workList;
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) async => [
    for (final w in workList)
      if (w.state == WorkState.ready) w,
  ];
  @override
  Future<WorkItem?> workItem(String id) async {
    for (final w in workList) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<List<OrchestrationAgent>> agents() async => agentList;
  @override
  Future<OrchestrationAgent?> agent(String id) async {
    for (final a in agentList) {
      if (a.id == id) return a;
    }
    return null;
  }

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
  }) => stream.stream;
  @override
  Stream<AgentOutputEvent> agentOutput(String sessionId) =>
      const Stream.empty();

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) => _call(P41cCall('respond', gateId, arg: response), requestId);
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => _call(P41cCall('message', agentId, arg: text), requestId);
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) => _call(P41cCall('controlAgent', agentId, arg: action), requestId);
  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => _call(P41cCall('cancelRun', runId), requestId);
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => _call(P41cCall('assign', workId, arg: agentId), requestId);
  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => _call(P41cCall('createWork', title), requestId);
}

final p41cClock = DateTime.utc(2026, 9, 11, 9, 41);

/// Boots a controller on [gates] against a fresh [P41cGateway]. Records
/// are stamped with the real time the kit's receipt timer reads, so a fresh
/// answer reads "Sending…".
Future<(OrchestrationController, P41cGateway)> p41cBoot(
  OrchestrationStore store, {
  OrchestrationCapabilities capabilities =
      OrchestrationCapabilities.gascityFront,
  List<OrchestrationGate> gates = const [],
}) async {
  var nextKey = 0;
  final gateway = P41cGateway(capabilities: capabilities)
    ..runList = [
      OrchestrationRun(
        id: 'oc-xru',
        title: 'Offline-first sessions',
        state: RunState.failed,
        kind: RunKind.formula,
        stepCount: 3,
        completedSteps: 1,
        startedAt: p41cClock.subtract(const Duration(hours: 1)),
      ),
    ]
    ..workList = const [
      WorkItem(
        id: 'w2',
        title: 'Sync engine',
        state: WorkState.blocked,
        runId: 'oc-xru',
        assignee: 'fox',
      ),
    ]
    ..agentList = [
      OrchestrationAgent(
        id: 'fox',
        name: 'fox',
        state: AgentState.working,
        rawState: 'active',
        sessionId: 'bl-5qc',
        currentWorkId: 'w2',
        sessionStartedAt: p41cClock.subtract(const Duration(hours: 3)),
      ),
    ]
    ..gateList = gates;
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
      name: 'Development PC',
      baseUrl: 'https://server.example:4096',
      orchestration: config,
    ),
    config: config,
    store: store,
    probe: (_) async => ProbeFound(
      host: gateway.host!,
      city: 'bright-lights',
      front: true,
      identityAllowed: true,
      capabilities: gateway.capabilities,
    ),
    gatewayFactory: (_, _) => gateway,
    now: DateTime.now,
    mintKey: () => 'key-${++nextKey}',
    refreshDebounce: const Duration(milliseconds: 10),
  );
  await controller.start();
  return (controller, gateway);
}
