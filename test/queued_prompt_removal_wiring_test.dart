// P7.2 wiring through the connection controller: removing a server with
// queued prompts acts on exactly the confirmed count, keeps them in Saved
// prompts (on every server, across a restart) unless the person deletes
// them too, and a changed queue stops the removal instead of losing work.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/queued_prompt_removal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/stash_memory_vault.dart';

Map<String, Object> _seed() => {
  'oc.profiles': jsonEncode([
    {'id': 'doomed', 'name': 'Old workstation', 'baseUrl': 'http://old'},
    {'id': 'keeper', 'name': 'Laptop', 'baseUrl': 'http://laptop'},
  ]),
  'oc.activeProfile': 'keeper',
  'oc.offlineQueue': jsonEncode([
    {
      'id': 'q1',
      'profileID': 'doomed',
      'sessionID': 'ses_a',
      'text': 'Refactor the billing module',
      'attachments': [
        {
          'mime': 'image/png',
          'filename': 'screenshot.png',
          'url': 'data:image/png;base64,AAAA',
        },
        {
          'mime': 'text/plain',
          'filename': 'notes.txt',
          'url': 'file:///home/dev/notes.txt',
        },
      ],
      'createdAt': 100,
    },
    {
      'id': 'q2',
      'profileID': 'doomed',
      'sessionID': 'ses_b',
      'text': 'Run the migration',
      'createdAt': 200,
      'dispatchedAt': 250,
    },
    {
      'id': 'q3',
      'profileID': 'keeper',
      'sessionID': 'ses_c',
      'text': 'keep me queued',
      'createdAt': 300,
    },
  ]),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('oc/background'),
          (_) async => null,
        );
    root = await Directory.systemTemp.createTemp('oc-p72-wiring-');
  });
  tearDown(() => root.delete(recursive: true));

  Future<ConnectionController> boot({Map<String, Object>? values}) async {
    if (values != null) SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    final controller = ConnectionController(
      store,
      draftAttachmentVault: DraftAttachmentVault(
        directory: () async => Directory('${root.path}/drafts'),
      ),
      stashAttachmentVault: StashMemoryVault(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  List<String> texts(ConnectionController c) => [
    for (final prompt in c.promptStash) prompt.text,
  ];

  test('kept queued prompts move to Saved prompts and survive a restart, '
      'restore and delete with Undo', () async {
    final c = await boot(values: _seed());
    final plan = c.inspectQueuedPromptsForRemoval('doomed');
    expect(plan.count, 2);
    expect(plan.uncertainCount, 1);

    final result = await c.deleteProfileAndLocalData(
      'doomed',
      queuedPrompts: plan,
      keepQueuedPrompts: true,
    );
    expect(result.removedProfile, isTrue);
    expect(result.removedQueuedPrompts, 2);
    expect(c.store.profiles.map((p) => p.id), ['keeper']);
    // Only the other server's prompt is still waiting to send.
    final prefs = await SharedPreferences.getInstance();
    expect(OfflineQueueStore(prefs: prefs).load().map((q) => q.id), ['q3']);
    expect(c.queuedPromptCountForProfile('doomed'), 0);
    // Newest first, beside this server's own saved prompts.
    expect(texts(c), ['Run the migration', 'Refactor the billing module']);

    // A restart finds them again; the removed server's key sweep left them.
    final again = await boot();
    expect(texts(again), ['Run the migration', 'Refactor the billing module']);

    final billing = again.promptStash.firstWhere(
      (p) => p.text == 'Refactor the billing module',
    );
    final recovered = await again.restorePromptStashAttachments(
      billing.id,
      locationRevision: again.locationRevision,
    );
    // Embedded bytes travel; the old server's file does not.
    expect(recovered.attachments.map((a) => a.filename), ['screenshot.png']);
    expect(recovered.unavailable, ['notes.txt']);
    // Restoring keeps the saved copy, like any saved prompt.
    expect(again.promptStash, hasLength(2));

    final undo = await again.deleteSavedPrompt(
      billing.id,
      locationRevision: again.locationRevision,
    );
    expect(texts(again), ['Run the migration']);
    await again.undoSavedPrompt(undo);
    expect(texts(again), ['Run the migration', 'Refactor the billing module']);
    await expectLater(again.undoSavedPrompt(undo), throwsStateError);
  });

  test('deleting them too leaves nothing of them behind', () async {
    final c = await boot(values: _seed());
    final result = await c.deleteProfileAndLocalData(
      'doomed',
      queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
    );
    expect(result.removedProfile, isTrue);
    expect(result.removedQueuedPrompts, 2);
    expect(c.promptStash, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(QueuedPromptRemoval.draftsKey), isNull);
    expect(prefs.getString('oc.offlineQueue'), isNot(contains('billing')));
  });

  test('a queue that changed after the confirmation stops the removal and '
      'loses nothing', () async {
    final c = await boot(values: _seed());
    final plan = c.inspectQueuedPromptsForRemoval('doomed');
    expect(plan.count, 2);
    // A prompt leaves the queue while the question is open.
    expect(await c.removeQueuedPrompt('q2'), isTrue);

    await expectLater(
      c.deleteProfileAndLocalData(
        'doomed',
        queuedPrompts: plan,
        keepQueuedPrompts: true,
      ),
      throwsA(
        isA<QueuedPromptRemovalException>().having(
          (e) => e.changed,
          'changed',
          isTrue,
        ),
      ),
    );
    expect(c.store.profiles.map((p) => p.id), containsAll(['doomed']));
    expect(c.queuedPromptCountForProfile('doomed'), 1);
    expect(c.promptStash, isEmpty);

    // Counted again, the removal goes through and keeps the one left.
    final result = await c.deleteProfileAndLocalData(
      'doomed',
      queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
      keepQueuedPrompts: true,
    );
    expect(result.removedProfile, isTrue);
    expect(texts(c), ['Refactor the billing module']);
  });

  test(
    'Saved prompts that cannot take them keep the server and its queue',
    () async {
      final full = [
        for (var i = 0; i < QueuedPromptRemoval.capacity; i++)
          {
            'id': 'old$i',
            'profileID': 'gone',
            'sessionID': 'ses_old',
            'text': 'older kept prompt $i',
            'createdAt': i,
          },
      ];
      final c = await boot(
        values: {..._seed(), QueuedPromptRemoval.draftsKey: jsonEncode(full)},
      );
      await expectLater(
        c.deleteProfileAndLocalData(
          'doomed',
          queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
          keepQueuedPrompts: true,
        ),
        throwsA(
          isA<QueuedPromptRemovalException>().having(
            (e) => e.changed,
            'changed',
            isFalse,
          ),
        ),
      );
      expect(c.store.profiles.map((p) => p.id), contains('doomed'));
      expect(c.queuedPromptCountForProfile('doomed'), 2);
    },
  );
}
