import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/quota_answer_preferences.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore(super.data) : super.withData();

  final entered = Completer<void>();
  Completer<void>? release;
  bool refuse = false;
  bool throwOnWrite = false;
  bool throwOnRead = false;
  bool refuseRemove = false;

  @override
  Future<Map<String, Object>> getAll() async {
    if (throwOnRead) throw StateError('Synthetic storage read failure');
    return super.getAll();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.startsWith('flutter.oc.quotaAnswers.')) {
      if (!entered.isCompleted) entered.complete();
      await release?.future;
      if (throwOnWrite) throw StateError('Synthetic storage failure');
      if (refuse) return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (refuseRemove) return false;
    return super.remove(key);
  }
}

Future<_ControlledStore> _controlStore() async {
  final original = SharedPreferencesStorePlatform.instance;
  final store = _ControlledStore(await original.getAll());
  SharedPreferencesStorePlatform.instance = store;
  addTearDown(() => SharedPreferencesStorePlatform.instance = original);
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  var current = true;
  var present = true;

  QuotaAnswerPreferences create({String profileId = 'one'}) =>
      QuotaAnswerPreferences(
        preferences: preferences,
        profileId: profileId,
        isCurrent: () => current,
        isProfilePresent: () => present,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    current = true;
    present = true;
    KitRedact.clearKnownSecrets();
  });

  tearDown(KitRedact.clearKnownSecrets);

  test('alerts start enabled without writing a record', () {
    final value = create();
    expect(value.alert80Enabled, isTrue);
    expect(value.failed, isFalse);
    expect(preferences.containsKey('oc.quotaAnswers.one'), isFalse);
  });

  test('rejects an empty or whitespace profile id', () {
    expect(() => create(profileId: ''), throwsArgumentError);
    expect(() => create(profileId: '  '), throwsArgumentError);
  });

  test(
    'disabled alerts survive reconstruction with only setting persisted',
    () async {
      final value = create();
      expect(await value.setAlert80Enabled(false), isTrue);
      expect(value.alert80Enabled, isFalse);
      expect(create().alert80Enabled, isFalse);
      expect(jsonDecode(preferences.getString('oc.quotaAnswers.one')!), {
        'version': 1,
        'alert80Enabled': false,
      });
    },
  );

  test(
    'profile deletion sweep removes only its own alert preference',
    () async {
      await create().setAlert80Enabled(false);
      await create(profileId: 'two').setAlert80Enabled(true);
      final profiles = ProfileStore(prefs: preferences);
      expect(profiles.profileScopedPreferenceKeys('one'), {
        'oc.quotaAnswers.one',
      });
      expect(await profiles.removeScopedPreferences('one'), isEmpty);
      expect(preferences.containsKey('oc.quotaAnswers.one'), isFalse);
      expect(preferences.containsKey('oc.quotaAnswers.two'), isTrue);
      expect(create(profileId: 'two').alert80Enabled, isTrue);
    },
  );

  test('invalid records default on and expose only the failure flag', () async {
    for (final raw in <Object>[
      'not json',
      17,
      '[]',
      '{"version":2,"alert80Enabled":false}',
      '{"version":1,"alert80Enabled":"false"}',
      '{"version":1,"alert80Enabled":false,"extra":"unknown"}',
    ]) {
      SharedPreferences.setMockInitialValues({'oc.quotaAnswers.one': raw});
      preferences = await SharedPreferences.getInstance();
      final value = create();
      expect(value.alert80Enabled, isTrue);
      expect(value.failed, isTrue);
      expect(await value.setAlert80Enabled(false), isTrue);
      expect(value.failed, isFalse);
    }
  });

  test(
    'refused writes preserve confirmed state and repair the cache',
    () async {
      final value = create();
      final disk = await _controlStore();
      disk.refuse = true;
      expect(await value.setAlert80Enabled(false), isFalse);
      expect(value.alert80Enabled, isTrue);
      expect(value.failed, isTrue);
      expect(create().alert80Enabled, isTrue);
      disk.refuse = false;
      expect(await value.setAlert80Enabled(false), isTrue);
      expect(value.failed, isFalse);
    },
  );

  test(
    'thrown writes return fixed failure and preserve confirmed state',
    () async {
      final value = create();
      final disk = await _controlStore();
      disk.throwOnWrite = true;
      expect(await value.setAlert80Enabled(false), isFalse);
      expect(value.failed, isTrue);
      expect(value.alert80Enabled, isTrue);
      expect(create().alert80Enabled, isTrue);
    },
  );

  test(
    'reconstruction ignores a pending write that is later rejected',
    () async {
      final value = create();
      final disk = await _controlStore();
      disk
        ..release = Completer<void>()
        ..refuse = true;
      final writing = value.setAlert80Enabled(false);
      await disk.entered.future;
      final reconstructed = create();
      expect(reconstructed.alert80Enabled, isTrue);
      disk.release!.complete();
      expect(await writing, isFalse);
      expect(reconstructed.alert80Enabled, isTrue);
      expect(reconstructed.failed, isTrue);
      expect(create().alert80Enabled, isTrue);
    },
  );

  test('write and reload failure preserve shared confirmed state', () async {
    final value = create();
    expect(await value.setAlert80Enabled(false), isTrue);
    final disk = await _controlStore();
    disk
      ..refuse = true
      ..throwOnRead = true;
    expect(await value.setAlert80Enabled(true), isFalse);
    final reconstructed = create();
    expect(value.alert80Enabled, isFalse);
    expect(reconstructed.alert80Enabled, isFalse);
    expect(reconstructed.failed, isTrue);
    disk
      ..refuse = false
      ..throwOnRead = false;
    expect(await reconstructed.setAlert80Enabled(true), isTrue);
    expect(value.alert80Enabled, isTrue);
    expect(create().failed, isFalse);
  });

  test('deletion resets shared state even after a failed reload', () async {
    final value = create();
    await value.setAlert80Enabled(false);
    final disk = await _controlStore();
    disk
      ..refuse = true
      ..throwOnRead = true;
    await value.setAlert80Enabled(true);
    expect(value.failed, isTrue);
    await ProfileStore(prefs: preferences).removeScopedPreferences('one');
    final reconstructed = create();
    expect(reconstructed.alert80Enabled, isTrue);
    expect(reconstructed.failed, isFalse);
  });

  test('mock preference replacement has independent confirmed state', () async {
    await create().setAlert80Enabled(false);
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    expect(create().alert80Enabled, isTrue);
    expect(create().failed, isFalse);
  });

  test('a redaction collision fails closed without persisting', () async {
    KitRedact.registerKnownSecret('alert80Enabled');
    final value = create();
    expect(await value.setAlert80Enabled(false), isFalse);
    expect(value.failed, isTrue);
    expect(preferences.containsKey('oc.quotaAnswers.one'), isFalse);
  });

  test(
    'concurrent instances serialize the last requested preference',
    () async {
      final disk = await _controlStore();
      disk.release = Completer<void>();
      final first = create().setAlert80Enabled(false);
      await disk.entered.future;
      final second = create().setAlert80Enabled(true);
      disk.release!.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(create().alert80Enabled, isTrue);
      final stored = await disk.getAll();
      expect(jsonDecode(stored['flutter.oc.quotaAnswers.one']! as String), {
        'version': 1,
        'alert80Enabled': true,
      });
    },
  );

  test(
    'deletion removes an in-flight write and rejects queued writes',
    () async {
      final disk = await _controlStore();
      disk.release = Completer<void>();
      final value = create();
      final first = value.setAlert80Enabled(false);
      await disk.entered.future;
      final second = value.setAlert80Enabled(true);
      present = false;
      await ProfileStore(prefs: preferences).removeScopedPreferences('one');
      disk.release!.complete();
      expect(await first, isFalse);
      expect(await second, isFalse);
      expect(value.alert80Enabled, isTrue);
      expect(preferences.containsKey('oc.quotaAnswers.one'), isFalse);
      expect(
        (await disk.getAll()).containsKey('flutter.oc.quotaAnswers.one'),
        isFalse,
      );
    },
  );

  test('failed late-write cleanup reports failure', () async {
    final disk = await _controlStore();
    disk.release = Completer<void>();
    final value = create();
    final writing = value.setAlert80Enabled(false);
    await disk.entered.future;
    present = false;
    disk.refuseRemove = true;
    disk.release!.complete();
    expect(await writing, isFalse);
    expect(value.failed, isTrue);
  });

  test(
    'navigation preserves an in-flight write for a present profile',
    () async {
      final disk = await _controlStore();
      disk.release = Completer<void>();
      final writing = create().setAlert80Enabled(false);
      await disk.entered.future;
      current = false;
      disk.release!.complete();
      expect(await writing, isFalse);
      expect(create().alert80Enabled, isFalse);
      expect(create(profileId: 'two').alert80Enabled, isTrue);
    },
  );

  test('stale and deleted instances cannot start new writes', () async {
    final value = create();
    current = false;
    expect(await value.setAlert80Enabled(false), isFalse);
    current = true;
    present = false;
    expect(await value.setAlert80Enabled(false), isFalse);
    expect(preferences.containsKey('oc.quotaAnswers.one'), isFalse);
  });
}
