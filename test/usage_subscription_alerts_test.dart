// The second alert path: plans read by a computer, by Paseo or from the Codex
// account alert at the plan's level, once per crossing, and any plan can say
// "it is back". A fake notification sink stands in for Android.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/notification_preferences.dart';
import 'package:opencode_mobile/state/usage_subscription_alerts.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _paseo = UsageConnection(
  id: 'paseo1',
  name: 'Studio',
  kind: UsageConnectionKind.paseoServer,
);
const _pc = UsageConnection(
  id: 'pc',
  name: 'PC',
  kind: UsageConnectionKind.openCodeServer,
);

class _Source implements UsageSource {
  List<UsageReading> readings = [];
  @override
  Future<UsageSourceResult> read(UsageReadContext context) async =>
      UsageSourceResult(readings: readings);
}

class _Bridge implements UsageAlertBridge, UsageAlertCoverage {
  Set<String> covered = {};
  @override
  bool covers(String connectionId, String providerId) =>
      covered.contains('$connectionId|$providerId');
  @override
  List<LegacyQuotaRule> legacyRules() => const [];
  @override
  Future<void> reconcile(
    List<QuotaWatch> wanted, {
    required bool alertsOn,
  }) async {}
}

class _Rig {
  _Rig._(this.prefs);
  final SharedPreferences prefs;
  final shown = <UsageAlertNote>[];
  final dismissed = <String>[];
  var sinkWorks = true;
  var onWifi = true;
  var rules = const SharedNotifyRules(quotaAlerts: true);
  var now = DateTime(2026, 10, 13, 14);
  final source = _Source();
  late SubscriptionAlertDelivery delivery;
  late UsageSubscriptionsController controller;
  var bridge = _Bridge();

  static Future<_Rig> create({
    List<UsageConnection> connections = const [_paseo, _pc],
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final rig = _Rig._(await SharedPreferences.getInstance());
    rig._build(connections);
    return rig;
  }

  void _build(List<UsageConnection> connections) {
    delivery = SubscriptionAlertDelivery(
      prefs: prefs,
      sharedRules: () => rules,
      show: (note) async {
        if (sinkWorks) shown.add(note);
        return sinkWorks;
      },
      dismiss: (key) async => dismissed.add(key),
      wifi: () async => onWifi,
      clock: () => now,
    );
    controller = UsageSubscriptionsController(
      prefs: prefs,
      connections: () => connections,
      sources: [source],
      sharedRules: () => rules,
      setQuotaAlerts: (_) async {},
      alertBridge: bridge,
      subscriptionAlerts: delivery,
      clock: () => now,
    );
    controller.setRuntime(foreground: false, backgroundAllowed: true);
  }

  /// A new delivery over the same stored records (an app restart).
  void restart() {
    controller.dispose();
    _build(const [_paseo, _pc]);
  }

  UsageReading reading(
    String connection, {
    String provider = 'claude',
    double used = 85,
    int resetHours = 2,
    Duration age = const Duration(minutes: 1),
    String? account,
  }) => UsageReading(
    providerId: provider,
    displayName: provider == 'claude' ? 'Claude' : 'Codex',
    connectionId: connection,
    status: UsageReadingStatus.ok,
    fetchedAt: now.toUtc().subtract(age),
    accountRef: account,
    method: SignInMethod.plan,
    windows: [
      UsageWindow(
        id: 'primary',
        usedPercent: used,
        durationSeconds: 18000,
        resetsAt: now.toUtc().add(Duration(hours: resetHours)),
      ),
    ],
  );

  Future<void> read(
    List<UsageReading> readings, {
    bool foreground = false,
  }) async {
    source.readings = readings;
    controller.setRuntime(foreground: foreground, backgroundAllowed: true);
    await controller.refresh(force: true);
  }

  void dispose() => controller.dispose();
}

void main() {
  test(
    'a Paseo plan past its level alerts once, with the plan\'s token',
    () async {
      final rig = await _Rig.create();
      addTearDown(rig.dispose);
      await rig.read([rig.reading('paseo1')]);
      expect(rig.shown, hasLength(1));
      final note = rig.shown.single;
      expect(note.reset, isFalse);
      expect(note.profileId, 'paseo1');
      expect(note.providerName, 'Claude');
      expect(note.token, matches(RegExp(r'^[a-f0-9]{64}$')));
      final key = rig.controller.snapshot.subscriptions.single.key;
      expect(note.token, SubscriptionAlertDelivery.tokenFor(key));
      expect(rig.controller.ownsAlertToken('paseo1', note.token), isTrue);
      expect(rig.controller.ownsAlertToken('pc', note.token), isFalse);
      expect(rig.controller.ownsAlertToken('paseo1', 'f' * 64), isFalse);
      // The same crossing again, and again: still one notification.
      await rig.read([rig.reading('paseo1', used: 88)]);
      await rig.read([rig.reading('paseo1', used: 90)]);
      expect(rig.shown, hasLength(1));
    },
  );

  test(
    'a computer plan alerts the same way, and again after its reset',
    () async {
      final rig = await _Rig.create();
      addTearDown(rig.dispose);
      await rig.read([rig.reading('pc', provider: 'codex')]);
      expect(rig.shown, hasLength(1));
      expect(rig.shown.single.profileId, 'pc');
      expect(rig.shown.single.providerName, 'Codex');
      // The window rolls over and crosses again: a new reset time is a new
      // crossing, so it alerts again.
      await rig.read([rig.reading('pc', provider: 'codex', used: 20)]);
      await rig.read([
        rig.reading('pc', provider: 'codex', used: 83, resetHours: 5),
      ]);
      expect(rig.shown, hasLength(2));
      expect(rig.shown.every((n) => !n.reset), isTrue);
    },
  );

  test(
    'below the level nothing is shown and a stale alert is dismissed',
    () async {
      final rig = await _Rig.create();
      addTearDown(rig.dispose);
      await rig.read([rig.reading('paseo1', used: 40)]);
      expect(rig.shown, isEmpty);
      expect(rig.dismissed, isNotEmpty);
    },
  );

  test('the plan\'s own level decides, not the default', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.read([rig.reading('paseo1', used: 60)]);
    final key = rig.controller.snapshot.subscriptions.single.key;
    expect(rig.shown, isEmpty);
    await rig.controller.setThresholdFor(key, 50);
    await rig.read([rig.reading('paseo1', used: 60)]);
    expect(rig.shown, hasLength(1));
  });

