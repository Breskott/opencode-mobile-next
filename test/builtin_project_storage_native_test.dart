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
  final compiler = _kotlinc();
  // Without a Kotlin compiler the host harness cannot run; say so instead of
  // failing the whole suite on machines (CI, phone) that only build Dart.
  final skip = compiler == null
      ? 'kotlinc not found (set KOTLINC); native storage harness not run'
      : null;

  setUpAll(() async {
    if (compiler == null) return;
    temporary = await Directory.systemTemp.createTemp(
      'builtin-storage-native-',
    );
    jar = '${temporary.path}/storage-test.jar';
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
    if (compiler == null) return;
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
    'read-only-directories',
    'invalid-size',
  ]) {
    test('native project storage: $scenario', skip: skip, () async {
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
