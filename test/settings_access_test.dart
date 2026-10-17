import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/settings_scope.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/settings_access.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _device = SettingsTarget.device();
const _phone = SettingsTarget.connection('phone');
const _laptop = SettingsTarget.connection('laptop');

Matcher _fails(SettingsFailureReason reason) => throwsA(
  isA<SettingsFailure>().having((error) => error.reason, 'reason', reason),
);

Map<String, Object> _data() => {
  'oc.profiles': jsonEncode([
    {'id': 'phone', 'name': 'Phone', 'baseUrl': 'http://127.0.0.1:4096'},
    {
      'id': 'laptop',
      'name': 'Laptop',
      'baseUrl': 'https://laptop.example.test',
    },
  ]),
  'oc.readStateConsentMigration.v1': jsonEncode({
    'version': 1,
    'complete': true,
    'ids': <String>[],
    'legacy': false,
  }),
};

class _ControlledPreferences extends InMemorySharedPreferencesStore {
  _ControlledPreferences(super.data) : super.withData();
  String? blockKey;
  bool refuse = false;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(blockKey ?? '\u0000')) {
      if (entered != null && !entered!.isCompleted) entered!.complete();
      await release?.future;
      if (refuse) return false;
    }
    return super.setValue(type, key, value);
  }
}

