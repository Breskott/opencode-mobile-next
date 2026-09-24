// Settings-area scenes for the design-standard migration (standard §9 step
// 6): the hub, its sub-screens, the servers list and form, diagnostics,
// About and the old Termux setup screen, each in a fixed synthetic state.
//
// Shared by the goldens (test/goldens/settings_golden_test.dart) and the
// before/after renders (tool/capture/design_standard_settings_test.dart).
// It drives public widgets only, so the same file renders the old code and
// the new one.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/server_probe.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/about_screen.dart';
import 'package:opencode_mobile/ui/screens/app_diagnostics_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/termux_setup_screen.dart';

import '../../tool/capture/fixtures.dart';
import 'setup_capture_preferences.dart';

/// The scenes, in the order the QA record lists them.
enum SettingsScene {
  hub,
  server,
  notifications,
  appearance,
  privacy,
  diagnostics,
  diagnosticsEmpty,
  about,
  servers,
  addServer,
  addServerFailed,
  termuxSetup,
}

/// File-name slug of a scene: `settings_hub`, `servers_list`, ...
String settingsSceneName(SettingsScene scene) => switch (scene) {
  SettingsScene.hub => 'settings_hub',
  SettingsScene.server => 'settings_this_server',
  SettingsScene.notifications => 'settings_notifications',
  SettingsScene.appearance => 'settings_appearance',
  SettingsScene.privacy => 'settings_privacy',
  SettingsScene.diagnostics => 'settings_diagnostics',
  SettingsScene.diagnosticsEmpty => 'settings_diagnostics_empty',
  SettingsScene.about => 'settings_about',
  SettingsScene.servers => 'servers_list',
  SettingsScene.addServer => 'servers_add',
  SettingsScene.addServerFailed => 'servers_add_failed',
  SettingsScene.termuxSetup => 'termux_setup',
};

final _en = lookupAppLocalizations(const Locale('en'));

class _Api extends CaptureApi {
  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.25');
}

class _Repository extends CaptureRepository {
  @override
  Future<TerminalShellSettings> loadTerminalShellSettings() async =>
      const TerminalShellSettings(selected: '', options: []);
}

/// Unsent work the privacy screen can offer to clear.
class _SettingsController extends CaptureController {
  _SettingsController(super.store);

  @override
  int get totalQueuedPromptCount => 3;
  @override
  int get totalSessionDraftCount => 2;
  @override
  int get queuedPromptBytes => 18 * 1024;
  @override
  bool get queuedPromptStorageReadable => true;
  @override
  int get sessionDraftBytes => 3 * 1024;
}

void _mockPlatform(WidgetTester tester) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const info = MethodChannel('dev.fluttercommunity.plus/package_info');
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  messenger.setMockMethodCallHandler(
    info,
    (call) async => <String, dynamic>{
      'appName': 'OpenCode Mobile',
      'packageName': 'com.opencode.mobile',
      'version': '1.0.44',
      'buildNumber': '52',
      'buildSignature': '',
    },
  );
  // Termux installed, the bridge unlocked, nothing installed in it yet.
  messenger.setMockMethodCallHandler(const MethodChannel('oc/termux'), (
    call,
  ) async {
    Map<String, Object> result(String stdout) => {
      'stdout': stdout,
      'stderr': '',
      'exitCode': 0,
      'err': -1,
      'errorMessage': '',
    };
    switch (call.method) {
      case 'getCapabilities':
        return <String, Object>{
          'installed': true,
          'version': '0.118',
          'serviceAvailable': true,
          'protocolSupported': true,
          'permissionGranted': true,
        };
      case 'runInTermux':
        final script = (call.arguments as Map)['script'] as String;
        if (script.contains('ubuntu=absent')) {
          return result('ubuntu=absent\nversion=\n');
        }
        if (script.contains("printf 'opencode-bridge-ok'")) {
          return result('opencode-bridge-ok');
        }
        return result(
          'phase=idle\nmessage=No setup has been started\nport=4096\n'
          'runner=\nversion=\npid=\n__OC_SETUP_OUTPUT__\n',
        );
      case 'getSigningCertificateSha256':
        return null;
    }
    return true;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(secure, null);
    messenger.setMockMethodCallHandler(info, null);
    messenger.setMockMethodCallHandler(const MethodChannel('oc/termux'), null);
  });
}

