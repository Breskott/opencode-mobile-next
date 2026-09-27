import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/termux/bridge.dart';

void main() {
  test(
    'first recovery arm admits only a confirmed crash with no live owner',
    () {
      final directory = Directory.systemTemp.createTempSync('oc-healing-arm-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final manager = TermuxBridge.managerScriptForTesting();
      final functions = manager.substring(
        0,
        manager.indexOf('\ncase "\${1:-status}" in'),
      );
      for (final scenario in [
        'crash',
        'recovery',
        'stopped',
        'setup-failed',
        'port-busy',
        'live-pid',
        'different-port',
        'switch-pending',
      ]) {
        final home = Directory('${directory.path}/$scenario')..createSync();
        final script = File('${home.path}/fixture.sh')
          ..writeAsStringSync('''
$functions
CURRENT_OPERATION=original
write_state failed synthetic 4096 proot '' '' '' crash
printf '123 456\\n' > "\$SERVER_PID"
kill() { [ '$scenario' = live-pid ]; }
recovery_port_busy() { [ '$scenario' = port-busy ]; }
case '$scenario' in
  recovery) write_state failed synthetic 4096 proot '' '' '' recovery ;;
  stopped) write_state stopped synthetic 4096 proot ;;
  setup-failed) write_state failed synthetic 4096 proot ;;
  different-port) write_state failed synthetic 4097 proot '' '' '' crash ;;
  switch-pending) touch "\$SWITCH_FILE" ;;
esac
recovery_arm permit
[ "\$(cat "\$RECOVERY_PERMIT")" = permit ]
''');
        final result = Process.runSync(
          'bash',
          [script.path],
          environment: {...Platform.environment, 'HOME': home.path},
        );
        expect(
          result.exitCode,
          ['crash', 'recovery'].contains(scenario) ? 0 : 75,
          reason: '$scenario: ${result.stderr}',
        );
      }
    },
  );
}
