import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `KOTLINC`, then `kotlinc` on PATH, then SDKMAN's install; null when absent.
String? _kotlinc() {
  final configured = Platform.environment['KOTLINC'];
  if (configured != null && configured.isNotEmpty) return configured;
  for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
    if (dir.isNotEmpty && File('$dir/kotlinc').existsSync()) return 'kotlinc';
  }
  final sdkman =
      '${Platform.environment['HOME']}/.sdkman/candidates/kotlin/current/bin/kotlinc';
  return File(sdkman).existsSync() ? sdkman : null;
}

void main() {
  late Directory temporary;
  late String jar;
  late String jsonJar;
  final compiler = _kotlinc();
  // Without a Kotlin compiler the host harness cannot run; say so instead of
  // failing the whole suite on machines (CI, phone) that only build Dart.
  final skip = compiler == null
      ? 'kotlinc not found (set KOTLINC); native storage harness not run'
      : null;

  setUpAll(() async {
    if (compiler == null) return;
    temporary = await Directory.systemTemp.createTemp('setup-runner-native-');
    jar = '${temporary.path}/setup-test.jar';
    final jsonCache = Directory(
      '${Platform.environment['HOME']}/.gradle/caches/modules-2/files-2.1/org.json/json',
    );
    jsonJar =
        Platform.environment['JSON_JAR'] ??
        jsonCache
            .listSync(recursive: true)
            .whereType<File>()
            .firstWhere((file) => file.path.endsWith('.jar'))
            .path;
    final result = await Process.run(compiler, [
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/SetupRunner.kt',
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/SetupJob.kt',
      if (File(
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/SetupPersistence.kt',
      ).existsSync())
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/SetupPersistence.kt',
      'test/native/setup_runner_harness.kt',
      ...Directory(
        'test/native/setup_runner_stubs',
      ).listSync().whereType<File>().map((file) => file.path),
      '-cp',
      jsonJar,
      '-include-runtime',
      '-d',
      jar,
    ]);
    expect(
      result.exitCode,
      0,
      reason: 'Native storage harness compilation failed: ${result.stderr}',
    );
  });

  tearDownAll(() async {
    if (compiler == null) return;
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  for (final scenario in [
    'ordered-terminal',
    'typed-write-failure',
    'failed-start-status',
  ]) {
    test('native setup persistence: $scenario', skip: skip, () async {
      final result = await Process.run(Platform.environment['JAVA'] ?? 'java', [
        '-cp',
        '$jar:$jsonJar',
        'io.github.eslamasabry.opencode_mobile.Setup_runner_harnessKt',
        scenario,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('PASS $scenario'));
    });
  }
}
