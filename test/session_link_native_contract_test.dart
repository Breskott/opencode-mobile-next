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
  final activity = File(
    '$androidMain/kotlin/io/github/eslamasabry/opencode_mobile/'
    'MainActivity.kt',
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

  test('the native scheme and host match the Dart link shape', () {
    expect(activity, contains('LINK_SCHEME = "${SessionLink.scheme}"'));
    expect(activity, contains('LINK_HOST = "${SessionLink.host}"'));
    expect(activity, contains('TEAM_LINK_HOST = "${TeamLink.host}"'));
    expect(activity, contains('LINK_CHANNEL_NAME = "oc/link"'));
    expect(activity, contains('"consumeSessionLink"'));
    expect(activity, contains('invokeMethod("linked", link)'));
  });

  test('the intent is consumed before the link is parked', () {
    final capture = activity.indexOf('private fun captureSessionLink');
    expect(capture, greaterThanOrEqualTo(0));
    final body = activity.substring(capture);
    final schemeCheck = body.indexOf('LINK_SCHEME, ignoreCase = true');
    final hostCheck = body.indexOf('LINK_HOST, ignoreCase = true');
    final teamHostCheck = body.indexOf('TEAM_LINK_HOST, ignoreCase = true');
    final clearAction = body.indexOf('intent.action = Intent.ACTION_MAIN');
    final clearData = body.indexOf('intent.data = null');
    final park = body.indexOf('pendingSessionLink = text');
    expect(schemeCheck, greaterThanOrEqualTo(0));
    expect(hostCheck, greaterThan(schemeCheck));
    expect(teamHostCheck, greaterThan(hostCheck));
    expect(clearAction, greaterThan(teamHostCheck));
    expect(clearData, greaterThan(clearAction));
    expect(park, greaterThan(clearData));
    // Only ACTION_VIEW is captured; a share or launcher intent is untouched.
    expect(body, contains('intent.action != Intent.ACTION_VIEW) return false'));
  });

  test('consumeSessionLink acknowledges readiness and drains once', () {
    final consume = activity.indexOf('"consumeSessionLink"');
    expect(consume, greaterThanOrEqualTo(0));
    final ready = activity.indexOf('linkDartReady = true', consume);
    final drain = activity.indexOf('pendingSessionLink = null', consume);
    expect(ready, greaterThan(consume));
    expect(drain, greaterThan(ready));
    // A live link is pushed only once Dart acknowledged readiness.
    final newIntent = activity.indexOf('override fun onNewIntent');
    final gate = activity.indexOf(
      'linkDartReady && channel != null && link != null',
      newIntent,
    );
    expect(gate, greaterThan(newIntent));
  });

  test('the bridge never forwards anything but the URI text', () {
    final capture = activity.indexOf('private fun captureSessionLink');
    final end = activity.indexOf(
      RegExp(r'\n    (private |override )?fun '),
      capture + 1,
    );
    final body = activity.substring(capture, end < 0 ? null : end);
    expect(body, contains('val text = data.toString()'));
    expect(body, isNot(contains('getStringExtra')));
    expect(body, isNot(contains('extras')));
  });
}
