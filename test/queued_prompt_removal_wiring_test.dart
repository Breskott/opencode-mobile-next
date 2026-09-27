// P7.2 wiring through the connection controller: removing a server with
// queued prompts acts on exactly the confirmed count, keeps them in Saved
// prompts (on every server, across a restart) unless the person deletes
// them too, and a changed queue stops the removal instead of losing work.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/while_away.dart';
import 'package:opencode_mobile/state/automatic_activity.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/draft_attachments.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/queued_prompt_removal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/stash_memory_vault.dart';

class _RemovalDisk extends InMemorySharedPreferencesStore {
  _RemovalDisk(super.data) : super.withData();

  final refused = <String>{};
  String? heldRemovalKey;
  Completer<void>? removalStarted;
  Completer<void>? releaseRemoval;

  bool _blocks(String key) =>
      refused.contains(key.replaceFirst('flutter.', ''));

  @override
  Future<bool> remove(String key) async {
    if (key.replaceFirst('flutter.', '') == heldRemovalKey) {
      if (!(removalStarted?.isCompleted ?? true)) removalStarted!.complete();
      await releaseRemoval?.future;
    }
    return _blocks(key) ? false : super.remove(key);
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async =>
      _blocks(key) ? false : super.setValue(type, key, value);
}

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
    addTearDown(AutomaticActivityController.resetShared);
    addTearDown(AutomationPolicyController.resetShared);
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
    await c.store.prefs.setString('oc.builtinServerOwner', 'doomed');
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
    expect(c.store.prefs.getString('oc.builtinServerOwner'), 'doomed');
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

  for (final failure in ['changed queue', 'full saved prompts']) {
    test('aborted removal after $failure preserves history, Undo and the '
        'same usable policy and activity owners', () async {
      final values = _seed();
      if (failure == 'full saved prompts') {
        values[QueuedPromptRemoval.draftsKey] = jsonEncode([
          for (var i = 0; i < QueuedPromptRemoval.capacity; i++)
            {
              'id': 'older-$i',
              'profileID': 'gone',
              'sessionID': 'ses_old',
              'text': 'Older saved prompt $i',
              'createdAt': i,
            },
        ]);
      }
      final c = await boot(values: values);
      final prefs = c.store.prefs;
      final history = AutomaticActivityController.forProfile(
        prefs,
        'doomed',
        isProfilePresent: () => c.store.profiles.any((p) => p.id == 'doomed'),
      )!;
      final policy = AutomationPolicyController.forProfile(prefs, 'doomed');
      await policy.setBehavior(AutomationBehavior.reconnect, false);
      var undone = 0;
      expect(
        await history.record(
          eventId: 'before-removal',
          location: '/project',
          kind: AutomaticActKind.reconnect,
          summary: 'Reconnected automatically',
          occurredAt: DateTime.utc(2026, 9, 27),
          undo: () async {
            undone++;
            return true;
          },
        ),
        isTrue,
      );
      final originalAct = history.acts.single;
      final originalHistory = prefs.getString(history.storageKey);
      final plan = c.inspectQueuedPromptsForRemoval('doomed');
      if (failure == 'changed queue') {
        expect(await c.removeQueuedPrompt('q2'), isTrue);
      }
      final originalQueue = prefs.getString('oc.offlineQueue');
      final originalDrafts = prefs.getString(QueuedPromptRemoval.draftsKey);

      await expectLater(
        c.deleteProfileAndLocalData(
          'doomed',
          queuedPrompts: plan,
          keepQueuedPrompts: true,
        ),
        throwsA(isA<QueuedPromptRemovalException>()),
      );
      expect(c.store.profiles.map((p) => p.id), contains('doomed'));
      expect(prefs.getString('oc.offlineQueue'), originalQueue);
      expect(prefs.getString(QueuedPromptRemoval.draftsKey), originalDrafts);
      expect(prefs.getString(history.storageKey), originalHistory);
      expect(history.acts.single.id, originalAct.id);
      expect(history.canUndo(originalAct.id), isTrue);
      expect(
        AutomaticActivityController.forProfile(
          prefs,
          'doomed',
          isProfilePresent: () => c.store.profiles.any((p) => p.id == 'doomed'),
        ),
        same(history),
      );
      expect(
        AutomationPolicyController.forProfile(prefs, 'doomed'),
        same(policy),
      );
      // Existing UI/executor references must be usable, without rebinding them.
      await policy.setBehavior(AutomationBehavior.reconnect, true);
      expect(policy.value.allows(AutomationBehavior.reconnect), isTrue);
      expect(await history.undo(originalAct.id), AutomaticUndoResult.undone);
      expect(undone, 1);
      expect(
        await history.record(
          eventId: 'after-abort',
          location: '/project',
          kind: AutomaticActKind.reconnect,
          summary: 'Reconnected after removal was cancelled',
          occurredAt: DateTime.utc(2026, 9, 27, 1),
          undo: () async => true,
        ),
        isTrue,
      );
      final remainingUndo = history.acts.first.id;
      expect(history.canUndo(remainingUndo), isTrue);

      if (failure == 'full saved prompts') {
        expect(await prefs.remove(QueuedPromptRemoval.draftsKey), isTrue);
      }
      final result = await c.deleteProfileAndLocalData(
        'doomed',
        queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
        keepQueuedPrompts: true,
      );
      expect(result.removedProfile, isTrue);
      expect(c.store.profiles.map((p) => p.id), isNot(contains('doomed')));
      expect(prefs.getString(history.storageKey), isNull);
      expect(
        prefs.getString(AutomationPolicyController.keyFor('doomed')),
        isNull,
      );
      expect(history.acts, isEmpty);
      expect(history.canUndo(remainingUndo), isFalse);
      expect(
        await history.undo(remainingUndo),
        AutomaticUndoResult.unavailable,
      );
      expect(undone, 1);
    });
  }

