import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/sse.dart' show StreamStatus;
import 'package:opencode_mobile/state/attention_feed.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profile_monitor.dart';

import 'support/profile_monitor_fixture.dart';
import 'support/stash_memory_vault.dart';

class _Gateway extends MonitorTestGateway {
  _Gateway({super.requests});
  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() async => [];
  @override
  Future<List<Map<String, dynamic>>> pendingQuestionsV2() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    AutomationPolicyController.resetShared();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
  });

  Future<ConnectionController> boot() async {
    final store = await monitorStore();
    await store.setActiveId('profile-1');
    final controller = ConnectionController(
      store,
      monitorGatewayFactory: (_) => (
        gateway: _Gateway(requests: [request(1)]),
        operations: MonitorTestOperations(),
      ),
      draftAttachmentVault: StashMemoryVault(),
      stashAttachmentVault: StashMemoryVault(),
    );
    addTearDown(controller.dispose);
    controller.api = _Gateway(requests: [request(1)]);
    controller.repository = MonitorTestOperations();
    controller.status = StreamStatus.connected;
    await controller.refreshPendingPermissions();
    await controller.refreshPendingQuestions();
    return controller;
  }

  test(
    'one feed combines selected transport and opted-in other server once',
    () async {
      final controller = await boot();
      await controller.profileMonitor.setRules(
        'profile-2',
        const ProfileNotifyRules(enabled: true),
      );
      await controller.profileMonitor.refresh();
      final feed = controller.attentionFeed;
      expect(feed.items, hasLength(2));
      expect(
        feed.items.map((item) => item.profileID),
        containsAll(['profile-1', 'profile-2']),
      );
      expect(feed.items.map((item) => item.identity).toSet(), hasLength(2));
      expect(controller.unifiedAttentionCount, feed.knownAttentionCount);
      expect(
        controller.store.prefs.getKeys().where(
          (key) => key.startsWith('oc.automaticActivity.'),
        ),
        isEmpty,
      );
      for (final item in feed.items) {
        expect(item.target.sessionID, 'same-session');
        expect(item.target.requestID, 'request-1');
        expect(item.status.isFresh, isTrue);
      }
      expect(
        controller.attentionFeed.items.first.status.observedAt,
        feed.items.first.status.observedAt,
      );
    },
  );

  test(
    'reconnect does not refresh cached requests; successful reads do',
    () async {
      final controller = await boot();
      final at = controller.attentionFeed.items.single.status.observedAt;
      controller.status = StreamStatus.reconnecting;
      expect(controller.attentionFeed.items.single.status.isFresh, isFalse);
      controller.status = StreamStatus.connected;
      expect(controller.attentionFeed.items.single.status.isFresh, isFalse);
      expect(controller.attentionFeed.items.single.status.observedAt, at);
      await controller.refreshPendingPermissions();
      await controller.refreshPendingQuestions();
      expect(controller.attentionFeed.items.single.status.isFresh, isTrue);
    },
  );

  test(
    'confirmed failure has no raw error and newer work retires it; removal excludes rows',
    () async {
      final controller = await boot();
      controller.handleEventForTesting(
        EventEnvelope(
          type: 'session.error',
          properties: {
            'sessionID': 'failed-session',
            'error': {'message': 'fixture diagnostic'},
          },
        ),
      );
      final failed = controller.attentionFeed.items
          .where((item) => item.kind == AttentionKind.failedRun)
          .single;
      expect(failed.target.sessionID, 'failed-session');
      expect(failed.title, isNull);
      controller.handleEventForTesting(
        EventEnvelope(
          type: 'session.status',
          properties: {
            'sessionID': 'failed-session',
            'status': {'type': 'busy'},
          },
        ),
      );
      expect(
        controller.attentionFeed.items.where(
          (item) => item.kind == AttentionKind.failedRun,
        ),
        isEmpty,
      );
      await controller.store.remove('profile-1');
      expect(controller.attentionFeed.items, isEmpty);
      expect(
        controller.attentionFeed.servers.map((server) => server.profileID),
        ['profile-2'],
      );
    },
  );
}
