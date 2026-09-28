// slice-fix-stop-offer, F3 remainder (docs/qa/emulator-qa-claude-2026-09-28):
// on the connected server a reply the person stopped is not a failure. The
// `session.error` a Stop produces (v1 `MessageAbortedError`, v2 `aborted`)
// never files a failed run, never counts toward "need you" and never sets
// the chat's error text. A real failure still does.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/sse.dart' show StreamStatus;
import 'package:opencode_mobile/state/attention_feed.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';

import 'support/profile_monitor_fixture.dart';
import 'support/stash_memory_vault.dart';

class _Gateway extends MonitorTestGateway {
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
      monitorGatewayFactory: (_) =>
          (gateway: _Gateway(), operations: MonitorTestOperations()),
      draftAttachmentVault: StashMemoryVault(),
      stashAttachmentVault: StashMemoryVault(),
    );
    addTearDown(controller.dispose);
    controller.api = _Gateway();
    controller.repository = MonitorTestOperations();
    controller.status = StreamStatus.connected;
    controller.busySessions.add('stopped');
    return controller;
  }

  void error(ConnectionController c, Map<String, Object?> error) =>
      c.handleEventForTesting(
        EventEnvelope(
          type: 'session.error',
          properties: {'sessionID': 'stopped', 'error': error},
        ),
      );

  failed(ConnectionController c) => c.attentionFeed.items.where(
    (item) => item.kind == AttentionKind.failedRun,
  );

  for (final (label, stop) in const [
    ('v1 MessageAbortedError', {'name': 'MessageAbortedError'}),
    ('v2 aborted', {'type': 'aborted'}),
  ]) {
    test('a Stop ($label) is never "Failed" and never needs you', () async {
      final c = await boot();
      final before = c.unifiedAttentionCount;
      error(c, {
        ...stop,
        'data': {'message': 'The operation was aborted.'},
      });
      expect(failed(c), isEmpty);
      expect(c.unifiedAttentionCount, before);
      expect(c.lastError, isNull);
      // The run is over all the same.
      expect(c.busySessions, isNot(contains('stopped')));
    });
  }

  test('a real failure is still "Failed" and needs you', () async {
    final c = await boot();
    final before = c.unifiedAttentionCount;
    error(c, {
      'name': 'ProviderAuthError',
      'data': {'message': 'fixture diagnostic'},
    });
    expect(failed(c).single.target.sessionID, 'stopped');
    expect(c.unifiedAttentionCount, before + 1);
  });
}
