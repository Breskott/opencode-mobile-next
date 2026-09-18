import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/orchestration/dispatch.dart'
    show isRefineryName, workHandedToMerge;

/// Repo-relative fixture root; `flutter test` runs from the package root.
final Directory _fixtureRoot = _findFixtureRoot();

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

Map<String, Object?> _readJson(File file) =>
    readMap(jsonDecode(file.readAsStringSync()));

Map<String, Object?> _recording(String name) =>
    _readJson(File('${_fixtureRoot.path}/recordings/$name.json'));

List<File> _files(String sub, String ext) =>
    Directory(
        '${_fixtureRoot.path}/$sub',
      ).listSync().whereType<File>().where((f) => f.path.endsWith(ext)).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Every DTO decoder, so any object can be pushed through all of them.
final List<Object Function(Map<String, Object?>)> _allDecoders = [
  GcHealth.fromJson,
  GcStatus.fromJson,
  GcReadiness.fromJson,
  GcAgent.fromJson,
  GcAgentSession.fromJson,
  GcSession.fromJson,
  GcSessionTurn.fromJson,
  GcTurn.fromJson,
  GcBead.fromJson,
  GcDependency.fromJson,
  GcConvoy.fromJson,
  GcBeadGraph.fromJson,
  GcRun.fromJson,
  GcRunStep.fromJson,
  GcRunsList.fromJson,
  GcPendingInteraction.fromJson,
  GcWait.fromJson,
  GcUsage.fromJson,
  GcUsageTotals.fromJson,
  GcEvent.fromJson,
  GcEventsPage.fromJson,
  GcHeartbeat.fromJson,
  GcStreamFrame.fromJson,
  GcSlingRequest.fromJson,
  GcSlingResponse.fromJson,
  GcProblem.fromJson,
  (json) => GcList<GcBead>.fromJson(json, GcBead.fromJson),
];

/// Recording name → the decode + map path the gateway will use for it.
/// Every file in `recordings/` must have an entry; the test fails
/// otherwise so a new recording is never silently skipped.
final Map<String, Object? Function(Map<String, Object?>)> _recordingPaths = {
  'health': (j) => GcHealth.fromJson(j).version,
  'status': (j) {
    final status = GcStatus.fromJson(j);
    return [
      mapStatusCounts(status),
      mapRigs(status),
      mapHostIdentity(
        url: 'http://h',
        hostMode: OrchestrationHostMode.computer,
        status: status,
      ),
    ];
  },
  'readiness': (j) => GcReadiness.fromJson(j).items,
  'agents': (j) =>
      mapAgents(GcList.fromJson(j, GcAgent.fromJson).items, const []),
  'agent': (j) => mapAgent(GcAgent.fromJson(j)),
  'sessions': (j) =>
      mapAgents(const [], GcList.fromJson(j, GcSession.fromJson).items),
  'session': (j) => mapSession(GcSession.fromJson(j)),
  'session_transcript': (j) => GcSessionTurn.fromJson(j).turns,
  'bd_create': (j) => mapBead(GcBead.fromJson(j)),
  'bead_after_sling': (j) => mapBead(GcBead.fromJson(j)),
  'bead_handed_to_refinery': (j) => mapBead(GcBead.fromJson(j)),
  'beads': (j) =>
      mapBeadList(GcList.fromJson(j, GcBead.fromJson), includeInternal: true),
  'beads_ready': (j) => mapBeadList(GcList.fromJson(j, GcBead.fromJson)),
  'beads_graph': (j) {
    final graph = GcBeadGraph.fromJson(j);
    return [?graph.root, ...graph.beads].map(mapBead).toList();
  },
  'convoy': (j) => GcProblem.looksLikeProblem(j)
      ? GcProblem.fromJson(j).message
      : mapConvoy(GcConvoy.fromJson(j)),
  'convoys': (j) => mapConvoys(GcList.fromJson(j, GcConvoy.fromJson).items),
  'runs': (j) => mapRunsList(GcRunsList.fromJson(j)),
  'runs_with_formula': (j) => mapRunsList(GcRunsList.fromJson(j)),
  'run_formula': (j) => mapRunsList(
    GcRunsList.fromJson({
      'runs': <Object?>[j],
      'status_counts': const {},
    }),
  ),
  'bead_workflow_root': (j) => mapBead(GcBead.fromJson(j)),
  'pending': (j) => mapGates(
    pending: GcList.fromJson(j, GcPendingInteraction.fromJson).items,
  ),
  'waits': (j) => GcWorkContext.from(
    waits: GcList.fromJson(j, GcWait.fromJson, itemsKey: 'waits').items,
  ),
  'usage': (j) => mapUsage(GcUsage.fromJson(j)),
  'events_page': (j) => GcEventsPage.fromJson(j).items.map(mapEvent).toList(),
  'sling_response': (j) => GcSlingResponse.fromJson(j).isSlung,
  'sling_cli_result': (j) => GcSlingResponse.fromJson(j).isSlung,
  'formulas': (j) => GcProblem.fromJson(j).slug,
  // Not modelled by the plugin (config, providers, rigs); they still must
  // pass through the generic decoders without throwing.
  'config': (j) => GcStatus.fromJson(j),
  'providers': (j) => GcList.fromJson(j, GcReadinessItem.fromJson),
  'rigs': (j) => GcList.fromJson(j, GcBead.fromJson),
};

const _garbage = <Object?>[
  null,
  '',
  'garbage',
  42,
  3.5,
  true,
  <Object?>[],
  <Object?>[1, 'x', null],
  <String, Object?>{},
  <String, Object?>{
    'nested': <String, Object?>{'deep': 1},
  },
];

/// Every key the DTOs read, so garbage can be planted under each.
const _knownKeys = [
  'id',
  'title',
  'status',
  'issue_type',
  'labels',
  'metadata',
  'dependencies',
  'is_blocked',
  'assignee',
  'created_at',
  'updated_at',
  'items',
  'total',
  'partial',
  'partial_errors',
  'runs',
  'status_counts',
  'run_id',
  'last_error',
  'scope',
  'name',
  'state',
  'running',
  'suspended',
  'session',
  'pool',
  'pack',
  'template',
  'session_name',
  'last_active',
  'last_activity',
  'seq',
  'type',
  'ts',
  'actor',
  'subject',
  'payload',
  'session_id',
  'data',
  'event',
  'turns',
  'today',
  'recent',
  'source',
  'work',
  'agents',
  'agent_details',
  'rig_details',
  'options',
  'prompt',
  'request_id',
  'kind',
  'waits',
  'version',
  'city',
  'uptime_sec',
  'detail',
  'code',
  'errors',
  'target',
  'bead',
  'run',
  'warnings',
  'progress',
  'convoy',
  'children',
  'root',
  'beads',
  'deps',
  'vars',
];

