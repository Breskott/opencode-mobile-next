import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The two contracts share nothing (each builds its own fixture tree), so
  // they run side by side; each test reports its own script's outcome.
  late final Future<ProcessResult> releaseScript;
  late final Future<ProcessResult> publication;

  setUpAll(() {
    final cwd = Directory.current.path;
    releaseScript = Process.run('bash', [
      'test/release_script_test.sh',
    ], workingDirectory: cwd);
    publication = Process.run('bash', [
      'test/github_release_script_test.sh',
    ], workingDirectory: cwd);
  });

  test(
    'release script enforces the fail-closed publish contract',
    () async {
      final result = await releaseScript;

      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      expect(result.stdout, contains('PASS: release script safety contract'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'GitHub publication verifies source, quality and signed draft assets',
    () async {
      final result = await publication;

      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      expect(result.stdout, contains('GitHub publication contract cases'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