Future<ProfileStore> _store({Map<String, Object>? initial}) async {
  SharedPreferences.setMockInitialValues(initial ?? _data());
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  test(
    'device preferences update across facades and preserve effects fields',
    () async {
      final store = await _store();
      final one = ProfileSettingsAccess(store);
      final anotherStore = ProfileStore(prefs: store.prefs);
      final two = ProfileSettingsAccess(anotherStore);
      addTearDown(one.dispose);
      addTearDown(two.dispose);
      final changes = StreamIterator(two.watchSetting('appearance', _device));
      expect(await changes.moveNext(), isTrue);
      final edit = await one.beginEdit('appearance', _device);
      final next = changes.moveNext();
      final receipt = await one.writeSetting(edit, 'light');
      expect(await next, isTrue);
      expect(changes.current.value, 'light');
      expect(receipt.confirmed.value, 'light');
      expect(store.prefs.getString('oc.appearance'), 'light');
      final effects = await one.beginEdit('effects', _device);
      final before = Map<String, Object>.from(effects.before.value as Map);
      final requested = {...before, 'glowStyle': 'softRing'};
      await one.writeSetting(effects, requested);
      final saved = await two.readSetting('effects', _device);
      expect(saved.value, requested);
      expect(() => (saved.value as Map).clear(), throwsUnsupportedError);
      await changes.cancel();
    },
  );

  test(
    'local model snapshots are read-only and malformed stored values unknown',
    () async {
      final store = await _store(
        initial: {
          ..._data(),
          'oc.model.phone': 'provider|model',
          'oc.model.laptop': 'malformed',
          'oc.agent.phone': 'build',
        },
      );
      final access = ProfileSettingsAccess(store);
      addTearDown(access.dispose);
      final model = await access.readSetting('model', _phone);
      expect(model.value, {'providerId': 'provider', 'modelId': 'model'});
      expect(model.authority, SettingAuthority.localPreference);
      expect(model.writable, isFalse);
      expect(
        (await access.readSetting('model', _laptop)).state,
        SettingValueState.unknown,
      );
      expect(
        (await access.readSetting('shell', _phone)).state,
        SettingValueState.unsupported,
      );
      expect(
        (await access.readSetting(
          'model',
          const SettingsTarget.project('phone', 'p'),
        )).state,
        SettingValueState.unsupported,
      );
      await expectLater(
        access.beginEdit('model', _phone),
        _fails(SettingsFailureReason.unsupported),
      );
    },
  );

  test(
    'active connection changes do not retarget a captured consent save',
    () async {
      final store = await _store();
      final access = ProfileSettingsAccess(store);
      addTearDown(access.dispose);
      await store.setActiveId('phone');
      final edit = await access.beginEdit('shareReadState', _phone);
      await store.setActiveId('laptop');
      final receipt = await access.writeSetting(edit, true);
      expect(receipt.confirmed.target, _phone);
      expect(store.prefs.getBool('oc.shareSessionViews.phone'), isTrue);
      expect(store.prefs.getBool('oc.shareSessionViews.laptop'), isNull);
    },
  );

  test(
    'cross-facade competing writes conflict and fabricated tokens fail',
    () async {
      final store = await _store();
      final one = ProfileSettingsAccess(store);
      final two = ProfileSettingsAccess(store);
      addTearDown(one.dispose);
      addTearDown(two.dispose);
      final first = await one.beginEdit('appearance', _device);
      final second = await two.beginEdit('appearance', _device);
      await expectLater(
        two.writeSetting(first, 'dark'),
        _fails(SettingsFailureReason.staleTarget),
      );
      final winner = one.writeSetting(first, 'light');
      final loser = two.writeSetting(second, 'system');
      await expectLater(loser, _fails(SettingsFailureReason.conflict));
      await winner;
      expect(store.appPreferences.value.appearance, AppAppearance.light);
      final edit = await one.beginEdit('appearance', _device);
      await expectLater(
        one.writeSetting(
          SettingsEditToken(
            before: edit.before,
            ownerFingerprint: edit.ownerFingerprint,
          ),
          'dark',
        ),
        _fails(SettingsFailureReason.staleTarget),
      );
    },
  );

  test(
    'transport replacement invalidates tokens and existing watch context',
    () async {
      final store = await _store();
      final access = ProfileSettingsAccess(store);
      addTearDown(access.dispose);
      final edit = await access.beginEdit('shareReadState', _phone);
      final watch = StreamIterator(
        access.watchSetting('shareReadState', _phone),
      );
      expect(await watch.moveNext(), isTrue);
      final changed = watch.moveNext();
      await store.upsert(
        ServerProfile(
          id: 'phone',
          name: 'Replacement',
          baseUrl: 'https://replacement.example.test',
        ),
      );
      expect(await changed, isTrue);
      expect(watch.current.state, SettingValueState.stale);
      await expectLater(
        access.writeSetting(edit, true),
        _fails(SettingsFailureReason.staleTarget),
      );
      expect(
        (await access.readSetting('shareReadState', _phone)).state,
        SettingValueState.known,
      );
      await watch.cancel();
    },
  );

  test(
    'closed owners reject writes; dispose closes streams and retains shared owner',
    () async {
      final store = await _store();
      final access = ProfileSettingsAccess(store);
      final edit = await access.beginEdit('shareReadState', _phone);
      final watch = StreamIterator(
        access.watchSetting('shareReadState', _phone),
      );
      expect(await watch.moveNext(), isTrue);
      final stale = watch.moveNext();
      await store.appPreferences.readStateConsent.closeProfile('phone');
      expect(await stale, isTrue);
      expect(watch.current.state, SettingValueState.stale);
      await expectLater(
        access.writeSetting(edit, true),
        _fails(SettingsFailureReason.staleTarget),
      );
      // closeProfile may emit multiple updates; cancel before checking disposal.
      await watch.cancel();
      final deviceWatch = StreamIterator(
        access.watchSetting('appearance', _device),
      );
      expect(await deviceWatch.moveNext(), isTrue);
      final done = deviceWatch.moveNext();
      access.dispose();
      expect(await done, isFalse);
      await expectLater(
        access.readSetting('appearance', _device),
        _fails(SettingsFailureReason.disposed),
      );
      await expectLater(
        access.watchSetting('appearance', _device).first,
        _fails(SettingsFailureReason.disposed),
      );
      await store.appPreferences.setAppearance(AppAppearance.light);
      expect(store.appPreferences.value.appearance, AppAppearance.light);
    },
  );

  test(
    'selection reads and streams publish only acknowledged shared writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = _ControlledPreferences({
        for (final entry in _data().entries)
          'flutter.${entry.key}': entry.value,
        'flutter.oc.model.phone': 'provider|old',
      });
      SharedPreferencesStorePlatform.instance = backend;
      final store = ProfileStore(prefs: await SharedPreferences.getInstance());
      await store.load();
      final secondStore = ProfileStore(prefs: store.prefs);
      final access = ProfileSettingsAccess(secondStore);
      addTearDown(access.dispose);
      final stream = StreamIterator(access.watchSetting('model', _phone));
      expect(await stream.moveNext(), isTrue);
      expect(stream.current.value, {
        'providerId': 'provider',
        'modelId': 'old',
      });
      backend.blockKey = 'oc.model.phone';
      backend.entered = Completer<void>();
      backend.release = Completer<void>();
      final pending = store.setModel(
        'phone',
        'provider',
        'new',
        explicit: true,
      );
      await backend.entered!.future;
      final fresh = ProfileSettingsAccess(secondStore);
      addTearDown(fresh.dispose);
      expect((await fresh.readSetting('model', _phone)).value, {
        'providerId': 'provider',
        'modelId': 'old',
      });
      final next = stream.moveNext();
      backend.release!.complete();
      await pending;
      expect(await next, isTrue);
      expect(stream.current.value, {
        'providerId': 'provider',
        'modelId': 'new',
      });
      final agent = StreamIterator(access.watchSetting('agent', _phone));
      expect(await agent.moveNext(), isTrue);
      final agentChanged = agent.moveNext();
      await store.setAgent('phone', 'review');
      expect(await agentChanged, isTrue);
      expect(agent.current.value, 'review');
      await agent.cancel();
      await stream.cancel();
    },
  );

  test(
    'a second ProfileStore observes replacement and closed target identity',
    () async {
      final store = await _store();
      final secondStore = ProfileStore(prefs: store.prefs);
      final access = ProfileSettingsAccess(secondStore);
      addTearDown(access.dispose);
      final old = await access.beginEdit('shareReadState', _phone);
      await store.upsert(
        ServerProfile(
          id: 'phone',
          name: 'Moved phone',
          baseUrl: 'https://moved.example.test',
        ),
      );
      await expectLater(
        access.writeSetting(old, true),
        _fails(SettingsFailureReason.staleTarget),
      );
      final fresh = await access.beginEdit('shareReadState', _phone);
      await store.appPreferences.readStateConsent.closeProfile('phone');
      await expectLater(
        access.writeSetting(fresh, true),
        _fails(SettingsFailureReason.staleTarget),
      );
      expect(
        (await access.readSetting('shareReadState', _phone)).state,
        SettingValueState.stale,
      );
    },
  );

  test(
    'late transport change cannot grant consent to the replacement',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = _ControlledPreferences({
        for (final entry in _data().entries)
          'flutter.${entry.key}': entry.value,
      });
      SharedPreferencesStorePlatform.instance = backend;
      final store = ProfileStore(prefs: await SharedPreferences.getInstance());
      await store.load();
      final access = ProfileSettingsAccess(store);
      addTearDown(access.dispose);
      final edit = await access.beginEdit('shareReadState', _phone);
      backend.blockKey = 'oc.shareSessionViews.phone';
      backend.entered = Completer<void>();
      backend.release = Completer<void>();
      final pending = access.writeSetting(edit, true);
      final check = expectLater(
        pending,
        _fails(SettingsFailureReason.staleTarget),
      );
      await backend.entered!.future;
      // ServerProfile is mutable: an editor can alter the transport before its
      // asynchronous upsert finishes and while this older write is awaiting I/O.
      store.profiles.firstWhere((profile) => profile.id == 'phone').baseUrl =
          'https://replacement.example.test';
      backend.release!.complete();
      await check;
      expect(store.appPreferences.readStateConsent.enabled('phone'), isFalse);
      expect(store.prefs.getBool('oc.shareSessionViews.phone'), isNot(isTrue));
    },
  );

  test(
    'refused save is failure, and opt-out is private before acknowledgment',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = _ControlledPreferences({
        for (final entry in _data().entries)
          'flutter.${entry.key}': entry.value,
        'flutter.oc.shareSessionViews.phone': true,
      });
      SharedPreferencesStorePlatform.instance = backend;
      final store = ProfileStore(prefs: await SharedPreferences.getInstance());
      await store.load();
      final access = ProfileSettingsAccess(store);
      addTearDown(access.dispose);
      final edit = await access.beginEdit('shareReadState', _phone);
      expect(edit.before.value, isTrue);
      backend.blockKey = 'oc.shareSessionViews.phone';
      backend.entered = Completer<void>();
      backend.release = Completer<void>();
      backend.refuse = true;
      final result = access.writeSetting(edit, false);
      final check = expectLater(
        result,
        _fails(SettingsFailureReason.storageFailed),
      );
      expect(store.appPreferences.readStateConsent.enabled('phone'), isFalse);
      await backend.entered!.future;
      expect(
        (await access.readSetting('shareReadState', _phone)).value,
        isFalse,
      );
      backend.release!.complete();
      await check;
      expect(store.appPreferences.readStateConsent.enabled('phone'), isFalse);
    },
  );
}
