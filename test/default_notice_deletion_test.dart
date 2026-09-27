import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/interaction_defaults.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _DelayedDisk extends InMemorySharedPreferencesStore {
  _DelayedDisk(super.data) : super.withData();
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith('oc.defaultNotices.audit') && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'audit', 'name': 'Audit', 'baseUrl': 'http://localhost:4096'},
      ]),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  test(
    'default notices use one owner per preference store and profile',
    () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        identical(
          InteractionDefaultsStore(prefs, profileID: 'audit'),
          InteractionDefaultsStore(prefs, profileID: 'audit'),
        ),
        isTrue,
      );
    },
  );

  test('default writes reject absent profiles', () async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = InteractionDefaultsStore(prefs, profileID: 'missing');
    await expectLater(defaults.rememberProject('project'), throwsStateError);
    expect(prefs.containsKey('oc.defaultProject.missing'), isFalse);
  });

  test(
    'profile deletion stops admission and drains a pending notice before sweeping',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final disk = _DelayedDisk(
        await SharedPreferencesStorePlatform.instance.getAll(),
      );
      SharedPreferencesStorePlatform.instance = disk;
      final profiles = ProfileStore(prefs: prefs);
      await profiles.load();
      final owner = InteractionDefaultsStore(prefs, profileID: 'audit');
      final writing = owner.takeAnnouncement(
        DefaultKind.project,
        InteractionDefaults.picker(['project'], label: (value) => value),
      );
      await disk.started.future;
      var removed = false;
      final removal = profiles.remove('audit').then((_) => removed = true);
      // Give all immediate deletion futures time to complete on the old code.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final removedBeforeDrain = removed;
      disk.release.complete();
      await writing;
      await removal;
      await prefs.reload();
      expect(
        removedBeforeDrain,
        isFalse,
        reason: 'deletion outran the pending write',
      );
      expect(profiles.profileScopedPreferenceKeys('audit'), isEmpty);
      await expectLater(owner.rememberProject('late'), throwsStateError);
      final reopened = InteractionDefaultsStore(prefs, profileID: 'audit');
      await expectLater(reopened.rememberProject('late'), throwsStateError);
    },
  );
}
