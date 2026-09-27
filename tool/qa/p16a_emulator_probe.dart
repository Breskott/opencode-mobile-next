// Explicit QA target only; never imported by lib/main.dart.
// Build release with --target tool/qa/p16a_emulator_probe.dart and ocPreview=true.
// Commands live in this preview app's private files/p16a directory. No network
// command endpoint, exported component, host credentials, or physical-device use.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  if (!Platform.isAndroid) return;
  final qemu = await Process.run('/system/bin/getprop', ['ro.kernel.qemu']);
  if (qemu.exitCode != 0 || qemu.stdout.toString().trim() != '1') return;
  final dir = Directory(
    '/data/user/0/io.github.eslamasabry.opencode_mobile.preview/files/p16a',
  );
  await dir.create(recursive: true);
  final linux = BuiltinLinux();
  await File('${dir.path}/ready').writeAsString('emulator-only\n');
  while (true) {
    final request = File('${dir.path}/request.json');
    if (!await request.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      continue;
    }
    final input = jsonDecode(await request.readAsString()) as Map;
    await request.delete();
    final watch = Stopwatch()..start();
    final response = <String, Object?>{'id': input['id']};
    try {
      switch (input['op']) {
        case 'status':
          final status = await linux.status();
          response.addAll({
            'installed': status.installed,
            'phase': status.phase.name,
            'abi': status.abi,
            'services': status.services,
          });
        case 'install':
          await linux.installUbuntu();
        case 'run':
          final result = await linux.run(
            input['script'] as String,
            timeout: Duration(seconds: (input['timeout'] as int?) ?? 120),
          );
          response.addAll({
            'exitCode': result.exitCode,
            'output': result.output,
          });
        case 'start':
          await linux.startService(
            'p16a',
            input['script'] as String,
            notice: 'Emulator feasibility check',
          );
        case 'stop':
          await linux.stopService('p16a');
        default:
          response['error'] = 'Unsupported probe operation';
      }
    } catch (_) {
      response['error'] = 'The emulator probe did not complete';
    }
    response['elapsedMs'] = watch.elapsedMilliseconds;
    await File('${dir.path}/response.json').writeAsString(jsonEncode(response));
  }
}
