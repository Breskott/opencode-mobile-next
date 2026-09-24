// Scenes for the Add server and Servers motion pass (slice B of
// docs/design/motion-and-illustration-2026-09-25.md, ledger row 15): the
// Servers welcome, Add server for each connection type, and the pairing and
// connection-check moments, each in a fixed synthetic state at 412x915.
//
// Shared by the goldens (test/goldens/servers_motion_golden_test.dart) and
// the before/after renders (tool/capture/motion_servers_test.dart). It drives
// public widgets only and adapts to what the screen offers (the old form has
// no "Enter the address instead" and tests with its own button), so the
// same file renders the old code and the new.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';

import '../../tool/capture/fixtures.dart';
import 'first_run_path.dart';
import 'setup_capture_preferences.dart';

/// The scenes, in the order the QA record lists them.
enum ServersMotionScene {
  /// Servers with nothing saved yet: the welcome.
  welcome,

  /// Add server, beside a saved server: OpenCode chosen (the default).
  addOpenCode,

  /// The same with "Enter the address instead" opened.
  addOpenCodeManual,

  /// Add server with Codex chosen.
  addCodex,

  /// Add server with Claude Code or Pi (Paseo) chosen.
  addPaseo,

  /// An address typed and Save & connect tapped: the connection is being
  /// checked (the old form: Test connection tapped).
  testing,

  /// A pairing code pasted and the server answered: paired.
  paired,

  /// An address typed and Save & connect tapped; nothing answered.
  failed,

  /// First run, "On my computer" › OpenCode: the connect screen.
  firstRunConnect,
}

/// File-name slug of a scene.
String serversMotionSceneName(ServersMotionScene scene) => switch (scene) {
  ServersMotionScene.welcome => 'servers_welcome',
  ServersMotionScene.addOpenCode => 'add_server_opencode',
  ServersMotionScene.addOpenCodeManual => 'add_server_manual',
  ServersMotionScene.addCodex => 'add_server_codex',
  ServersMotionScene.addPaseo => 'add_server_paseo',
  ServersMotionScene.testing => 'add_server_testing',
  ServersMotionScene.paired => 'add_server_paired',
  ServersMotionScene.failed => 'add_server_failed',
  ServersMotionScene.firstRunConnect => 'first_run_connect',
};

/// A stand-in serve password. Never a live one.
const _password = 'fixture-not-a-live-serve-password-000000000';

void _mockPlatform(WidgetTester tester, {String? clipboard}) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const termux = MethodChannel('oc/termux');
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  // No Termux: nothing found running on the phone, so the screens show only
  // what these scenes are about.
  messenger.setMockMethodCallHandler(termux, (call) async {
    if (call.method == 'getCapabilities') return {'installed': false};
    return null;
  });
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return clipboard == null ? null : {'text': clipboard};
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(secure, null);
    messenger.setMockMethodCallHandler(termux, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

Future<void> _settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapIfPresent(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await tester.ensureVisible(finder.first);
  await _settle(tester, frames: 3);
  await tester.tap(finder.first);
  await _settle(tester, frames: 12);
}

/// Types an address and asks for the check: Save & connect where it checks
/// by itself (the new form), Test connection on the old one.
Future<void> _typeAndCheck(WidgetTester tester) async {
  await _tapIfPresent(
    tester,
    find.byKey(const ValueKey('server-manual-address')),
  );
  final url = find.byKey(const ValueKey('server-url-field'));
  await tester.ensureVisible(url);
  await tester.enterText(url, 'https://build.example.net');
  await tester.enterText(
    find.byKey(const ValueKey('server-password-field')),
    'synthetic-password',
  );
  tester.testTextInput.hide();
  await _settle(tester, frames: 3);
  final folds = find
      .byKey(const ValueKey('server-manual-address'))
      .evaluate()
      .isNotEmpty;
  final action = folds
      ? find.byKey(const ValueKey('save-server-profile'))
      : find.byKey(const ValueKey('test-server-connection'));
  if (!folds) await tester.ensureVisible(action);
  await tester.tap(action);
}

/// Mounts [scene] under [boundary] at 412x915 and settles it. Returns what
/// to call once the frame has been captured.
Future<Future<void> Function()> mountServersMotionScene(
  WidgetTester tester,
  ServersMotionScene scene, {
  required bool light,
  required GlobalKey boundary,
}) async {
  _mockPlatform(
    tester,
    clipboard: scene == ServersMotionScene.paired
        ? '{"urls":${jsonEncode(['https://studio.example.net:4097'])},'
              '"username":"opencode","password":"$_password"}'
        : null,
  );
  debugPlatformCapabilities = const PlatformCapabilities.android();
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final previousProbe = serverProbe;
  final pending = Completer<ServerProbeResult>();
  serverProbe = switch (scene) {
    ServersMotionScene.testing =>
      ({required baseUrl, username, password}) => pending.future,
    ServersMotionScene.failed =>
      ({required baseUrl, username, password}) async =>
          const ServerProbeResult.failure(
            'The connection was refused. Is opencode serve running on that '
            'host and port?',
            suggestsMissingServer: true,
          ),
    _ =>
      ({required baseUrl, username, password}) async =>
          const ServerProbeResult.success('2.0.10', flavor: ServerFlavor.v2),
  };
  final firstRun =
      scene == ServersMotionScene.welcome ||
      scene == ServersMotionScene.firstRunConnect;
  final prefs = await setupCapturePreferences();
  final store = SeededProfileStore(
    prefs: prefs,
    seeded: firstRun
        ? const []
        : [
            ServerProfile(
              id: 'laptop',
              name: 'Laptop',
              baseUrl: 'https://laptop.example.net',
              flavor: ServerFlavor.v2,
              serverVersion: '2.0.10',
            ),
          ],
  );
  final controller = CaptureController(store);
  await tester.pumpWidget(
    captureApp(
      home: const ServersScreen(),
      boundaryKey: boundary,
      controller: controller,
      light: light,
      routes: {
        '/home': (_) => const Scaffold(),
        '/guide': (_) => const Scaffold(),
      },
    ),
  );
  await _settle(tester);
  switch (scene) {
    case ServersMotionScene.welcome:
      break;
    case ServersMotionScene.firstRunConnect:
      await openFirstRunConnect(tester);
    default:
      await tester.tap(find.byKey(const ValueKey('servers-add')));
      await _settle(tester);
  }
  switch (scene) {
    case ServersMotionScene.addOpenCodeManual:
      await _tapIfPresent(
        tester,
        find.byKey(const ValueKey('server-manual-address')),
      );
    case ServersMotionScene.addCodex:
      final row = find.byKey(const ValueKey('server-backend-codex'));
      await _tapIfPresent(
        tester,
        row.evaluate().isNotEmpty ? row : find.text('Codex (experimental)'),
      );
    case ServersMotionScene.addPaseo:
      await _tapIfPresent(
        tester,
        find.byKey(const ValueKey('server-backend-paseo')),
      );
    case ServersMotionScene.testing:
      await _typeAndCheck(tester);
      // Mid-check: the probe never answers in this scene.
      await _settle(tester, frames: 12);
    case ServersMotionScene.failed:
      await _typeAndCheck(tester);
      await _settle(tester);
    case ServersMotionScene.paired:
      await _tapIfPresent(
        tester,
        find.byKey(const ValueKey('server-pairing-paste')),
      );
      await _settle(tester);
    default:
      break;
  }
  return () async {
    serverProbe = previousProbe;
    debugPlatformCapabilities = null;
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  };
}
