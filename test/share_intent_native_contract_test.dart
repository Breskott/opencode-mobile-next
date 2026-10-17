import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Activity wires share capture, delivery, and cleanup', () {
    const native =
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile';
    final activity = File('$native/MainActivity.kt').readAsStringSync();
    final launches = File('$native/LaunchActivityBridge.kt').readAsStringSync();
    expect(activity, contains('launches.configure(messenger, intent)'));
    expect(activity, contains('launches.onNewIntent(intent)'));
    expect(activity, contains('launches.reset()'));
    expect(launches, contains('shares.capture(intent)'));
    expect(launches, contains('shares.configure(messenger)'));
    expect(launches, contains('shares.onNewIntent(intent)'));
    expect(launches, contains('shares.reset()'));
  });

  test('native share delivery waits for Dart readiness acknowledgment', () {
    final source = File(
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/'
      'LaunchShareChannel.kt',
    ).readAsStringSync();

    expect(source, contains('private var dartReady = false'));
    expect(source, contains('channel = null'));
    expect(source, contains('dartReady = false'));

    final consume = source.indexOf('"consumeSharedText"');
    final ready = source.indexOf('dartReady = true', consume);
    final consumeClear = source.indexOf('pending = null', consume);
    expect(consume, greaterThanOrEqualTo(0));
    expect(ready, greaterThan(consume));
    expect(consumeClear, greaterThan(ready));

    final newIntent = source.indexOf('fun onNewIntent');
    final dispatch = source.indexOf(
      'if (dartReady && currentChannel != null && text != null)',
      newIntent,
    );
    final invoke = source.indexOf(
      'currentChannel.invokeMethod("shared", text)',
      dispatch,
    );
    expect(newIntent, greaterThanOrEqualTo(0));
    expect(dispatch, greaterThan(newIntent));
    expect(invoke, greaterThan(dispatch));
  });

  test('native share-out opens the chooser without this app as a target', () {
    final source = File(
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/'
      'LaunchShareChannel.kt',
    ).readAsStringSync();
    final method = source.indexOf('"shareText" ->');
    final body = source.indexOf('private fun shareTextOut');
    expect(method, greaterThanOrEqualTo(0));
    expect(body, greaterThanOrEqualTo(0));
    final share = source.substring(body, source.indexOf('\n    }\n', body));
    expect(share, contains('Intent.ACTION_SEND'));
    expect(share, contains('Intent.createChooser'));
    expect(share, contains('Intent.EXTRA_EXCLUDE_COMPONENTS'));
  });
}