  test('quiet hours hold it back and it is announced afterwards', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    rig.rules = const SharedNotifyRules(
      quotaAlerts: true,
      quietStart: 22 * 60,
      quietEnd: 8 * 60,
    );
    rig.now = DateTime(2026, 10, 13, 23);
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, isEmpty);
    rig.now = DateTime(2026, 10, 14, 9);
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, hasLength(1));
  });

  test('with the app open, or alerts off, nothing is shown', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.read([rig.reading('paseo1')], foreground: true);
    expect(rig.shown, isEmpty);
    rig.rules = const SharedNotifyRules();
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, isEmpty);
    rig.rules = const SharedNotifyRules(quotaAlerts: true);
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, hasLength(1));
  });

  test('Wi-Fi only waits for Wi-Fi without losing the crossing', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    rig.rules = const SharedNotifyRules(quotaAlerts: true, wifiOnly: true);
    rig.onWifi = false;
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, isEmpty);
    rig.onWifi = true;
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, hasLength(1));
  });

  test('a notification the system refused is tried again, not lost', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    rig.sinkWorks = false;
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, isEmpty);
    rig.sinkWorks = true;
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, hasLength(1));
  });

  test('the crossing stays alerted across an app restart', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, hasLength(1));
    rig.restart();
    await rig.read([rig.reading('paseo1')]);
    expect(rig.shown, hasLength(1));
  });

  test('numbers older than the limit never alert', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.read([rig.reading('paseo1', age: const Duration(hours: 3))]);
    expect(rig.shown, isEmpty);
  });

  test(
    'a plan the quota monitor already alerts for is not alerted twice',
    () async {
      final rig = await _Rig.create();
      addTearDown(rig.dispose);
      rig.bridge.covered = {'pc|codex'};
      await rig.read([rig.reading('pc', provider: 'codex')]);
      expect(rig.shown, isEmpty);
    },
  );

  group('the reset message', () {
    Future<_Rig> highThenLow({
      required bool covered,
      required bool switchOn,
    }) async {
      final rig = await _Rig.create();
      addTearDown(rig.dispose);
      if (covered) rig.bridge.covered = {'pc|codex'};
      await rig.read([rig.reading('pc', provider: 'codex', used: 90)]);
      final key = rig.controller.snapshot.subscriptions.single.key;
      if (switchOn) await rig.controller.setNotifyOnReset(key, true);
      rig.shown.clear();
      rig.now = rig.now.add(const Duration(hours: 3));
      await rig.read([
        rig.reading('pc', provider: 'codex', used: 2, resetHours: 5),
      ]);
      return rig;
    }

    test('says the plan is back, once, when asked to', () async {
      final rig = await highThenLow(covered: false, switchOn: true);
      expect(rig.shown, hasLength(1));
      expect(rig.shown.single.reset, isTrue);
      expect(rig.shown.single.providerName, 'Codex');
      expect(rig.shown.single.key, startsWith('quota-reset|'));
      await rig.read([
        rig.reading('pc', provider: 'codex', used: 3, resetHours: 5),
      ]);
      expect(rig.shown, hasLength(1));
    });

    test('is not sent when the switch is off', () async {
      final rig = await highThenLow(covered: false, switchOn: false);
      expect(rig.shown, isEmpty);
    });

    test(
      'is sent for a plan the monitor alerts for, without a second level alert',
      () async {
        final rig = await highThenLow(covered: true, switchOn: true);
        expect(rig.shown, hasLength(1));
        expect(rig.shown.single.reset, isTrue);
      },
    );

    test('is not sent after a long silence', () async {
      final rig = await _Rig.create();
      addTearDown(rig.dispose);
      await rig.read([rig.reading('pc', provider: 'codex', used: 90)]);
      final key = rig.controller.snapshot.subscriptions.single.key;
      await rig.controller.setNotifyOnReset(key, true);
      rig.shown.clear();
      rig.now = rig.now.add(const Duration(days: 2));
      await rig.read([
        rig.reading('pc', provider: 'codex', used: 2, resetHours: 5),
      ]);
      expect(rig.shown, isEmpty);
    });
  });

  test('records of a removed server go with it', () async {
    final rig = await _Rig.create();
    addTearDown(rig.dispose);
    await rig.read([rig.reading('paseo1')]);
    expect(rig.prefs.getString(SubscriptionAlertDelivery.storeKey), isNotNull);
    rig.controller.removeProfile('paseo1');
    await Future<void>.delayed(Duration.zero);
    final left = rig.prefs.getString(SubscriptionAlertDelivery.storeKey);
    expect(left, anyOf(isNull, isNot(contains('claude'))));
  });
}
