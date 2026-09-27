import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/managed_server_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _DelayedRecoveryStore extends InMemorySharedPreferencesStore {
  _DelayedRecoveryStore(super.data) : super.withData();
  final entered = Completer<void>();
  final release = Completer<void>();
  bool holdNext = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (holdNext && key == 'flutter.oc.managedServerRecovery.local') {
      holdNext = false;
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AutomationPolicyController.resetShared();
    // Keep native transports out of this persistence regression; a saved
    // Termux recovery record must be removable on any supported client.
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('oc/termux'),
      null,
    );
  });

  for (final createOwner in [false, true]) {
    test(
      'deletion drains ${createOwner ? 'loaded' : 'stored'} recovery while policy edits are paused',
      () async {
        SharedPreferences.setMockInitialValues({
          'oc.profiles': jsonEncode([
            {
              'id': 'local',
              'name': 'Phone server',
              'baseUrl': 'http://127.0.0.1:4096',
              'username': '',
            },
          ]),
          ManagedServerRecovery.preferenceKey('local'): jsonEncode({
            'enabled': true,
            'token': '',
            'attempts': 1,
            'operation': 'original',
            'pendingOperation': '',
          }),
        });
        final prefs = await SharedPreferences.getInstance();
        final store = ProfileStore(prefs: prefs);
        await store.load();
        final connection = ConnectionController(store);
        addTearDown(() {
          connection.dispose();
          ManagedServerRecovery.disposeForPreferences(prefs);
        });
        if (createOwner) ManagedServerRecovery.forProfile(prefs, 'local');

        final result = await connection.deleteProfileAndLocalData('local');

        expect(result.removedProfile, isTrue);
        expect(result.failures, isEmpty);
        expect(store.profiles, isEmpty);
        expect(
          prefs.getString(ManagedServerRecovery.preferenceKey('local')),
          isNull,
        );
      },
    );
  }

  for (final loadedAlias in [false, true]) {
    test(
      'deleting ${loadedAlias ? 'loaded' : 'stored'} alias keeps the surviving owner permit',
      () async {
        debugPlatformCapabilities = const PlatformCapabilities.android();
        final record = jsonEncode({
          'enabled': true,
          'token': 'test-shared-permit',
          'attempts': 1,
          'operation': 'original',
          'pendingOperation': '',
        });
        SharedPreferences.setMockInitialValues({
          ManagedServerRecovery.preferenceKey('keeper'): record,
          ManagedServerRecovery.preferenceKey('alias'): record,
        });
        final prefs = await SharedPreferences.getInstance();
        addTearDown(() => ManagedServerRecovery.disposeForPreferences(prefs));
        var commands = 0;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('oc/termux'),
          (_) async {
            commands++;
            return {'exitCode': 0, 'stdout': '', 'stderr': ''};
          },
        );
        final keeper = ManagedServerRecovery.forProfile(prefs, 'keeper');
        if (loadedAlias) ManagedServerRecovery.forProfile(prefs, 'alias');

        await ManagedServerRecovery.prepareForProfileDeletion(prefs, 'alias');

        expect(keeper.ownsInstallation, isTrue);
        expect(keeper.enabled, isTrue);
        expect(commands, 0);
        expect(
          prefs.getString(ManagedServerRecovery.preferenceKey('keeper')),
          record,
        );
      },
    );
  }

  test(
    'aborted deletion keeps policy and reopens the retained recovery owner',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      addTearDown(() => ManagedServerRecovery.disposeForPreferences(prefs));
      final recovery = ManagedServerRecovery.forProfile(prefs, 'local');
      final policy = AutomationPolicyController.forProfile(prefs, 'local');
      await policy.setBehavior(AutomationBehavior.restartPhoneServer, true);
      final before = prefs.getString(
        AutomationPolicyController.keyFor('local'),
      );
      await policy.pauseForDeletion();

      await ManagedServerRecovery.prepareForProfileDeletion(prefs, 'local');

      expect(recovery.enabled, isFalse);
      expect(
        prefs.getString(AutomationPolicyController.keyFor('local')),
        before,
      );
      policy.cancelDeletion();
      ManagedServerRecovery.syncProfiles(prefs, ['local']);
      expect(ManagedServerRecovery.forProfile(prefs, 'local'), same(recovery));
      expect(recovery.enabled, isTrue);
    },
  );

  for (final aliasWrite in [false, true]) {
    test(
      'deletion drains an admitted ${aliasWrite ? 'alias budget' : 'manual recovery'} write before sweeping',
      () async {
        SharedPreferences.setMockInitialValues({
          'oc.profiles': jsonEncode([
            {
              'id': 'local',
              'name': 'Phone server',
              'baseUrl': 'http://127.0.0.1:4096',
              'username': '',
            },
            if (aliasWrite)
              {
                'id': 'keeper',
                'name': 'Other local profile',
                'baseUrl': 'http://127.0.0.1:4096',
                'username': '',
              },
          ]),
        });
        final platform = _DelayedRecoveryStore(
          await SharedPreferencesStorePlatform.instance.getAll(),
        );
        SharedPreferencesStorePlatform.instance = platform;
        SharedPreferences.resetStatic();
        final prefs = await SharedPreferences.getInstance();
        final store = ProfileStore(prefs: prefs);
        await store.load();
        final connection = ConnectionController(store);
        addTearDown(() {
          connection.dispose();
          ManagedServerRecovery.disposeForPreferences(prefs);
        });
        ManagedServerRecovery.forProfile(prefs, 'local');
        ManagedServerRecovery? alias;
        if (aliasWrite) {
          ManagedServerRecovery.syncProfiles(prefs, ['local', 'keeper']);
          alias = ManagedServerRecovery.forProfile(prefs, 'keeper');
          alias.attempts = 1;
        }
        platform.holdNext = true;
        final writing =
            alias?.retryCheck() ??
            ManagedServerRecovery.resumeAfterManualStartForProfile(
              prefs,
              'local',
            );
        await platform.entered.future;
        var deleted = false;
        final deletion = connection.deleteProfileAndLocalData('local').then((
          result,
        ) {
          deleted = true;
          return result;
        });
        // Flush asynchronous storage work without assuming a device-time duration.
        for (var turn = 0; turn < 100; turn++) {
          await Future<void>.delayed(Duration.zero);
        }
        final deletedBeforeWriteSettled = deleted;
        platform.release.complete();
        await writing;
        final result = await deletion;
        await prefs.reload();

        expect(deletedBeforeWriteSettled, isFalse);
        expect(result.removedProfile, isTrue);
        expect(
          prefs.containsKey(ManagedServerRecovery.preferenceKey('local')),
          isFalse,
        );
        // Disposal of the last facade and a late manual-start callback must not
        // reopen the deleted ID or publish fresh recovery metadata.
        await ManagedServerRecovery.resumeAfterManualStartForProfile(
          prefs,
          'local',
        );
        await ManagedServerRecovery.forProfile(prefs, 'local').retryCheck();
        await prefs.reload();
        expect(
          prefs.containsKey(ManagedServerRecovery.preferenceKey('local')),
          isFalse,
        );
        if (aliasWrite) {
          expect(
            (jsonDecode(
                  prefs.getString(
                    ManagedServerRecovery.preferenceKey('keeper'),
                  )!,
                )
                as Map)['attempts'],
            1,
          );
        }
      },
    );
  }
}
