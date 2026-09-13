import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/termux/bridge.dart';

String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

const _mocks = r'''
claim_direct_lock() { return 0; }
process_group() { printf '%s' "$$"; }
process_start() { printf 123; }
ubuntu_usable() { return 0; }
require_setup_space() { return 0; }
termux-wake-lock() { :; }
termux-wake-unlock() { :; }
release_setup_lock() { :; }
runtime_version() { cat "$OC_DIR/binary-$(managed_runtime)" 2>/dev/null; }
install_runtime() {
  printf '%s\n' "$(managed_runtime)" >> "$OC_DIR/installed"
  [ "${FAIL_INSTALL:-0}" != 1 ] || fail_setup 'Test install failed'
  printf '%s' "$1" > "$OC_DIR/binary-$(managed_runtime)"
}
stop_server() {
  [ "${REFUSE_STOP:-0}" != 1 ] || return 75
  printf stopped >> "$OC_DIR/stops"
}
start_server() {
  [ "${FAIL_START:-0}" != 1 ] || fail_setup 'Test authentication failed'
  write_state ready 'Authenticated fixture ready' "$CURRENT_PORT" proot "$1" '' completed
  SETUP_SUCCEEDED=1
}
''';

Future<ProcessResult> _run(Directory home, String body) async {
  final manager = TermuxBridge.managerScriptForTesting();
  // The switch owns an asynchronous logger subprocess. Run that real logger
  // against this synthetic home, while server/install operations stay mocked.
  final logger = File('${home.path}/.oc/manager.sh')
    ..writeAsStringSync(
      manager.replaceFirst(
        '#!/data/data/com.termux/files/usr/bin/bash',
        '#!/usr/bin/env bash',
      ),
    );
  final executable = await Process.run('chmod', ['700', logger.path]);
  expect(executable.exitCode, 0);
  final functions = manager.substring(
    0,
    manager.indexOf('\ncase "\${1:-status}" in'),
  );
  final probe = File('${home.path}/probe.sh')
    ..writeAsStringSync('$functions\n$_mocks\n$body\n');
  return Process.run(
    'bash',
    [probe.path],
    environment: {...Platform.environment, 'HOME': home.path},
  );
}

Directory _home({bool legacyTwo = false}) {
  final home = Directory.systemTemp.createTempSync('oc-switch-test-');
  addTearDown(() => home.deleteSync(recursive: true));
  final oc = Directory('${home.path}/.oc')..createSync();
  File(
    '${oc.path}/runtime',
  ).writeAsStringSync(legacyTwo ? 'opencode2' : 'opencode1');
  File(
    '${oc.path}/server.password',
  ).writeAsStringSync(legacyTwo ? 'two-fixture' : 'one-fixture');
  File('${oc.path}/binary-opencode1').writeAsStringSync('1.18.29');
  if (legacyTwo) {
    File('${oc.path}/binary-opencode2').writeAsStringSync('0.0.0-beta-18600');
  }
  File(
    '${oc.path}/original-data',
  ).writeAsStringSync('original history fixture');
  return home;
}

String _switch(String target, String password, {String before = ''}) =>
    '''
CURRENT_PORT=57643
CURRENT_OPERATION=fixture
$before
printf '%s' ${_quote(password)} > "\$OC_DIR/switch-password-fixture"
switch_runtime ${_quote(target)}
''';