Future<_SettingsController> _controller(
  WidgetTester tester, {
  List<ServerProfile>? profiles,
}) async {
  final prefs = await setupCapturePreferences();
  final store = SeededProfileStore(
    prefs: prefs,
    seeded:
        profiles ??
        [
          ServerProfile(
            id: 'laptop',
            name: 'Laptop',
            baseUrl: 'http://192.168.1.20:4096',
            password: 'synthetic',
          ),
        ],
  );
  final api = _Api();
  final controller = _SettingsController(store)
    ..api = api
    ..repository = _Repository()
    ..status = StreamStatus.connected
    ..directory = projectDirectory
    ..version = '1.18.25';
  controller.catalog = sampleCatalog();
  final model = controller.catalog!.models.first;
  controller.selectedModel = ModelRef(
    providerID: model.providerID,
    modelID: model.id,
  );
  controller.selectedAgent = 'build';
  return controller;
}

List<ServerProfile> _savedServers() => [
  ServerProfile(
    id: 'laptop',
    name: 'Laptop',
    baseUrl: 'http://192.168.1.20:4096',
    password: 'synthetic',
    serverVersion: '1.18.25',
  ),
  ServerProfile(
    id: 'studio',
    name: 'Studio Mac',
    baseUrl: 'https://studio.tail0c1.ts.net',
    flavor: ServerFlavor.v2,
    serverVersion: '2.0.10',
  ),
  ServerProfile(
    id: 'office',
    name: 'Office build box',
    baseUrl: 'http://10.0.4.12:4096',
  )..requiresPasswordReentry = true,
];

/// Mounts [scene] under [boundary] at 412x915 and settles it. Returns what
/// to call once the frame has been captured.
Future<Future<void> Function()> mountSettingsScene(
  WidgetTester tester,
  SettingsScene scene, {
  required bool light,
  required GlobalKey boundary,
}) async {
  _mockPlatform(tester);
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final previousProbe = serverProbe;
  final controller = await _controller(
    tester,
    profiles: switch (scene) {
      SettingsScene.servers ||
      SettingsScene.addServer ||
      SettingsScene.addServerFailed => _savedServers(),
      _ => null,
    },
  );
  controller.appearance.value = light
      ? AppAppearance.light
      : AppAppearance.dark;
  if (scene == SettingsScene.diagnostics) {
    final base = DateTime(2026, 9, 24, 9, 41, 7);
    controller.diagnostics
      ..record(
        StateError('Connection closed before the reply finished'),
        StackTrace.fromString('#0 SseClient._read (lib/api/sse.dart:212:7)'),
        source: 'sse',
        at: base,
      )
      ..record(
        const FormatException('Unexpected character in tool output'),
        StackTrace.fromString('#0 Part.fromJson (lib/api/models.dart:88:5)'),
        source: 'flutter',
        at: base.add(const Duration(minutes: 3)),
      );
  }
  final home = switch (scene) {
    SettingsScene.hub => SettingsScreen(controller: controller),
    SettingsScene.server => ServerSettingsScreen(controller: controller),
    SettingsScene.notifications => NotificationsSettingsScreen(
      controller: controller,
    ),
    SettingsScene.appearance => AppearanceSettingsScreen(
      controller: controller,
    ),
    SettingsScene.privacy => PrivacySettingsScreen(controller: controller),
    SettingsScene.diagnostics || SettingsScene.diagnosticsEmpty =>
      AppDiagnosticsScreen(controller: controller),
    SettingsScene.about => const AboutScreen(),
    SettingsScene.servers ||
    SettingsScene.addServer ||
    SettingsScene.addServerFailed => const ServersScreen(),
    SettingsScene.termuxSetup => const TermuxSetupScreen(),
  };
  await tester.pumpWidget(
    captureApp(
      home: home,
      boundaryKey: boundary,
      controller: controller,
      light: light,
      routes: {
        '/home': (_) => const Scaffold(),
        '/servers': (_) => const Scaffold(),
        '/guide': (_) => const Scaffold(),
      },
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (scene == SettingsScene.about) {
    // The documents come from the asset bundle, off the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (scene == SettingsScene.addServer ||
      scene == SettingsScene.addServerFailed) {
    await tester.tap(find.text(_en.e7SetupAddServer).last);
    await tester.pumpAndSettle();
  }
  if (scene == SettingsScene.addServerFailed) {
    serverProbe = ({required baseUrl, username, password}) async =>
        const ServerProbeResult.failure(
          'Nothing answered at this address. Check that OpenCode is running '
          'and the phone is on the same network.',
          suggestsMissingServer: true,
        );
    // The address waits under "Enter the address instead"; Save & connect
    // checks it and explains the failure (ledger row 15).
    final manual = find.byKey(const ValueKey('server-manual-address'));
    if (manual.evaluate().isNotEmpty) {
      await tester.tap(manual);
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'https://build.example.net',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('save-server-profile')));
    await tester.pumpAndSettle();
  }
  if (scene == SettingsScene.termuxSetup) {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  return () async {
    serverProbe = previousProbe;
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  };
}
