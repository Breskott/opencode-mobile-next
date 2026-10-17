import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/setup_scripts.dart';

void main() {
  late Directory temporary;
  late Map<String, String> environment;
  setUp(() {
    temporary = Directory.systemTemp.createTempSync('oc-apt-repair-');
    final bin = Directory('${temporary.path}/bin')..createSync();
    final lists = Directory('${temporary.path}/lists')..createSync();
    File('${lists.path}/test_Packages').writeAsStringSync('');
    File('${temporary.path}/stamp').writeAsStringSync('');
    File('${bin.path}/dpkg').writeAsStringSync(r'''#!/bin/sh
printf 'dpkg %s\n' "$*" >> "$TEST_LOG"
case "$1" in
  --configure)
    [ "$TEST_MODE" != repair ] || [ -f "$TEST_LOG.repaired" ] || exit 1
    [ "$TEST_MODE" != broken ] || exit 1 ;;
  --audit)
    if [ "$TEST_MODE" = broken ] || [ "$TEST_MODE" = audit ]; then
      echo 'The following packages are only half configured: test-package'
    fi
    case "$TEST_MODE" in
      reinstall*)
        if [ ! -f "$TEST_LOG.reinstalled" ] || [ "$TEST_MODE" = reinstall-still-broken ]; then
          echo 'The following packages are in a mess due to serious problems during installation.'
          echo 'They must be reinstalled for them (and any packages that depend on them) to function properly:'
          echo ' libonig5:amd64        regular expressions library'
          echo 'The following packages are missing the list control file in the database:'
          echo ' libonig5:amd64        regular expressions library'
          echo 'The following packages are missing the md5sums control file in the database:'
          echo ' libonig5:amd64        regular expressions library'
        fi ;;
    esac ;;
  -s)
    [ "$TEST_MODE" != missing ] || exit 1
    if [ "$TEST_MODE" = half ]; then
      echo 'Status: install ok half-configured'
    else
      echo 'Status: install ok installed'
    fi ;;
esac
''');
    File('${bin.path}/dpkg-query').writeAsStringSync(r'''#!/bin/sh
printf 'dpkg-query %s\n' "$*" >> "$TEST_LOG"
case "$TEST_MODE" in
  reinstall-query-failed) exit 2 ;;
  reinstall-invalid-name)
    printf '%s\t%s\t%s\n' '--allow-remove-essential' 'install reinstreq half-installed' '6.9.9-1build1' ;;
  reinstall-invalid-version)
    printf '%s\t%s\t%s\n' 'libonig5:amd64' 'install reinstreq half-installed' '6.9.9;echo PRIVATE' ;;
  reinstall*)
    printf '%s\t%s\t%s\n' 'libonig5:amd64' 'install reinstreq half-installed' '6.9.9-1build1'
    printf '%s\t%s\t%s\n' 'healthy:amd64' 'install ok installed' '1.0' ;;
esac
''');
    File('${bin.path}/apt-get').writeAsStringSync(r'''#!/bin/sh
printf 'apt %s\n' "$*" >> "$TEST_LOG"
case " $* " in
  *" --reinstall "*)
    [ "$TEST_MODE" != reinstall-failed ] || exit 100
    touch "$TEST_LOG.reinstalled" ;;
  *" -f "*)
    [ "$TEST_MODE" != broken ] || exit 100
    touch "$TEST_LOG.repaired" ;;
esac
''');
    Process.runSync('chmod', [
      '755',
      '${bin.path}/dpkg',
      '${bin.path}/dpkg-query',
      '${bin.path}/apt-get',
    ]);
    environment = {
      'PATH': '${bin.path}:/usr/bin:/bin',
      'OC_APT_STAMP': '${temporary.path}/stamp',
      'OC_APT_LISTS': lists.path,
      'TEST_LOG': '${temporary.path}/calls',
    };
  });
  tearDown(() => temporary.deleteSync(recursive: true));

  Future<ProcessResult> install(String mode, String shell) => Process.run(
    shell,
    [
      '-c',
      'set -eu\n${withSetupPrelude("oc_apt_install test-package\necho FINISHED")}',
    ],
    environment: {...environment, 'TEST_MODE': mode},
  );

  for (final shell in ['dash', 'bash']) {
    test(
      '$shell reinstalls an interrupted unpack before Python installation',
      () async {
        final result = await install('reinstall', shell);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final calls = File(environment['TEST_LOG']!).readAsLinesSync();
        final repair = calls.indexWhere(
          (line) => line.contains(' --reinstall '),
        );
        expect(repair, greaterThan(0));
        expect(
          calls[repair],
          'apt -o APT::Status-Fd=3 --reinstall --no-remove install -y '
          '--no-install-recommends -o Acquire::Retries=5 '
          'libonig5:amd64=6.9.9-1build1',
        );
        expect(calls[repair + 1], 'dpkg --configure -a');
        expect(calls[repair + 2], 'dpkg --audit');
        expect(calls.last, 'dpkg -s test-package');
        expect(result.stdout, contains('missing the list control file'));
        expect(result.stdout, contains('missing the md5sums control file'));
        expect(result.stdout, contains('FINISHED'));
      },
    );

    for (final mode in ['reinstall-failed', 'reinstall-still-broken']) {
      test('$shell refuses installation after an unsuccessful $mode', () async {
        final result = await install(mode, shell);
        expect(result.exitCode, isNot(0));
        expect(result.stdout, contains('dpkg --audit'));
        expect(result.stdout, contains('libonig5:amd64'));
        expect(result.stdout, isNot(contains('FINISHED')));
        final calls = File(environment['TEST_LOG']!).readAsStringSync();
        expect(calls, contains(' --reinstall --no-remove '));
        expect(calls, isNot(contains('dpkg -s test-package')));
      });
    }

    for (final mode in [
      'reinstall-query-failed',
      'reinstall-invalid-name',
      'reinstall-invalid-version',
    ]) {
      test('$shell refuses untrusted repair targets: $mode', () async {
        final result = await install(mode, shell);
        expect(result.exitCode, isNot(0));
        expect(
          result.stdout,
          contains('damaged packages could not be checked'),
        );
        expect(result.stdout, isNot(contains('FINISHED')));
        expect(
          File(environment['TEST_LOG']!).readAsStringSync(),
          isNot(contains('apt ')),
        );
      });
    }

    test('$shell repairs dependency interruption before installing', () async {
      final result = await install('repair', shell);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final calls = File(environment['TEST_LOG']!).readAsLinesSync();
      final repair = calls.indexWhere(
        (line) => line.startsWith('apt ') && line.contains(' -f '),
      );
      expect(repair, greaterThan(0));
      expect(calls[repair + 1], 'dpkg --configure -a');
      expect(calls.last, 'dpkg -s test-package');
      expect(result.stdout, contains('FINISHED'));
    });

    test('$shell refuses failed repair and gives dpkg audit details', () async {
      final result = await install('broken', shell);
      expect(result.exitCode, isNot(0));
      expect('${result.stdout}\n${result.stderr}', contains('dpkg --audit'));
      expect(
        '${result.stdout}\n${result.stderr}',
        contains('half configured: test-package'),
      );
      expect(result.stdout, isNot(contains('FINISHED')));
    });

    test('$shell catches audit findings even when audit exits zero', () async {
      final result = await install('audit', shell);
      expect(result.exitCode, isNot(0));
      expect('${result.stdout}\n${result.stderr}', contains('dpkg --audit'));
      final calls = File(environment['TEST_LOG']!).readAsStringSync();
      expect(calls, isNot(contains('apt ')));
    });

    for (final mode in ['missing', 'half']) {
      test(
        '$shell verifies dpkg status after apt claims success: $mode',
        () async {
          final result = await install(mode, shell);
          expect(result.exitCode, isNot(0));
          expect(result.stdout, isNot(contains('FINISHED')));
          expect(
            File(environment['TEST_LOG']!).readAsStringSync(),
            contains('dpkg -s test-package'),
          );
        },
      );
    }
  }
}
