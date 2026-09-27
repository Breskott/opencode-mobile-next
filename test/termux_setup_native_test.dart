import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final configured = Platform.environment['KOTLINC'];
  final sdkman =
      '${Platform.environment['HOME']}/.sdkman/candidates/kotlin/current/bin/kotlinc';
  final onPath = (Platform.environment['PATH'] ?? '')
      .split(':')
      .any(
        (directory) =>
            directory.isNotEmpty && File('$directory/kotlinc').existsSync(),
      );
  final compiler =
      configured ??
      (File(sdkman).existsSync() ? sdkman : (onPath ? 'kotlinc' : null));
  late Directory temporary;
  late String jar;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('termux-setup-native-');
    if (compiler == null) return;
    jar = '${temporary.path}/lifecycle.jar';
    final compiled = await Process.run(compiler, [
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/TermuxSetupShell.kt',
      'test/native/termux_setup_harness.kt',
      '-include-runtime',
      '-d',
      jar,
    ]);
    expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
  });
  tearDownAll(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  for (final scenario in [
    'progress-and-finish',
    'cancel-and-resume',
    'interrupted-launch',
  ]) {
    test(
      'Termux durable shell: $scenario',
      skip: compiler == null
          ? 'kotlinc unavailable; native shell lifecycle harness not run'
          : null,
      () async {
        final result = await Process.run('java', ['-jar', jar, scenario]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout, contains('PASS $scenario'));
      },
    );
  }
}
