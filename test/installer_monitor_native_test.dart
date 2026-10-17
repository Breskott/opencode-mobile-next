import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

String _member(String source, String signature) {
  final begin = source.indexOf('    $signature');
  expect(begin, greaterThanOrEqualTo(0), reason: signature);
  final next = RegExp(
    r'\n    (?:(?:private|internal|public) )?(?:fun |val |var |/\*\*|@)',
  ).firstMatch(source.substring(begin + signature.length + 4));
  expect(next, isNotNull, reason: 'next member after $signature');
  return source.substring(begin, begin + signature.length + 4 + next!.start);
}

void main() {
  final compiler = _kotlinc();
  final skip = compiler == null
      ? 'kotlinc not found (set KOTLINC); monitor fixture not run'
      : null;
  Directory? temporary;
  late String jar;

  setUpAll(() async {
    if (compiler == null) return;
    temporary = await Directory.systemTemp.createTemp('oc-installer-monitor-');
    jar = '${temporary!.path}/monitor.jar';
    const source =
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BuiltinLinux.kt';
    final reference = Platform.environment['OC_INSTALLER_SOURCE_REF'];
    final String linux;
    if (reference != null && reference.isNotEmpty) {
      final historical = await Process.run('git', [
        'show',
        '$reference:$source',
      ]);
      expect(historical.exitCode, 0, reason: '${historical.stderr}');
      linux = historical.stdout as String;
    } else {
      linux = await File(source).readAsString();
    }
    final template = await File(
      'test/native/installer_monitor_harness.kt',
    ).readAsString();
    final fixture = File('${temporary!.path}/ProductionMonitor.kt');
    await fixture.writeAsString(
      template
          .replaceFirst(
            '/* PRODUCTION_MONITOR */',
            _member(linux, 'private fun monitorInstallerOwnership('),
          )
          .replaceFirst(
            '/* PRODUCTION_FINISH */',
            _member(linux, 'internal fun finishInstaller('),
          ),
    );
    final compiled = await Process.run(
      compiler,
      [fixture.path, '-include-runtime', '-d', jar],
      environment: {'JAVA_OPTS': '-Xms32m -Xmx256m'},
    );
    expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
  });

  tearDownAll(() async {
    await temporary?.delete(recursive: true);
  });

  for (final scenario in [
    'monitor-failure-zero-exit',
    'retry-same-runtime',
    'stale-monitor-new-launch',
  ]) {
    test('native installer monitor: $scenario', skip: skip, () async {
      final result = await Process.run(Platform.environment['JAVA'] ?? 'java', [
        '-Xms16m',
        '-Xmx64m',
        '-jar',
        jar,
        scenario,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, 'PASS $scenario\n');
    });
  }
}