void main() {
  group('recordings round-trip', () {
    final files = _files('recordings', '.json');

    test('fixture directory has recordings', () {
      expect(files, isNotEmpty);
    });

    test('every recording has a mapping path (none skipped)', () {
      final names = files.map(
        (f) => f.uri.pathSegments.last.replaceAll('.json', ''),
      );
      expect(names.toSet(), equals(_recordingPaths.keys.toSet()));
    });

    for (final file in files) {
      final name = file.uri.pathSegments.last.replaceAll('.json', '');
      test('$name decodes and maps without throwing', () {
        final json = _readJson(file);
        final path = _recordingPaths[name];
        expect(path, isNotNull, reason: 'no mapping path for $name');
        expect(() => path!(json), returnsNormally);
        for (final decode in _allDecoders) {
          expect(
            () => decode(json),
            returnsNormally,
            reason: '$decode on $name',
          );
        }
      });
    }
  });

  group('event logs round-trip', () {
    final files = _files('events', '.ndjson');

    test('fixture directory has event logs', () {
      expect(files, isNotEmpty);
    });

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      test('$name: every line decodes and maps', () {
        final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
        var count = 0;
        var heartbeats = 0;
        var unknown = 0;
        for (final line in lines) {
          final json = readMap(jsonDecode(line));
          final frame = GcStreamFrame.fromJson(json);
          final mapped = mapStreamFrame(frame);
          if (mapped is StreamHeartbeat) heartbeats++;
          if (mapped is UnknownOrchestrationEvent) unknown++;
          if (frame.isCityEvent) {
            final event = frame.toEvent();
            expect(event.type, isNot('unknown'));
            mapActivity(event);
            mapEvent(event);
            // Embedded beads are full bead documents: they must map too.
            final bead = event.payloadBead;
            if (bead != null) mapBead(GcBead.fromJson(bead));
          }
          if (frame.isTurn) {
            final turn = GcSessionTurn.fromJson(frame.data);
            expect(turn.id, isNotEmpty);
          }
          for (final decode in _allDecoders) {
            decode(json);
            decode(frame.data);
          }
          count++;
        }
        expect(count, greaterThan(0));
        expect(unknown, 0, reason: 'recorded types are all modelled');
        if (name.startsWith('session-')) expect(heartbeats, greaterThan(0));
      });
    }

    test('city events map to the documented product events', () {
      final seen = <Type, Set<String>>{};
      for (final file in files) {
        for (final line in file.readAsLinesSync()) {
          if (line.trim().isEmpty) continue;
          final frame = GcStreamFrame.fromJson(readMap(jsonDecode(line)));
          if (!frame.isCityEvent) continue;
          final event = frame.toEvent();
          final mapped = mapEvent(event);
          seen.putIfAbsent(mapped.runtimeType, () => {}).add(event.type);
          expect(mapped.seq, event.seq);
          expect(mapped.raw, same(event.raw));
        }
      }
      expect(
        seen[BeadChanged],
        containsAll(['bead.created', 'bead.updated', 'bead.closed']),
      );
      expect(
        seen[SessionChanged],
        containsAll(['session.woke', 'session.stopped']),
      );
      expect(seen[RunChanged], contains('convoy.closed'));
      expect(
        seen[ActivityAppended],
        containsAll(['order.fired', 'order.completed', 'order.failed']),
      );
      expect(seen.containsKey(UnknownOrchestrationEvent), isFalse);
    });

    test('heartbeat frames become StreamHeartbeat with a timestamp', () {
      final frame = GcStreamFrame.fromJson({
        'event': 'heartbeat',
        'data': {'timestamp': '2026-09-10T18:34:07Z'},
      });
      final mapped = mapStreamFrame(frame);
      expect(mapped, isA<StreamHeartbeat>());
      expect(
        (mapped as StreamHeartbeat).timestamp,
        DateTime.utc(2026, 9, 10, 18, 34, 7),
      );
      // A nameless frame carrying only a timestamp is a heartbeat too.
      final bare = GcStreamFrame.fromJson({
        'data': {'timestamp': '2026-09-10T18:34:07Z'},
      });
      expect(mapStreamFrame(bare), isA<StreamHeartbeat>());
    });
  });

  group('tolerance', () {
    test('every decoder survives garbage under every known key', () {
      for (final decode in _allDecoders) {
        for (final value in _garbage) {
          final json = {for (final key in _knownKeys) key: value};
          expect(
            () => decode(json),
            returnsNormally,
            reason: '$decode with $value',
          );
          expect(() => decode(const {}), returnsNormally);
        }
      }
    });

    test('mappers survive garbage DTOs', () {
      final json = {for (final key in _knownKeys) key: 'garbage'};
      expect(() => mapBead(GcBead.fromJson(json)), returnsNormally);
      expect(() => mapConvoy(GcConvoy.fromJson(json)), returnsNormally);
      expect(() => mapRun(GcRun.fromJson(json)), returnsNormally);
      expect(() => mapRunsList(GcRunsList.fromJson(json)), returnsNormally);
      expect(
        () =>
            mapAgent(GcAgent.fromJson(json), session: GcSession.fromJson(json)),
        returnsNormally,
      );
      expect(() => mapSession(GcSession.fromJson(json)), returnsNormally);
      expect(
        () => mapPendingInteraction(GcPendingInteraction.fromJson(json)),
        returnsNormally,
      );
      expect(
        () => mapUsage(GcUsage.fromJson(json), status: GcStatus.fromJson(json)),
        returnsNormally,
      );
      expect(() => mapEvent(GcEvent.fromJson(json)), returnsNormally);
      expect(
        () => mapStreamFrame(GcStreamFrame.fromJson(json)),
        returnsNormally,
      );
      expect(() => mapActivity(GcEvent.fromJson(json)), returnsNormally);
    });

    test('unknown enum strings map to unknown and keep the raw string', () {
      final bead = GcBead.fromJson(const {
        'id': 'b1',
        'title': 't',
        'status': 'quantum',
      });
      final work = mapBead(bead);
      expect(work.state, WorkState.unknown);
      expect(work.rawState, 'quantum');
      expect(work.raw['status'], 'quantum');

      final run = mapRun(
        GcRun.fromJson(const {
          'run_id': 'r1',
          'title': 'r',
          'status': 'teleporting',
        }),
      );
      expect(run.state, RunState.unknown);
      expect(run.rawState, 'teleporting');

      final agent = mapAgent(
        GcAgent.fromJson(const {
          'name': 'a',
          'state': 'levitating',
          'running': true,
        }),
      );
      expect(agent.state, AgentState.unknown);
      expect(agent.rawState, 'levitating');

      final gate = mapPendingInteraction(
        GcPendingInteraction.fromJson(const {
          'request_id': 'q',
          'kind': 'riddle',
        }),
      );
      expect(gate.kind, GateKind.unknown);
      expect(gate.rawKind, 'riddle');
      expect(gate.title, 'riddle');

      final event = mapEvent(
        GcEvent.fromJson(const {'seq': 7, 'type': 'martian.landed'}),
      );
      expect(event, isA<UnknownOrchestrationEvent>());
      expect(event.type, 'martian.landed');
      expect(event.seq, 7);
      expect(event.raw['type'], 'martian.landed');
    });

    test('unknown fields are ignored and kept in raw', () {
      final bead = GcBead.fromJson(const {
        'id': 'b1',
        'title': 't',
        'status': 'open',
        'brand_new_field': {'x': 1},
      });
      expect(bead.raw['brand_new_field'], isA<Map<String, Object?>>());
      expect(mapBead(bead).raw['brand_new_field'], isNotNull);
    });

    test('problem+json decodes and is recognised', () {
      final problem = GcProblem.fromJson(_recording('convoy'));
      expect(GcProblem.looksLikeProblem(_recording('convoy')), isTrue);
      expect(GcProblem.looksLikeProblem(_recording('health')), isFalse);
      expect(problem.status, 404);
      expect(problem.slug, 'convoy-not-found');
      expect(problem.isNotFound, isTrue);
      expect(problem.message, 'bead gc-3 is not a convoy');
    });
  });

  group('state table (04 §4)', () {
    GcBead bead(Map<String, Object?> extra) => GcBead.fromJson({
      'id': 'w1',
      'title': 'Work',
      'status': 'open',
      ...extra,
    });

    test('work: queued', () {
      expect(mapBead(bead(const {})).state, WorkState.queued);
    });
    test('work: ready when in the ready set', () {
      final context = GcWorkContext.from(ready: [bead(const {})]);
      expect(mapBead(bead(const {}), context: context).state, WorkState.ready);
      expect(
        mapBead(bead(const {'id': 'other'}), context: context).state,
        WorkState.queued,
      );
    });
    test('work: working', () {
      expect(
        mapBead(bead(const {'status': 'in_progress'})).state,
        WorkState.working,
      );
    });
    test('work: waiting when its session is parked in /waits', () {
      final context = GcWorkContext.from(
        waits: [
          GcWait.fromJson(const {
            'id': 'wt',
            'session_id': 'bl-48k',
            'state': 'waiting',
          }),
        ],
      );
      final item = mapBead(
        bead(const {
          'status': 'in_progress',
          'metadata': {'gc.session_id': 'bl-48k'},
        }),
        context: context,
      );
      expect(item.state, WorkState.waiting);
    });
    test('work: blocked via is_blocked', () {
      final item = mapBead(
        bead(const {'status': 'in_progress', 'is_blocked': true}),
      );
      expect(item.state, WorkState.blocked);
      expect(item.isBlocked, isTrue);
    });
    test('work: needs input when its session has a pending interaction', () {
      final context = GcWorkContext.from(
        pending: [
          GcPendingInteraction.fromJson(const {
            'request_id': 'q1',
            'kind': 'choice',
            'session_id': 'bl-48k',
          }),
        ],
      );
      final item = mapBead(
        bead(const {
          'status': 'in_progress',
          'metadata': {'gc.session_id': 'bl-48k'},
        }),
        context: context,
      );
      expect(item.state, WorkState.needsInput);
    });
    test('work: review via needs-review label', () {
      final item = mapBead(
        bead(const {
          'status': 'in_progress',
          'labels': ['needs-review'],
        }),
      );
      expect(item.state, WorkState.review);
      expect(item.labels, contains('needs-review'));
    });
    test('work: failed via last_error (metadata and run step)', () {
      expect(
        mapBead(
          bead(const {
            'status': 'in_progress',
            'metadata': {'last_error': 'boom'},
          }),
        ).state,
        WorkState.failed,
      );
      expect(
        mapBead(
          bead(const {'status': 'in_progress'}),
          context: const GcWorkContext(runErrors: {'w1': 'step exploded'}),
        ).state,
        WorkState.failed,
      );
      // An empty last_error (what nudge beads carry) is not a failure.
      expect(
        mapBead(
          bead(const {
            'status': 'in_progress',
            'metadata': {'last_error': ''},
          }),
        ).state,
        WorkState.working,
      );
    });
    test('work: completed', () {
      final item = mapBead(
        bead(const {
          'status': 'closed',
          'metadata': {'close_reason': 'convoy autoclose: all children closed'},
        }),
      );
      expect(item.state, WorkState.completed);
      expect(item.closedReason, 'convoy autoclose: all children closed');
    });
    test('work: cancelled via closed_reason', () {
      expect(
        mapBead(
          bead(const {
            'status': 'closed',
            'metadata': {'closed_reason': 'cancelled'},
          }),
        ).state,
        WorkState.cancelled,
      );
      expect(
        mapBead(
          bead(const {
            'status': 'closed',
            'metadata': {'close_reason': 'cancelled'},
          }),
        ).state,
        WorkState.cancelled,
      );
    });

    OrchestrationRun run(
      String status, [
      Map<String, Object?> extra = const {},
    ]) => mapRun(
      GcRun.fromJson({
        'run_id': 'r1',
        'title': 'Run',
        'status': status,
        ...extra,
      }),
    );

    test(
      'run: planning',
      () => expect(run('pending').state, RunState.planning),
    );
    test('run: working', () => expect(run('active').state, RunState.working));
    test('run: waiting', () => expect(run('waiting').state, RunState.waiting));
    test('run: blocked (convoy with a blocked item)', () {
      final convoy = GcConvoy.fromJson(const {
        'id': 'c1',
        'title': 'sling-w1',
        'status': 'open',
        'issue_type': 'convoy',
        'dependencies': [
          {'issue_id': 'c1', 'depends_on_id': 'w1', 'type': 'tracks'},
        ],
      });
      final blocked = mapBead(
        bead(const {'status': 'in_progress', 'is_blocked': true}),
      );
      final mapped = mapConvoy(convoy, work: {'w1': blocked});
      expect(mapped.kind, RunKind.batch);
      expect(mapped.state, RunState.blocked);
      expect(mapped.stepCount, 1);
      expect(mapped.completedSteps, 0);
    });
    test('run: failed', () {
      final failed = run('failed', {
        'last_error': {'code': 'step_failed', 'message': 'tests red'},
      });
      expect(failed.state, RunState.failed);
      expect(failed.lastError, 'tests red');
      expect(failed.kind, RunKind.formula);
    });
    test(
      'run: completed',
      () => expect(run('completed').state, RunState.completed),
    );
    test('run: cancelled (canceled, canceling, skipped)', () {
      expect(run('canceled').state, RunState.cancelled);
      expect(run('canceling').state, RunState.cancelled);
      expect(run('skipped').state, RunState.cancelled);
    });
    test('run: convoy derives from tracked work', () {
      GcConvoy convoy([
        String status = 'open',
        Map<String, Object?> extra = const {},
      ]) => GcConvoy.fromJson({
        'id': 'c1',
        'title': 'sling-w1',
        'status': status,
        'issue_type': 'convoy',
        'dependencies': [
          {'issue_id': 'c1', 'depends_on_id': 'w1', 'type': 'tracks'},
          {'issue_id': 'c1', 'depends_on_id': 'w2', 'type': 'tracks'},
        ],
        ...extra,
      });
      WorkItem w(String id, Map<String, Object?> extra) =>
          mapBead(bead({'id': id, ...extra}));
      RunState state(Map<String, WorkItem> work, [GcConvoy? c]) =>
          mapConvoy(c ?? convoy(), work: work).state;

      // TEAM-115: nothing started is "waiting for an agent", never
      // planning (that word is the formula runs' `pending`).
      expect(state({}), RunState.waiting);
      expect(
        state({'w1': w('w1', const {}), 'w2': w('w2', const {})}),
        RunState.waiting,
      );
      expect(
        state({
          'w1': w('w1', const {'status': 'in_progress'}),
          'w2': w('w2', const {}),
        }),
        RunState.working,
      );
      expect(
        state({
          'w1': w('w1', const {
            'status': 'in_progress',
            'labels': ['needs-review'],
          }),
          'w2': w('w2', const {}),
        }),
        RunState.working,
      );
      expect(
        state({
          'w1': w('w1', const {
            'status': 'in_progress',
            'metadata': {'last_error': 'x'},
          }),
          'w2': w('w2', const {}),
        }),
        RunState.failed,
      );
      expect(
        state({
          'w1': w('w1', const {'status': 'closed'}),
          'w2': w('w2', const {'status': 'closed'}),
        }),
        RunState.completed,
      );
      expect(state({}, convoy('closed')), RunState.completed);
      expect(
        state(
          {},
          convoy('closed', const {
            'metadata': {'close_reason': 'cancelled by operator'},
          }),
        ),
        RunState.cancelled,
      );
    });

    test('run: batch state table (TEAM-115)', () {
      GcConvoy convoy(List<String> ids) => GcConvoy.fromJson({
        'id': 'c1',
        'title': 'sling-${ids.first}',
        'status': 'open',
        'issue_type': 'convoy',
        'dependencies': [
          for (final id in ids)
            {'issue_id': 'c1', 'depends_on_id': id, 'type': 'tracks'},
        ],
      });
      WorkItem w(
        String id,
        Map<String, Object?> extra, {
        GcWorkContext context = const GcWorkContext(),
      }) => mapBead(bead({'id': id, ...extra}), context: context);
      RunState state(List<WorkItem> items) => mapConvoy(
        convoy([for (final i in items) i.id]),
        work: {for (final i in items) i.id: i},
      ).state;

      // Queued, ready or open with only a pool routing: nobody has it.
      expect(state([w('a', const {})]), RunState.waiting);
      expect(
        state([
          w('a', const {}, context: const GcWorkContext(readyIds: {'a'})),
        ]),
        RunState.waiting,
      );
      expect(
        state([
          w('a', const {
            'metadata': {'gc.routed_to': 'ocproof/gastown.polecat'},
          }),
        ]),
        RunState.waiting,
      );
      // An assignee or a live session means an agent has it: working.
      expect(
        state([
          w('a', const {'assignee': 'ocproof/gastown.polecat-1'}),
        ]),
        RunState.working,
      );
      expect(
        state([
          w('a', const {
            'metadata': {'gc.session_id': 'bl-48k'},
          }),
        ]),
        RunState.working,
      );
      // TEAM-117: the refinery holding an open bead is the merge queue,
      // not an agent working it. The item reads as review pending and
      // the batch waits (for the merge); another item still working
      // keeps the batch working, a blocked one blocks it.
      final handed = w('a', const {'assignee': 'ocproof/gastown.refinery'});
      expect(handed.state, WorkState.review);
      expect(workHandedToMerge(handed), isTrue);
      expect(state([handed]), RunState.waiting);
      expect(
        state([
          handed,
          w('b', const {
            'status': 'in_progress',
            'metadata': {'gc.session_id': 'bl-49k'},
          }),
        ]),
        RunState.working,
      );
      expect(
        state([
          handed,
          w('b', const {'status': 'in_progress', 'is_blocked': true}),
        ]),
        RunState.blocked,
      );
      expect(
        state([
          handed,
          w('b', const {'status': 'closed'}),
        ]),
        RunState.waiting,
      );
      // A closed bead the refinery still names is done, not pending;
      // the pool routing alone is not a hand-off.
      final merged = w('a', const {
        'status': 'closed',
        'assignee': 'ocproof/gastown.refinery',
      });
      expect(merged.state, WorkState.completed);
      expect(workHandedToMerge(merged), isFalse);
      expect(
        workHandedToMerge(
          w('a', const {
            'metadata': {'gc.routed_to': 'ocproof/gastown.refinery'},
          }),
        ),
        isFalse,
      );
      expect(isRefineryName('ocproof/gastown.refinery'), isTrue);
      expect(isRefineryName('gastown.refinery'), isTrue);
      expect(isRefineryName('ocproof/gastown.polecat'), isFalse);
      expect(
        state([
          w('a', const {'status': 'in_progress'}),
          w('b', const {}),
        ]),
        RunState.working,
      );
      // Blocked or needing input: blocked.
      expect(
        state([
          w('a', const {'status': 'in_progress', 'is_blocked': true}),
          w('b', const {'status': 'in_progress'}),
        ]),
        RunState.blocked,
      );
      expect(
        state([
          w('a', const {
            'status': 'in_progress',
            'metadata': {'gc.session_id': 's1'},
          }, context: const GcWorkContext(needsInputSessions: {'s1'})),
        ]),
        RunState.blocked,
      );
      // Failed wins; all done is completed.
      expect(
        state([
          w('a', const {
            'status': 'in_progress',
            'metadata': {'last_error': 'boom'},
          }),
          w('b', const {'status': 'closed'}),
        ]),
        RunState.failed,
      );
      expect(
        state([
          w('a', const {'status': 'closed'}),
          w('b', const {'status': 'closed'}),
        ]),
        RunState.completed,
      );
      // Partly done with the rest unclaimed is still waiting for an agent.
      expect(
        state([
          w('a', const {'status': 'closed'}),
          w('b', const {}),
        ]),
        RunState.waiting,
      );
    });

    test('run: batch title is the work\'s title (TEAM-115)', () {
      GcConvoy convoy(String title, List<String> ids) => GcConvoy.fromJson({
        'id': 'oc-sv1',
        'title': title,
        'status': 'open',
        'issue_type': 'convoy',
        'dependencies': [
          for (final id in ids)
            {'issue_id': 'oc-sv1', 'depends_on_id': id, 'type': 'tracks'},
        ],
      });
      final docstring = mapBead(
        bead(const {
          'id': 'oc-ckg',
          'title': 'Add a docstring to multiply() in calc.py',
        }),
      );
      final tests = mapBead(
        bead(const {'id': 'oc-2', 'title': 'Write tests for calc.py'}),
      );
      // The live shape: `sling-<bead>` tracking one bead.
      final single = mapConvoy(
        convoy('sling-oc-ckg', ['oc-ckg']),
        work: {'oc-ckg': docstring},
      );
      expect(single.title, 'Add a docstring to multiply() in calc.py');
      expect(single.raw['title'], 'sling-oc-ckg', reason: 'raw kept');
      expect(single.state, RunState.waiting);
      // Several tracked items: the first plus a count.
      expect(
        mapConvoy(
          convoy('sling-oc-ckg', ['oc-ckg', 'oc-2']),
          work: {'oc-ckg': docstring, 'oc-2': tests},
        ).title,
        'Add a docstring to multiply() in calc.py + 1 more',
      );
      // An untitled convoy takes the work's title too.
      expect(
        mapConvoy(convoy('', ['oc-ckg']), work: {'oc-ckg': docstring}).title,
        'Add a docstring to multiply() in calc.py',
      );
      // A person's own convoy title is kept.
      expect(
        mapConvoy(
          convoy('Calc polish', ['oc-ckg']),
          work: {'oc-ckg': docstring},
        ).title,
        'Calc polish',
      );
      // Nothing to name it by: the host's title, else the id.
      expect(
        mapConvoy(convoy('sling-oc-ckg', ['oc-ckg'])).title,
        'sling-oc-ckg',
      );
      expect(mapConvoy(convoy('', [])).title, 'oc-sv1');
    });

    test('run: upkeep detection (TEAM-115)', () {
      bool upkeep(Map<String, Object?> json) => mapRun(
        GcRun.fromJson({'run_id': 'r', 'title': '', ...json}),
      ).isUpkeep;

      // The live `/runs` shape: every item a pack patrol wisp.
      const live = <String, Object?>{
        'run_id': 'oc-wisp-m63',
        'title': 'mol-refinery-patrol',
        'status': 'pending',
        'target': 'workflow',
        'scope': <String, Object?>{},
        'started_at': '2026-09-11T08:00:00Z',
        'updated_at': '2026-09-11T08:00:00Z',
      };
      final mapped = mapRun(GcRun.fromJson(live));
      expect(mapped.isUpkeep, isTrue);
      expect(mapped.state, RunState.planning);
      expect(mapped.title, 'mol-refinery-patrol', reason: 'raw title kept');
      expect(mapped.raw, live);

      expect(upkeep(const {'title': 'mol-deacon-patrol'}), isTrue);
      expect(upkeep(const {'title': 'mol-witness-patrol'}), isTrue);
      expect(upkeep(const {'title': 'mol-shutdown-dance'}), isTrue);
      expect(upkeep(const {'title': 'mol-digest-generate'}), isTrue);
      expect(upkeep(const {'formula': 'mol-refinery-patrol'}), isTrue);
      expect(upkeep(const {'title': 'order: gate-sweep'}), isTrue);
      expect(upkeep(const {'title': 'nudge:nudge-50666b477fd6'}), isTrue);
      // A scope-less workflow wisp naming no work is upkeep...
      expect(
        upkeep(const {'title': 'wisp', 'target': 'workflow', 'scope': {}}),
        isTrue,
      );
      // ...but one with a scope or tracked work is the person's.
      expect(
        upkeep(const {
          'title': 'wisp',
          'target': 'workflow',
          'scope': {'kind': 'rig', 'ref': 'ocproof'},
        }),
        isFalse,
      );
      expect(
        upkeep(const {
          'title': 'wisp',
          'target': 'workflow',
          'scope': {},
          'bead': 'oc-ckg',
        }),
        isFalse,
      );
      expect(upkeep(const {'title': 'Ship the calc feature'}), isFalse);
      expect(
        upkeep(const {'title': 'mol-polish', 'formula': 'mol-polish'}),
        isFalse,
      );
      expect(upkeep(const {'title': 'Add a docstring (patrol)'}), isFalse);
      // A failed upkeep run raises no gate.
      expect(
        gateFromRun(
          mapRun(
            GcRun.fromJson(const {
              'run_id': 'r',
              'title': 'mol-refinery-patrol',
              'status': 'failed',
              'last_error': 'boom',
            }),
          ),
        ),
        isNull,
      );
      expect(
        gateFromRun(
          mapRun(
            GcRun.fromJson(const {
              'run_id': 'r',
              'title': 'Ship it',
              'status': 'failed',
              'last_error': 'boom',
            }),
          ),
        ),
        isNotNull,
      );
    });

    OrchestrationAgent agent(
      Map<String, Object?> extra, {
      GcSession? session,
      GcAgentContext context = const GcAgentContext(),
    }) => mapAgent(
      GcAgent.fromJson({'name': 'gastown.mayor', ...extra}),
      session: session,
      context: context,
    );

    test('agent: working', () {
      expect(
        agent(const {'state': 'active', 'running': true}).state,
        AgentState.working,
      );
      final session = GcSession.fromJson(const {
        'id': 's1',
        'state': 'active',
        'running': true,
      });
      expect(
        agent(const {'running': true}, session: session).state,
        AgentState.working,
      );
    });
    test('agent: idle', () {
      expect(
        agent(const {'state': 'idle', 'running': true}).state,
        AgentState.idle,
      );
    });
    test('agent: waiting when its session has a pending interaction', () {
      final session = GcSession.fromJson(const {
        'id': 'bl-8jc',
        'state': 'active',
        'running': true,
        'session_name': 'gastown__mayor',
      });
      final context = GcAgentContext.from(
        pending: [
          GcPendingInteraction.fromJson(const {
            'request_id': 'q',
            'kind': 'confirm',
            'session_id': 'bl-8jc',
          }),
        ],
      );
      expect(
        agent(
          const {'state': 'idle', 'running': true},
          session: session,
          context: context,
        ).state,
        AgentState.waiting,
      );
    });
    test('agent: blocked when its session is parked in /waits', () {
      final session = GcSession.fromJson(const {
        'id': 'bl-8jc',
        'state': 'active',
        'running': true,
      });
      final context = GcAgentContext.from(
        waits: [
          GcWait.fromJson(const {
            'id': 'wt',
            'session_id': 'bl-8jc',
            'state': 'waiting',
          }),
        ],
      );
      expect(
        agent(
          const {'state': 'idle', 'running': true},
          session: session,
          context: context,
        ).state,
        AgentState.blocked,
      );
    });
    test('agent: stopped (stopped, suspended, not running)', () {
      expect(
        agent(const {'state': 'stopped', 'running': false}).state,
        AgentState.stopped,
      );
      expect(
        agent(const {
          'state': 'idle',
          'running': true,
          'suspended': true,
        }).state,
        AgentState.stopped,
      );
      expect(
        agent(const {'state': 'suspended', 'running': false}).state,
        AgentState.stopped,
      );
      expect(agent(const {'running': false}).state, AgentState.stopped);
    });
    test('agent: a running session outranks a stopped agent word', () {
      // On the phone (no tmux server) /agents says "stopped" for the pool
      // template while /sessions shows its session active and running
      // (emulator proof 2026-09-12, session ph-7bt on bead as-2m5).
      final live = GcSession.fromJson(const {
        'id': 'ph-7bt',
        'state': 'active',
        'running': true,
      });
      expect(
        agent(const {'state': 'stopped', 'running': false}, session: live)
            .state,
        AgentState.working,
      );
      final gone = GcSession.fromJson(const {
        'id': 'ph-7bt',
        'state': 'active',
        'running': false,
      });
      expect(
        agent(const {'state': 'stopped', 'running': false}, session: gone)
            .state,
        AgentState.stopped,
      );
    });
    test('agent: crashed', () {
      expect(
        agent(const {'state': 'error', 'running': false}).state,
        AgentState.crashed,
      );
      final session = GcSession.fromJson(const {
        'id': 's1',
        'state': 'crashed',
        'running': false,
      });
      expect(
        agent(const {
          'state': 'idle',
          'running': false,
        }, session: session).state,
        AgentState.crashed,
      );
      expect(mapSession(session).state, AgentState.crashed);
    });
    test('agent: session name, last activity and pool template', () {
      final mapped = mapAgent(
        GcAgent.fromJson(const {
          'name': 'gastown.dog-1',
          'state': 'idle',
          'running': true,
          'pool': 'gastown.dog',
          'pack': 'gastown',
          'provider': 'opencode',
          'active_bead': 'gc-19',
          'session': {
            'name': 'gastown__dog-1',
            'last_activity': '2026-09-10T21:43:20Z',
            'attached': false,
          },
        }),
      );
      expect(mapped.sessionName, 'gastown__dog-1');
      expect(mapped.lastActivity, DateTime.utc(2026, 9, 10, 21, 43, 20));
      expect(mapped.pool, 'gastown.dog');
      expect(mapped.pack, 'gastown');
      expect(mapped.provider, 'opencode');
      expect(mapped.currentWorkId, 'gc-19');
    });
    test('agents join sessions and unclaimed sessions become agents', () {
      final agents = GcList.fromJson(
        _recording('agents'),
        GcAgent.fromJson,
      ).items;
      final sessions = [
        ...GcList.fromJson(_recording('sessions'), GcSession.fromJson).items,
        GcSession.fromJson(_recording('session')),
      ];
      final mapped = mapAgents(agents, sessions);
      final mayor = mapped.firstWhere((a) => a.id == 'gastown.mayor');
      expect(mayor.sessionId, 'bl-8jc');
      expect(mayor.sessionName, 'gastown__mayor');
      expect(mayor.state, AgentState.idle);
      final polecat = mapped.firstWhere((a) => a.id == 'gc-58');
      expect(polecat.name, 'ocproof/gastown.furiosa');
      expect(polecat.pool, 'ocproof/gastown.polecat');
      expect(polecat.state, AgentState.working);
      final refinery = mapped.firstWhere((a) => a.id == 'bl-wisp-qqpj');
      expect(refinery.name, 'ocproof/gastown.refinery');
      expect(refinery.pool, isNull);
      // TEAM-115: the three unspawned dog slots and the core helper are
      // not agents; every entry comes back with includeSlots.
      expect(mapped.length, agents.length + sessions.length - 3 - 4);
      expect(
        mapAgents(agents, sessions, includeSlots: true).length,
        agents.length + sessions.length - 3,
      );
    });

    test('agents: only the live ones from agents.json (TEAM-115)', () {
      final agents = GcList.fromJson(
        _recording('agents'),
        GcAgent.fromJson,
      ).items;
      final sessions = GcList.fromJson(
        _recording('sessions'),
        GcSession.fromJson,
      ).items;
      final mapped = mapAgents(agents, sessions);
      expect(mapped.map((a) => a.name).toList(), [
        'gastown.boot',
        'gastown.deacon',
        'gastown.mayor',
        'ocproof/gastown.refinery',
        'ocproof/gastown.witness',
      ]);
      expect(mapped.every((a) => a.state != AgentState.stopped), isTrue);
      expect(mapped.every((a) => !a.suspended), isTrue);
    });

    test('agents: the live city shape keeps suspended, drops slots', () {
      // `/agents` on the PC city as the owner saw it (TEAM-115).
      final agents = [
        for (final json in <Map<String, Object?>>[
          {
            'name': 'bd.dog-1',
            'state': 'stopped',
            'pool': 'bd.dog',
            'pack': 'bd',
          },
          {
            'name': 'bd.dog-2',
            'state': 'stopped',
            'pool': 'bd.dog',
            'pack': 'bd',
          },
          {
            'name': 'core.control-dispatcher',
            'state': 'stopped',
            'pack': 'core',
          },
          {
            'name': 'ocproof/core.control-dispatcher',
            'state': 'stopped',
            'pack': 'core',
          },
          for (final n in ['a', 'b', 'c', 'd', 'e'])
            {
              'name': 'ocproof/gastown.$n',
              'state': 'stopped',
              'pool': 'ocproof/gastown.polecat',
              'pack': 'gastown',
            },
          {
            'name': 'ocproof/gastown.refinery',
            'state': 'idle',
            'running': true,
            'pack': 'gastown',
            'session': {'name': 'ocproof--gastown__refinery'},
          },
          {
            'name': 'ocproof/gastown.witness',
            'state': 'stopped',
            'pack': 'gastown',
          },
          {'name': 'gastown.boot', 'state': 'suspended', 'suspended': true},
          {'name': 'gastown.deacon', 'state': 'suspended', 'suspended': true},
          {'name': 'gastown.mayor', 'state': 'suspended', 'suspended': true},
        ])
          GcAgent.fromJson(json),
      ];
      expect(agents, hasLength(14));
      final mapped = mapAgents(agents, const []);
      expect(mapped.map((a) => a.name).toList(), [
        'ocproof/gastown.refinery',
        'ocproof/gastown.witness',
        'gastown.boot',
        'gastown.deacon',
        'gastown.mayor',
      ]);
      final refinery = mapped.first;
      expect(refinery.state, AgentState.idle);
      expect(refinery.suspended, isFalse);
      // A named agent that is merely stopped is kept (switched off).
      expect(mapped[1].state, AgentState.stopped);
      expect(mapped[1].suspended, isFalse);
      for (final agent in mapped.skip(2)) {
        expect(agent.state, AgentState.stopped);
        expect(agent.suspended, isTrue);
      }
      // A running helper or a running slot is an agent.
      expect(
        mapAgents([
          GcAgent.fromJson(const {
            'name': 'bd.dog-1',
            'state': 'active',
            'running': true,
            'pool': 'bd.dog',
            'pack': 'bd',
          }),
          GcAgent.fromJson(const {
            'name': 'core.control-dispatcher',
            'state': 'idle',
            'running': true,
            'pack': 'core',
          }),
        ], const []).map((a) => a.name),
        ['bd.dog-1', 'core.control-dispatcher'],
      );
    });

    test('gate: choice', () {
      final gate = mapPendingInteraction(
        GcPendingInteraction.fromJson(const {
          'request_id': 'q1',
          'kind': 'choice',
          'session_id': 'bl-48k',
          'prompt': 'Which branch?',
          'options': [
            'master',
            {'label': 'develop'},
          ],
        }),
      );
      expect(gate.kind, GateKind.choice);
      expect(gate.id, 'q1');
      expect(gate.agentId, 'bl-48k');
      expect(gate.title, 'Which branch?');
      expect(gate.choices, ['master', 'develop']);
    });
    test('gate: confirmation', () {
      final gate = mapPendingInteraction(
        GcPendingInteraction.fromJson(const {
          'request_id': 'q2',
          'kind': 'confirm',
        }),
      );
      expect(gate.kind, GateKind.confirmation);
      expect(gate.title, 'Confirm to continue');
    });
    test('gate: free text', () {
      final gate = mapPendingInteraction(
        GcPendingInteraction.fromJson(const {
          'request_id': 'q3',
          'kind': 'text',
        }),
      );
      expect(gate.kind, GateKind.freeText);
    });
    test('gate: gate bead', () {
      final gate = gateFromBead(
        bead(const {'issue_type': 'gate', 'description': 'Merge to master?'}),
      );
      expect(gate?.kind, GateKind.gateBead);
      expect(gate?.workId, 'w1');
      expect(gate?.prompt, 'Merge to master?');
      expect(
        gateFromBead(bead(const {'issue_type': 'gate', 'status': 'closed'})),
        isNull,
      );
      expect(
        gateFromBead(
          bead(const {
            'labels': ['gc:gate'],
          }),
        )?.kind,
        GateKind.gateBead,
      );
      expect(gateFromBead(bead(const {})), isNull);
    });
    test('gate: run failed', () {
      final failed = run('failed', {
        'last_error': {'code': 'x', 'message': 'tests red'},
      });
      final gate = gateFromRun(failed);
      expect(gate?.kind, GateKind.runFailed);
      expect(gate?.runId, 'r1');
      expect(gate?.prompt, 'tests red');
      expect(gateFromRun(run('completed')), isNull);
    });
    test('gate: review ready', () {
      final gate = gateFromBead(
        bead(const {
          'status': 'in_progress',
          'labels': ['needs-review'],
        }),
      );
      expect(gate?.kind, GateKind.reviewReady);
      expect(gate?.workId, 'w1');
    });
    test('mapGates collects every source', () {
      final gates = mapGates(
        pending: [
          GcPendingInteraction.fromJson(const {
            'request_id': 'q',
            'kind': 'choice',
          }),
        ],
        beads: [
          bead(const {'issue_type': 'gate'}),
          bead(const {
            'id': 'w2',
            'labels': ['needs-review'],
          }),
          bead(const {'id': 'w3'}),
        ],
        runs: [run('failed'), run('active')],
      );
      expect(gates.map((g) => g.kind), [
        GateKind.choice,
        GateKind.gateBead,
        GateKind.reviewReady,
        GateKind.runFailed,
      ]);
    });
  });

  group('recorded shapes', () {
    test('bead oc-loy handed to the refinery', () {
      final bead = GcBead.fromJson(_recording('bead_handed_to_refinery'));
      expect(bead.branch, 'polecat/oc-loy');
      expect(bead.routedTo, isNull, reason: 'empty gc.routed_to reads as null');
      expect(bead.sessionId, 'bl-48k');
      expect(bead.sessionName, 'gastown__polecat-bl-48k');
      expect(bead.target, 'master');
      expect(bead.mergeStrategy, 'local');
      expect(bead.workDir, endsWith('polecats/gastown.furiosa'));

      final item = mapBead(bead);
      expect(item.id, 'oc-loy');
      expect(item.branch, 'polecat/oc-loy');
      expect(item.assignee, 'ocproof/gastown.refinery');
      expect(item.sessionId, 'bl-48k');
      expect(item.sessionName, 'gastown__polecat-bl-48k');
      expect(item.target, 'master');
      expect(item.mergeStrategy, 'local');
      expect(item.projectId, 'ocproof');
      // TEAM-117: in the refinery's hands the bead waits for the merge.
      expect(item.state, WorkState.review);
      expect(workHandedToMerge(item), isTrue);
      expect(item.rawState, 'open');
      // The recorded bead carries no `updated_at`: the strip must not
      // invent one.
      expect(item.updatedAt, isNull);
      expect(item.createdAt, DateTime.utc(2026, 9, 10, 18, 44, 45));
    });

    test('bead after sling keeps routing in assignee', () {
      final item = mapBead(GcBead.fromJson(_recording('bead_after_sling')));
      expect(item.assignee, 'ocproof/gastown.polecat');
      expect(item.routedTo, 'ocproof/gastown.polecat');
      expect(item.branch, isNull);
    });

    test('runs.json with partial: true yields an empty list and the flag', () {
      final list = GcRunsList.fromJson(_recording('runs'));
      expect(list.partial, isTrue);
      expect(list.partialErrors, ['run projection is warming']);
      expect(list.statusCounts['pending'], 0);
      final mapped = mapRunsList(list);
      expect(mapped.items, isEmpty);
      expect(mapped.partial, isTrue);
      expect(mapped.partialErrors, ['run projection is warming']);
      // Nothing recorded is upkeep, and nothing recorded is hidden.
      expect(mapped.items.where((r) => r.isUpkeep), isEmpty);
    });

    test('convoys track beads and become batch runs', () {
      final convoys = GcList.fromJson(
        _recording('convoys'),
        GcConvoy.fromJson,
      ).items;
      expect(convoys.single.trackedIds, ['oc-loy']);
      final loy = mapBead(
        GcBead.fromJson(_recording('bead_handed_to_refinery')),
      );
      final runs = mapConvoys(convoys, work: [loy]);
      expect(runs.single.id, 'oc-xru');
      expect(runs.single.kind, RunKind.batch);
      // The refinery holds the bead (assignee + session): waiting for
      // the merge (TEAM-117), not working; and the batch is named by
      // its work, the `sling-` title kept raw.
      expect(runs.single.state, RunState.waiting);
      expect(runs.single.title, 'Add subtract function to calc.py');
      expect(runs.single.raw['title'], 'sling-oc-loy');
      expect(runs.single.isUpkeep, isFalse);
      expect(runs.single.stepCount, 1);
      final context = GcWorkContext.from(convoys: convoys);
      expect(
        mapBead(
          GcBead.fromJson(_recording('bead_handed_to_refinery')),
          context: context,
        ).runId,
        'oc-xru',
      );
    });

    test('beads.json: internal beads are filtered unless asked for', () {
      final list = GcList.fromJson(_recording('beads'), GcBead.fromJson);
      expect(list.items, hasLength(14));
      expect(list.partial, isFalse);
      final work = mapBeadList(list);
      expect(work.items.map((w) => w.id), ['gc-2', 'gc-1', 'gc-19']);
      expect(mapBeadList(list, includeInternal: true).items, hasLength(14));
      final ready = GcList.fromJson(
        _recording('beads_ready'),
        GcBead.fromJson,
      ).items;
      final context = GcWorkContext.from(ready: ready);
      final states = {
        for (final w in mapBeads(list.items, context: context)) w.id: w.state,
      };
      expect(states['gc-19'], WorkState.ready);
      expect(states['gc-1'], WorkState.queued);
    });

    test('beads_graph root is a closed order bead', () {
      final graph = GcBeadGraph.fromJson(_recording('beads_graph'));
      final root = mapBead(graph.root!);
      expect(root.state, WorkState.completed);
      expect(root.closedReason, startsWith('order dispatch completed'));
      expect(root.labels, contains('exec-failed'));
    });

    test('status maps to host identity, counts and rigs', () {
      final status = GcStatus.fromJson(_recording('status'));
      final health = GcHealth.fromJson(_recording('health'));
      final host = mapHostIdentity(
        url: 'http://127.0.0.1:8372',
        hostMode: OrchestrationHostMode.computer,
        health: health,
        status: status,
      );
      expect(host.provider, 'gascity');
      expect(host.version, '1.4.1');
      expect(host.city, 'bright-lights');
      expect(health.isOk, isTrue);
      final counts = mapStatusCounts(status);
      expect(counts.workOpen, 29);
      expect(counts.workReady, 10);
      expect(counts.workInProgress, 0);
      expect(counts.activeAgents, 5);
      expect(status.agentDetails, hasLength(14));
      expect(status.agentDetails.where((a) => a.running), hasLength(5));
      final rigs = mapRigs(status);
      expect(rigs.single.id, 'ocproof');
      expect(rigs.single.directory, '/home/eslam/Storage/Code/oc-bg-proof');
      expect(
        mapHostIdentity(
          url: 'u',
          hostMode: OrchestrationHostMode.phone,
          status: status,
        ).city,
        'bright-lights',
      );
    });

    test('usage is labelled estimated', () {
      final usage = GcUsage.fromJson(_recording('usage'));
      expect(usage.isEstimate, isTrue);
      expect(usage.today?.computeFacts, 13);
      expect(usage.today?.wallSeconds, closeTo(4578.69, 0.01));
      final mapped = mapUsage(
        usage,
        status: GcStatus.fromJson(_recording('status')),
      );
      expect(mapped.isEstimated, isTrue);
      expect(mapped.source, 'local_estimate');
      expect(mapped.inputTokens, 0);
      expect(mapped.costUsd, 0);
      expect(mapped.workOpen, 29);
      expect(mapped.capturedAt, isNotNull);
      expect(mapped.isEmpty, isFalse);
    });

    test('events page is newest first and maps to activity', () {
      final page = GcEventsPage.fromJson(_recording('events_page'));
      expect(page.total, 1443);
      expect(page.maxSeq, 1443);
      expect(page.nextCursor, isNotNull);
      final activity = page.items.map(mapActivity).toList();
      expect(activity.first.seq, 1443);
      expect(activity.first.summary, 'order gate-sweep completed');
      expect(activity.first.actor, 'controller');
      final events = page.items.map(mapEvent);
      expect(events, everyElement(isA<ActivityAppended>()));
    });

    test('event payloads carry ids the product events need', () {
      final woke = mapEvent(
        GcEvent.fromJson(const {
          'seq': 999,
          'type': 'session.woke',
          'actor': 'gc',
          'subject': 'gastown.boot',
          'payload': {},
          'session_id': 'bl-2e9',
        }),
      );
      expect(woke, isA<SessionChanged>());
      expect((woke as SessionChanged).sessionId, 'bl-2e9');
      expect(woke.change, SessionChange.woke);
      expect(woke.agentId, 'gastown.boot');

      final stopped = mapEvent(
        GcEvent.fromJson(const {
          'seq': 969,
          'type': 'session.stopped',
          'subject': 'gastown.boot',
          'payload': {
            'session_id': 'bl-2e9',
            'template': 'gastown.boot',
            'reason': 'exited gracefully',
          },
        }),
      );
      expect((stopped as SessionChanged).sessionId, 'bl-2e9');
      expect(stopped.change, SessionChange.stopped);

      final closed = mapEvent(
        GcEvent.fromJson(const {
          'seq': 1352,
          'type': 'bead.closed',
          'subject': 'oc-a31',
          'payload': {
            'bead': {
              'id': 'oc-a31',
              'title': 'sling-oc-cq6',
              'status': 'closed',
            },
          },
          'run_id': 'oc-a31',
        }),
      );
      expect((closed as BeadChanged).beadId, 'oc-a31');
      expect(closed.change, BeadChange.closed);

      final noSubject = mapEvent(
        GcEvent.fromJson(const {
          'type': 'bead.created',
          'payload': {
            'bead': {'id': 'oc-new'},
          },
        }),
      );
      expect((noSubject as BeadChanged).beadId, 'oc-new');

      final convoyClosed = mapEvent(
        GcEvent.fromJson(const {
          'seq': 1353,
          'type': 'convoy.closed',
          'subject': 'oc-a31',
        }),
      );
      expect((convoyClosed as RunChanged).runId, 'oc-a31');
      expect(convoyClosed.state, RunState.completed);

      final failed = mapEvent(
        GcEvent.fromJson(const {
          'seq': 960,
          'type': 'order.failed',
          'subject': 'order-tracking-sweep',
          'message': 'context canceled',
        }),
      );
      expect(
        (failed as ActivityAppended).event.summary,
        'order order-tracking-sweep failed: context canceled',
      );
    });

    test('session stream turn frames decode the transcript', () {
      final file = File('${_fixtureRoot.path}/events/session-refinery.ndjson');
      final frames = file
          .readAsLinesSync()
          .where((l) => l.isNotEmpty)
          .map((l) => GcStreamFrame.fromJson(readMap(jsonDecode(l))));
      final turn = frames.firstWhere((f) => f.isTurn);
      final decoded = GcSessionTurn.fromJson(turn.data);
      expect(decoded.id, 'bl-wisp-qqpj');
      expect(decoded.template, 'ocproof/gastown.refinery');
      expect(decoded.turns, isNotEmpty);
      expect(decoded.turns.first.role, 'output');
      final mapped = mapStreamFrame(turn);
      expect(mapped, isA<ActivityAppended>());
      expect((mapped as ActivityAppended).event.type, 'session.turn');
      expect(mapped.event.subject, 'bl-wisp-qqpj');
      final pending = mapStreamFrame(
        GcStreamFrame.fromJson(const {
          'event': 'pending',
          'data': {'request_id': 'q9', 'kind': 'choice'},
        }),
      );
      expect((pending as GateChanged).gateId, 'q9');
      expect(pending.resolved, isFalse);
    });

    test('sling request and response', () {
      final request = GcSlingRequest(
        target: 'ocproof/gastown.polecat',
        bead: 'oc-loy',
        force: true,
      );
      expect(request.toJson(), {
        'target': 'ocproof/gastown.polecat',
        'bead': 'oc-loy',
        'force': true,
      });
      final response = GcSlingResponse.fromJson(_recording('sling_response'));
      expect(response.isSlung, isTrue);
      expect(response.bead, 'oc-loy');
      expect(response.mode, 'direct');
      final cli = GcSlingResponse.fromJson(_recording('sling_cli_result'));
      expect(cli.isSlung, isTrue);
      expect(cli.bead, 'gc-1');
      expect(cli.convoyId, 'gc-5');
    });

    test('readiness keyed items decode', () {
      final readiness = GcReadiness.fromJson(_recording('readiness'));
      expect(readiness.items.map((i) => i.name), [
        'claude',
        'codex',
        'gemini',
        'github_cli',
      ]);
      expect(readiness.items.every((i) => i.isConfigured), isTrue);
      expect(readiness.items.last.kind, 'tool');
    });

    test('no adapter file imports the OpenCode API layers', () {
      final dir = Directory('lib/orchestration/adapters/gascity');
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('/api/')), reason: file.path);
        expect(source, isNot(contains('/api2/')), reason: file.path);
        expect(
          source,
          isNot(contains('package:opencode_sdk')),
          reason: file.path,
        );
      }
    });
  });
}
