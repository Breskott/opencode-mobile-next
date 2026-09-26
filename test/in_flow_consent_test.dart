import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/keep_alive_advice.dart';
import 'package:opencode_mobile/state/in_flow_consent.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _RefusingStore extends InMemorySharedPreferencesStore {
  _RefusingStore() : super.withData({});

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'first phone start claims once, remembers denial and isolates servers',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final consent = await InFlowConsent.load(prefs, profileId: 'phone');
      final claims = await Future.wait([
        consent.phoneServerFirstStart(
          batteryAlreadyExempt: false,
          maker: PhoneMaker.xiaomi,
        ),
        consent.phoneServerFirstStart(
          batteryAlreadyExempt: false,
          maker: PhoneMaker.xiaomi,
        ),
      ]);
      expect(claims.first, [
        InFlowConsentKind.batteryExemption,
        InFlowConsentKind.makerAutoStart,
      ]);
      expect(claims.last, isEmpty);
      await consent.answer(InFlowConsentKind.batteryExemption, allow: false);
      await consent.answer(InFlowConsentKind.makerAutoStart, allow: false);
      final restored = await InFlowConsent.load(prefs, profileId: 'phone');
      expect(
        await restored.phoneServerFirstStart(
          batteryAlreadyExempt: false,
          maker: PhoneMaker.xiaomi,
        ),
        isEmpty,
      );
      expect(
        restored.row(InFlowConsentKind.batteryExemption).explanation,
        InFlowConsentExplanation.batteryMayStopServer,
      );
      expect(
        restored.row(InFlowConsentKind.makerAutoStart).explanation,
        InFlowConsentExplanation.makerMayPreventRestart,
      );
      final other = await InFlowConsent.load(prefs, profileId: 'other');
      expect(
        await other.phoneServerFirstStart(
          batteryAlreadyExempt: true,
          maker: PhoneMaker.other,
        ),
        isEmpty,
      );
      // A later loss of exemption or changed maker does not restart onboarding.
      expect(
        await other.phoneServerFirstStart(
          batteryAlreadyExempt: false,
          maker: PhoneMaker.xiaomi,
        ),
        isEmpty,
      );
    },
  );

  test(
    'preset survives restart; interrupted asks explain themselves; Settings revises',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var consent = await InFlowConsent.load(prefs, profileId: 'phone');
      expect(await consent.requestNeedsYouPreset(), isTrue);
      consent = await InFlowConsent.load(prefs, profileId: 'phone');
      expect(await consent.requestNeedsYouPreset(), isFalse);
      expect(
        consent.row(InFlowConsentKind.needsYouNotifications).explanation,
        InFlowConsentExplanation.unfinished,
      );
      await consent.answer(
        InFlowConsentKind.needsYouNotifications,
        allow: false,
      );
      expect(
        consent.row(InFlowConsentKind.needsYouNotifications).explanation,
        InFlowConsentExplanation.needsYouAlertsOff,
      );
      await consent.changeFromSettings(
        InFlowConsentKind.needsYouNotifications,
        allow: true,
      );
      consent = await InFlowConsent.load(prefs, profileId: 'phone');
      expect(
        consent.row(InFlowConsentKind.needsYouNotifications).choice,
        InFlowConsentChoice.accepted,
      );
      expect(await consent.requestNeedsYouPreset(), isFalse);
      await expectLater(
        consent.answer(InFlowConsentKind.needsYouNotifications, allow: true),
        throwsStateError,
      );
      // Stored intent does not overwrite the application's global notification rules.
      expect(prefs.containsKey('oc.notify.requests'), isFalse);
    },
  );

  test(
    'profile deletion removes consent and leaves another server intact',
    () async {
      final prefs = await SharedPreferences.getInstance();
      for (final id in ['phone', 'other']) {
        final consent = await InFlowConsent.load(prefs, profileId: id);
        await consent.requestNeedsYouPreset();
      }
      final store = ProfileStore(prefs: prefs);
      expect(await store.removeScopedPreferences('phone'), isEmpty);
      expect(prefs.containsKey('oc.inFlowConsent.phone'), isFalse);
      expect(prefs.containsKey('oc.inFlowConsent.other'), isTrue);
      final recreated = await InFlowConsent.load(prefs, profileId: 'phone');
      expect(await recreated.requestNeedsYouPreset(), isTrue);
    },
  );

  test(
    'bad storage and failed writes never offer consent or record a grant',
    () async {
      SharedPreferences.setMockInitialValues({
        'oc.inFlowConsent.phone': '{broken',
      });
      var prefs = await SharedPreferences.getInstance();
      await expectLater(
        InFlowConsent.load(prefs, profileId: 'phone'),
        throwsStateError,
      );
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = _RefusingStore();
      prefs = await SharedPreferences.getInstance();
      final consent = await InFlowConsent.load(prefs, profileId: 'phone');
      await expectLater(consent.requestNeedsYouPreset(), throwsStateError);
      expect(consent.storageAvailable, isFalse);
      expect(
        consent.row(InFlowConsentKind.needsYouNotifications).choice,
        InFlowConsentChoice.unseen,
      );
      await expectLater(consent.requestNeedsYouPreset(), throwsStateError);
      final restored = await InFlowConsent.load(prefs, profileId: 'phone');
      expect(
        restored.row(InFlowConsentKind.needsYouNotifications).choice,
        InFlowConsentChoice.unseen,
      );
    },
  );
}
