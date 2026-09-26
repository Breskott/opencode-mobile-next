import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/queued_prompt_removal.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.withData({});
  bool refuse = false;

  @override
  Future<bool> remove(String key) =>
      refuse && key == 'flutter.${QueuedPromptRemoval.draftsKey}'
      ? Future.value(false)
      : super.remove(key);

  @override
  Future<bool> setValue(String type, String key, Object value) =>
      refuse && key == 'flutter.${QueuedPromptRemoval.draftsKey}'
      ? Future.value(false)
      : super.setValue(type, key, value);
}

QueuedPrompt _prompt(
  String id, {
  String profile = 'source',
  String text = 'draft text',
  int? dispatchedAt,
  List<PromptAttachment> attachments = const [],
}) => QueuedPrompt(
  id: id,
  profileID: profile,
  sessionID: 'old-session',
  text: text,
  createdAt: 1,
  dispatchedAt: dispatchedAt,
  attachments: attachments,
  modelID: 'model',
  modelProviderID: 'provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late OfflineQueueStore queue;
  late QueuedPromptRemoval service;

  setUp(() async {
    KitRedact.clearKnownSecrets();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    queue = OfflineQueueStore(prefs: prefs);
    service = QueuedPromptRemoval(preferences: prefs, queue: queue);
  });
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'count, keep, restart, source sweep and explicit draft deletion',
    () async {
      await queue.save([
        _prompt('a', text: 'password=fake-value'),
        _prompt(
          'b',
          dispatchedAt: 12,
          attachments: [
            const PromptAttachment(
              mime: 'image/png',
              filename: 'sketch.png',
              url: 'data:image/png;base64,AAAA',
            ),
          ],
        ),
        _prompt('c', profile: 'other'),
      ]);
      final plan = service.inspect('source');
      expect(plan.count, 2);
      expect(plan.uncertainCount, 1);
      expect(await service.keepAsDrafts(plan), 2);
      expect(await service.keepAsDrafts(plan), 2);
      expect(queue.load(), hasLength(3));

      // Use the real scoped-key deletion rule. Preserved ownership is app-wide.
      final profiles = ProfileStore(prefs: prefs);
      expect(await profiles.removeScopedPreferences('source'), isEmpty);
      await queue.save([_prompt('c', profile: 'other')]);
      await prefs.reload();
      final restarted = QueuedPromptRemoval(preferences: prefs, queue: queue);
      expect(restarted.savedDrafts, hasLength(2));
      expect(restarted.savedDrafts.first.text, 'password=${KitRedact.mask}');
      expect(restarted.keptPrompts.last.dispatchedAt, 12);
      expect(restarted.keptPrompts.first.modelID, 'model');
      expect(
        restarted.savedDrafts.last.attachments.single.url,
        'data:image/png;base64,AAAA',
      );
      await restarted.forgetDraft(restarted.savedDrafts.first.id);
      expect(restarted.savedDrafts, hasLength(1));
      await restarted.forgetDraft(restarted.savedDrafts.single.id);
      expect(prefs.containsKey(QueuedPromptRemoval.draftsKey), isFalse);
    },
  );

  test(
    'move requires explicit sessions and preserves other queued work',
    () async {
      await queue.save([_prompt('a'), _prompt('b', profile: 'other')]);
      final plan = service.inspect('source');
      final moved = service.moveToSessions(
        plan,
        destinationProfileID: 'other',
        availableProfileIDs: {'source', 'other'},
        destinationSessions: {'a': 'new-session'},
      );
      expect(moved.first.profileID, 'other');
      expect(moved.first.sessionID, 'new-session');
      expect(moved.first.modelID, 'model');
      expect(moved.first.dispatched, isFalse);
      expect(moved.last.toJson(), queue.load().last.toJson());
      expect(queue.load().first.profileID, 'source'); // preparation is pure
      for (final destination in ['source', 'missing']) {
        expect(
          () => service.moveToSessions(
            plan,
            destinationProfileID: destination,
            availableProfileIDs: {'source', 'other'},
            destinationSessions: {'a': 'new-session'},
          ),
          throwsStateError,
        );
      }
      expect(
        () => service.moveToSessions(
          plan,
          destinationProfileID: 'other',
          availableProfileIDs: {'source', 'other'},
          destinationSessions: {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'stale confirmation, corrupt queue and unsafe moves fail closed',
    () async {
      await queue.save([_prompt('a')]);
      final old = service.inspect('source');
      await queue.save([_prompt('a'), _prompt('b')]);
      await expectLater(service.keepAsDrafts(old), throwsStateError);
      expect(service.savedDrafts, isEmpty);
      for (final prompt in [
        _prompt('a', dispatchedAt: 1),
        _prompt(
          'a',
          attachments: [
            const PromptAttachment(
              mime: 'text/plain',
              filename: 'x',
              url: 'file:///x',
            ),
          ],
        ),
      ]) {
        await queue.save([prompt]);
        expect(
          () => service.moveToSessions(
            service.inspect('source'),
            destinationProfileID: 'other',
            availableProfileIDs: {'source', 'other'},
            destinationSessions: {'a': 'new-session'},
          ),
          throwsStateError,
        );
        expect(queue.load(), hasLength(1));
      }
      await prefs.setString('oc.offlineQueue', '{');
      expect(() => service.inspect('source'), throwsStateError);
    },
  );

  test(
    'refused, corrupt and full draft storage never consume the queue',
    () async {
      final fake = _RefusingStore();
      SharedPreferencesStorePlatform.instance = fake;
      await prefs.reload();
      await queue.save([_prompt('a')]);
      fake.refuse = true;
      await expectLater(
        service.keepAsDrafts(service.inspect('source')),
        throwsStateError,
      );
      expect(service.savedDrafts, isEmpty);
      expect(queue.load(), hasLength(1));
      fake.refuse = false;
      await service.keepAsDrafts(service.inspect('source'));
      fake.refuse = true;
      await expectLater(
        service.forgetDraft(service.savedDrafts.single.id),
        throwsStateError,
      );
      await service.reload();
      expect(service.savedDrafts, hasLength(1));
      fake.refuse = false;
      await queue.save([_prompt('a', text: 'edited')]);
      await expectLater(
        service.keepAsDrafts(service.inspect('source')),
        throwsStateError,
      );
      expect(service.savedDrafts.single.text, 'draft text');
      await prefs.setString(QueuedPromptRemoval.draftsKey, '{');
      await expectLater(
        service.keepAsDrafts(service.inspect('source')),
        throwsStateError,
      );
      await prefs.setString(
        QueuedPromptRemoval.draftsKey,
        jsonEncode([
          for (var i = 0; i < QueuedPromptRemoval.capacity; i++)
            _prompt('saved-$i').toJson(),
        ]),
      );
      await expectLater(
        service.keepAsDrafts(service.inspect('source')),
        throwsStateError,
      );
      expect(service.savedDrafts, hasLength(QueuedPromptRemoval.capacity));
      expect(queue.load().single.id, 'a');
    },
  );
}