void main() {
  test(
    'switch dispatch acknowledges while its detached manager is still running',
    () async {
      final home = _home();
      final release = File('${home.path}/.oc/release-dispatch-fixture');
      final finished = File('${home.path}/.oc/dispatch-fixture-finished');
      const heldManager = r'''#!/usr/bin/env bash
case "$1" in
  restart)
    for _ in {1..160}; do
      [ ! -f "$HOME/.oc/release-dispatch-fixture" ] || break
      sleep 0.05
    done
    touch "$HOME/.oc/dispatch-fixture-finished"
    ;;
  write-log) cat >/dev/null ;;
esac
''';
      final source =
          TermuxBridge.restartScript(
                operationID: 'dispatch-fixture',
                switchTarget: TermuxRuntime.openCode2,
                switchPassword: 'fixture-only',
              )
              .replaceFirst(TermuxBridge.managerScriptForTesting(), heldManager)
              .replaceAll(TermuxBridge.termuxHome, home.path);
      final script = File('${home.path}/dispatch.sh')
        ..writeAsStringSync(source);
      final launched = Process.run(
        'bash',
        [script.path],
        environment: {...Platform.environment, 'HOME': home.path},
      );
      try {
        final result = await launched.timeout(const Duration(seconds: 2));
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          TermuxBridge.isLaunchAcknowledged(result.stdout.toString()),
          isTrue,
        );
        expect(
          finished.existsSync(),
          isFalse,
          reason: 'The manager has not been released yet',
        );
      } finally {
        release.writeAsStringSync('release');
        await launched.timeout(const Duration(seconds: 3));
        for (
          var attempt = 0;
          attempt < 100 && !finished.existsSync();
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(
          finished.existsSync(),
          isTrue,
          reason: 'The exact fixture manager must finish before cleanup',
        );
      }
    },
  );

  test(
    'switch rotates prior output under ownership and preserves bounded history on reopen',
    () async {
      final home = _home();
      final oc = '${home.path}/.oc';
      File('$oc/install.log').writeAsStringSync(
        'OLD_INSTALL_HEAD\n${'x' * 1048576}\nOLD_INSTALL_TAIL\n',
      );
      File('$oc/install.log.1').writeAsStringSync('OLDER_HISTORY\n');
      File('$oc/install.log.2').writeAsStringSync('OLDEST_DROPPED\n');
      final result = await _run(
        home,
        '${_switch('opencode2', 'two-fixture', before: r'''
install_runtime() {
  printf '%s\n' 'CURRENT_SWITCH_INSTALL'
  printf '%s' "$1" > "$OC_DIR/binary-$(managed_runtime)"
}
''')}\nprintf \'CURRENT_SWITCH_COMPLETE\\n\'\n',
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final active = File('$oc/install.log').readAsStringSync();
      expect(active, contains('CURRENT_SWITCH_INSTALL'));
      expect(active, contains('CURRENT_SWITCH_COMPLETE'));
      expect(active, isNot(contains('OLD_INSTALL')));
      expect(
        File('$oc/install.log.1').readAsStringSync(),
        endsWith('OLD_INSTALL_TAIL\n'),
      );
      expect(File('$oc/install.log.2').readAsStringSync(), 'OLDER_HISTORY\n');
      final logs = Directory(oc)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('install.log'))
          .toList();
      expect(logs.length, 3);
      final before = {for (final log in logs) log.path: log.readAsBytesSync()};
      for (final log in logs) {
        expect(log.lengthSync(), lessThanOrEqualTo(1048576), reason: log.path);
      }
      expect((await _run(home, 'status')).exitCode, 0);
      for (final entry in before.entries) {
        expect(File(entry.key).readAsBytesSync(), entry.value);
      }
    },
  );

  test(
    'a switch without lock ownership does not rotate another operation output',
    () async {
      final home = _home();
      final active = File('${home.path}/.oc/install.log')
        ..writeAsStringSync('OWNED_BY_OTHER_OPERATION');
      final result = await _run(
        home,
        _switch(
          'opencode2',
          'two-fixture',
          before: 'claim_direct_lock() { return 75; }',
        ),
      );
      expect(result.exitCode, 75);
      expect(active.readAsStringSync(), 'OWNED_BY_OTHER_OPERATION');
      expect(File('${home.path}/.oc/install.log.1').existsSync(), isFalse);
    },
  );

  test(
    'explicit switch installs beta and preserves original binary/data/credential',
    () async {
      final home = _home();
      final result = await _run(home, _switch('opencode2', 'two-fixture'));
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final oc = '${home.path}/.oc';
      expect(File('$oc/runtime').readAsStringSync(), 'opencode2');
      expect(File('$oc/server.password').readAsStringSync(), 'two-fixture');
      expect(File('$oc/password-opencode1').readAsStringSync(), 'one-fixture');
      expect(File('$oc/binary-opencode1').readAsStringSync(), '1.18.29');
      expect(
        File('$oc/original-data').readAsStringSync(),
        'original history fixture',
      );
      expect(File('$oc/opencode2-data-mode').readAsStringSync(), 'isolated');
      expect(File('$oc/runtime-switch').existsSync(), isFalse);
      expect(result.stdout.toString(), isNot(contains('fixture')));
    },
  );

  test(
    'return uses installed OC1 and leaves isolated beta data and credential intact',
    () async {
      final home = _home();
      expect(
        (await _run(home, _switch('opencode2', 'two-fixture'))).exitCode,
        0,
      );
      final oc = '${home.path}/.oc';
      File('$oc/beta-data').writeAsStringSync('beta history fixture');
      final result = await _run(home, _switch('opencode1', 'one-fixture'));
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(File('$oc/runtime').readAsStringSync(), 'opencode1');
      expect(File('$oc/server.password').readAsStringSync(), 'one-fixture');
      expect(File('$oc/password-opencode2').readAsStringSync(), 'two-fixture');
      expect(File('$oc/beta-data').readAsStringSync(), 'beta history fixture');
      expect(File('$oc/installed').readAsLinesSync(), ['opencode2']);
      expect(File('$oc/opencode2-data-mode').readAsStringSync(), 'isolated');
    },
  );

  for (final failure in ['FAIL_INSTALL=1', 'FAIL_START=1', 'REFUSE_STOP=1']) {
    test(
      '$failure leaves durable return and permits explicit old-runtime recovery',
      () async {
        final home = _home();
        final result = await _run(
          home,
          _switch('opencode2', 'two-fixture', before: failure),
        );
        expect(result.exitCode, isNot(0));
        final oc = '${home.path}/.oc';
        final journal = File('$oc/runtime-switch').readAsStringSync();
        expect(journal, contains('switch_previous=opencode1'));
        expect(journal, contains('switch_target=opencode2'));
        expect(
          File('$oc/password-opencode1').readAsStringSync(),
          'one-fixture',
        );
        final restored = await _run(home, _switch('opencode1', 'one-fixture'));
        expect(restored.exitCode, 0, reason: restored.stderr.toString());
        expect(File('$oc/runtime').readAsStringSync(), 'opencode1');
        expect(File('$oc/server.password').readAsStringSync(), 'one-fixture');
        expect(File('$oc/runtime-switch').existsSync(), isFalse);
      },
    );
  }

  test(
    'interruption between password and marker writes never overwrites saved old credential',
    () async {
      final home = _home();
      final oc = '${home.path}/.oc';
      File('$oc/password-opencode1').writeAsStringSync('one-fixture');
      File('$oc/server.password').writeAsStringSync('two-fixture');
      File('$oc/runtime-switch').writeAsStringSync(
        'switch_previous=opencode1\nswitch_target=opencode2\nswitch_phase=stopping\n',
      );
      final result = await _run(home, _switch('opencode1', 'one-fixture'));
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(File('$oc/password-opencode1').readAsStringSync(), 'one-fixture');
      expect(File('$oc/server.password').readAsStringSync(), 'one-fixture');
    },
  );

  test(
    'pre-existing first-run OC2 cannot launch OC1 against its default data',
    () async {
      final home = _home(legacyTwo: true);
      final result = await _run(home, _switch('opencode1', 'one-fixture'));
      expect(result.exitCode, isNot(0));
      final oc = '${home.path}/.oc';
      expect(File('$oc/runtime').readAsStringSync(), 'opencode2');
      expect(File('$oc/server.password').readAsStringSync(), 'two-fixture');
      expect(File('$oc/opencode2-data-mode').existsSync(), isFalse);
      expect(File('$oc/stops').existsSync(), isFalse);
    },
  );

  test(
    'unknown data mode refuses switch before touching the managed server',
    () async {
      final home = _home();
      File(
        '${home.path}/.oc/opencode2-data-mode',
      ).writeAsStringSync('unreadable');
      final result = await _run(home, _switch('opencode2', 'two-fixture'));
      expect(result.exitCode, isNot(0));
      expect(File('${home.path}/.oc/stops').existsSync(), isFalse);
    },
  );

  test(
    'return refuses changed saved credentials before stopping target server',
    () async {
      final home = _home();
      expect(
        (await _run(home, _switch('opencode2', 'two-fixture'))).exitCode,
        0,
      );
      final oc = '${home.path}/.oc';
      final stops = File('$oc/stops').readAsStringSync();
      final result = await _run(home, _switch('opencode1', 'edited-fixture'));
      expect(result.exitCode, isNot(0));
      expect(File('$oc/stops').readAsStringSync(), stops);
      expect(File('$oc/password-opencode1').readAsStringSync(), 'one-fixture');
      expect(File('$oc/server.password').readAsStringSync(), 'two-fixture');
    },
  );

  test('persisted ready commits only the matching switch operation', () async {
    final home = _home();
    final result = await _run(home, r'''
CURRENT_OPERATION=targetOperation
CURRENT_RUNTIME=opencode2
write_switch opencode1 opencode2 starting
write_state stopped 'Fixture' 4096
# Inspect journal directly: no ready state may erase the previous runtime.
[ "$(switch_value switch_operation)" = targetOperation ] || exit 84
[ -f "$SWITCH_FILE" ] || exit 85
printf '%s' opencode2 > "$RUNTIME_FILE"
# ready status is only authoritative while its tracked server identity exists.
# No PID means it must become failed and preserve the unresolved journal.
write_state ready 'Fixture' 4096 proot 18600
status
[ -f "$SWITCH_FILE" ] || exit 86
''');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString(), contains('switch_previous=opencode1'));
  });

  test(
    'pending journal suppresses automatic recovery and restores return metadata',
    () {
      final status = TermuxSetupStatus.parse(
        'phase=failed\nrunner=proot\nport=4096\nfailure_kind=crash\nruntime=opencode2\nswitch_previous=opencode1\nswitch_target=opencode2\nswitch_phase=starting\nswitch_return=opencode1\n',
      );
      expect(status.switchPending, isTrue);
      expect(status.canRecover, isFalse);
      expect(status.switchReturnAvailable, isTrue);
      expect(status.switchPrevious, TermuxRuntime.openCode1);
      expect(
        TermuxSetupStatus.parse(
          'phase=ready\nruntime=opencode2',
        ).switchReturnAvailable,
        isFalse,
      );
    },
  );

  test(
    'switch requires explicit target credential and validates operation identity',
    () {
      expect(
        () => TermuxBridge.restartScript(
          operationID: 'fixture',
          switchTarget: TermuxRuntime.openCode2,
        ),
        throwsArgumentError,
      );
      expect(
        () => TermuxBridge.restartScript(
          operationID: '../bad',
          switchTarget: TermuxRuntime.openCode2,
          switchPassword: 'fixture',
        ),
        throwsArgumentError,
      );
      final script = TermuxBridge.restartScript(
        operationID: 'fixture',
        switchTarget: TermuxRuntime.openCode2,
        switchPassword: "fixture'quoted",
      );
      expect(script, contains('manager-started:%s'));
      expect(script, contains('managed-operation-owner-changed'));
    },
  );
}
