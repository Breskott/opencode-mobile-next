import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release script enforces the fail-closed publish contract', () async {
    final result = await Process.run('bash', [
      'test/release_script_test.sh',
    ], workingDirectory: Directory.current.path);

    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
    expect(result.stdout, contains('PASS: release script safety contract'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('GitHub publication verifies source, quality and signed draft assets', () async {
    final result = await Process.run('bash', [
      'test/github_release_script_test.sh',
    ], workingDirectory: Directory.current.path);

    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
    expect(result.stdout, contains('GitHub publication contract cases'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
