// Explicit QA target only; never imported by lib/main.dart.
// Build release with --target tool/qa/p16a_emulator_probe.dart and ocPreview=true.
// Default mode uses private files on an emulator. The physical ARM64 probe must
// opt in with P16A_PHYSICAL=true and P16A_TOKEN, using an adb-reversed host server.
// The app is an HTTP client only; it never exports a command server.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';

const _physical = bool.fromEnvironment('P16A_PHYSICAL');
const _token = String.fromEnvironment('P16A_TOKEN');
const _host = 'http://127.0.0.1:18761';
const _transportTimeout = Duration(seconds: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  if (!Platform.isAndroid) return;
  final qemu = await Process.run('/system/bin/getprop', ['ro.kernel.qemu']);
  if (qemu.exitCode != 0) return;
  if (_physical) {
    if (_token.isEmpty || qemu.stdout.toString().trim() == '1') return;
    final abi = await Process.run('/system/bin/getprop', [
      'ro.product.cpu.abi',
    ]);
    if (abi.exitCode != 0 || abi.stdout.toString().trim() != 'arm64-v8a') {
      return;
    }
  } else if (qemu.stdout.toString().trim() != '1') {
    return;
  }
  // Creation succeeds only inside the separate preview package's sandbox.
  final dir = Directory(
    '/data/user/0/io.github.eslamasabry.opencode_mobile.preview/files/p16a',
  );
  await dir.create(recursive: true);
  final linux = BuiltinLinux();
  if (_physical) {
    await _physicalLoop(linux);
    return;
  }
  await File('${dir.path}/ready').writeAsString('emulator-only\n');
  while (true) {
    final request = File('${dir.path}/request.json');
    if (!await request.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      continue;
    }
    final input = jsonDecode(await request.readAsString()) as Map;
    await request.delete();
    final response = await _execute(linux, input);
    await File('${dir.path}/response.json').writeAsString(jsonEncode(response));
  }
}

Future<Map<String, Object?>> _execute(BuiltinLinux linux, Map input) async {
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
        response.addAll({'exitCode': result.exitCode, 'output': result.output});
      case 'start':
        await linux.startService(
          'p16a',
          input['script'] as String,
          notice: _physical
              ? 'ARM64 feasibility check'
              : 'Emulator feasibility check',
        );
      case 'stop':
        await linux.stopService('p16a');
      case 'measure':
        // Only this preview sandbox and this process; no other app data.
        final size = await Process.run('/system/bin/du', [
          '-sk',
          '/data/user/0/io.github.eslamasabry.opencode_mobile.preview/files/linux/ubuntu',
        ]);
        response['rootfsDu'] = size.stdout.toString().trim();
        response['rootfsDuExit'] = size.exitCode;
        response['pid'] = pid;
        response['status'] = (await File('/proc/self/status').readAsLines())
            .where(
              (line) => RegExp(r'^(Uid|Gid|Seccomp|VmRSS):').hasMatch(line),
            )
            .toList();
        response['selinux'] = (await File(
          '/proc/self/attr/current',
        ).readAsString()).trim();
      default:
        response['error'] = 'Unsupported probe operation';
    }
  } catch (_) {
    response['error'] = 'The feasibility probe did not complete';
  }
  response['elapsedMs'] = watch.elapsedMilliseconds;
  return response;
}

Future<String?> _exchange(
  HttpClient client,
  String method,
  String path, [
  Map<String, Object?>? body,
]) async {
  final request = await client
      .openUrl(method, Uri.parse('$_host$path'))
      .timeout(_transportTimeout);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close().timeout(_transportTimeout);
  final content = await response
      .transform(utf8.decoder)
      .join()
      .timeout(_transportTimeout);
  if (response.statusCode == HttpStatus.noContent) return null;
  if (response.statusCode != HttpStatus.ok) {
    throw const HttpException('Probe transport unavailable');
  }
  return content;
}

Future<void> _physicalLoop(BuiltinLinux linux) async {
  final client = HttpClient()..connectionTimeout = _transportTimeout;
  try {
    await _exchange(client, 'POST', '/ready', {
      'mode': 'physical-arm64',
      'abi': 'arm64-v8a',
    });
    var failures = 0;
    while (true) {
      String? payload;
      try {
        payload = await _exchange(client, 'GET', '/request');
        failures = 0;
      } catch (_) {
        if (++failures >= 3) return;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }
      if (payload == null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }
      final input = jsonDecode(payload) as Map;
      final response = await _execute(linux, input);
      // A lost response stops the probe rather than risking command replay.
      await _exchange(client, 'POST', '/response', response);
    }
  } catch (_) {
    // Command output and the transport credential must never enter app logs.
  } finally {
    client.close(force: true);
    try {
      await linux.stopService('p16a').timeout(_transportTimeout);
    } catch (_) {
      // Host cleanup still uninstalls this preview package if transport fails.
    }
  }
}
