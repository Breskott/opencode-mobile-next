import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/settings_scope.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/read_state_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Disk extends InMemorySharedPreferencesStore {
  _Disk(super.data) : super.withData();

  bool Function(String key, Object value)? refuse;
  String? heldKey;
  Completer<void>? entered;
  Completer<void>? release;

  void hold(String key) {
    heldKey = 'flutter.$key';
    entered = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == heldKey) {
      heldKey = null;
      entered!.complete();
      await release!.future;
    }
    if (refuse?.call(key, value) == true) return false;
    return super.setValue(type, key, value);
  }

  Future<Map<String, Object>> savedPreferences() async => {
    for (final entry in (await getAll()).entries)
      entry.key.replaceFirst('flutter.', ''): entry.value,
  };
}

Future<(SharedPreferences, _Disk, ReadStateConsentStore)> _harness([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final disk = _Disk(await SharedPreferencesStorePlatform.instance.getAll());
  SharedPreferencesStorePlatform.instance = disk;
  return (prefs, disk, ReadStateConsentStore.forPreferences(prefs));
}

Matcher _fails(SettingsFailureReason reason) => throwsA(
  isA<SettingsFailure>().having((error) => error.reason, 'reason', reason),
);

String _journal(
  List<String> ids, {
  bool complete = false,
  bool legacy = true,
}) => jsonEncode({
  'version': 1,
  'complete': complete,
  'ids': ids,
  'legacy': legacy,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'missing legacy default migrates only the initial saved population',
    () async {
      final (prefs, _, consent) = await _harness();
      expect(consent.enabled('old'), isFalse);
      await consent.migrateExistingProfiles(['old']);
      expect(consent.enabled('old'), isTrue);
      expect(consent.origin('old'), SettingOriginKind.migrated);
      expect(consent.enabled('new'), isFalse);
      await consent.migrateExistingProfiles(['old', 'new']);
      expect(consent.enabled('new'), isFalse);
      expect(
        prefs.containsKey(ReadStateConsentStore.preferenceKey('new')),
        isFalse,
      );
      final journal = jsonDecode(
        prefs.getString(ReadStateConsentStore.migrationKey)!,
      );
      expect(journal['complete'], isTrue);
      expect(journal['ids'], isEmpty);
    },
  );

  for (final malformed in <Object>[
    'true',
    1,
    <String>['true'],
  ]) {
    test(
      'malformed legacy ${malformed.runtimeType} cannot grant sharing',
      () async {
        final (prefs, _, consent) = await _harness({
          'oc.shareSessionViews': malformed,
        });
        await consent.migrateExistingProfiles(['old']);
        expect(consent.enabled('old'), isFalse);
        expect(
          prefs.getBool(ReadStateConsentStore.preferenceKey('old')),
          isFalse,
        );
        expect(consent.origin('old'), SettingOriginKind.migrated);
      },
    );
  }

  test('migration preserves explicit destination choices', () async {
    final (_, _, consent) = await _harness({
      'oc.shareSessionViews': false,
      ReadStateConsentStore.preferenceKey('on'): true,
      ReadStateConsentStore.originKey('on'): 'explicit',
      ReadStateConsentStore.preferenceKey('off'): false,
    });
    await consent.migrateExistingProfiles(['on', 'off', 'legacy']);
    expect(consent.enabled('on'), isTrue);
    expect(consent.origin('on'), SettingOriginKind.explicitValue);
    expect(consent.enabled('off'), isFalse);
    expect(consent.origin('off'), SettingOriginKind.explicitValue);
    expect(consent.enabled('legacy'), isFalse);
  });

  test(
    'refused migration completion stays private and retry can finish',
    () async {
      final (prefs, disk, consent) = await _harness();
      disk.refuse = (key, value) =>
          key == 'flutter.${ReadStateConsentStore.migrationKey}' &&
          value is String &&
          jsonDecode(value)['complete'] == true;
      await expectLater(
        consent.migrateExistingProfiles(['old']),
        _fails(SettingsFailureReason.storageFailed),
      );
      // The individual copy reached disk, but an incomplete migration may not
      // grant new live consent in the process reporting that failure.
      expect(prefs.getBool(ReadStateConsentStore.preferenceKey('old')), isTrue);
      expect(consent.enabled('old'), isFalse);
      expect(consent.saving('old'), isFalse);
      disk.refuse = null;
      await consent.migrateExistingProfiles(['old']);
      expect(consent.enabled('old'), isTrue);
      expect(consent.origin('old'), SettingOriginKind.migrated);
    },
  );

  test(
    'interrupted durable cohort does not absorb later profiles after restart',
    () async {
      final (_, disk, consent) = await _harness();
      disk.refuse = (key, _) =>
          key == 'flutter.${ReadStateConsentStore.preferenceKey('old')}';
      await expectLater(
        consent.migrateExistingProfiles(['old']),
        _fails(SettingsFailureReason.storageFailed),
      );
      final saved = await disk.savedPreferences();
      final firstJournal = jsonDecode(
        saved[ReadStateConsentStore.migrationKey] as String,
      );
      expect(firstJournal['complete'], isFalse);
      expect(firstJournal['ids'], ['old']);
      final (restartedPrefs, _, restarted) = await _harness(saved);
      await restarted.migrateExistingProfiles(['old', 'later']);
      expect(restarted.enabled('old'), isTrue);
      expect(restarted.enabled('later'), isFalse);
      expect(
        restartedPrefs.containsKey(
          ReadStateConsentStore.preferenceKey('later'),
        ),
        isFalse,
      );
    },
  );

  test(
    'migration cannot expose an optimistic true before disk acknowledgment',
    () async {
      final (prefs, disk, consent) = await _harness();
      disk.hold(ReadStateConsentStore.preferenceKey('old'));
      final migration = consent.migrateExistingProfiles(['old']);
      expect(consent.saving('old'), isTrue);
      expect(consent.enabled('old'), isFalse);
      await disk.entered!.future;
      // SharedPreferences has already changed its local cache here.
      expect(prefs.getBool(ReadStateConsentStore.preferenceKey('old')), isTrue);
      expect(consent.enabled('old'), isFalse);
      expect(consent.saving('old'), isTrue);
      disk.release!.complete();
      await migration;
      expect(consent.saving('old'), isFalse);
      expect(consent.enabled('old'), isTrue);
    },
  );

  test('failed opt-out stays private and explicit retry persists it', () async {
    final (_, disk, consent) = await _harness({
      ReadStateConsentStore.preferenceKey('old'): true,
    });
    expect(consent.enabled('old'), isTrue);
    final previousEpoch = consent.epoch;
    disk.refuse = (key, _) =>
        key == 'flutter.${ReadStateConsentStore.preferenceKey('old')}';
    final save = consent.setEnabled('old', false);
    expect(consent.enabled('old'), isFalse);
    expect(consent.epoch, greaterThan(previousEpoch));
    await expectLater(save, _fails(SettingsFailureReason.storageFailed));
    expect(consent.enabled('old'), isFalse);
    expect(consent.saving('old'), isFalse);
    expect(
      (await disk.savedPreferences())[ReadStateConsentStore.preferenceKey(
        'old',
      )],
      isTrue,
    );
    disk.refuse = null;
    await consent.setEnabled('old', false);
    final (_, _, restarted) = await _harness(await disk.savedPreferences());
    expect(restarted.enabled('old'), isFalse);
  });

  test(
    'deletion drains a pending grant, prunes its journal and sweeps both keys',
    () async {
      final (prefs, disk, consent) = await _harness({
        ReadStateConsentStore.migrationKey: _journal(['old', 'retained']),
        ReadStateConsentStore.preferenceKey('retained'): true,
      });
      disk.hold(ReadStateConsentStore.preferenceKey('old'));
      final grant = consent.setEnabled('old', true);
      final refusedGrant = expectLater(
        grant,
        _fails(SettingsFailureReason.staleTarget),
      );
      await disk.entered!.future;
      var finishedClosing = false;
      final closing = consent
          .closeProfile('old')
          .then((_) => finishedClosing = true);
      expect(consent.enabled('old'), isFalse);
      expect(consent.isClosed('old'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(finishedClosing, isFalse);
      disk.release!.complete();
      await refusedGrant;
      await closing;
      final journal = jsonDecode(
        prefs.getString(ReadStateConsentStore.migrationKey)!,
      );
      expect(journal['ids'], ['retained']);
      final profiles = ProfileStore(prefs: prefs);
      expect(
        profiles.profileScopedPreferenceKeys('old'),
        containsAll([
          ReadStateConsentStore.preferenceKey('old'),
          ReadStateConsentStore.originKey('old'),
        ]),
      );
      expect(await profiles.removeScopedPreferences('old'), isEmpty);
      await prefs.reload();
      expect(profiles.profileScopedPreferenceKeys('old'), isEmpty);
      expect(consent.enabled('retained'), isTrue);
      await expectLater(
        consent.setEnabled('old', true),
        _fails(SettingsFailureReason.staleTarget),
      );
      consent.reopenProfile('old');
      expect(consent.enabled('old'), isFalse);
    },
  );

  test(
    'failed journal pruning is retryable and never restores consent',
    () async {
      final (prefs, disk, consent) = await _harness({
        ReadStateConsentStore.migrationKey: _journal(['old', 'retained']),
        ReadStateConsentStore.preferenceKey('old'): true,
      });
      disk.refuse = (key, _) =>
          key == 'flutter.${ReadStateConsentStore.migrationKey}';
      await expectLater(
        consent.closeProfile('old'),
        _fails(SettingsFailureReason.storageFailed),
      );
      expect(consent.enabled('old'), isFalse);
      consent.reopenProfile('old');
      expect(consent.enabled('old'), isFalse);
      disk.refuse = null;
      await consent.closeProfile('old');
      final journal = jsonDecode(
        prefs.getString(ReadStateConsentStore.migrationKey)!,
      );
      expect(journal['ids'], ['retained']);
    },
  );
}
