// A phone after an app storage reset (slice-termux-clarity, 2026-09-28):
// Termux is installed and its OpenCode answers on the loopback address, but
// Android took the app's Termux permission back with the data. Used by the
// before/after renders in tool/capture/termux_clarity_test.dart.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/termux_running_server.dart';

/// Installs the reset phone; undone by the test's tear-down.
void useResetTermuxPhone() {
  final oldProbe = termuxRunningServerProbe;
  debugPlatformCapabilities = const PlatformCapabilities.android();
  // OpenCode answers on the phone and asks for its password.
  termuxRunningServerProbe =
      ({required baseUrl, username, password, cancellation}) async =>
          const ServerProbeResult.failure('auth', needsPassword: true);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const termux = MethodChannel('oc/termux');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  messenger.setMockMethodCallHandler(
    termux,
    (call) async => switch (call.method) {
      'getCapabilities' => <String, Object>{
        'installed': true,
        'version': '0.118',
        'serviceAvailable': true,
        'protocolSupported': true,
        'permissionGranted': false,
      },
      'runInTermux' => throw PlatformException(
        code: 'permission_denied',
        message: 'OpenCode does not have Termux\'s RUN_COMMAND permission.',
      ),
      _ => null,
    },
  );
  messenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  addTearDown(() {
    debugPlatformCapabilities = null;
    termuxRunningServerProbe = oldProbe;
    messenger.setMockMethodCallHandler(termux, null);
    messenger.setMockMethodCallHandler(secure, null);
  });
}
