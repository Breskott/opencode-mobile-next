import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late String jar;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp(
      'builtin-storage-native-',
    );
    jar = '${temporary.path}/storage-test.jar';
    final compiler = Platform.environment['KOTLINC'] ?? 'kotlinc';
    final result = await Process.run(compiler, [
      'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BuiltinProjectStorage.kt',
      'test/native/builtin_project_storage_harness.kt',
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
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  for (final scenario in [
    'fresh',
    'migration',
    'empty-destination',
    'retry-after-rename',
    'retain-reinstall-delete',
    'reset-rootfs',
    'collision',
    'symlink-ancestors',
    'symlink-contents',
    'measurement',
    'inspection-failure',
    'deletion-failure',
    'invalid-size',
  ]) {
    test('native project storage: $scenario', () async {
      final result = await Process.run(Platform.environment['JAVA'] ?? 'java', [
        '-jar',
        jar,
        scenario,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('PASS $scenario'));
    });
  }
}
