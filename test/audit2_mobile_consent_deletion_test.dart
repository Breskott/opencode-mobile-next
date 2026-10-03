import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/consent_owners.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/mobile_download_consent.dart';
import 'package:opencode_mobile/state/download_size.dart';
import 'package:opencode_mobile/platform/network.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusedConsentRemoval extends InMemorySharedPreferencesStore {
  _RefusedConsentRemoval(super.data) : super.withData();

  @override
  Future<bool> remove(String key) async =>
      key == 'flutter.oc.mobileDownloadConsent.retained'
      ? false
      : super.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('controller reopens mobile consent after a refused removal', () async {
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secure, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(secure, null));
    SharedPreferences.setMockInitialValues({
      'oc.profiles':
          '[{"id":"retained","name":"Fixture","baseUrl":"https://server.test"}]',
    });
    SharedPreferencesStorePlatform.instance = _RefusedConsentRemoval(
      await SharedPreferencesStorePlatform.instance.getAll(),
    );
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    final connection = ConnectionController(store);
    addTearDown(connection.dispose);
    final old = await ConsentOwners.mobileDownloads(prefs, 'retained');
    await old.changeFromSettings(allow: false);
    final result = await connection.deleteProfileAndLocalData('retained');
    expect(result.removedProfile, isFalse);
    expect(result.failures, isNotEmpty);
    final replacement = await ConsentOwners.mobileDownloads(prefs, 'retained');
    expect(replacement.choice, MobileDownloadChoice.denied);
    await replacement.changeFromSettings(allow: true);
    await expectLater(old.changeFromSettings(allow: true), throwsStateError);
  });

  test(
    'only a completed abort reopens a retained profile with a fresh owner',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles': '[{"id":"retained"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final old = await ConsentOwners.mobileDownloads(prefs, 'retained');
      await old.changeFromSettings(allow: false);
      await ConsentOwners.closeProfile(prefs, 'retained');
      ConsentOwners.cancelDeletion(prefs, 'retained');
      final replacement = await ConsentOwners.mobileDownloads(
        prefs,
        'retained',
      );
      expect(identical(old, replacement), isFalse);
      expect(replacement.choice, MobileDownloadChoice.denied);
      await replacement.changeFromSettings(allow: true);
      await expectLater(old.changeFromSettings(allow: false), throwsStateError);

      await ConsentOwners.closeProfile(prefs, 'retained');
      await prefs.setString('oc.profiles', '[]');
      ConsentOwners.cancelDeletion(prefs, 'retained');
      await expectLater(
        ConsentOwners.mobileDownloads(prefs, 'retained'),
        throwsStateError,
      );
    },
  );

  test('a new consent facade cannot resurrect a removed profile key', () async {
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'removed'},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final original = await ConsentOwners.mobileDownloads(prefs, 'removed');
    await original.changeFromSettings(allow: true);

    await ConsentOwners.closeProfile(prefs, 'removed');
    await prefs.remove('oc.mobileDownloadConsent.removed');
    await prefs.setString('oc.profiles', '[]');

    Future<void> lateWrite() async {
      final reopened = await ConsentOwners.mobileDownloads(prefs, 'removed');
      await reopened.changeFromSettings(allow: true);
    }

    await expectLater(lateWrite(), throwsStateError);
    expect(prefs.containsKey('oc.mobileDownloadConsent.removed'), isFalse);
  });

  test(
    'deletion closes new facade admission before draining a probe',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles': '[{"id":"closing"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final original = await ConsentOwners.mobileDownloads(prefs, 'closing');
      final network = Completer<NetworkReading>();
      final entered = Completer<void>();
      final pending = original.request(
        size: const DownloadSize.exact(60000000),
        readNetwork: () {
          entered.complete();
          return network.future;
        },
      );
      await entered.future;
      final closing = ConsentOwners.closeProfile(prefs, 'closing');
      await expectLater(
        ConsentOwners.mobileDownloads(prefs, 'closing'),
        throwsStateError,
      );
      network.complete(
        const NetworkReading(
          status: NetworkStatus.online,
          transport: NetworkTransport.mobile,
          connected: true,
        ),
      );
      expect((await pending).reason, MobileDownloadReason.closed);
      await closing;
      expect(prefs.containsKey('oc.mobileDownloadConsent.closing'), isFalse);
    },
  );

  test(
    'absent profiles cannot load or write through an old direct owner',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.profiles': '[{"id":"present"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        MobileDownloadConsent.load(prefs, profileId: 'missing'),
        throwsStateError,
      );
      final owner = await MobileDownloadConsent.load(
        prefs,
        profileId: 'present',
      );
      await prefs.setString('oc.profiles', '[]');
      await expectLater(
        owner.changeFromSettings(allow: true),
        throwsStateError,
      );
      expect(prefs.containsKey('oc.mobileDownloadConsent.present'), isFalse);
    },
  );
}
