import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android executes the same ASCII byte ceiling before Dart delivery',
    () async {
      final configured = Platform.environment['KOTLINC'];
      final sdkman =
          '${Platform.environment['HOME']}/.sdkman/candidates/kotlin/current/bin/kotlinc';
      final compiler =
          configured ?? (File(sdkman).existsSync() ? sdkman : 'kotlinc');
      final directory = await Directory.systemTemp.createTemp(
        'session-link-native-',
      );
      try {
        final jar = '${directory.path}/ingress.jar';
        final compiled = await Process.run(compiler, [
          'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/SessionLinkIngress.kt',
          'test/native/session_link_ingress_harness.kt',
          '-include-runtime',
          '-d',
          jar,
        ]);
        expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
        final run = await Process.run('java', ['-jar', jar]);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout, contains('PASS bounded ASCII native ingress'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'native consumes invalid intents before bounded capture without logging',
    () {
      final activity = File(
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt',
      ).readAsStringSync();
      final start = activity.indexOf('private fun captureSessionLink');
      final end = activity.indexOf('private fun captureLaunchAction', start);
      final body = activity.substring(start, end);
      expect(
        body.indexOf('intent.data = null'),
        lessThan(body.indexOf('SessionLinkIngress.accepts(text)')),
      );
      expect(
        body.indexOf('SessionLinkIngress.accepts(text)'),
        lessThan(body.indexOf('pendingSessionLink = text')),
      );
      expect(body, isNot(contains('Log.')));
    },
  );
}
