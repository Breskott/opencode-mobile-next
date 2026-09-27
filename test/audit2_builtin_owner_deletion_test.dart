import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/builtin/builtin_server_recovery.dart';
import 'package:opencode_mobile/builtin/phone_server_healing.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/builtin_server_owner.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class _OwnerDisk extends InMemorySharedPreferencesStore {
  _OwnerDisk(super.data) : super.withData();

  final entered = Completer<void>();
  final release = Completer<void>();
  bool hold = true;
  bool refuseClear = false;
  bool refuseClaim = false;
  bool throwClaim = false;
  bool failReads = false;

  @override
  Future<Map<String, Object>> getAll() {
    if (failReads) throw StateError('Synthetic storage read failure');
    return super.getAll();
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) {
    if (failReads) throw StateError('Synthetic storage read failure');
    return super.getAllWithParameters(parameters);
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.oc.builtinServerOwner' && value == 'candidate') {
      if (throwClaim) throw StateError('Synthetic storage write failure');
      if (refuseClaim) return false;
    }
    if (refuseClear && key == 'flutter.oc.builtinServerOwner' && value == '') {
      return false;
    }
    if (hold && key == 'flutter.oc.builtinServerOwner' && value == 'phone') {
      hold = false;
      entered.complete();
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

class _Linux extends BuiltinLinux {
  @override
  Future<BuiltinLinuxStatus> status() async => const BuiltinLinuxStatus(
    installed: true,
    phase: BuiltinLinuxPhase.ready,
    serverRunning: false,
    serverRestartWanted: false,
  );

  @override
  Future<void> cancelServerRecovery() async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  for (final throws in [false, true]) {
    test(
      '${throws ? 'thrown' : 'refused'} claim cannot hide another durable owner from deletion',
      () async {
        SharedPreferences.setMockInitialValues({
          BuiltinServerOwner.key: 'retained',
        });
        final disk =
            _OwnerDisk(await SharedPreferencesStorePlatform.instance.getAll())
              ..hold = false
              ..refuseClaim = !throws
              ..throwClaim = throws;
        SharedPreferencesStorePlatform.instance = disk;
        SharedPreferences.resetStatic();
        final prefs = await SharedPreferences.getInstance();
        final owner = BuiltinServerOwner.forPreferences(prefs);

        await expectLater(
          owner.claim('candidate', isReadable: () => true),
          throwsStateError,
        );
        expect(prefs.getString(BuiltinServerOwner.key), 'retained');
        await owner.clearProfile('retained');
        await prefs.reload();
        expect(prefs.getString(BuiltinServerOwner.key), '');
      },
    );
  }

  test(
    'unreadable cache after a failed claim blocks clears until reconciled',
    () async {
      SharedPreferences.setMockInitialValues({
        BuiltinServerOwner.key: 'retained',
      });
      final disk =
          _OwnerDisk(await SharedPreferencesStorePlatform.instance.getAll())
            ..hold = false
            ..refuseClaim = true;
      SharedPreferencesStorePlatform.instance = disk;
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      final owner = BuiltinServerOwner.forPreferences(prefs);
      disk.failReads = true;

      await expectLater(
        owner.claim('candidate', isReadable: () => true),
        throwsStateError,
      );
      // The plugin still exposes optimistic cache, but the owner cannot treat
      // that cache as proof that the retained profile no longer owns the runtime.
      expect(prefs.getString(BuiltinServerOwner.key), 'candidate');
      await expectLater(owner.clearProfile('retained'), throwsStateError);
      await expectLater(
        owner.claim('another', isReadable: () => true),
        throwsStateError,
      );

      disk.failReads = false;
      await owner.clearProfile('retained');
      await prefs.reload();
      expect(prefs.getString(BuiltinServerOwner.key), '');
    },
  );

  test('refused owner clear aborts real deletion and can be retried', () async {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    AutomationPolicyController.resetShared();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    addTearDown(() {
      debugPlatformCapabilities = null;
      AutomationPolicyController.resetShared();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {
          'id': 'phone',
          'name': 'Phone server',
          'baseUrl': BuiltinLinux.serverUrl,
          'username': BuiltinLinux.serverUsername,
        },
      ]),
      PhoneServerHealing.ownerKey: 'phone',
    });
    final disk =
        _OwnerDisk(await SharedPreferencesStorePlatform.instance.getAll())
          ..hold = false
          ..refuseClear = true;
    SharedPreferencesStorePlatform.instance = disk;
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    final connection = ConnectionController(store);
    addTearDown(connection.dispose);

    await expectLater(
      connection.deleteProfileAndLocalData('phone'),
      throwsStateError,
    );
    expect(store.profiles.single.id, 'phone');
    expect(connection.isProfileReadable('phone'), isTrue);
    expect(prefs.getString(PhoneServerHealing.ownerKey), 'phone');
    // The completed abort reopens the shared owner. A fresh explicit claim
    // is permitted, while the deletion retry must still clear the disk value.
    await BuiltinServerOwner.forPreferences(
      prefs,
    ).claim('phone', isReadable: () => connection.isProfileReadable('phone'));
    disk.refuseClear = false;
    final result = await connection.deleteProfileAndLocalData('phone');
    expect(result.removedProfile, isTrue);
    await prefs.reload();
    expect(prefs.getString(PhoneServerHealing.ownerKey), '');
    await expectLater(
      BuiltinServerOwner.forPreferences(
        prefs,
      ).claim('phone', isReadable: () => true),
      throwsStateError,
    );
  });

  test(
    'real profile deletion drains a delayed manual-start owner claim',
    () async {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      AutomationPolicyController.resetShared();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
      addTearDown(() {
        debugPlatformCapabilities = null;
        AutomationPolicyController.resetShared();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
      });
      SharedPreferences.setMockInitialValues({
        'oc.profiles': jsonEncode([
          {
            'id': 'phone',
            'name': 'Phone server',
            'baseUrl': BuiltinLinux.serverUrl,
            'username': BuiltinLinux.serverUsername,
          },
        ]),
      });
      final disk = _OwnerDisk(
        await SharedPreferencesStorePlatform.instance.getAll(),
      );
      SharedPreferencesStorePlatform.instance = disk;
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs: prefs);
      await store.load();
      final connection = ConnectionController(store);
      final linux = _Linux();
      final starter = BuiltinServerStarter(linux: linux);
      final healing = PhoneServerHealing(
        connection: connection,
        starter: starter,
        createRecovery: (record) => BuiltinServerRecovery(
          store: store,
          linux: linux,
          starter: starter,
          onRestart: record,
        ),
      );
      addTearDown(() {
        healing.dispose();
        starter.dispose();
        connection.dispose();
      });
      final profile = store.profiles.single;
      final writing = starter.beforeManualStart!(profile);
      final refused = expectLater(writing, throwsStateError);
      await disk.entered.future;
      var deleted = false;
      final deletion = connection.deleteProfileAndLocalData(profile.id).then((
        result,
      ) {
        deleted = true;
        return result;
      });
      for (var turn = 0; turn < 100; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
      final deletedBeforeClaimSettled = deleted;
      disk.release.complete();
      await refused;
      final result = await deletion;
      await prefs.reload();

      expect(deletedBeforeClaimSettled, isFalse);
      expect(result.removedProfile, isTrue);
      expect(result.failures, isEmpty);
      expect(prefs.getString(PhoneServerHealing.ownerKey), isNot(profile.id));
      await expectLater(starter.beforeManualStart!(profile), throwsStateError);
      await prefs.reload();
      expect(prefs.getString(PhoneServerHealing.ownerKey), isNot(profile.id));
    },
  );
}
