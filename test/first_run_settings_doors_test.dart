import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/guide_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/tailscale_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first-run welcome stopped offering Tailscale setup, the setup guide
/// and External agents (UX plan 5.4). They moved; they did not disappear.
/// This pins the other half of that change: each one is still a row in
/// Settings, reachable while connected.

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'http://localhost');

  @override
  ServerCapabilities get capabilities => ServerCapabilities.allV1;

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.23');
}

class _Repository implements ProductRepository {
  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<TerminalShellSettings> loadTerminalShellSettings() async =>
      const TerminalShellSettings(selected: '', options: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _controller() async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Workstation',
        'baseUrl': 'http://localhost:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return ConnectionController(store)
    ..api = _Api()
    ..repository = _Repository()
    ..status = StreamStatus.connected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const tailscale = MethodChannel('oc/tailscale');
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    messenger.setMockMethodCallHandler(
      tailscale,
      (call) async => call.method == 'check' ? 'installed' : true,
    );
    // ProfileStore reads passwords through flutter_secure_storage, whose
    // unmocked channel never answers inside testWidgets.
    messenger.setMockMethodCallHandler(secure, (_) async => null);
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    messenger.setMockMethodCallHandler(tailscale, null);
    messenger.setMockMethodCallHandler(secure, null);
  });

  testWidgets('Settings still opens what left the first-run welcome', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> open(String key) async {
      final row = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      // Bounded: a destination may keep a progress indicator spinning.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await open('settings-tailscale');
    expect(find.byType(TailscaleSetupScreen), findsOneWidget);
    await tester.pageBack();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await open('settings-setup-guide');
    expect(find.byType(GuideScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final externalAgents = find.byKey(
      const ValueKey('settings-external-agents'),
    );
    await tester.scrollUntilVisible(
      externalAgents,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(externalAgents, findsOneWidget);
  });
}
