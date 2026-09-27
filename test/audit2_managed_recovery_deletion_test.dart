import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/managed_server_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('oc/termux'),
      null,
    );
    debugPlatformCapabilities = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
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
}
