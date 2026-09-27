import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    KitRedact.clearKnownSecrets();
  });
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'saved dispatch redacts content and receipts without changing send data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = MutationStore(prefs);
      final record = MutationRecord(
        key: 'request-1',
        request: MutationRequest.createWork(
          title: 'Use password="fake-value"',
          description: 'Keep "quoted text" and\na second line',
          projectId: 'demo',
        ),
        createdAt: DateTime.utc(2026, 9, 27),
        status: MutationStatus.confirmed,
        receipt: const MutationReceipt(
          id: 'request-1',
          status: MutationReceiptStatus.accepted,
          raw: {'bead': 'task-1', 'password': 'fake-response'},
        ),
      );
      await store.save('profile', record);
      final restored = MutationStore(prefs).get('profile', 'request-1')!;
      expect(restored.key, 'request-1');
      expect(restored.targetId, 'Use password="${KitRedact.mask}"');
      expect(restored.request.text, record.request.text);
      expect(restored.receipt?.raw['password'], KitRedact.mask);
      expect(restored.receipt?.raw['bead'], 'task-1');
      expect(record.targetId, 'Use password="fake-value"');
      expect(record.receipt?.raw['password'], 'fake-response');
      expect(MutationStore(prefs).read('other'), isEmpty);
    },
  );

  test(
    'cached usage keeps numeric facts while masking nested credentials',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = OrchestrationStore(prefs);
      final at = DateTime.utc(2026, 9, 27);
      await store.saveSnapshot(
        'profile',
        OrchestrationSnapshotCache(
          usage: const {
            'today': {'input_tokens': 42, 'cost_usd_estimate': 0.25},
            'partial_reasons': ['Authorization: Bearer fake-token'],
            'metadata': {'api_key': 'fake-api-value'},
          },
          refreshedAt: at,
        ),
      );
      final restored = OrchestrationStore(prefs).readSnapshot('profile')!;
      expect(restored.usage?['today'], {
        'input_tokens': 42,
        'cost_usd_estimate': 0.25,
      });
      expect(restored.usage?['partial_reasons'], [
        'Authorization: ${KitRedact.mask}',
      ]);
      expect(restored.usage?['metadata'], {'api_key': KitRedact.mask});
      expect(restored.refreshedAt, at);
      expect(store.readSnapshot('other'), isNull);
      // The existing profile-scoped prefix remains sweepable; no new keys.
      expect(store.keysFor('profile'), {
        OrchestrationStore.snapshotKey('profile'),
        OrchestrationStore.refreshedAtKey('profile'),
      });
    },
  );
}
