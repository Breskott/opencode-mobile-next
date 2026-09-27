import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/usage.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/orchestration/models/usage.dart';

void main() {
  test('today retains partial and unpriced estimate evidence', () {
    final mapped = mapUsage(
      GcUsage.fromJson({
        'available': true,
        'recording': false,
        'source': 'local_estimate',
        'partial': true,
        'partial_reasons': ['history bounded'],
        'observed_from': '2026-09-27T02:00:00Z',
        'updated_at': '2026-09-27T03:00:00Z',
        'today': {
          'input_tokens': 50,
          'output_tokens': 10,
          'cost_usd_estimate': 0.25,
          'unpriced': 2,
        },
      }),
    );
    final evidence = mapped.evidence!;
    expect(evidence.available, isTrue);
    expect(evidence.recording, isFalse);
    expect(evidence.isEstimated, isTrue);
    expect(evidence.partial, isTrue);
    expect(evidence.partialReasons, ['history bounded']);
    expect(evidence.observedFrom, DateTime.utc(2026, 9, 27, 2));
    expect(evidence.updatedAt, mapped.capturedAt);
    expect(evidence.today!.costUsdEstimate, 0.25);
    expect(evidence.today!.unpriced, 2);
    expect(evidence.today!.cacheReadTokens, isNull);
    expect(mapped.costUsd, 0.25);
    expect(mapped.inputTokens, 50);
    expect(evidence.recentBySession, isNull);
    expect(() => evidence.partialReasons.add('other'), throwsUnsupportedError);
  });

  test('unavailable and absent usage never manufacture a zero cost', () {
    expect(const OrchestrationUsage().evidence, isNull);
    for (final flags in [
      {'available': false, 'source': 'local_estimate'},
      {'available': true, 'source': 'unavailable'},
      <String, Object?>{},
    ]) {
      final mapped = mapUsage(
        GcUsage.fromJson({
          ...flags,
          'today': {'cost_usd_estimate': 0},
          'recent': {'cost_usd_estimate': 0},
          'recent_by_session': <Object?>[],
        }),
      );
      expect(mapped.evidence!.available, isFalse);
      expect(mapped.costUsd, isNull);
      expect(mapped.evidence!.today, isNull);
      expect(mapped.evidence!.recent, isNull);
      expect(mapped.evidence!.recentBySession, isNull);
    }
    final empty = mapUsage(GcUsage.fromJson({'available': true})).evidence!;
    expect(empty.today, isNull);
    expect(empty.recentWindow, isNull);
  });

  test('recent sessions remain separate window snapshots, not task totals', () {
    final payload = <String, Object?>{
      'available': true,
      'recording': true,
      'source': 'local_estimate',
      'today': {'cost_usd_estimate': 4},
      'recent': {'cost_usd_estimate': 1},
      'recent_window_secs': 300,
      'recent_by_session': [
        {
          'session': 'worker-a',
          'session_id': 'session-bead-1',
          'input_tokens': 100,
          'output_tokens': 20,
          'cache_read_tokens': 8,
          'cache_creation_tokens': 3,
          'cost_usd_estimate': 0.75,
          'unpriced': 1,
        },
        {'session': 'worker-b', 'cost_usd_estimate': 0.25},
      ],
    };
    final first = mapUsage(GcUsage.fromJson(payload)).evidence!;
    final next = mapUsage(GcUsage.fromJson(payload)).evidence!;
    expect(first.recentWindow, const Duration(minutes: 5));
    expect(first.recentBySession, hasLength(2));
    final worker = first.recentBySession!.first;
    expect(worker.workerName, 'worker-a');
    expect(worker.sessionId, 'session-bead-1');
    expect(worker.totals.inputTokens, 100);
    expect(worker.totals.outputTokens, 20);
    expect(worker.totals.cacheReadTokens, 8);
    expect(worker.totals.cacheCreationTokens, 3);
    expect(worker.totals.costUsdEstimate, 0.75);
    expect(worker.totals.unpriced, 1);
    expect(first.recentBySession!.last.sessionId, isNull);
    expect(first.recentBySession!.last.totals.unpriced, isNull);
    expect(next.today!.costUsdEstimate, 4);
    expect(next.recent!.costUsdEstimate, 1);
    expect(() => first.recentBySession!.clear(), throwsUnsupportedError);
    expect(
      mapUsage(
        GcUsage.fromJson({...payload, 'recent_by_session': <Object?>[]}),
      ).evidence!.recentBySession,
      isEmpty,
    );
  });

  test('invalid figures remain unknown and future sources stay estimates', () {
    final mapped = mapUsage(
      const GcUsage(
        available: true,
        source: 'future-source',
        recentWindowSecs: -1,
        today: GcUsageTotals(
          inputTokens: -1,
          costUsdEstimate: double.nan,
          unpriced: -1,
        ),
      ),
    );
    final evidence = mapped.evidence!;
    expect(mapped.isEstimated, isTrue);
    expect(evidence.isEstimated, isTrue);
    expect(evidence.today!.inputTokens, isNull);
    expect(evidence.today!.costUsdEstimate, isNull);
    expect(evidence.today!.unpriced, isNull);
    expect(evidence.recentWindow, isNull);
  });
}