  for (final source in <Object>['{unreadable queued prompts', 42]) {
    for (final preserve in [true, false]) {
      test(
        'unreadable ${source is String ? 'JSON' : 'platform type'} queue '
        'with no plan and keep=$preserve retains the profile and history',
        () async {
          final c = await boot(values: {..._seed(), 'oc.offlineQueue': source});
          final prefs = c.store.prefs;
          final history = AutomaticActivityController.forProfile(
            prefs,
            'doomed',
            isProfilePresent: () =>
                c.store.profiles.any((p) => p.id == 'doomed'),
          )!;
          expect(
            await history.record(
              eventId: 'before-unreadable-removal',
              location: '/project',
              kind: AutomaticActKind.reconnect,
              summary: 'Reconnected automatically',
              occurredAt: DateTime.utc(2026, 9, 27),
              undo: () async => true,
            ),
            isTrue,
          );
          final originalHistory = prefs.getString(history.storageKey);
          final originalAct = history.acts.single.id;
          expect(
            () => c.inspectQueuedPromptsForRemoval('doomed'),
            throwsStateError,
          );

          await expectLater(
            preserve
                ? c.deleteProfileAndLocalData('doomed', keepQueuedPrompts: true)
                : c.deleteProfileAndLocalData('doomed'),
            throwsA(isA<QueuedPromptRemovalException>()),
          );
          expect(c.store.profiles.map((p) => p.id), contains('doomed'));
          expect(prefs.get('oc.offlineQueue'), source);
          expect(prefs.getString(QueuedPromptRemoval.draftsKey), isNull);
          expect(prefs.getString(history.storageKey), originalHistory);
          expect(history.canUndo(originalAct), isTrue);
          await prefs.reload();
          expect(prefs.get('oc.offlineQueue'), source);
          expect(prefs.getString(history.storageKey), originalHistory);
          final restored = ProfileStore(prefs: prefs);
          await restored.load();
          expect(restored.profiles.map((p) => p.id), contains('doomed'));
        },
      );
    }
  }

  test(
    'preservation without a confirmed plan retains readable queued work',
    () async {
      final c = await boot(values: _seed());
      final prefs = c.store.prefs;
      final originalQueue = prefs.getString('oc.offlineQueue');
      await expectLater(
        c.deleteProfileAndLocalData('doomed', keepQueuedPrompts: true),
        throwsA(isA<QueuedPromptRemovalException>()),
      );
      expect(c.store.profiles.map((p) => p.id), contains('doomed'));
      expect(prefs.getString('oc.offlineQueue'), originalQueue);
      expect(prefs.getString(QueuedPromptRemoval.draftsKey), isNull);
      expect(c.queuedPromptCountForProfile('doomed'), 2);
    },
  );

