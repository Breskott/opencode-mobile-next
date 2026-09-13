// TEAM-105: per-profile plugin config, OrchestrationController, its store
// and the removal / deletion sweep, over the fixture gateway and an
// in-memory store.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
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

/// In-memory Keystore that records every delete.
class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();

  final values = <String, String>{};
  final deletes = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletes.add(key);
    values.remove(key);
  }
}

/// Wraps the fixture: counts every read, owns the event stream so a test
/// can push events, close it or fail it, and can replace the gates list.
class _CountingGateway implements OrchestrationGateway {
  _CountingGateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final calls = <String, int>{};
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationGate>? gatesOverride;
  EventCursor? resumedFrom;

  int count(String name) => calls[name] ?? 0;
  void reset() => calls.clear();
  void _hit(String name) => calls[name] = count(name) + 1;

  @override
  OrchestrationCapabilities get capabilities => inner.capabilities;

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
  Future<List<OrchestrationProject>> projects() {
    _hit('projects');
    return inner.projects();
  }

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) {
    _hit('runs');
    return inner.runs(projectId: projectId);
  }

  @override
  Future<OrchestrationRun?> run(String id) {
    _hit('run');
    return inner.run(id);
  }

  @override
  Future<List<WorkItem>> work({String? projectId}) {
    _hit('work');
    return inner.work(projectId: projectId);
  }

  @override
  Future<List<WorkItem>> readyWork({String? projectId}) {
    _hit('readyWork');
    return inner.readyWork(projectId: projectId);
  }

  @override
  Future<WorkItem?> workItem(String id) {
    _hit('workItem');
    return inner.workItem(id);
  }

  @override
  Future<List<OrchestrationAgent>> agents() {
    _hit('agents');
    return inner.agents();
  }

  @override
  Future<OrchestrationAgent?> agent(String id) {
    _hit('agent');
    return inner.agent(id);
  }

  @override
  Future<List<OrchestrationGate>> gates() async {
    _hit('gates');
    return gatesOverride ?? await inner.gates();
  }

  @override
  Future<OrchestrationUsage?> usage() {
    _hit('usage');
    return inner.usage();
  }

  @override
  Future<List<ActivityEvent>> activity({int? afterSeq, int limit = 100}) {
    _hit('activity');
    return inner.activity(afterSeq: afterSeq, limit: limit);
  }

  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) {
    resumedFrom = resumeFrom;
    return stream.stream;
  }

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
}

const _profileId = 'srv-1';
const _otherId = 'srv-2';

/// The `blocked` scenario's derived `/pending` entry.
const _blockedPending = <String, Object?>{
  'session_id': 'bl-polecat-1',
  'request_id': 'req-fixture-choice-1',
  'kind': 'choice',
  'prompt': 'calc.py already defines subtract(). Replace it, keep it, or stop?',
  'options': ['replace', 'keep', 'stop'],
  'metadata': {'bead': 'oc-loy', 'fixture.scenario': 'blocked'},
};

/// The `failed` scenario's derived `/runs` entry.
const _failedRun = <String, Object?>{
  'run_id': 'oc-loy',
  'title': 'Add subtract() to calc.py',
  'status': 'failed',
  'scope': {'kind': 'rig', 'ref': 'ocproof'},
  'target': 'ocproof/polecats',
  'started_at': '2026-09-10T10:00:00Z',
  'updated_at': '2026-09-10T10:05:00Z',
  'last_error': {'code': 'fail', 'message': 'tests failed'},
};

const _gateBead = <String, Object?>{
  'id': 'gc-gate-1',
  'title': 'Approve the release',
  'status': 'open',
  'issue_type': 'gate',
};

