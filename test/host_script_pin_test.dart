// The host scripts the app tells people to download are pinned to one
// published commit and checked against a SHA-256 before they run
// (slice-close-security). These tests keep that pin honest: a script edit
// without a new pin and checksum fails here, and so does a guide or a
// screen that tells anyone to pipe a download straight into a shell.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/setup_commands.dart';

const _scripts = {'ubuntu': HostScripts.ubuntu, 'front': HostScripts.front};

/// `curl … | bash`, `wget … | sh` and friends: a download run unchecked.
final _pipedToShell = RegExp(
  r'(curl|wget)\b[^\n|]*\|\s*(sudo\s+)?(ba|z|da)?sh\b',
);

void main() {
  test('the pin is a full commit hash, never a branch or a tag', () {
    expect(HostScripts.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
    for (final script in _scripts.values) {
      expect(script.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        script.url,
        'https://raw.githubusercontent.com/${HostScripts.repository}/'
        '${HostScripts.commit}/${script.path}',
      );
      expect(script.url, isNot(contains('/master/')));
      expect(script.url, isNot(contains('/main/')));
    }
  });

  for (final MapEntry(key: name, value: script) in _scripts.entries) {
    test('$name: the checksum matches the file in this checkout', () {
      final bytes = File(script.path).readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        script.sha256,
        reason:
            '${script.path} changed. Publish a commit that holds it, then '
            'move HostScripts.commit and its sha256 in '
            'lib/ui/setup_commands.dart together.',
      );
    });

    test('$name: the pinned commit holds exactly those bytes', () {
      final result = Process.runSync('git', [
        'cat-file',
        'blob',
        '${HostScripts.commit}:${script.path}',
      ], stdoutEncoding: null);
      if (result.exitCode != 0) {
        markTestSkipped(
          'git has no ${HostScripts.commit} here (shallow clone?): '
          '${result.stderr}',
        );
        return;
      }
      expect(
        sha256.convert(result.stdout as List<int>).toString(),
        script.sha256,
      );
    });

    test('$name: the command checks the download before it is named', () {
      final lines = script.verifiedDownload.split('\n');
      expect(lines.first, startsWith('curl -fsSLo ${script.saveAs}.part'));
      expect(script.verifiedDownload, contains(script.url));
      expect(
        script.verifiedDownload,
        contains(
          "echo '${script.sha256}  ${script.saveAs}.part' | sha256sum -c - &&",
        ),
      );
      expect(lines.last, 'mv ${script.saveAs}.part ${script.saveAs}');
      expect(_pipedToShell.hasMatch(script.verifiedDownload), isFalse);
    });
  }

  test('the install command checks, then installs on the given port', () {
    final command = HostScripts.install(4747);
    expect(command, startsWith(HostScripts.ubuntu.verifiedDownload));
    expect(
      command,
      endsWith('&&\nOPENCODE_PORT=4747 bash ubuntu-opencode.sh install'),
    );
    // Every line but the last ends the chain with && (or continues with \),
    // so a pasted block stops at the first failure.
    final lines = command.split('\n');
    for (final line in lines.take(lines.length - 1)) {
      expect(line, anyOf(endsWith('&&'), endsWith(r'\')), reason: line);
    }
  });

  test('the front command checks, then runs the checked copy', () {
    final command = HostScripts.teamFront;
    expect(command, startsWith(HostScripts.front.verifiedDownload));
    expect(command, contains('python3 opencode-mobile-front.py '));
    expect(command, isNot(contains('python3 tool/')));
  });

  test('the guides show the same pinned, checked commands', () {
    final ubuntu = File('docs/ubuntu-host.md').readAsStringSync();
    expect(ubuntu, contains(HostScripts.ubuntu.verifiedDownload));
    final team = File('docs/ai-team-host.md').readAsStringSync();
    expect(team, contains(HostScripts.front.verifiedDownload));
    for (final guide in [ubuntu, team]) {
      expect(guide, isNot(contains('/master/scripts/')));
      expect(guide, isNot(contains('/master/tool/')));
    }
  });

  test('nothing in the app tells anyone to pipe a download into a shell', () {
    final offenders = <String>[];
    final files = [
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('app_localizations')),
      File('lib/l10n/app_en.arb'),
    ];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (_pipedToShell.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
