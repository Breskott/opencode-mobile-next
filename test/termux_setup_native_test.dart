import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'native/kotlin_jar_cache.dart';

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
  const scenarios = [
    'progress-and-finish',
    'cancel-and-resume',
    'interrupted-launch',
  ];
  // The scenarios share nothing: the JVMs run side by side.
  final runs = <String, Future<ProcessResult>>{};

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('termux-setup-native-');
    if (compiler == null) return;
    jar = await cachedKotlinJar(
      compiler: compiler,
      sources: [
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/TermuxSetupShell.kt',
        'test/native/termux_setup_harness.kt',
      ],
    );
    for (final scenario in scenarios) {
      runs[scenario] = Process.run('java', ['-jar', jar, scenario]);
    }
  });
  tearDownAll(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  for (final scenario in scenarios) {
    test(
      'Termux durable shell: $scenario',
      skip: compiler == null
          ? 'kotlinc unavailable; native shell lifecycle harness not run'
          : null,
      () async {
        final result = await runs[scenario]!;
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
