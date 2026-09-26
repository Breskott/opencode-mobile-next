import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// G13 (STANDARDS.md §18, STATE-12) lives in `tool/ux/check_kit_map.py`, a
/// docs-data check with no Flutter dependency. This twin runs it inside
/// `flutter test`, so the full suite blocks a kit map that drifts: a
/// `replaces` entry the map lacks, a new hand-built element, a hidden or dead
/// row for a capability that has an enable flow, or a baseline that grew.
void main() {
  ProcessResult python(List<String> args) =>
      Process.runSync('python3', ['tool/ux/check_kit_map.py', ...args]);

  String output(ProcessResult result) => '${result.stdout}${result.stderr}';

  test('the kit map gate passes on the committed map', () {
    // Compare the baseline with the merge base when the integration branch
    // is known locally, so a baseline raised by hand in a branch fails too.
    final base = Platform.environment['G13_BASE'] ?? 'feat/phone-setup-v2';
    final known = Process.runSync('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      '$base^{commit}',
    ]);
    final result = python([
      if (known.exitCode == 0) ...['--base', base],
    ]);
    expect(result.exitCode, 0, reason: output(result));
    expect(output(result), contains('G13 PASSED'));
  });

  test('the kit map gate self-test passes', () {
    final result = python(['--self-test']);
    expect(result.exitCode, 0, reason: output(result));
    expect(output(result), isNot(contains('not ok')));
  });
}