const _reviewBead = <String, Object?>{
  'id': 'gc-review-1',
  'title': 'Review the diff',
  'status': 'open',
  'issue_type': 'task',
  'labels': ['needs-review'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fixturePath;
  late SharedPreferences prefs;
  late _MemorySecureStorage secure;
  late OrchestrationStore store;
  late DateTime clock;

  ServerProfile profile({
    OrchestrationConfig? config,
    String id = _profileId,
  }) => ServerProfile(
    id: id,
    name: 'Workstation',
    baseUrl: 'https://server.example:4096',
    orchestration: config,
  );

  OrchestrationConfig fixtureConfig() => OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: fixturePath,
    city: 'bright-lights',
    enabledAt: DateTime.utc(2026, 9, 10),
  );

  setUp(() async {
    fixturePath = _findFixtureRoot().path;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secure = _MemorySecureStorage();
    store = OrchestrationStore(prefs, secure: secure);
    clock = DateTime.utc(2026, 9, 11, 12);
  });

  /// A controller over a counting fixture gateway; [start] is awaited.
  Future<(OrchestrationController, _CountingGateway)> boot({
    Duration debounce = const Duration(milliseconds: 400),
    int timelineLimit = 500,
    List<OrchestrationGate>? gates,
  }) async {
    final gateway = _CountingGateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath),
    )..gatesOverride = gates;
    final controller = OrchestrationController(
      profile: profile(config: fixtureConfig()),
      config: fixtureConfig(),
      store: store,
      gatewayFactory: (_, _) => gateway,
      now: () => clock,
      refreshDebounce: debounce,
      timelineLimit: timelineLimit,
    );
    addTearDown(controller.dispose);
    await controller.start();
    return (controller, gateway);
  }

  Set<String> keysFor(String id) => {
    for (final key in prefs.getKeys())
      if (key.startsWith('oc.orchestration') && key.contains('.$id.')) key,
  };

  group('OrchestrationConfig on the profile', () {
    test('round-trips through profile JSON', () {
      final config = OrchestrationConfig(
        provider: OrchestrationProvider.gascity,
        url: 'http://100.64.1.2:8080',
        city: 'bright-lights',
        hostMode: OrchestrationHostMode.phone,
        front: true,
        enabledAt: DateTime.utc(2026, 9, 10, 8, 30),
      );
      final restored = ServerProfile.fromJson(profile(config: config).toJson());
      expect(restored.orchestration, config);
      expect(restored.orchestration!.provider, OrchestrationProvider.gascity);
      expect(restored.orchestration!.hostMode, OrchestrationHostMode.phone);
      expect(restored.orchestration!.front, isTrue);
      expect(
        restored.orchestration!.enabledAt,
        DateTime.utc(2026, 9, 10, 8, 30),
      );
    });

    test('a profile stored before the plugin has it off', () {
      final restored = ServerProfile.fromJson({
        'id': 'old',
        'name': 'Old',
        'baseUrl': 'https://old.example:4096',
      });
      expect(restored.orchestration, isNull);
      expect(restored.toJson(), isNot(contains('orchestration')));
      // Corrupt or url-less entries read as off rather than crashing.
      expect(OrchestrationConfig.fromJson('garbage'), isNull);
      expect(OrchestrationConfig.fromJson({'provider': 'gascity'}), isNull);
    });

    test('missing fields take their defaults', () {
      final config = OrchestrationConfig.fromJson({
        'provider': 'fixture',
        'url': '/tmp/fixture',
      });
      expect(config, isNotNull);
      expect(config!.provider, OrchestrationProvider.fixture);
      expect(config.city, '');
      expect(config.hostMode, OrchestrationHostMode.computer);
      expect(config.hostKind, OrchestrationHostKind.pc);
      expect(config.front, isFalse);
      expect(config.enabledAt, isNull);
    });

    // TEAM-206: the kind of computer behind the disclaimer line.
    test('hostKind round-trips and defaults from hostMode when absent', () {
      for (final kind in OrchestrationHostKind.values) {
        final config = OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: 'http://100.64.1.2:8372',
          hostMode: kind.mode,
          hostKind: kind,
        );
        final json = config.toJson();
        expect(json['hostKind'], kind.name);
        expect(json['hostMode'], kind.mode.name);
        expect(OrchestrationConfig.fromJson(json), config);
        expect(
          ServerProfile.fromJson(
            profile(config: config).toJson(),
          ).orchestration,
          config,
        );
      }
      // A config stored before the field existed: the mode's default kind.
      final old = OrchestrationConfig.fromJson({
        'provider': 'gascity',
        'url': 'http://100.64.1.2:8372',
        'hostMode': 'computer',
      });
      expect(old!.hostKind, OrchestrationHostKind.pc);
      final oldPhone = OrchestrationConfig.fromJson({
        'provider': 'gascity',
        'url': 'http://100.64.1.2:8372',
        'hostMode': 'phone',
      });
      expect(oldPhone!.hostKind, OrchestrationHostKind.phone);
      // The constructor without a kind derives it the same way, and an
      // explicit default compares equal to a derived one.
      expect(
        const OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: 'u',
          hostMode: OrchestrationHostMode.phone,
        ).hostKind,
        OrchestrationHostKind.phone,
      );
      expect(
        const OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: 'u',
        ),
        const OrchestrationConfig(
          provider: OrchestrationProvider.gascity,
          url: 'u',
          hostKind: OrchestrationHostKind.pc,
        ),
      );
    });

    test('hostKind never contradicts hostMode', () {
      // An unknown name, or a kind from the other mode, in stored JSON.
      final unknown = OrchestrationConfig.fromJson({
        'provider': 'gascity',
        'url': 'http://100.64.1.2:8372',
        'hostMode': 'computer',
        'hostKind': 'mainframe',
      });
      expect(unknown!.hostKind, OrchestrationHostKind.pc);
      final crossed = OrchestrationConfig.fromJson({
        'provider': 'gascity',
        'url': 'http://100.64.1.2:8372',
        'hostMode': 'phone',
        'hostKind': 'laptop',
      });
      expect(crossed!.hostMode, OrchestrationHostMode.phone);
      expect(crossed.hostKind, OrchestrationHostKind.phone);
      // copyWith re-derives the kind when the mode changes under it and
      // keeps it when the mode stays.
      const laptop = OrchestrationConfig(
        provider: OrchestrationProvider.gascity,
        url: 'u',
        hostKind: OrchestrationHostKind.laptop,
      );
      expect(
        laptop.copyWith(hostMode: OrchestrationHostMode.phone).hostKind,
        OrchestrationHostKind.phone,
      );
      expect(laptop.copyWith(city: 'c').hostKind, OrchestrationHostKind.laptop);
      expect(
        laptop.copyWith(hostKind: OrchestrationHostKind.wsl).hostKind,
        OrchestrationHostKind.wsl,
      );
      expect(
        laptop.copyWith(hostKind: OrchestrationHostKind.phone).hostKind,
        OrchestrationHostKind.pc,
        reason: 'a phone kind on a computer mode falls back to the default',
      );
      expect(OrchestrationHostKind.fromName('wsl'), OrchestrationHostKind.wsl);
      expect(OrchestrationHostKind.fromName(null), isNull);
      for (final kind in OrchestrationHostKind.values) {
        expect(OrchestrationHostKind.forMode(kind.mode).mode, kind.mode);
      }
    });
  });

  group('lifecycle', () {
    testWidgets('start probes, connects, subscribes and refreshes', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      expect(controller.phase, OrchestrationPhase.ready);
      expect(controller.host?.provider, 'fixture');
      expect(controller.host?.city, 'bright-lights');
      expect(controller.capabilities, same(OrchestrationCapabilities.fixture));
      expect(controller.streamStatus, OrchestrationStreamStatus.live);
      expect(controller.lastError, isNull);
      expect(controller.snapshot.hasData, isTrue);
      expect(controller.snapshot.runs.map((r) => r.id), contains('oc-xru'));
      expect(controller.snapshot.work, isNotEmpty);
      expect(controller.snapshot.agents, isNotEmpty);
      expect(controller.snapshot.usage, isNotNull);
      expect(controller.timeline, isNotEmpty);
      expect(controller.lastRefreshedAt, clock);
      expect(gateway.resumedFrom, EventCursor.none);
      for (final scope in const [
        'projects',
        'runs',
        'work',
        'agents',
        'gates',
        'usage',
        'activity',
      ]) {
        expect(gateway.count(scope), 1, reason: scope);
      }
      // The snapshot and its timestamp are cached under the profile prefix.
      await tester.pump();
      expect(
        keysFor(_profileId),
        containsAll([
          'oc.orchestration.$_profileId.snapshot',
          'oc.orchestration.$_profileId.refreshedAt',
        ]),
      );
      expect(store.readSnapshot(_profileId)?.runs, isNotEmpty);
      expect(store.lastRefreshedAt(_profileId), clock);
    });

    testWidgets('stop closes the gateway and remove sweeps the store', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      await tester.pump();
      // Another profile's plugin data and a reserved secret for this one.
      await prefs.setString('oc.orchestration.$_otherId.snapshot', '{}');
      secure.values['oc.orchestration.$_profileId.grant'] = 'token';
      expect(keysFor(_profileId), isNotEmpty);

      final failures = await controller.remove();

      expect(failures, isEmpty);
      expect(controller.phase, OrchestrationPhase.stopped);
      expect(gateway.isClosed, isTrue);
      expect(controller.streamStatus, OrchestrationStreamStatus.closed);
      expect(controller.isStale, isFalse);
      expect(keysFor(_profileId), isEmpty);
      expect(
        prefs.getKeys().where((k) => k.contains(_profileId)),
        isEmpty,
        reason: 'no oc.orchestration*.<profileId> key may survive',
      );
      expect(
        secure.values,
        isNot(contains('oc.orchestration.$_profileId.grant')),
      );
      expect(secure.deletes, contains('oc.orchestration.$_profileId.grant'));
      expect(prefs.getString('oc.orchestration.$_otherId.snapshot'), '{}');
    });

    testWidgets('probe verdicts become stable error kinds', (tester) async {
      final verdicts = <ProbeVerdict, OrchestrationErrorKind>{
        const ProbeNotGasCity(statusCode: 200, detail: 'html'):
            OrchestrationErrorKind.notGasCity,
        const ProbeCityNotRunning(city: 'bright-lights'):
            OrchestrationErrorKind.cityNotRunning,
        const ProbePlainHttpRefused(host: 'example.com'):
            OrchestrationErrorKind.plainHttpRefused,
        const ProbeUnreachable(error: 'refused'):
            OrchestrationErrorKind.unreachable,
      };
      for (final entry in verdicts.entries) {
        var built = 0;
        final controller = OrchestrationController(
          profile: profile(config: fixtureConfig()),
          config: fixtureConfig(),
          store: store,
          probe: (_) async => entry.key,
          gatewayFactory: (_, _) {
            built += 1;
            return FixtureOrchestrationGateway(fixturePath: fixturePath);
          },
          now: () => clock,
        );
        addTearDown(controller.dispose);
        await controller.start();
        expect(controller.phase, OrchestrationPhase.failed);
        expect(controller.lastError?.kind, entry.value);
        expect(controller.lastError?.verdict, same(entry.key));
        expect(controller.lastError?.message, entry.key.describe());
        expect(built, 0, reason: 'no gateway after ${entry.key}');
        expect(controller.isStale, isFalse);
        expect(controller.attentionCount, 0);
        expect(keysFor(_profileId), isEmpty);
      }
    });

    testWidgets('a factory that throws is unreachable', (tester) async {
      final controller = OrchestrationController(
        profile: profile(config: fixtureConfig()),
        config: fixtureConfig(),
        store: store,
        gatewayFactory: (_, _) => throw StateError('no adapter'),
        now: () => clock,
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.phase, OrchestrationPhase.failed);
      expect(controller.lastError?.kind, OrchestrationErrorKind.unreachable);
      expect(controller.host?.provider, 'fixture');
    });
  });

  group('stale detection', () {
    testWidgets('data older than 60 s is stale', (tester) async {
      final (controller, _) = await boot();
      expect(controller.isStale, isFalse);
      clock = clock.add(const Duration(seconds: 60));
      expect(controller.isStale, isFalse);
      clock = clock.add(const Duration(seconds: 1));
      expect(controller.isStale, isTrue);
      // A refresh brings it back.
      await controller.refresh();
      expect(controller.lastRefreshedAt, clock);
      expect(controller.isStale, isFalse);
    });

    testWidgets('a stream that is not live is stale', (tester) async {
      final (controller, gateway) = await boot();
      expect(controller.isStale, isFalse);
      gateway.stream.addError(StateError('dropped'));
      await tester.pump();
      expect(controller.streamStatus, OrchestrationStreamStatus.reconnecting);
      expect(controller.isStale, isTrue);
      // A heartbeat only refreshes liveness: nothing dirty, nothing fetched.
      gateway.reset();
      gateway.stream.add(StreamHeartbeat(timestamp: clock));
      await tester.pump();
      expect(controller.streamStatus, OrchestrationStreamStatus.live);
      expect(controller.isStale, isFalse);
      expect(controller.dirtyScopes, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(gateway.calls, isEmpty);
      await gateway.stream.close();
      await tester.pump();
      expect(controller.streamStatus, OrchestrationStreamStatus.closed);
      expect(controller.isStale, isTrue);
    });
  });

  group('dirty scopes and debounce', () {
    testWidgets('BeadChanged refetches only work, runs and gates', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      gateway.reset();
      gateway.stream.add(
        const BeadChanged(
          beadId: 'oc-loy',
          change: BeadChange.updated,
          seq: 9001,
        ),
      );
      await tester.pump();
      expect(controller.dirtyScopes, {'work', 'runs', 'gates'});
      expect(controller.cursor.seq, 9001);
      expect(gateway.calls, isEmpty, reason: 'nothing before the debounce');
      await tester.pump(const Duration(milliseconds: 399));
      expect(gateway.calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(controller.dirtyScopes, isEmpty);
      expect(gateway.calls, {'work': 1, 'runs': 1, 'gates': 1});
      expect(store.readCursor(_profileId).seq, 9001);
    });

    testWidgets('a burst of events collapses into one refetch', (tester) async {
      final (controller, gateway) = await boot();
      gateway.reset();
      for (var i = 0; i < 5; i++) {
        gateway.stream.add(
          BeadChanged(beadId: 'b$i', change: BeadChange.updated, seq: 100 + i),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(gateway.calls, isEmpty, reason: 'the debounce keeps resetting');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(gateway.calls, {'work': 1, 'runs': 1, 'gates': 1});
      expect(controller.dirtyScopes, isEmpty);
    });

    testWidgets('each event kind marks its scopes', (tester) async {
      final (controller, gateway) = await boot();
      gateway.reset();
      gateway.stream.add(const RunChanged(runId: 'oc-xru', seq: 5200));
      await tester.pump();
      expect(controller.dirtyScopes, {'runs', 'run:oc-xru'});
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(gateway.calls, {'runs': 1}, reason: 'runs subsumes run:<id>');

      gateway.reset();
      gateway.stream.add(
        const SessionChanged(
          sessionId: 'bl-wisp-qqpj',
          change: SessionChange.woke,
          agentId: 'gastown.mayor',
          seq: 5201,
        ),
      );
      await tester.pump();
      expect(controller.dirtyScopes, {'agents', 'agent:gastown.mayor'});
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(gateway.calls, {'agents': 1});

      gateway.reset();
      gateway.stream.add(const GateChanged(gateId: 'req-1', seq: 5202));
      await tester.pump();
      expect(controller.dirtyScopes, {'gates'});
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(gateway.calls, {'gates': 1});

      gateway.reset();
      gateway.stream.add(
        ActivityAppended(
          event: const ActivityEvent(type: 'session.turn', seq: 5203),
          seq: 5203,
        ),
      );
      await tester.pump();
      expect(controller.dirtyScopes, {'activity'});
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(gateway.calls, {'activity': 1});
      expect(controller.timeline.last.seq, 5203);
    });

    testWidgets('a head-only replay refetches every scope', (tester) async {
      final (controller, gateway) = await boot();
      gateway.reset();
      gateway.stream.add(
        const StreamHeadOnlyReplay(requestedSeq: 10, firstSeq: 500),
      );
      await tester.pump();
      expect(controller.dirtyScopes, OrchestrationScope.all);
      expect(controller.cursor.seq, 499);
      final before = controller.timeline.length;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(gateway.calls, {
        'projects': 1,
        'runs': 1,
        'work': 1,
        'agents': 1,
        'gates': 1,
        'usage': 1,
        'activity': 1,
      });
      expect(
        controller.timeline.length,
        before,
        reason: 'the replay marker itself is not a timeline entry',
      );
    });
  });

  group('attention and timeline', () {
    testWidgets('attention counts pending, gate beads and failed runs', (
      tester,
    ) async {
      final gates = mapGates(
        pending: [GcPendingInteraction.fromJson(_blockedPending)],
        beads: [GcBead.fromJson(_gateBead), GcBead.fromJson(_reviewBead)],
        runs: mapRunsList(
          GcRunsList.fromJson({
            'runs': [_failedRun],
          }),
        ).items,
      );
      expect(gates.map((g) => g.kind), [
        GateKind.choice,
        GateKind.gateBead,
        GateKind.reviewReady,
        GateKind.runFailed,
      ]);
      final (controller, _) = await boot(gates: gates);
      expect(controller.snapshot.gates, hasLength(4));
      expect(
        controller.attentionCount,
        3,
        reason: 'review-ready is not a gate',
      );
    });

    testWidgets('the fixture at rest needs nothing', (tester) async {
      final (controller, _) = await boot();
      expect(controller.attentionCount, 0);
    });

    testWidgets('the timeline is append-only and bounded', (tester) async {
      final (controller, gateway) = await boot(timelineLimit: 500);
      final seeded = controller.timeline.length;
      expect(seeded, greaterThan(0));
      final firstSeq = controller.timeline.last.seq ?? 0;
      for (var i = 1; i <= 520; i++) {
        gateway.stream.add(
          BeadChanged(
            beadId: 'b$i',
            change: BeadChange.updated,
            seq: firstSeq + i,
          ),
        );
      }
      await tester.pump();
      expect(controller.timeline, hasLength(500));
      expect(controller.timeline.last.seq, firstSeq + 520);
      expect(controller.timeline.first.seq, firstSeq + 21);
      // Duplicates by seq never re-enter.
      gateway.stream.add(
        BeadChanged(
          beadId: 'dup',
          change: BeadChange.updated,
          seq: firstSeq + 520,
        ),
      );
      await tester.pump();
      expect(controller.timeline, hasLength(500));
      expect(controller.timeline.last.seq, firstSeq + 520);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('ConnectionController', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('oc/background'),
            (_) async => null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('oc/shortcut'),
            (_) async => null,
          );
    });

    Future<ConnectionController> bootConnection(ServerProfile p) async {
      final profiles = ProfileStore(prefs: prefs, secure: secure);
      await profiles.upsert(p);
      await profiles.setActiveId(p.id);
      final controller = ConnectionController(profiles);
      addTearDown(controller.dispose);
      controller.adoptConnectedProfileForTesting(p);
      return controller;
    }

    Future<void> until(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!done()) {
        if (DateTime.now().isAfter(deadline)) fail('timed out');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('a profile with config null gets no controller and no keys', () async {
      final controller = await bootConnection(profile());
      expect(controller.orchestration, isNull);
      controller.syncOrchestration();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.orchestration, isNull);
      expect(controller.unifiedAttentionCount, 0);
      expect(
        prefs.getKeys().where((k) => k.startsWith('oc.orchestration')),
        isEmpty,
      );
      expect(secure.deletes.where((k) => k.contains('orchestration')), isEmpty);
    });

    test(
      'a configured profile gets a sibling that follows the config',
      () async {
        final p = profile(config: fixtureConfig());
        final controller = await bootConnection(p);
        controller.syncOrchestration();
        final first = controller.orchestration;
        expect(first, isNotNull);
        expect(first!.config, fixtureConfig());
        await until(() => first.phase == OrchestrationPhase.ready);
        await until(
          () =>
              prefs.getKeys().contains('oc.orchestration.$_profileId.snapshot'),
        );
        expect(first.snapshot.hasData, isTrue);

        // Same config: the sibling is kept.
        controller.syncOrchestration();
        expect(controller.orchestration, same(first));

        // Changed config: replaced.
        p.orchestration = fixtureConfig().copyWith(city: 'other');
        controller.syncOrchestration();
        final second = controller.orchestration;
        expect(second, isNot(same(first)));
        expect(first.phase, OrchestrationPhase.stopped);
        await until(() => second!.phase == OrchestrationPhase.ready);

        // Turned off: gone.
        p.orchestration = null;
        controller.syncOrchestration();
        expect(controller.orchestration, isNull);
        expect(second!.phase, OrchestrationPhase.stopped);
      },
    );
  });
}
