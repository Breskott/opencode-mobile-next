import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/quota_answers.dart';
import 'package:opencode_mobile/domain/usage_statistics.dart';

UsageStatistics _statistics(DateTime from, DateTime to) => UsageStatistics(
  from: from.millisecondsSinceEpoch,
  to: to.millisecondsSinceEpoch,
  sessions: 0,
  subagents: 0,
  prompts: 0,
  steps: 0,
  activeDays: 0,
  streak: 0,
  cost: 0,
  tokens: const UsageTokens(
    input: 0,
    output: 0,
    reasoning: 0,
    cacheRead: 0,
    cacheWrite: 0,
  ),
  models: const [],
  activity: const [],
);

void main() {
  test('weekly 60 percent used means 40 percent remaining', () {
    const window = QuotaAnswerWindow(
      id: 'weekly',
      usedPercent: 60,
      durationMinutes: 10080,
    );
    expect(window.remainingPercent, 40);
    expect(window.isWeekly, isTrue);
    expect(
      const QuotaAnswerWindow(id: 'short', usedPercent: 60).isWeekly,
      isFalse,
    );
    expect(
      const QuotaAnswerWindow(
        id: 'exceeded',
        usedPercent: 120,
      ).remainingPercent,
      0,
    );
  });

  test('offline reads keep observation time and increase age', () {
    final observed = DateTime.utc(2026, 9, 27, 10);
    final snapshot = QuotaAnswerSnapshot(
      source: QuotaAnswerSource.codexAccount,
      observedAt: observed,
      windows: const [],
    );
    expect(
      snapshot.age(observed.add(const Duration(minutes: 5))),
      const Duration(minutes: 5),
    );
    expect(
      snapshot.age(observed.add(const Duration(hours: 2))),
      const Duration(hours: 2),
    );
    expect(snapshot.observedAt, observed);
    expect(
      snapshot.age(observed.subtract(const Duration(seconds: 1))),
      Duration.zero,
    );
  });

  test(
    'a window expires at its reset while an unknown reset stays unknown',
    () {
      final reset = DateTime.utc(2026, 9, 29);
      final snapshot = QuotaAnswerSnapshot(
        source: QuotaAnswerSource.codexAccount,
        observedAt: reset.subtract(const Duration(days: 1)),
        windows: [
          const QuotaAnswerWindow(id: 'unknown', usedPercent: 20),
          QuotaAnswerWindow(id: 'weekly', usedPercent: 60, resetsAt: reset),
        ],
      );
      expect(
        snapshot.isExpired(reset.subtract(const Duration(milliseconds: 1))),
        isFalse,
      );
      expect(snapshot.isExpired(reset), isTrue);
      expect(snapshot.isExpired(reset.add(const Duration(days: 1))), isTrue);
      final unknown = QuotaAnswerSnapshot(
        source: QuotaAnswerSource.collector,
        observedAt: reset,
        windows: const [QuotaAnswerWindow(id: 'unknown', usedPercent: 20)],
      );
      expect(unknown.isExpired(reset.add(const Duration(days: 365))), isFalse);
    },
  );

  test('snapshot copies its windows and does not allow mutation', () {
    final input = [const QuotaAnswerWindow(id: 'weekly', usedPercent: 60)];
    final snapshot = QuotaAnswerSnapshot(
      source: QuotaAnswerSource.codexAccount,
      observedAt: DateTime.utc(2026, 9, 27),
      windows: input,
    );
    input.clear();
    expect(snapshot.windows.single.id, 'weekly');
    expect(() => snapshot.windows.clear(), throwsUnsupportedError);
  });

  test(
    'Spent preserves Sep 2–6 bounds when thirty-day response is narrower',
    () {
      final requestedFrom = DateTime.utc(2026, 8, 9);
      final requestedTo = DateTime.utc(2026, 9, 8);
      final actualFrom = DateTime.utc(2026, 9, 2);
      final actualTo = DateTime.utc(2026, 9, 7);
      final period = SpentPeriod.fromUsage(
        query: UsageQuery(
          from: requestedFrom.millisecondsSinceEpoch,
          to: requestedTo.millisecondsSinceEpoch,
          timezone: 'UTC',
        ),
        statistics: _statistics(actualFrom, actualTo),
        requestedRange: UsageRange.thirtyDays,
      );
      expect(period.from, actualFrom);
      expect(period.to, actualTo);
      expect(period.requestedRange, UsageRange.thirtyDays);
      expect(period.matchesRequestedRange, isFalse);
      expect(period.to.subtract(const Duration(milliseconds: 1)).day, 6);
    },
  );

  test('Spent reports matching submitted interval without extending it', () {
    final from = DateTime.utc(2026, 9, 1);
    final to = DateTime.utc(2026, 9, 27, 10);
    final period = SpentPeriod.fromUsage(
      query: UsageQuery(
        from: from.millisecondsSinceEpoch,
        to: to.millisecondsSinceEpoch,
        timezone: 'UTC',
      ),
      statistics: _statistics(from, to),
      requestedRange: UsageRange.thirtyDays,
    );
    expect(period.matchesRequestedRange, isTrue);
    expect(period.from.isUtc, isTrue);
    expect(period.to, to);
  });

  test(
    'Spent notices a changed lower bound even with matching upper bound',
    () {
      final from = DateTime.utc(2026, 8, 29);
      final to = DateTime.utc(2026, 9, 27, 10);
      final period = SpentPeriod.fromUsage(
        query: UsageQuery(
          from: from.millisecondsSinceEpoch,
          to: to.millisecondsSinceEpoch,
          timezone: 'UTC',
        ),
        statistics: _statistics(from.add(const Duration(days: 1)), to),
        requestedRange: UsageRange.thirtyDays,
      );
      expect(period.matchesRequestedRange, isFalse);
    },
  );

  test(
    'all-time accepts first available record but still checks upper bound',
    () {
      final from = DateTime.utc(2020, 1, 1);
      final to = DateTime.utc(2026, 9, 27);
      final query = UsageQuery(to: to.millisecondsSinceEpoch, timezone: 'UTC');
      final period = SpentPeriod.fromUsage(
        query: query,
        statistics: _statistics(from, to),
        requestedRange: UsageRange.allTime,
      );
      expect(period.matchesRequestedRange, isTrue);
      expect(period.from, from);
      expect(
        SpentPeriod.fromUsage(
          query: query,
          statistics: _statistics(from, to.subtract(const Duration(days: 1))),
          requestedRange: UsageRange.allTime,
        ).matchesRequestedRange,
        isFalse,
      );
      expect(
        SpentPeriod.fromUsage(
          query: query,
          statistics: _statistics(from, to),
          requestedRange: UsageRange.thirtyDays,
        ).matchesRequestedRange,
        isFalse,
      );
    },
  );
}
