import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/profile_monitor.dart';
import 'package:opencode_mobile/state/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// A quota-monitor record exactly as the old screen stored it.
String _quotaRecord({
  bool notifications = false,
  bool wifiOnly = false,
  bool quiet = false,
}) => jsonEncode({
  'version': 1,
  'rules': {
    'codex': {
      'source': _hash,
      'account': _hash,
      'token': _hash,
      'notifications': notifications,
      'wifiOnly': wifiOnly,
      'quietStart': quiet ? 22 * 60 : null,
      'quietEnd': quiet ? 8 * 60 : null,
      'alerted': <String, String>{},
      'threshold': 90,
    },
  },
});

void main() {
  group('mergeLegacyNotifyRules: quiet hours', () {
    test('only the saved-server pair: the pair is kept', () {
      final merged = mergeLegacyNotifyRules(
        profileRules: const [
          ProfileNotifyRules(quietStart: 23 * 60 + 30, quietEnd: 6 * 60 + 15),
        ],
      );
      expect(merged.quietStart, 23 * 60 + 30);
      expect(merged.quietEnd, 6 * 60 + 15);
      expect(merged.quietEnabled, isTrue);
    });

    test('only the quota toggle on: 22:00 to 08:00', () {
      final merged = mergeLegacyNotifyRules(
        quotaRules: const [LegacyQuotaNotify(quietHours: true)],
      );
      expect(merged.quietStart, 22 * 60);
      expect(merged.quietEnd, 8 * 60);
    });

    test('both: the saved-server pair wins', () {
      final merged = mergeLegacyNotifyRules(
        profileRules: const [
          ProfileNotifyRules(),
          ProfileNotifyRules(quietStart: 60, quietEnd: 120),
          ProfileNotifyRules(quietStart: 200, quietEnd: 300),
        ],
        quotaRules: const [LegacyQuotaNotify(quietHours: true)],
      );
      // The first pair in the given order, not the quota default and not a
      // later server's.
      expect(merged.quietStart, 60);
      expect(merged.quietEnd, 120);
    });

    test('neither: quiet hours are off', () {
      final merged = mergeLegacyNotifyRules(
        profileRules: const [ProfileNotifyRules(enabled: true)],
        quotaRules: const [LegacyQuotaNotify(notifications: true)],
      );
      expect(merged.quietEnabled, isFalse);
      expect(merged.quietStart, isNull);
      expect(merged.quietEnd, isNull);
      expect(merged.quietAt(DateTime(2026, 1, 1, 23)), isFalse);
    });

    test('half a pair is not a pair', () {
      final merged = mergeLegacyNotifyRules(
        profileRules: const [ProfileNotifyRules(quietStart: 60)],
      );
      expect(merged.quietEnabled, isFalse);
    });
  });

  group('mergeLegacyNotifyRules: the other shared values', () {
    test('Wi-Fi only is on when either legacy toggle was on', () {
      expect(mergeLegacyNotifyRules().wifiOnly, isFalse);
      expect(
        mergeLegacyNotifyRules(
          profileRules: const [ProfileNotifyRules(wifiOnly: true)],
        ).wifiOnly,
        isTrue,
      );
      expect(
        mergeLegacyNotifyRules(
          quotaRules: const [LegacyQuotaNotify(wifiOnly: true)],
        ).wifiOnly,
        isTrue,
      );
      expect(
        mergeLegacyNotifyRules(
          profileRules: const [ProfileNotifyRules()],
          quotaRules: const [LegacyQuotaNotify()],
        ).wifiOnly,
        isFalse,
      );
    });

    test('check-ins take the first duration; quota alerts any source', () {
      final merged = mergeLegacyNotifyRules(
        profileRules: const [
          ProfileNotifyRules(),
          ProfileNotifyRules(checkInAfterMinutes: 60),
          ProfileNotifyRules(checkInAfterMinutes: 15),
        ],
        quotaRules: const [
          LegacyQuotaNotify(),
          LegacyQuotaNotify(notifications: true),
        ],
      );
      expect(merged.checkInAfterMinutes, 60);
      expect(merged.quotaAlerts, isTrue);
    });
  });

  group('NotificationPreferences', () {
    Future<NotificationPreferences> prefs(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return NotificationPreferences(await SharedPreferences.getInstance());
    }

    test('nothing is shared until the migration has run', () async {
      final preferences = await prefs({
        'oc.notifyRules.a': jsonEncode(
          const ProfileNotifyRules(quietStart: 60, quietEnd: 120).toJson(),
        ),
      });
      expect(preferences.migrated, isFalse);
      expect(preferences.shared, isNull);
      // The legacy answer is still readable, harmlessly.
      expect(preferences.readLegacy(['a']).quietStart, 60);
    });

    test('reads both legacy stores, in the order given', () async {
      final preferences = await prefs({
        'oc.notifyRules.a': jsonEncode(
          const ProfileNotifyRules(quietStart: 60, quietEnd: 120).toJson(),
        ),
        'oc.notifyRules.b': jsonEncode(
          const ProfileNotifyRules(
            quietStart: 200,
            quietEnd: 300,
            wifiOnly: true,
          ).toJson(),
        ),
        'oc.quotaMonitor.a': _quotaRecord(quiet: true, notifications: true),
      });
      final merged = await preferences.migrate(['b', 'a']);
      expect(merged.quietStart, 200);
      expect(merged.quietEnd, 300);
      expect(merged.wifiOnly, isTrue);
      expect(merged.quotaAlerts, isTrue);
      expect(preferences.shared, merged);
    });

    test('only the quota toggle: 22:00 to 08:00 and Wi-Fi only', () async {
      final preferences = await prefs({
        'oc.quotaMonitor.a': _quotaRecord(quiet: true, wifiOnly: true),
      });
      final merged = await preferences.migrate(['a']);
      expect(merged.quietStart, 22 * 60);
      expect(merged.quietEnd, 8 * 60);
      expect(merged.wifiOnly, isTrue);
      expect(merged.quotaAlerts, isFalse);
    });

    test('runs once: a second pass never overwrites an edit', () async {
      final preferences = await prefs({
        'oc.notifyRules.a': jsonEncode(
          const ProfileNotifyRules(quietStart: 60, quietEnd: 120).toJson(),
        ),
      });
      await preferences.migrate(['a']);
      await preferences.save(
        preferences.shared!.copyWith(clearQuiet: true, wifiOnly: true),
      );
      final again = await preferences.migrate(['a']);
      expect(again.quietEnabled, isFalse);
      expect(again.wifiOnly, isTrue);
      // The legacy record is left for an older build to find.
      expect(preferences.prefs.getString('oc.notifyRules.a'), isNotNull);
    });

    test('a corrupt legacy record migrates as off', () async {
      final preferences = await prefs({
        'oc.notifyRules.a': '{not json',
        'oc.quotaMonitor.a': '[]',
      });
      final merged = await preferences.migrate(['a']);
      expect(merged, const SharedNotifyRules());
      expect(preferences.migrated, isTrue);
    });

    test('the two "what notifies me" choices default to on', () async {
      final preferences = await prefs({});
      expect(preferences.finishedRuns, isTrue);
      expect(preferences.requests, isTrue);
      await preferences.setFinishedRuns(false);
      await preferences.setRequests(false);
      expect(preferences.finishedRuns, isFalse);
      expect(preferences.requests, isFalse);
    });
  });
}
