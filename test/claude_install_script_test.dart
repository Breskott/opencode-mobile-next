import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/claude_scripts.dart';
import 'package:opencode_mobile/builtin/setup/setup_scripts.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('claude-install-'));
  tearDown(() => temp.deleteSync(recursive: true));

  String isolatedScript() => ClaudeScripts.install
      .replaceAll('/opt/oc-claude', '${temp.path}/install')
      .replaceAll('/usr/local/bin', '${temp.path}/bin');

  test('both ABIs request the exact pinned glibc payload', () async {
    for (final entry in {
      'aarch64': ('arm64', ClaudeScripts.arm64Sha256),
      'x86_64': ('x64', ClaudeScripts.x64Sha256),
    }.entries) {
      final result = await Process.run('/bin/sh', [
        '-c',
        '''
uname() { echo ${entry.key}; }
getconf() { echo 'glibc 2.39'; }
oc_stage() { :; }
oc_download() { printf '%s\\n' "\$1" "\$3"; return 23; }
${isolatedScript()}
''',
      ]);
      expect(result.exitCode, 23);
      expect(
        result.stdout,
        contains('/2.1.283/linux-${entry.value.$1}/claude'),
      );
      expect(result.stdout, contains(entry.value.$2));
      expect(File('${temp.path}/bin/claude').existsSync(), isFalse);
    }
  });

  test(
    'bad checksum never executes payload or replaces previous install',
    () async {
      final previous = File('${temp.path}/install/claude');
      previous.parent.createSync();
      previous.writeAsStringSync('previous');
      final result = await Process.run('/bin/sh', [
        '-c',
        '''
$setupPrelude
uname() { echo aarch64; }
getconf() { echo 'glibc 2.39'; }
# Exercise real oc_download checksum handling without any network request.
curl() {
  case "\$1" in
    -fsSIL) printf 'Content-Length: 1\\n' ;;
    *) printf '#!/bin/sh\\ntouch ${temp.path}/executed\\n' > "\$oc_file" ;;
  esac
}
${isolatedScript()}
''',
      ]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('did not match its checksum'));
      expect(File('${temp.path}/executed').existsSync(), isFalse);
      expect(previous.readAsStringSync(), 'previous');
      expect(File('${temp.path}/install/claude.new').existsSync(), isFalse);
    },
  );

  test('unsupported architecture fails before downloading', () async {
    final result = await Process.run('/bin/sh', [
      '-c',
      'uname() { echo riscv64; }; ${isolatedScript()}',
    ]);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('requires ARM64 or x64 Ubuntu'));
    expect(Directory('${temp.path}/install').existsSync(), isFalse);
  });
}
