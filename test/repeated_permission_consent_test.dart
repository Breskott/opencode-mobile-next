import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/repeated_permission_consent.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.withData({});
  bool allowWrites = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      allowWrites ? super.setValue(valueType, key, value) : false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;

  PermissionConsentScope scope({
    String session = 'session-a',
    String pattern = '/workspace/file',
    List<String> always = const [],
  }) => PermissionConsentScope(
    sessionID: session,
    permission: 'edit',
    patterns: [pattern],
    alwaysPatterns: always,
  );

  Future<RepeatedPermissionStatus> ask(
    RepeatedPermissionConsent service,
    String id, {
    PermissionConsentScope? target,
    bool supported = true,
  }) => service.observe(
    scope: target ?? scope(),
    requestID: id,
    supportsPersistentGrants: supported,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    KitRedact.clearKnownSecrets();
  });
  tearDown(KitRedact.clearKnownSecrets);

  test(
    'third distinct ask offers once, survives restart and explains decline',
    () async {
      var service = RepeatedPermissionConsent(preferences, profileId: 'one');
      expect((await ask(service, '1')).offerAlwaysAllow, isFalse);
      expect((await ask(service, '1')).distinctAsks, 1);
      expect((await ask(service, '2')).offerAlwaysAllow, isFalse);
      service = RepeatedPermissionConsent(preferences, profileId: 'one');
      final concurrent = await Future.wait([
        ask(service, '3'),
        ask(service, '3'),
      ]);
      expect(concurrent.where((s) => s.offerAlwaysAllow).length, 1);
      await service.recordDecision(scope(), accepted: false);
      service = RepeatedPermissionConsent(preferences, profileId: 'one');
      expect((await ask(service, '4')).offerAlwaysAllow, isFalse);
      expect((await service.status(scope())).explainDeclinedInSettings, isTrue);
      expect(
        (await service.status(
          scope(session: 'later-session'),
        )).explainDeclinedInSettings,
        isTrue,
      );
      final other = RepeatedPermissionConsent(preferences, profileId: 'two');
      expect((await ask(other, '3')).distinctAsks, 1);
      await preferences.remove(service.storageKey);
      expect((await service.status(scope())).distinctAsks, 0);
    },
  );

  test(
    'capability and exact scope gate offers across sessions without storing secrets',
    () async {
      final service = RepeatedPermissionConsent(preferences, profileId: 'one');
      expect(
        () => RepeatedPermissionConsent(preferences, profileId: 'token=unsafe'),
        throwsArgumentError,
      );
      KitRedact.registerKnownSecret('known-secret-profile');
      expect(
        () => RepeatedPermissionConsent(
          preferences,
          profileId: 'known-secret-profile',
        ),
        throwsArgumentError,
      );
      expect((await ask(service, '1', supported: false)).distinctAsks, 0);
      expect(preferences.containsKey(service.storageKey), isFalse);
      final first = scope(pattern: 'token=fake-first-token');
      final second = scope(pattern: 'token=fake-second-token');
      await ask(service, '1', target: first);
      await ask(service, '2', target: first);
      expect((await ask(service, '3', target: second)).distinctAsks, 1);
      expect(
        (await ask(
          service,
          '1',
          target: scope(session: 'other', pattern: 'token=fake-first-token'),
        )).offerAlwaysAllow,
        isTrue,
      );
      expect(
        (await ask(service, '3', target: scope(session: 'other'))).distinctAsks,
        1,
      );
      expect(
        (await ask(service, '3', target: scope(always: ['*']))).distinctAsks,
        1,
      );
      expect(
        (await ask(service, '3', target: first)).offerAlwaysAllow,
        isFalse,
      );
      final stored = preferences.getString(service.storageKey)!;
      expect(stored.contains('fake-first-token'), isFalse);
      expect(stored.contains('fake-second-token'), isFalse);
      expect(stored.contains('/workspace/file'), isFalse);
      expect(stored.contains('session-a'), isFalse);
      final decision = await service.recordDecision(first, accepted: true);
      expect(decision.decision, PermissionOfferDecision.accepted);
      expect(decision.offerAlwaysAllow, isFalse);
    },
  );

  test('corrupt storage and refused writes suppress offers', () async {
    final service = RepeatedPermissionConsent(preferences, profileId: 'one');
    await preferences.setString(service.storageKey, '{invalid');
    expect((await ask(service, '1')).storageAvailable, isFalse);
    expect((await ask(service, '2')).offerAlwaysAllow, isFalse);
    expect(preferences.getString(service.storageKey), '{invalid');

    SharedPreferences.resetStatic();
    final store = _RefusingStore();
    SharedPreferencesStorePlatform.instance = store;
    final writePreferences = await SharedPreferences.getInstance();
    final refusing = RepeatedPermissionConsent(
      writePreferences,
      profileId: 'two',
    );
    expect((await ask(refusing, '1')).storageAvailable, isFalse);
    expect((await ask(refusing, '2')).offerAlwaysAllow, isFalse);
    expect((await ask(refusing, '3')).offerAlwaysAllow, isFalse);
    store.allowWrites = true;
    final restarted = RepeatedPermissionConsent(
      writePreferences,
      profileId: 'two',
    );
    expect((await ask(restarted, 'new-request')).distinctAsks, 1);

    await writePreferences.setString(
      'oc.permissionConsent.large',
      List.filled(128 * 1024 + 1, 'x').join(),
    );
    final oversized = RepeatedPermissionConsent(
      writePreferences,
      profileId: 'large',
    );
    expect((await ask(oversized, '1')).storageAvailable, isFalse);
  });
}
