import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/while_away.dart';
import 'package:opencode_mobile/state/automatic_activity.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _ActivityDisk extends InMemorySharedPreferencesStore {
  _ActivityDisk(super.data) : super.withData();

  bool refuse = false;
  bool throwOnWrite = false;
  Completer<void>? gate;
  Completer<void>? writeStarted;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (!(writeStarted?.isCompleted ?? true)) writeStarted!.complete();
    await gate?.future;
    if (throwOnWrite) throw StateError('Synthetic storage failure');
    return refuse ? false : super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async => refuse ? false : super.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late _ActivityDisk disk;
  late AutomaticActivityController controller;
  late bool profilePresent;
  final time = DateTime.utc(2026, 9, 27, 12);

  AutomaticActivityController createController({String profileId = 'alpha'}) =>
      AutomaticActivityController(
        preferences: preferences,
        profileId: profileId,
        isProfilePresent: () => profilePresent,
      );

  Future<bool> record(
    String eventId, {
    String location = '/project/one',
    String summary = 'Reconnected automatically',
    DateTime? occurredAt,
    String? sessionId,
    Future<bool> Function()? undo,
  }) => controller.record(
    eventId: eventId,
    location: location,
    kind: AutomaticActKind.reconnect,
    summary: summary,
    occurredAt: occurredAt ?? time,
    sessionId: sessionId,
    undo: undo,
  );

  setUp(() async {
    KitRedact.clearKnownSecrets();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    disk = _ActivityDisk(
      await SharedPreferencesStorePlatform.instance.getAll(),
    );
    SharedPreferencesStorePlatform.instance = disk;
    profilePresent = true;
    controller = createController();
  });

  tearDown(() {
    controller.dispose();
    KitRedact.clearKnownSecrets();
  });

  test(
    'profiles and locations are isolated and profile deletion finds key',
    () async {
      final otherProfile = createController(profileId: 'beta');
      addTearDown(otherProfile.dispose);
      await record('same-event');
      await record('same-event', location: '/project/two');

      expect(controller.acts, hasLength(2));
      expect(controller.forLocation('/project/one'), hasLength(1));
      expect(controller.forLocation('/project/two'), hasLength(1));
      expect(controller.forLocation('/project/missing'), isEmpty);
      expect(otherProfile.acts, isEmpty);
      expect(controller.storageKey, 'oc.automaticActivity.alpha');
      expect(
        ProfileStore(prefs: preferences).profileScopedPreferenceKeys('alpha'),
        contains(controller.storageKey),
      );
      expect(controller.locationKey('/project/one'), isNot('/project/one'));
    },
  );

  test(
    'duplicate occurrence preserves original report but new occurrence appears',
    () async {
      await record('event-1');
      final originalId = controller.acts.single.id;
      expect(await record('event-1', summary: 'Changed duplicate'), isTrue);
      expect(controller.acts.single.id, originalId);
      expect(controller.acts.single.summary, 'Reconnected automatically');
      await record('event-2', occurredAt: time.add(const Duration(minutes: 1)));
      expect(controller.acts, hasLength(2));
      expect(controller.acts.first.id, isNot(originalId));
    },
  );

  test(
    'history survives reload ordered by occurrence time and is immutable',
    () async {
      await record('newer', occurredAt: time.add(const Duration(minutes: 1)));
      await record('older', occurredAt: time, summary: 'Earlier reconnect');
      await preferences.reload();
      final restored = createController();
      addTearDown(restored.dispose);

      expect(restored.acts.map((act) => act.summary), [
        'Reconnected automatically',
        'Earlier reconnect',
      ]);
      expect(() => restored.acts.clear(), throwsUnsupportedError);
      expect(
        () => restored.forLocation('/project/one').clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'persisted reports redact copy and never store raw location or event identity',
    () async {
      const fakeSecret = 'synthetic-private-value-for-activity-test';
      KitRedact.registerKnownSecret(fakeSecret);
      await record(
        'event-$fakeSecret',
        location: 'https://example.invalid/project/$fakeSecret',
        summary: 'Reconnected\npassword=$fakeSecret\nReady',
        sessionId: 'session-$fakeSecret',
      );

      final persisted = preferences.getString(controller.storageKey)!;
      expect(persisted.contains(fakeSecret), isFalse);
      expect(persisted.contains('https://example.invalid'), isFalse);
      expect(persisted.contains('event-'), isFalse);
      expect(controller.acts.single.summary.contains('\n'), isFalse);
      expect(controller.acts.single.summary.contains(KitRedact.mask), isTrue);
      expect(
        controller.acts.single.sessionId?.contains(fakeSecret) ?? false,
        isFalse,
      );
    },
  );

  test(
    'acknowledging a captured snapshot leaves later arrivals unread',
    () async {
      await record('shown');
      final capturedIds = controller.acts.map((act) => act.id).toList();
      await record(
        'arrived-later',
        occurredAt: time.add(const Duration(seconds: 1)),
      );
      expect(await controller.acknowledge(capturedIds), isTrue);
      expect(controller.acts.first.acknowledged, isFalse);
      expect(controller.acts.last.acknowledged, isTrue);
      await preferences.reload();
      final restored = createController();
      addTearDown(restored.dispose);
      expect(restored.acts.first.acknowledged, isFalse);
      expect(restored.acts.last.acknowledged, isTrue);
    },
  );

  test(
    'refused and thrown writes preserve published and restored state then retry',
    () async {
      await record('saved');
      final savedId = controller.acts.single.id;
      disk.refuse = true;
      expect(await record('refused'), isFalse);
      expect(controller.persistenceFailed, isTrue);
      expect(controller.acts.single.id, savedId);
      await preferences.reload();
      final restored = createController();
      expect(restored.acts.single.id, savedId);
      restored.dispose();

      disk.refuse = false;
      disk.throwOnWrite = true;
      expect(await record('throws'), isFalse);
      expect(controller.acts.single.id, savedId);
      disk.throwOnWrite = false;
      expect(await record('refused'), isTrue);
      expect(controller.acts, hasLength(2));
      expect(controller.persistenceFailed, isFalse);
    },
  );

  test(
    'malformed persisted histories are safe empty and visibly marked corrupt',
    () async {
      for (final value in ['not JSON', '{"version":999,"acts":[]}', '[null]']) {
        await preferences.setString(controller.storageKey, value);
        final restored = createController();
        expect(restored.acts, isEmpty);
        expect(restored.corruptHistory, isTrue);
        restored.dispose();
      }
    },
  );

  test(
    'history retains the newest 200 occurrences even with late older arrivals',
    () async {
      for (
        var index = 0;
        index < AutomaticActivityController.maxEntries + 2;
        index++
      ) {
        await record(
          'event-$index',
          occurredAt: time.add(Duration(seconds: index)),
        );
      }
      await record(
        'very-old',
        occurredAt: time.subtract(const Duration(days: 1)),
      );
      expect(controller.acts, hasLength(200));
      expect(
        controller.acts.first.occurredAt,
        time.add(const Duration(seconds: 201)),
      );
      expect(
        controller.acts.last.occurredAt,
        time.add(const Duration(seconds: 2)),
      );
    },
  );

  test(
    'concurrent Undo invokes its callback once and survives restart as unavailable',
    () async {
      var calls = 0;
      final callbackStarted = Completer<void>();
      final completion = Completer<bool>();
      await record(
        'undoable',
        undo: () async {
          calls++;
          callbackStarted.complete();
          return completion.future;
        },
      );
      final id = controller.acts.single.id;
      expect(controller.canUndo(id), isTrue);
      final first = controller.undo(id);
      await callbackStarted.future;
      final second = controller.undo(id);
      completion.complete(true);
      expect(await first, AutomaticUndoResult.undone);
      expect(await second, AutomaticUndoResult.unavailable);
      expect(calls, 1);
      expect(controller.canUndo(id), isFalse);
      await preferences.reload();
      final restored = createController();
      addTearDown(restored.dispose);
      expect(await restored.undo(id), AutomaticUndoResult.unavailable);
      expect(calls, 1);
    },
  );

  test(
    'Undo false and exceptions are distinguished and never retried or leaked',
    () async {
      var calls = 0;
      await record(
        'false',
        undo: () async {
          calls++;
          return false;
        },
      );
      final failedId = controller.acts.single.id;
      expect(await controller.undo(failedId), AutomaticUndoResult.failed);
      expect(await controller.undo(failedId), AutomaticUndoResult.unavailable);
      const fakeError = 'synthetic-sensitive-exception-value';
      await record(
        'throws',
        occurredAt: time.add(const Duration(seconds: 1)),
        undo: () async {
          calls++;
          throw StateError(fakeError);
        },
      );
      final thrownId = controller.acts.first.id;
      expect(await controller.undo(thrownId), AutomaticUndoResult.unconfirmed);
      expect(await controller.undo(thrownId), AutomaticUndoResult.unavailable);
      expect(calls, 2);
      expect(
        preferences.getString(controller.storageKey)!.contains(fakeError),
        isFalse,
      );
    },
  );

  test(
    'Undo requires durable attempt marker before invoking callback',
    () async {
      var calls = 0;
      await record(
        'undoable',
        undo: () async {
          calls++;
          return true;
        },
      );
      final id = controller.acts.single.id;
      disk.refuse = true;
      expect(await controller.undo(id), AutomaticUndoResult.failed);
      expect(calls, 0);
      expect(controller.persistenceFailed, isTrue);
      disk.refuse = false;
      expect(await controller.undo(id), AutomaticUndoResult.undone);
      expect(calls, 1);
    },
  );

  test(
    'an unpersisted Undo outcome stays uncertain and cannot repeat',
    () async {
      var calls = 0;
      await record(
        'inverse-applied',
        undo: () async {
          calls++;
          // The intent was saved, but the outcome write will be refused.
          disk.refuse = true;
          return true;
        },
      );
      final id = controller.acts.single.id;
      expect(await controller.undo(id), AutomaticUndoResult.unconfirmed);
      expect(controller.acts.single.undoAttempted, isTrue);
      expect(controller.acts.single.undone, isFalse);
      expect(controller.persistenceFailed, isTrue);
      disk.refuse = false;
      expect(await controller.undo(id), AutomaticUndoResult.unavailable);
      await preferences.reload();
      final restored = createController();
      addTearDown(restored.dispose);
      expect(restored.acts.single.undoAttempted, isTrue);
      expect(restored.acts.single.undone, isFalse);
      expect(await restored.undo(id), AutomaticUndoResult.unavailable);
      expect(calls, 1);
    },
  );

  test(
    'queued acknowledgement captures IDs before the caller changes them',
    () async {
      await record('shown');
      final shownId = controller.acts.single.id;
      final ids = <String>[shownId];
      disk.gate = Completer<void>();
      disk.writeStarted = Completer<void>();
      final arriving = record(
        'later',
        occurredAt: time.add(const Duration(seconds: 1)),
      );
      await disk.writeStarted!.future;
      final acknowledged = controller.acknowledge(ids);
      ids.clear();
      disk.gate!.complete();
      expect(await arriving, isTrue);
      expect(await acknowledged, isTrue);
      expect(controller.acts.first.acknowledged, isFalse);
      expect(
        controller.acts.singleWhere((act) => act.id == shownId).acknowledged,
        isTrue,
      );
    },
  );

  test(
    'invalid observations are refused without saving empty history',
    () async {
      expect(await record(''), isFalse);
      expect(await record('empty', summary: ' \n '), isFalse);
      expect(
        await record(
          'invalid-time',
          occurredAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        isFalse,
      );
      expect(controller.acts, isEmpty);
      expect(preferences.containsKey(controller.storageKey), isFalse);
    },
  );

  test(
    'restart retains reports but does not revive process-local Undo callbacks',
    () async {
      var calls = 0;
      await record(
        'undoable',
        undo: () async {
          calls++;
          return true;
        },
      );
      final id = controller.acts.single.id;
      final restored = createController();
      addTearDown(restored.dispose);
      expect(restored.acts, hasLength(1));
      expect(restored.canUndo(id), isFalse);
      expect(await restored.undo(id), AutomaticUndoResult.unavailable);
      expect(calls, 0);
    },
  );

  test(
    'deleted profiles refuse records and Undo without invoking callbacks',
    () async {
      var calls = 0;
      await record(
        'undoable',
        undo: () async {
          calls++;
          return true;
        },
      );
      final id = controller.acts.single.id;
      profilePresent = false;
      expect(await record('after-delete'), isFalse);
      expect(await controller.undo(id), AutomaticUndoResult.unavailable);
      expect(calls, 0);
    },
  );

  test(
    'deletion waits for pending write and permanently prevents resurrection',
    () async {
      disk.gate = Completer<void>();
      disk.writeStarted = Completer<void>();
      final pending = record('pending');
      await disk.writeStarted!.future;
      final deleted = controller.deleteProfileData();
      expect(await record('after-delete-started'), isFalse);
      disk.gate!.complete();
      await pending;
      expect(await deleted, isTrue);
      expect(controller.acts, isEmpty);
      expect(preferences.containsKey(controller.storageKey), isFalse);
      await preferences.reload();
      expect(preferences.containsKey(controller.storageKey), isFalse);
      expect(await record('after-delete-finished'), isFalse);
    },
  );

  test(
    'deletion drains an in-flight Undo before erasing its durable history',
    () async {
      final started = Completer<void>();
      final completion = Completer<bool>();
      await record(
        'undoable',
        undo: () async {
          started.complete();
          return completion.future;
        },
      );
      final undo = controller.undo(controller.acts.single.id);
      await started.future;
      var deletionFinished = false;
      final deletion = controller.deleteProfileData().then((value) {
        deletionFinished = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(deletionFinished, isFalse);
      completion.complete(true);
      await undo;
      expect(await deletion, isTrue);
      expect(controller.acts, isEmpty);
      await preferences.reload();
      expect(preferences.containsKey(controller.storageKey), isFalse);
    },
  );

  test(
    'failed deletion reports failure and retry erases the retained history',
    () async {
      await record('saved');
      disk.refuse = true;
      expect(await controller.deleteProfileData(), isFalse);
      expect(controller.persistenceFailed, isTrue);
      expect(await record('after-failed-delete'), isFalse);
      disk.refuse = false;
      expect(await controller.deleteProfileData(), isTrue);
      expect(controller.acts, isEmpty);
      await preferences.reload();
      expect(preferences.containsKey(controller.storageKey), isFalse);
    },
  );

  test(
    'dispose stops writes and notifications without deleting history',
    () async {
      await record('saved');
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      expect(await record('after-dispose'), isFalse);
      expect(notifications, 0);
      await preferences.reload();
      expect(preferences.containsKey(controller.storageKey), isTrue);
      // Replace the disposed instance for the shared teardown.
      controller = createController();
      expect(controller.acts, hasLength(1));
    },
  );

  test(
    'profile IDs must be opaque and cannot persist registered credentials in keys',
    () {
      const fakeSecret = 'synthetic-sensitive-profile-value';
      KitRedact.registerKnownSecret(fakeSecret);
      for (final invalidId in [
        '',
        'https://example.invalid',
        'alpha.beta',
        fakeSecret,
      ]) {
        expect(
          () => createController(profileId: invalidId),
          throwsArgumentError,
        );
      }
      expect(preferences.getKeys(), isEmpty);
    },
  );
}