  for (final refusedKey in ['oc.agent.doomed', 'oc.profiles']) {
    test('a deletion refusal at $refusedKey retains history and usable owners '
        'until the profile commit succeeds', () async {
      final c = await boot(values: {..._seed(), 'oc.agent.doomed': 'build'});
      final prefs = c.store.prefs;
      final disk = _RemovalDisk(
        await SharedPreferencesStorePlatform.instance.getAll(),
      );
      SharedPreferencesStorePlatform.instance = disk;
      final history = AutomaticActivityController.forProfile(
        prefs,
        'doomed',
        isProfilePresent: () => c.store.profiles.any((p) => p.id == 'doomed'),
      )!;
      final policy = AutomationPolicyController.forProfile(prefs, 'doomed');
      await policy.setBehavior(AutomationBehavior.reconnect, false);
      var undone = 0;
      expect(
        await history.record(
          eventId: 'before-storage-refusal',
          location: '/project',
          kind: AutomaticActKind.reconnect,
          summary: 'Reconnected automatically',
          occurredAt: DateTime.utc(2026, 9, 27),
          undo: () async {
            undone++;
            return true;
          },
        ),
        isTrue,
      );
      final originalHistory = prefs.getString(history.storageKey);
      final originalAct = history.acts.single.id;
      final plan = c.inspectQueuedPromptsForRemoval('doomed');
      disk.refused.add(refusedKey);
      final removal = c.deleteProfileAndLocalData(
        'doomed',
        queuedPrompts: plan,
        keepQueuedPrompts: true,
      );
      if (refusedKey == 'oc.profiles') {
        await expectLater(removal, throwsStateError);
      } else {
        expect((await removal).removedProfile, isFalse);
      }
      expect(c.store.profiles.map((p) => p.id), contains('doomed'));
      expect(prefs.getString(history.storageKey), originalHistory);
      expect(history.canUndo(originalAct), isTrue);
      expect(
        AutomaticActivityController.forProfile(
          prefs,
          'doomed',
          isProfilePresent: () => c.store.profiles.any((p) => p.id == 'doomed'),
        ),
        same(history),
      );
      expect(
        AutomationPolicyController.forProfile(prefs, 'doomed'),
        same(policy),
      );
      await policy.setBehavior(AutomationBehavior.reconnect, true);
      expect(policy.value.allows(AutomationBehavior.reconnect), isTrue);
      expect(await history.undo(originalAct), AutomaticUndoResult.undone);
      expect(undone, 1);
      // Queue preservation completed before the later deletion step failed.
      expect(texts(c), ['Run the migration', 'Refactor the billing module']);
      await prefs.reload();
      expect(prefs.getString(history.storageKey), isNotNull);
      final restored = ProfileStore(prefs: prefs);
      await restored.load();
      expect(restored.profiles.map((p) => p.id), contains('doomed'));

      disk.refused.clear();
      final retry = await c.deleteProfileAndLocalData(
        'doomed',
        queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
        keepQueuedPrompts: true,
      );
      expect(retry.removedProfile, isTrue);
      expect(prefs.getString(history.storageKey), isNull);
      expect(history.acts, isEmpty);
      expect(history.canUndo(originalAct), isFalse);
      expect(texts(c), ['Run the migration', 'Refactor the billing module']);
    });
  }

