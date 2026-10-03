import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/attention_feed.dart';
import 'package:opencode_mobile/domain/work_row_status.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/profile_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';

import 'support/profile_monitor_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    AutomationPolicyController.resetShared();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storage,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  Future<void> legacyConsent(ProfileStore store) async {
    await store.prefs.setString(
      ProfileMonitor.rulesKey('profile-1'),
      jsonEncode(const ProfileNotifyRules(enabled: true).toJson()),
    );
  }

  test(
    'existing policy off forbids transport despite enabled monitor rule',
    () async {
      final store = await monitorStore(count: 1);
      await legacyConsent(store);
      await AutomationPolicyController.forProfile(
        store.prefs,
        'profile-1',
      ).setBehavior(AutomationBehavior.monitorOtherServers, false);
      var factories = 0;
      final monitor = ProfileMonitor(
        store: store,
        createGateway: (_) {
          factories++;
          return (
            gateway: MonitorTestGateway(),
            operations: MonitorTestOperations(),
          );
        },
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      await monitor.refresh();
      expect(factories, 0);
      expect(
        monitor.snapshotFor('profile-1').status,
        ProfileMonitorStatus.disabled,
      );
      await monitor.setRules(
        'profile-1',
        monitor.rulesFor('profile-1').copyWith(notifications: false),
      );
      await monitor.refresh();
      expect(factories, 0);
      expect(
        AutomationPolicyController.forProfile(
          store.prefs,
          'profile-1',
        ).value.allows(AutomationBehavior.monitorOtherServers),
        isFalse,
      );
      await monitor.setEnabled('profile-1', true);
      await monitor.refresh();
      expect(factories, 1);
      expect(
        AutomationPolicyController.forProfile(
          store.prefs,
          'profile-1',
        ).value.allows(AutomationBehavior.monitorOtherServers),
        isTrue,
      );
    },
  );

  for (final interruption in ['policy', 'runtime', 'remove']) {
    test('$interruption interrupts an in-flight read permanently', () async {
      final store = await monitorStore(count: 1);
      await legacyConsent(store);
      final pending = Completer<List<PermissionRequest>>();
      final entered = Completer<void>();
      final gateway = MonitorTestGateway(pending: pending);
      var enriched = 0;
      final monitor = ProfileMonitor(
        store: store,
        createGateway: (_) {
          entered.complete();
          return (gateway: gateway, operations: MonitorTestOperations());
        },
        readAttention: (p, pair, sessions, statuses, current) async {
          enriched++;
          return const MonitorAttentionDetails(items: [], complete: true);
        },
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      final read = monitor.refresh();
      await entered.future;
      // Let the list resolve so the pending permission read is the boundary.
      await Future<void>.delayed(Duration.zero);
      if (interruption == 'policy') {
        await AutomationPolicyController.forProfile(
          store.prefs,
          'profile-1',
        ).setBehavior(AutomationBehavior.reconnect, false);
        expect(gateway.isClosed, isFalse);
        await AutomationPolicyController.forProfile(
          store.prefs,
          'profile-1',
        ).setBehavior(AutomationBehavior.monitorOtherServers, false);
      } else if (interruption == 'runtime') {
        monitor.setRuntime(foreground: false, backgroundAllowed: false);
        monitor.setRuntime(foreground: true, backgroundAllowed: false);
      } else {
        monitor.removeProfile('profile-1');
      }
      expect(gateway.isClosed, isTrue);
      pending.complete([request(1)]);
      await read;
      expect(enriched, 0);
      expect(monitor.snapshotFor('profile-1').isCurrent, isFalse);
      expect(monitor.snapshotFor('profile-1').requests, isEmpty);
      if (interruption == 'remove') {
        expect(monitor.snapshots.containsKey('profile-1'), isFalse);
      }
    });
  }

  test(
    'failed and partial reads keep evidence stale; location change clears it',
    () async {
      final store = await monitorStore(count: 1);
      await legacyConsent(store);
      var now = DateTime(2026, 9, 28, 12);
      final firstObserved = now;
      var fail = false;
      var enrichFail = false;
      var clearFailure = false;
      final monitor = ProfileMonitor(
        store: store,
        now: () => now,
        createGateway: (_) => (
          gateway: MonitorTestGateway(requests: [request(1)], failure: fail),
          operations: MonitorTestOperations(),
        ),
        readAttention: (p, pair, sessions, statuses, current) async {
          if (enrichFail) throw StateError('fixture technical detail');
          if (clearFailure) {
            return const MonitorAttentionDetails(
              items: [],
              complete: false,
              checkedSessionIDs: {'same-session'},
            );
          }
          return MonitorAttentionDetails(
            items: [
              AttentionObservation(
                id: 'failed',
                kind: AttentionKind.failedRun,
                facts: const WorkRowFacts(phase: WorkRowPhase.failed),
                observedAt: now,
                sessionID: 'same-session',
              ),
            ],
            complete: true,
          );
        },
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      await monitor.refresh();
      expect(monitor.snapshotFor('profile-1').attentionComplete, isTrue);
      now = now.add(const Duration(minutes: 2));
      enrichFail = true;
      await monitor.refresh();
      var snapshot = monitor.snapshotFor('profile-1');
      expect(snapshot.isCurrent, isTrue);
      expect(snapshot.attentionComplete, isFalse);
      expect(snapshot.attention.single.isFresh, isFalse);
      expect(snapshot.attention.single.observedAt, firstObserved);
      now = now.add(const Duration(minutes: 2));
      fail = true;
      await monitor.refresh();
      snapshot = monitor.snapshotFor('profile-1');
      expect(snapshot.status, ProfileMonitorStatus.unavailable);
      expect(snapshot.requests.single.id, 'request-1');
      expect(snapshot.attention.single.observedAt, firstObserved);
      expect(snapshot.isCurrent, isFalse);
      fail = false;
      enrichFail = false;
      clearFailure = true;
      now = now.add(const Duration(minutes: 3));
      await monitor.refresh();
      expect(monitor.snapshotFor('profile-1').attention, isEmpty);
      await store.setLocation('profile-1', directory: '/another');
      expect(monitor.snapshotFor('profile-1').requests, isEmpty);
    },
  );

  test(
    'age expiry and paused runtime retain rows without claiming current',
    () async {
      final store = await monitorStore(count: 1);
      await legacyConsent(store);
      var now = DateTime(2026, 9, 28, 12);
      final monitor = ProfileMonitor(
        store: store,
        now: () => now,
        createGateway: (_) => (
          gateway: MonitorTestGateway(requests: [request(1)]),
          operations: MonitorTestOperations(),
        ),
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      await monitor.refresh();
      now = now.add(const Duration(minutes: 3));
      expect(
        monitor.snapshotFor('profile-1').status,
        ProfileMonitorStatus.waiting,
      );
      expect(monitor.snapshotFor('profile-1').requests, hasLength(1));
      monitor.setRuntime(foreground: false, backgroundAllowed: false);
      expect(
        monitor.snapshotFor('profile-1').status,
        ProfileMonitorStatus.paused,
      );
      expect(monitor.snapshotFor('profile-1').requests, hasLength(1));
    },
  );

  test(
    'two phone defaults are not consent and cannot create transports',
    () async {
      final store = await monitorStore();
      for (final profile in store.profiles) {
        profile.baseUrl = 'http://127.0.0.1:4096';
      }
      var factories = 0;
      final monitor = ProfileMonitor(
        store: store,
        createGateway: (_) {
          factories++;
          return (
            gateway: MonitorTestGateway(),
            operations: MonitorTestOperations(),
          );
        },
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      await monitor.refresh();
      expect(factories, 0);
      expect(
        store.prefs.containsKey(AutomationPolicyController.keyFor('profile-1')),
        isFalse,
      );
    },
  );
  test(
    'session recovery does not erase team evidence; team recovery does',
    () async {
      final store = await monitorStore(count: 1);
      await legacyConsent(store);
      var now = DateTime(2026, 9, 28, 12);
      var phase = 0;
      final monitor = ProfileMonitor(
        store: store,
        now: () => now,
        createGateway: (_) => (
          gateway: MonitorTestGateway(),
          operations: MonitorTestOperations(),
        ),
        readAttention: (p, pair, sessions, statuses, current) async =>
            MonitorAttentionDetails(
              items: phase == 0
                  ? [
                      AttentionObservation(
                        id: 'session-failure',
                        kind: AttentionKind.failedRun,
                        facts: const WorkRowFacts(phase: WorkRowPhase.failed),
                        observedAt: now,
                        sessionID: 'same-session',
                      ),
                      AttentionObservation(
                        id: 'team-failure',
                        kind: AttentionKind.failedRun,
                        facts: const WorkRowFacts(phase: WorkRowPhase.failed),
                        observedAt: now,
                        sessionID: 'same-session',
                        taskID: 'task',
                      ),
                    ]
                  : [],
              complete: phase == 0,
              checkedSessionIDs: phase == 1 ? {'same-session'} : {},
              teamComplete: phase == 2,
            ),
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      await monitor.refresh();
      expect(monitor.snapshotFor('profile-1').attention, hasLength(2));
      now = now.add(const Duration(minutes: 2));
      phase = 1;
      await monitor.refresh();
      expect(monitor.snapshotFor('profile-1').attention.single.taskID, 'task');
      expect(
        monitor.snapshotFor('profile-1').attention.single.isFresh,
        isFalse,
      );
      now = now.add(const Duration(minutes: 2));
      phase = 2;
      await monitor.refresh();
      expect(monitor.snapshotFor('profile-1').attention, isEmpty);
    },
  );
  test(
    'policy revoked during Wi-Fi check forbids the following transport',
    () async {
      final store = await monitorStore(count: 1);
      await store.prefs.setString(
        ProfileMonitor.rulesKey('profile-1'),
        jsonEncode(
          const ProfileNotifyRules(enabled: true, wifiOnly: true).toJson(),
        ),
      );
      final wifi = Completer<bool?>();
      final entered = Completer<void>();
      var factories = 0;
      final monitor = ProfileMonitor(
        store: store,
        createGateway: (_) {
          factories++;
          return (
            gateway: MonitorTestGateway(),
            operations: MonitorTestOperations(),
          );
        },
        isReadable: (_) => true,
        networkWifi: () {
          entered.complete();
          return wifi.future;
        },
        alert: (_, r, k, t) async => true,
        dismiss: (_) async => true,
      );
      addTearDown(monitor.dispose);
      final read = monitor.refresh();
      await entered.future;
      await AutomationPolicyController.forProfile(
        store.prefs,
        'profile-1',
      ).setBehavior(AutomationBehavior.monitorOtherServers, false);
      wifi.complete(true);
      await read;
      expect(factories, 0);
      expect(
        monitor.snapshotFor('profile-1').status,
        ProfileMonitorStatus.disabled,
      );
    },
  );
}
