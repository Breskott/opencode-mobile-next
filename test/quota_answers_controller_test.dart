import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/domain/quota_answers.dart';
import 'package:opencode_mobile/state/quota_answer_preferences.dart';
import 'package:opencode_mobile/state/quota_answers_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/account_fakes.dart';

class _Collector implements ProviderQuotaGateway {
  final Future<ProviderQuotaSnapshot> Function() read;
  bool closed = false;
  _Collector(this.read);
  @override
  Future<ProviderQuotaSnapshot> readSnapshot() => read();
  @override
  void close() => closed = true;
}

ProviderQuotaSnapshot _collected(DateTime now, {bool stale = false}) =>
    ProviderQuotaSnapshot.fromJson({
      'schemaVersion': 1,
      'provider': 'codex',
      'source': 'codex.wham',
      'status': 'ok',
      'freshness': stale ? 'stale' : 'fresh',
      'fetchedAtMs': now.millisecondsSinceEpoch,
      'expiresAtMs': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      'account': {'ref': 'a' * 64, 'status': 'matched'},
      'ordinaryUsageAllowed': true,
      'windows': [
        {
          'id': 'weekly',
          'status': 'reported',
          'usedPercent': 80,
          'durationSeconds': 604800,
          'resetsAtMs': now.add(const Duration(days: 2)).millisecondsSinceEpoch,
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late bool current;
  late bool present;
  late QuotaAnswerPreferences preferences;
  late FakeAccountSession session;
  late QuotaAnswersController controller;

  List<AccountRateBucket> limits(int used) => [
    AccountRateBucket(
      'Codex',
      null,
      AccountRateWindow(used, 10080, DateTime.utc(2026, 9, 29)),
    ),
  ];

  setUp(() async {
    now = DateTime.utc(2026, 9, 27, 12);
    current = true;
    present = true;
    SharedPreferences.setMockInitialValues({});
    preferences = QuotaAnswerPreferences(
      preferences: await SharedPreferences.getInstance(),
      profileId: 'test-profile',
      isCurrent: () => current,
      isProfilePresent: () => present,
    );
    session = FakeAccountSession()
      ..account = fixtureSignedIn
      ..buckets = limits(60);
    controller = QuotaAnswersController.codex(
      session: session,
      preferences: preferences,
      isCurrent: () => current && present,
      clock: () => now,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'Codex Remaining comes from account rate limits without enrollment',
    () async {
      await controller.refresh();
      expect(controller.status, QuotaAnswerStatus.ready);
      expect(controller.snapshot!.source, QuotaAnswerSource.codexAccount);
      expect(controller.snapshot!.windows.single.remainingPercent, 40);
      expect(controller.snapshot!.windows.single.isWeekly, isTrue);
      expect(controller.snapshot!.observedAt, now);
      expect(controller.alert80Enabled, isTrue);
      expect(session.starts, 0);
      expect(session.usageReads, 0);
    },
  );

  test(
    'offline and failed refresh keep original value and its growing age',
    () async {
      await controller.refresh();
      final fetchedAt = controller.snapshot!.observedAt;
      now = now.add(const Duration(hours: 3));
      session.onRead = () async =>
          throw StateError('synthetic transport error');
      await controller.refresh();
      expect(controller.status, QuotaAnswerStatus.unavailable);
      expect(controller.snapshot!.windows.single.remainingPercent, 40);
      expect(controller.snapshot!.observedAt, fetchedAt);
      expect(controller.age, const Duration(hours: 3));
      expect(controller.stale, isTrue);
      expect(controller.attentionRequired, isFalse);
      session.notifications.add(
        const AccountEvent(AccountEventKind.disconnected),
      );
      now = now.add(const Duration(hours: 1));
      expect(controller.age, const Duration(hours: 4));
    },
  );

  test('80 percent alert is default-on and deduped per reset window', () async {
    session.buckets = limits(79);
    await controller.refresh();
    expect(controller.attentionRequired, isFalse);
    session.buckets = limits(80);
    await controller.refresh();
    expect(controller.attentionRequired, isTrue);
    await controller.refresh();
    expect(controller.attentionRequired, isFalse);
    session.buckets = [
      AccountRateBucket(
        null,
        AccountRateWindow(81, 10080, DateTime.utc(2026, 10, 6)),
        null,
      ),
    ];
    await controller.refresh();
    expect(controller.attentionRequired, isTrue);
  });

  test('disabled alert stays off across successful reads', () async {
    expect(await controller.setAlert80Enabled(false), isTrue);
    session.buckets = limits(95);
    await controller.refresh();
    expect(controller.alert80Enabled, isFalse);
    expect(controller.attentionRequired, isFalse);
    expect(preferences.alert80Enabled, isFalse);
  });

  test(
    'reset passing does not invent replenishment or a fresh alert',
    () async {
      session.buckets = limits(90);
      await controller.refresh();
      now = DateTime.utc(2026, 9, 29);
      expect(controller.stale, isTrue);
      expect(controller.snapshot!.windows.single.remainingPercent, 10);
      expect(controller.attentionRequired, isFalse);
      await controller.refresh();
      expect(controller.stale, isTrue);
      expect(controller.attentionRequired, isFalse);
    },
  );

  test(
    'signed-out and API-key accounts never read subscription limits',
    () async {
      session.account = fixtureSignedOut;
      await controller.refresh();
      expect(controller.status, QuotaAnswerStatus.needsSignIn);
      expect(controller.snapshot, isNull);
      session.account = const AgentAccount(
        type: 'apiKey',
        requiresSignIn: false,
      );
      await controller.refresh();
      expect(controller.status, QuotaAnswerStatus.unsupported);
      expect(session.limitReads, 0);
    },
  );

  test('unsupported account runtime does not dispatch reads', () async {
    session.supported = false;
    await controller.refresh();
    expect(controller.status, QuotaAnswerStatus.unsupported);
    expect(session.reads, 0);
    expect(session.limitReads, 0);
  });

  test('profile deletion blocks late readings and preference writes', () async {
    final pending = Completer<List<AccountRateBucket>>();
    session.onLimits = () => pending.future;
    final read = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    present = false;
    controller.invalidate(forget: true);
    pending.complete(limits(90));
    await read;
    expect(controller.snapshot, isNull);
    expect(controller.loading, isFalse);
    expect(await controller.setAlert80Enabled(false), isFalse);
  });

  test('account change drops old identity before a failed refresh', () async {
    await controller.refresh();
    session.onRead = () async =>
        throw const AgentAccountException(AgentAccountFailure.unavailable);
    session.notifications.add(const AccountEvent(AccountEventKind.changed));
    expect(controller.snapshot, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(controller.snapshot, isNull);
    expect(controller.status, QuotaAnswerStatus.unavailable);
  });

  test(
    'new session after reconnect cannot inherit old account quota',
    () async {
      await controller.refresh();
      final replacement = FakeAccountSession()..account = fixtureSignedOut;
      controller.replaceAccountSession(replacement);
      expect(controller.snapshot, isNull);
      await controller.refresh();
      expect(controller.status, QuotaAnswerStatus.needsSignIn);
      expect(session.closed, isTrue);
      expect(replacement.reads, 1);
    },
  );

  test(
    'latest refresh wins and late reads after dispose are ignored',
    () async {
      final pending = Completer<List<AccountRateBucket>>();
      session.onLimits = () => pending.future;
      final first = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      session.onLimits = null;
      session.buckets = limits(25);
      await controller.refresh();
      pending.complete(limits(95));
      await first;
      expect(controller.snapshot!.windows.single.remainingPercent, 75);
      final late = Completer<AgentAccount>();
      session.onRead = () => late.future;
      final last = controller.refresh();
      controller.dispose();
      late.complete(fixtureSignedIn);
      await last;
      expect(controller.snapshot, isNull);
    },
  );

  test('invalid percentages never become remaining answers', () async {
    session.buckets = limits(101);
    await controller.refresh();
    expect(controller.snapshot, isNull);
    expect(controller.status, QuotaAnswerStatus.invalidResponse);
  });

  void useCollector(Future<ProviderQuotaSnapshot> Function() read) {
    controller.dispose();
    controller = QuotaAnswersController.collector(
      gatewayFactory: () => _Collector(read),
      serverName: 'Work server',
      preferences: preferences,
      isCurrent: () => current && present,
      clock: () => now,
    );
  }

  test(
    'missing collector names selected server and provides setup guide',
    () async {
      useCollector(
        () async =>
            throw const ProviderQuotaFailure(QuotaFailureKind.unsupported),
      );
      await controller.refresh();
      expect(controller.status, QuotaAnswerStatus.needsCollector);
      expect(controller.serverName, 'Work server');
      expect(
        QuotaAnswersController.collectorSetupGuide,
        'tool/quota/README.md',
      );
      expect(controller.snapshot, isNull);
    },
  );

  test(
    'collector timestamp is preserved and stale results never alert',
    () async {
      final observedAt = now.subtract(const Duration(hours: 1));
      useCollector(() async => _collected(observedAt, stale: true));
      await controller.refresh();
      expect(controller.snapshot!.observedAt, observedAt);
      expect(controller.age, const Duration(hours: 1));
      expect(controller.snapshot!.windows.single.isWeekly, isTrue);
      expect(controller.stale, isTrue);
      expect(controller.attentionRequired, isFalse);
    },
  );

  test('collector setup exposes only a redacted server label', () {
    controller.dispose();
    controller = QuotaAnswersController.collector(
      gatewayFactory: () => _Collector(() async => _collected(now)),
      serverName: 'Work https://synthetic:fixture@example.invalid',
      preferences: preferences,
      isCurrent: () => true,
      clock: () => now,
    );
    expect(controller.serverName, 'Work https://•••@example.invalid');
  });

  test('collector freshness expires even if the clock jumps forward', () async {
    final observed = now;
    useCollector(() async => _collected(observed));
    await controller.refresh();
    expect(controller.stale, isFalse);
    now = now.add(const Duration(minutes: 5));
    expect(controller.stale, isTrue);
    expect(controller.attentionRequired, isFalse);
    expect(controller.snapshot!.observedAt, observed);
  });

  test(
    'same-account collector outages keep the original observation',
    () async {
      ProviderQuotaStatus? failure;
      final observed = now;
      useCollector(() async {
        if (failure == null) return _collected(observed);
        return ProviderQuotaSnapshot.fromJson({
          'schemaVersion': 1,
          'provider': 'codex',
          'source': 'codex.wham',
          'status': failure.name,
          'freshness': 'none',
          'fetchedAtMs': now.millisecondsSinceEpoch,
          'expiresAtMs': now.millisecondsSinceEpoch,
          'account': {'ref': 'a' * 64, 'status': 'matched'},
          'windows': <Object>[],
        });
      });
      await controller.refresh();
      now = now.add(const Duration(hours: 1));
      for (final kind in [
        ProviderQuotaStatus.unavailable,
        ProviderQuotaStatus.rateLimited,
      ]) {
        failure = kind;
        await controller.refresh();
        expect(controller.snapshot!.observedAt, observed);
        expect(controller.age, const Duration(hours: 1));
        expect(controller.snapshot!.windows.single.remainingPercent, 20);
        expect(controller.stale, isTrue);
        expect(controller.attentionRequired, isFalse);
      }
    },
  );

  test('changed account clears listeners before pending rate limits', () async {
    await controller.refresh();
    session.account = const AgentAccount(
      type: 'chatgpt',
      email: 'another@example.com',
      requiresSignIn: true,
    );
    final pending = Completer<List<AccountRateBucket>>();
    session.onLimits = () => pending.future;
    var sawCleared = false;
    controller.addListener(() {
      if (controller.snapshot == null) sawCleared = true;
    });
    final reading = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(sawCleared, isTrue);
    expect(controller.snapshot, isNull);
    pending.complete(limits(20));
    await reading;
    expect(controller.snapshot!.windows.single.remainingPercent, 80);
  });

  test('collector auth failure clears previously attributed values', () async {
    var fail = false;
    useCollector(() async {
      if (fail) {
        throw const ProviderQuotaFailure(QuotaFailureKind.collectorAuth);
      }
      return _collected(now);
    });
    await controller.refresh();
    expect(controller.attentionRequired, isTrue);
    fail = true;
    await controller.refresh();
    expect(controller.snapshot, isNull);
    expect(controller.status, QuotaAnswerStatus.collectorAuth);
  });
}
