import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/attention_tile_snapshot.dart';
import 'package:opencode_mobile/platform/launch_shortcut.dart';

/// The Android half of the F6 launch surfaces cannot run under
/// `flutter test`, so the contract Dart relies on is pinned from the sources:
/// the pinned-session extras and channel methods, the shortcut publisher's
/// disable-then-publish order, the tile's manifest registration, the
/// preference key the tile reads, and the whitelisted action its tap sends.
void main() {
  const androidMain = 'android/app/src/main';
  const kotlin = '$androidMain/kotlin/io/github/eslamasabry/opencode_mobile';
  final activity = File('$kotlin/MainActivity.kt').readAsStringSync();
  final shortcuts = File(
    '$kotlin/PinnedSessionShortcuts.kt',
  ).readAsStringSync();
  final tile = File('$kotlin/AttentionTileService.kt').readAsStringSync();
  final manifest = File('$androidMain/AndroidManifest.xml').readAsStringSync();
  final strings = File(
    '$androidMain/res/values/strings.xml',
  ).readAsStringSync();
  final arabic = File(
    '$androidMain/res/values-ar/strings.xml',
  ).readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  group('pinned-session shortcuts', () {
    test('the channel exposes the session drain and the publisher', () {
      expect(activity, contains('"consumeSessionLaunch"'));
      expect(activity, contains('"setPinnedSessions"'));
      expect(activity, contains('invokeMethod("launchedSession", launch)'));
      expect(
        activity,
        contains('EXTRA_LAUNCH_PROFILE = "oc.shortcut.profile"'),
      );
      expect(
        activity,
        contains('EXTRA_LAUNCH_SESSION = "oc.shortcut.session"'),
      );
    });

    test('a tap carries the two IDs only and both extras are consumed', () {
      final capture = activity.indexOf('private fun captureSessionLaunch');
      expect(capture, greaterThanOrEqualTo(0));
      final body = activity.substring(capture);
      final removeSession = body.indexOf('removeExtra(EXTRA_LAUNCH_SESSION)');
      final removeProfile = body.indexOf('removeExtra(EXTRA_LAUNCH_PROFILE)');
      final park = body.indexOf('pendingSessionLaunch = mapOf(');
      expect(removeSession, greaterThanOrEqualTo(0));
      expect(removeProfile, greaterThanOrEqualTo(0));
      expect(park, greaterThan(removeSession));
      expect(park, greaterThan(removeProfile));
      expect(
        body.substring(park, body.indexOf('return true', park)),
        allOf(
          contains('"profileID" to profileID'),
          contains('"sessionID" to sessionID'),
        ),
      );
    });

    test('consumeSessionLaunch drains once', () {
      final consume = activity.indexOf('"consumeSessionLaunch"');
      expect(consume, greaterThanOrEqualTo(0));
      final drain = activity.indexOf('pendingSessionLaunch = null', consume);
      final reply = activity.indexOf('result.success(launch)', consume);
      expect(drain, greaterThan(consume));
      expect(reply, greaterThan(drain));
    });

    test('a live tap is pushed only once Dart is listening', () {
      final newIntent = activity.indexOf('override fun onNewIntent');
      final body = activity.substring(newIntent);
      final captured = body.indexOf('if (captureSessionLaunch(intent))');
      final gate = body.indexOf(
        'if (shortcutDartReady && channel != null && launch != null)',
        captured,
      );
      final push = body.indexOf(
        'invokeMethod("launchedSession", launch)',
        gate,
      );
      expect(captured, greaterThanOrEqualTo(0));
      expect(gate, greaterThan(captured));
      expect(push, greaterThan(gate));
    });

    test('the publisher targets MainActivity with the same extras', () {
      expect(shortcuts, contains('ShortcutManagerCompat'));
      expect(shortcuts, contains('Intent(context, MainActivity::class.java)'));
      expect(
        shortcuts,
        contains('putExtra(MainActivity.EXTRA_LAUNCH_PROFILE, profileID)'),
      );
      expect(
        shortcuts,
        contains('putExtra(MainActivity.EXTRA_LAUNCH_SESSION, sessionID)'),
      );
      // Titles only: the builder reads exactly the id and title keys.
      final reads = RegExp(
        r'entry\["([a-zA-Z]+)"\]',
      ).allMatches(shortcuts).map((m) => m.group(1)).toSet();
      expect(reads, {'id', 'title'});
    });

    test('stale entries are disabled before the new set is published', () {
      final disable = shortcuts.indexOf('disableShortcuts(');
      final publish = shortcuts.indexOf('setDynamicShortcuts(');
      expect(disable, greaterThanOrEqualTo(0));
      expect(publish, greaterThan(disable));
      // Pinned copies on the home screen are matched too, so a deleted
      // server's titles do not survive as user-pinned shortcuts.
      expect(shortcuts, contains('FLAG_MATCH_PINNED'));
      expect(strings, contains('name="shortcut_session_unavailable"'));
      expect(arabic, contains('name="shortcut_session_unavailable"'));
      expect(strings, contains('name="shortcut_session_untitled"'));
      expect(arabic, contains('name="shortcut_session_untitled"'));
    });

    test('the shortcut icon exists and the compat library is declared', () {
      expect(
        File('$androidMain/res/drawable/ic_shortcut_session.xml').existsSync(),
        isTrue,
      );
      expect(gradle, contains('androidx.core:core:'));
    });
  });

  group('Quick Settings tile', () {
    test('is registered with the binding permission and QS action', () {
      final service = RegExp(
        r'<service[\s\S]*?AttentionTileService[\s\S]*?</service>',
      ).firstMatch(manifest)?.group(0);
      expect(service, isNotNull);
      expect(
        service,
        contains(
          'android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"',
        ),
      );
      expect(service, contains('android:exported="true"'));
      expect(service, contains('android:label="@string/tile_label"'));
      expect(
        service,
        contains('android:icon="@drawable/ic_launcher_monochrome"'),
      );
      expect(service, contains('android.service.quicksettings.action.QS_TILE'));
    });

    test('reads the key the Dart writer uses, from the Flutter prefs file', () {
      expect(
        tile,
        contains('SNAPSHOT_KEY = "flutter.${AttentionTileSnapshot.prefsKey}"'),
      );
      expect(tile, contains('FLUTTER_PREFS = "FlutterSharedPreferences"'));
      expect(tile, contains('optInt("pendingCount"'));
      expect(tile, contains('optLong("updatedAt"'));
      // Never connects: no network or transport types are referenced.
      expect(tile, isNot(contains('HttpURLConnection')));
      expect(tile, isNot(contains('OkHttp')));
    });

    test('a tap sends the whitelisted Activity action and nothing more', () {
      expect(
        tile,
        contains(
          'LAUNCH_ACTION_ACTIVITY = "${LaunchAction.activity.wireValue}"',
        ),
      );
      expect(
        tile,
        contains(
          'putExtra(MainActivity.EXTRA_LAUNCH_ACTION, LAUNCH_ACTION_ACTIVITY)',
        ),
      );
      expect(tile, isNot(contains('EXTRA_LAUNCH_SESSION')));
      expect(tile, contains('startActivityAndCollapse'));
      expect(tile, contains('unlockAndRun'));
      final whitelist = RegExp(
        r'LAUNCH_ACTIONS\s*=\s*setOf\(([^)]*)\)',
      ).firstMatch(activity)!.group(1)!;
      expect(whitelist, contains('"${LaunchAction.activity.wireValue}"'));
    });

    test('degrades to the bare label and has localized copy', () {
      expect(tile, contains('R.string.tile_label'));
      expect(tile, contains('R.plurals.tile_need_you'));
      expect(tile, contains('R.string.tile_all_clear'));
      for (final resources in [strings, arabic]) {
        expect(resources, contains('name="tile_label"'));
        expect(resources, contains('name="tile_label_with_count"'));
        expect(resources, contains('name="tile_all_clear"'));
        expect(resources, contains('<plurals name="tile_need_you">'));
      }
    });
  });
}