  for (final abort in [false, true]) {
    test('queue admission stays closed after source cleanup until deletion '
        '${abort ? 'aborts' : 'commits'}', () async {
      final c = await boot(values: {..._seed(), 'oc.agent.doomed': 'build'});
      final prefs = c.store.prefs;
      final disk = _RemovalDisk(
        await SharedPreferencesStorePlatform.instance.getAll(),
      );
      SharedPreferencesStorePlatform.instance = disk;
      disk.heldRemovalKey = 'oc.agent.doomed';
      disk.removalStarted = Completer<void>();
      disk.releaseRemoval = Completer<void>();
      if (abort) disk.refused.add('oc.agent.doomed');
      const latePrompt = QueuedPrompt(
        id: 'late-doomed',
        profileID: 'doomed',
        sessionID: 'ses_late',
        text: 'Keep this new work in the composer if removal is pending',
        createdAt: 400,
      );
      final removal = c.deleteProfileAndLocalData(
        'doomed',
        queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
        keepQueuedPrompts: true,
      );
      try {
        await disk.removalStarted!.future.timeout(const Duration(seconds: 5));
        // This setting is swept after queue cleanup, before row commitment.
        expect(c.queuedPromptCountForProfile('doomed'), 0);
        expect(c.store.profiles.map((p) => p.id), contains('doomed'));
        expect(await c.queuePrompt(latePrompt), isFalse);
        expect(c.queuedPromptCountForProfile('doomed'), 0);
        // Other profiles still have a usable queue while this row is held.
        expect(
          await c.queuePrompt(
            const QueuedPrompt(
              id: 'late-keeper',
              profileID: 'keeper',
              sessionID: 'ses_other',
              text: 'Work for the other server',
              createdAt: 401,
            ),
          ),
          isTrue,
        );
      } finally {
        disk.releaseRemoval!.complete();
        await removal;
      }
      final result = await removal;
      expect(result.removedProfile, !abort);
      expect(await c.queuePrompt(latePrompt), abort);
      expect(c.queuedPromptCountForProfile('doomed'), abort ? 1 : 0);
      expect(
        OfflineQueueStore(prefs: prefs).load().map((p) => p.id),
        unorderedEquals(
          abort ? ['q3', 'late-keeper', 'late-doomed'] : ['q3', 'late-keeper'],
        ),
      );
    });
  }

  test('refused policy cleanup reports an incomplete committed removal and '
      'does not claim the durable policy key was erased', () async {
    final c = await boot(values: _seed());
    final prefs = c.store.prefs;
    final policy = AutomationPolicyController.forProfile(prefs, 'doomed');
    await policy.setBehavior(AutomationBehavior.reconnect, false);
    final policyKey = AutomationPolicyController.keyFor('doomed');
    final originalPolicy = prefs.getString(policyKey);
    final disk = _RemovalDisk(
      await SharedPreferencesStorePlatform.instance.getAll(),
    );
    SharedPreferencesStorePlatform.instance = disk;
    disk.refused.add(policyKey);

    final result = await c.deleteProfileAndLocalData(
      'doomed',
      queuedPrompts: c.inspectQueuedPromptsForRemoval('doomed'),
      keepQueuedPrompts: true,
    );
    expect(result.removedProfile, isTrue);
    expect(result.complete, isFalse);
    expect(result.failures, isNotEmpty);
    expect(result.removedPreferenceKeys, isNot(contains(policyKey)));
    expect(c.store.profiles.map((p) => p.id), isNot(contains('doomed')));
    await prefs.reload();
    expect(prefs.getString(policyKey), originalPolicy);
    final restored = ProfileStore(prefs: prefs);
    await restored.load();
    expect(restored.profiles.map((p) => p.id), isNot(contains('doomed')));
    expect(texts(c), ['Run the migration', 'Refactor the billing module']);
  });

  test('repairing an unreadable source permits a confirmed preservation retry '
      'on the same controller', () async {
    final c = await boot(
      values: {..._seed(), 'oc.offlineQueue': '{unreadable queued prompts'},
    );
    // Prime the decoded cache while storage is unreadable.
    expect(c.queuedPromptCountForProfile('doomed'), 0);
    await expectLater(
      c.deleteProfileAndLocalData('doomed', keepQueuedPrompts: true),
      throwsA(isA<QueuedPromptRemovalException>()),
    );
    expect(c.store.profiles.map((p) => p.id), contains('doomed'));

    // Simulate recovering the source blob without recreating the controller.
    final prefs = c.store.prefs;
    expect(
      await prefs.setString(
        'oc.offlineQueue',
        _seed()['oc.offlineQueue']! as String,
      ),
      isTrue,
    );
    final plan = c.inspectQueuedPromptsForRemoval('doomed');
    expect(plan.count, 2);
    final result = await c.deleteProfileAndLocalData(
      'doomed',
      queuedPrompts: plan,
      keepQueuedPrompts: true,
    );
    expect(result.removedProfile, isTrue);
    expect(texts(c), ['Run the migration', 'Refactor the billing module']);
    expect(OfflineQueueStore(prefs: prefs).load().map((p) => p.id), ['q3']);
  });
}
