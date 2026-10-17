import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/domain/team_link.dart';

/// The Android side of the session handoff link (F4-S2) cannot run under
/// `flutter test`, so the contract Dart relies on is pinned here from the
/// sources: the VIEW intent filter, the scheme and host, the channel and
/// method names, the single consumption of the intent data, and the
/// readiness gate that decides between a live push and a parked value.
void main() {
  const androidMain = 'android/app/src/main';
  final links = File(
    '$androidMain/kotlin/io/github/eslamasabry/opencode_mobile/'
    'LaunchLinkChannel.kt',
  ).readAsStringSync();
  final activity = File(
    '$androidMain/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt',
  ).readAsStringSync();
  final launches = File(
    '$androidMain/kotlin/io/github/eslamasabry/opencode_mobile/LaunchActivityBridge.kt',
  ).readAsStringSync();
  final manifest = File('$androidMain/AndroidManifest.xml').readAsStringSync();

  test('the manifest declares exactly one VIEW filter for the link', () {
    final filters = RegExp(
      r'<intent-filter>[\s\S]*?</intent-filter>',
    ).allMatches(manifest).map((m) => m.group(0)!).toList();
    final view = filters
        .where((f) => f.contains('android.intent.action.VIEW'))
        .toList();
    expect(view, hasLength(1));
    expect(view.single, contains('android.intent.category.DEFAULT'));
    expect(view.single, contains('android.intent.category.BROWSABLE'));
    expect(
      view.single,
      contains(
        '<data android:scheme="${SessionLink.scheme}" '
        'android:host="${SessionLink.host}" />',
      ),
    );
    // The AI Team link (TEAM-203) rides the same filter under its own host.
    expect(
      view.single,
      contains(
        '<data android:scheme="${TeamLink.scheme}" '
        'android:host="${TeamLink.host}" />',
      ),
    );
    // Route identifiers only: no path prefix or mime type widens the filter.
    expect(view.single, isNot(contains('android:pathPrefix')));
    expect(view.single, isNot(contains('android:mimeType')));
  });

  test('the Activity wires link capture, delivery, and cleanup', () {
    expect(activity, contains('launches.configure(messenger, intent)'));
    expect(activity, contains('launches.onNewIntent(intent)'));
    expect(activity, contains('launches.reset()'));
    expect(launches, contains('links.capture(intent)'));
    expect(launches, contains('links.configure(messenger)'));
    expect(launches, contains('links.onNewIntent(intent)'));
    expect(launches, contains('links.reset()'));
  });

  test('the native scheme and host match the Dart link shape', () {
    expect(
      links,
      contains(
        'data.scheme.equals("${SessionLink.scheme}", ignoreCase = true)',
      ),
    );
    expect(
      links,
      contains('data.host.equals("${SessionLink.host}", ignoreCase = true)'),
    );
    expect(
      links,
      contains('data.host.equals("${TeamLink.host}", ignoreCase = true)'),
    );
    expect(links, contains('MethodChannel(messenger, "oc/link")'));
    expect(links, contains('"consumeSessionLink"'));
    expect(links, contains('invokeMethod("linked", link)'));
  });

  test('the intent is consumed before the link is parked', () {
    final capture = links.indexOf('fun capture(intent: Intent?)');
    expect(capture, greaterThanOrEqualTo(0));
    final body = links.substring(capture);
    final routeCheck = body.indexOf('!isHandoffRoute(data)');
    final clearAction = body.indexOf('intent.action = Intent.ACTION_MAIN');
    final clearData = body.indexOf('intent.data = null');
    final park = body.indexOf('if (accepted) pending = text');
    expect(routeCheck, greaterThanOrEqualTo(0));
    expect(clearAction, greaterThan(routeCheck));
    expect(clearData, greaterThan(clearAction));
    expect(park, greaterThan(clearData));
    // Only ACTION_VIEW is captured; a share or launcher intent is untouched.
    expect(
      body,
      contains(
        'intent?.action != Intent.ACTION_VIEW || data == null || !isHandoffRoute(data)) return false',
      ),
    );
  });

  test('consumeSessionLink acknowledges readiness and drains once', () {
    final consume = links.indexOf('"consumeSessionLink"');
    expect(consume, greaterThanOrEqualTo(0));
    final ready = links.indexOf('dartReady = true', consume);
    final drain = links.indexOf('pending = null', consume);
    expect(ready, greaterThan(consume));
    expect(drain, greaterThan(ready));
    // A live link is pushed only once Dart acknowledged readiness.
    final newIntent = links.indexOf('fun onNewIntent');
    final gate = links.indexOf(
      'dartReady && currentChannel != null && link != null',
      newIntent,
    );
    expect(gate, greaterThan(newIntent));
  });

  test('the bridge never forwards anything but the URI text', () {
    final capture = links.indexOf('fun capture(intent: Intent?)');
    final end = links.indexOf(
      RegExp(r'\n    (private |override )?fun '),
      capture + 1,
    );
    final body = links.substring(capture, end < 0 ? null : end);
    expect(body, contains('val text = data.toString()'));
    expect(body, isNot(contains('getStringExtra')));
    expect(body, isNot(contains('extras')));
  });
}
