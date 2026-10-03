// Finished runs stay visible (docs/qa/aiteam-builtin-2026-09-24 step 12,
// Run 2 step 8): Gas City's `/convoys` lists open convoys only, so a batch
// vanished the moment its task merged and the home said "No runs yet".
// The gateway now also reads the recently closed convoys; these tests run
// it and the mappers over JSON recorded from the live emulator city
// (test/support/gascity_recorded_city.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';

import 'support/gascity_recorded_city.dart';

const _task = 'Create hello.py that prints Hello from the AI Team';

void main() {
  group('mapping (recorded JSON)', () {
    test('a closed convoy from GET /convoy/{id} is a finished, merged run', () {
      final convoy = GcConvoy.fromJson(recordedJson('convoy_ma-lqw.json'));
      final run = mapConvoy(convoy, closedAt: recordedConvoyClosedAt);
      expect(run.id, 'ma-lqw');
      expect(run.title, _task);
      expect(run.kind, RunKind.batch);
      expect(run.state, RunState.completed);
      expect(run.merged, isTrue);
      expect(run.finishedAt, recordedConvoyClosedAt);
      // No updated_at on the host's bead: the close time orders it.
      expect(run.updatedAt, recordedConvoyClosedAt);
      expect(run.stepCount, 1);
      expect(run.completedSteps, 1);
    });

    test('a closed convoy whose work reports no merge is done, not merged', () {
      final json = recordedJson('convoy_ma-lqw.json');
      final child = Map<String, Object?>.of(
        (json['children']! as List).single as Map<String, Object?>,
      );
      child['metadata'] = {'close_reason': 'nothing to change'};
      final convoy = GcConvoy.fromJson({
        ...json,
        'children': [child],
      });
      final run = mapConvoy(convoy, closedAt: recordedConvoyClosedAt);
      expect(run.state, RunState.completed);
      expect(run.merged, isFalse);
      expect(run.finishedAt, recordedConvoyClosedAt);
    });

    test('a cancelled close is finished, cancelled and never merged', () {
      final json = recordedJson('convoy_ma-lqw.json');
      final bead = Map<String, Object?>.of(
        json['convoy']! as Map<String, Object?>,
      );
      bead['metadata'] = {'close_reason': 'cancelled by owner'};
      final run = mapConvoy(
        GcConvoy.fromJson({...json, 'convoy': bead}),
        closedAt: recordedConvoyClosedAt,
      );
      expect(run.state, RunState.cancelled);
      expect(run.merged, isFalse);
      expect(run.finishedAt, recordedConvoyClosedAt);
    });

    test('an open convoy with work in progress has no finish time and is '
        'not merged', () {
      final json = recordedJson('convoy_ma-lqw.json');
      final bead = Map<String, Object?>.of(
        json['convoy']! as Map<String, Object?>,
      )..['status'] = 'open';
      final child = Map<String, Object?>.of(
        (json['children']! as List).single as Map<String, Object?>,
      );
      child['status'] = 'in_progress';
      child['metadata'] = {'gc.session_id': 'ph-4ti', 'branch': 'polecat/x'};
      final run = mapConvoy(
        GcConvoy.fromJson({
          ...json,
          'convoy': bead,
          'children': [child],
        }),
        closedAt: recordedConvoyClosedAt,
      );
      expect(run.state, isNot(RunState.completed));
      expect(run.finishedAt, isNull);
      expect(run.merged, isFalse);
    });

    test('convoyClosedTimes reads subject and ts of convoy.closed', () {
      final page = GcEventsPage.fromJson(
        recordedJson('events_convoy_closed.json'),
      );
      expect(convoyClosedTimes(page.items), {'ma-lqw': recordedConvoyClosedAt});
      expect(
        convoyClosedTimes([
          GcEvent(type: 'bead.closed', subject: 'x', ts: DateTime.utc(2026)),
        ]),
        isEmpty,
      );
    });

    group('selectFinishedConvoys', () {
      final recorded = GcList<GcBead>.fromJson(
        recordedJson('beads_closed_convoys.json'),
        GcBead.fromJson,
      ).items;
      GcBead closed(String id, DateTime created) => GcBead(
        id: id,
        title: 'sling-$id',
        status: 'closed',
        issueType: 'convoy',
        createdAt: created,
      );

      test('keeps a convoy closed within the window', () {
        final picked = selectFinishedConvoys(
          recorded,
          now: recordedConvoyClosedAt.add(const Duration(hours: 5)),
          window: const Duration(days: 7),
          limit: 20,
          closedAt: {'ma-lqw': recordedConvoyClosedAt},
        );
        expect([for (final b in picked) b.id], ['ma-lqw']);
      });

      test('drops one closed before the window, by close time', () {
        expect(
          selectFinishedConvoys(
            recorded,
            now: recordedConvoyClosedAt.add(const Duration(days: 8)),
            window: const Duration(days: 7),
            limit: 20,
            closedAt: {'ma-lqw': recordedConvoyClosedAt},
          ),
          isEmpty,
        );
      });

      test('drops one that is open again, and non-convoys', () {
        final task = GcBead(
          id: 'ma-7mr',
          title: _task,
          status: 'closed',
          issueType: 'task',
          createdAt: recordedConvoyClosedAt,
        );
        expect(
          selectFinishedConvoys(
            [...recorded, task],
            now: recordedConvoyClosedAt,
            window: const Duration(days: 7),
            limit: 20,
            openIds: {'ma-lqw'},
          ),
          isEmpty,
        );
      });

      test('newest first, at most limit, created_at when no close event', () {
        final base = DateTime.utc(2026, 9, 20);
        final picked = selectFinishedConvoys(
          [
            closed('c-1', base),
            closed('c-2', base.add(const Duration(days: 1))),
            closed('c-3', base.add(const Duration(days: 2))),
          ],
          now: base.add(const Duration(days: 3)),
          window: const Duration(days: 7),
          limit: 2,
          closedAt: {'c-1': base.add(const Duration(days: 2, hours: 12))},
        );
        expect([for (final b in picked) b.id], ['c-1', 'c-3']);
      });
    });
  });

  group('gateway against the recorded city', () {
    late RecordedCity city;

    setUp(() async {
      city = await RecordedCity.start();
      addTearDown(city.close);
    });

    GasCityGateway gateway({DateTime? now}) {
      final gateway = GasCityGateway(
        url: city.url,
        city: recordedCity,
        clock: () =>
            now ?? recordedConvoyClosedAt.add(const Duration(hours: 5)),
      );
      addTearDown(gateway.close);
      return gateway;
    }

    Iterable<String> sent(String path) => [
      for (final uri in city.requests)
        if (uri.path == '/v0/city/$recordedCity$path') uri.query,
    ];

    test('the merged task stays listed as a finished run after its convoy '
        'closed (/convoys is empty)', () async {
      final runs = await gateway().runs();
      final batch = runs.where((r) => r.kind == RunKind.batch).toList();
      expect(batch, hasLength(1));
      final run = batch.single;
      expect(run.id, 'ma-lqw');
      expect(run.title, _task);
      expect(run.state, RunState.completed);
      expect(run.merged, isTrue);
      expect(run.finishedAt, recordedConvoyClosedAt);
      expect(run.isUpkeep, isFalse);
      // The recorded /runs are all refinery patrols: upkeep, never counted.
      expect(
        runs.where((r) => r.kind == RunKind.formula).every((r) => r.isUpkeep),
        isTrue,
      );
    });

    test('a finished run keeps its work: the merged task is listed under it '
        '(the Work tab of a finished run was empty)', () async {
      final g = gateway();
      final work = await g.work();
      final mine = work.where((item) => item.runId == 'ma-lqw').toList();
      expect(mine.map((item) => item.id), ['ma-7mr']);
      expect(mine.single.title, _task);
      expect(mine.single.state, WorkState.completed);
      // Listed once, even when the open list has it too.
      expect(work.where((item) => item.id == 'ma-7mr'), hasLength(1));
    });

    test('history reads are bounded: newest 20, one week of close events, '
        'each closed convoy detail fetched once', () async {
      final g = gateway();
      await g.runs();
      expect(sent('/beads'), contains('status=closed&type=convoy&limit=20'));
      expect(
        sent('/events'),
        contains('type=convoy.closed&since=10080m&limit=20'),
      );
      expect(sent('/convoy/ma-lqw'), hasLength(1));
      await g.runs();
      expect(sent('/convoy/ma-lqw'), hasLength(1), reason: 'cached');
      expect(await g.run('ma-lqw'), isNotNull);
    });

    test(
      'a run that finished before the window is not listed or fetched',
      () async {
        final runs = await gateway(
          now: recordedConvoyClosedAt.add(const Duration(days: 8)),
        ).runs();
        expect(runs.where((r) => r.kind == RunKind.batch), isEmpty);
        expect(sent('/convoy/ma-lqw'), isEmpty);
      },
    );

    test(
      'a host without the history routes still lists the open runs',
      () async {
        city.missing.addAll(['/beads?closed-convoys', '/events?convoy.closed']);
        final runs = await gateway().runs();
        expect(runs, isNotEmpty);
        expect(runs.where((r) => r.kind == RunKind.batch), isEmpty);
      },
    );

    test(
      'an unreadable detail falls back to the list bead: still done',
      () async {
        city.missing.add('/convoy/ma-lqw');
        final runs = await gateway().runs();
        final run = runs.singleWhere((r) => r.id == 'ma-lqw');
        expect(run.state, RunState.completed);
        expect(run.finishedAt, recordedConvoyClosedAt);
        expect(run.merged, isFalse, reason: 'the work was not read');
      },
    );
  });
}
