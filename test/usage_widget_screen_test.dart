import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/background/usage_widget_snapshot.dart';
import 'package:opencode_mobile/domain/provider_usage.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/paseo_usage_monitor.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_widget_screen.dart';
import 'package:opencode_mobile/ui/search/search_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Future<ConnectionController> _controller({
  bool phone = false,
  void Function()? onHostCreated,
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'oc',
        'name': 'Workstation',
        'baseUrl': 'http://localhost:4096',
        'username': '',
      },
      {
        'id': 'ps',
        'name': 'Desk Paseo',
        'baseUrl': 'ws://100.64.0.1:6767',
        'username': '',
        'backend': 'paseo',
      },
    ]),
    'oc.activeProfile': 'oc',
  });
  final prefs = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: prefs);
  await store.load();
  return ConnectionController(
    store,
    phoneAgentHostFactory: phone
        ? (_) {
            onHostCreated?.call();
            throw StateError('the host must not be created to read usage');
          }
        : null,
  )..status = StreamStatus.connected;
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() => debugPlatformCapabilities = null);

  testWidgets('U17: no Sources group and no per-server Paseo switches', (
    tester,
  ) async {
    final controller = await _controller(phone: true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(UsageWidgetScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text(_en.usageWidgetIntro), findsOneWidget);
    expect(find.byKey(const ValueKey('paseo-usage-section')), findsNothing);
    expect(find.byKey(const ValueKey('paseo-usage-phone')), findsNothing);
    expect(find.byKey(const ValueKey('paseo-usage-ps')), findsNothing);
    expect(find.text(_en.usageSources), findsNothing);
    expect(find.text(_en.usageWidgetPhoneTitle), findsNothing);
  });

  testWidgets('U17: Paseo connections are read without any switch', (
    tester,
  ) async {
    final controller = await _controller(phone: true);
    addTearDown(controller.dispose);
    final monitor = controller.paseoUsageMonitor;
    expect(monitor.enabled('ps'), isTrue);
    expect(monitor.enabled('phone'), isTrue);
    // A Workstation (OpenCode) is not a Paseo server.
    expect(monitor.enabled('oc'), isFalse);
  });

  testWidgets('U15: one header style and the control is named once', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(UsageWidgetScreen(controller: controller)));
    await tester.pumpAndSettle();
    // Header text is drawn once; the segmented control carries the one
    // semantic name.
    expect(find.text(_en.usageWidgetSettingsWindows), findsOneWidget);
    expect(
      find.bySemanticsLabel(_en.usageWidgetSettingsWindows),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('turning This phone on never starts the host', (tester) async {
    var created = 0;
    final controller = await _controller(
      phone: true,
      onHostCreated: () => created++,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      final monitor = controller.paseoUsageMonitor;
      expect(await monitor.setEnabled('phone', true), isTrue);
      await monitor.refresh();
      expect(monitor.statusFor('phone'), PaseoUsageStatus.hostStopped);
    });
    expect(created, 0);
  });

  testWidgets('the Usage widget lives inside Usage, not on the hub', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-category-usage-widget')),
      findsNothing,
    );
    final entry = searchEntries(
      _en,
      SearchScope(controller: controller),
      'usage widget',
    ).firstWhere((e) => e.id == 'settings-category-usage-widget');
    expect(entry.kind, SearchEntryKind.insideSettings);
    expect(entry.parent, _en.settingsHubGroupUsage);
  });

  testWidgets('the settings page is in the app search', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final ids = [
      for (final e in searchEntries(
        _en,
        SearchScope(controller: controller),
        'usage widget',
      ))
        e.id,
    ];
    expect(ids, contains('settings-category-usage-widget'));
  });

  test('rows from the phone source are labelled for This phone', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final widget = UsageWidgetSnapshot(
      prefs: prefs,
      isAndroid: true,
      refreshNative: () async {},
    );
    final store = ProfileStore(prefs: prefs);
    final monitor = PaseoUsageMonitor(
      store: store,
      widget: widget,
      createGateway: (_) => throw StateError('no server gateway'),
      isReadable: (_) => false,
      phoneSupported: () => true,
      phoneRead: () async => parseProviderUsageList({
        'providers': [
          {
            'providerId': 'claude',
            'displayName': 'Claude',
            'status': 'available',
            'windows': [
              {'id': 'five_hour', 'label': '5h', 'usedPct': 40},
            ],
          },
        ],
      }, now: DateTime.utc(2026, 10, 12)),
    );
    addTearDown(monitor.dispose);
    expect(await monitor.setEnabled('phone', true), isTrue);
    await monitor.refresh();
    final doc =
        jsonDecode(prefs.getString(UsageWidgetSnapshot.key('phone'))!)
            as Map<String, dynamic>;
    expect(doc['local'], isTrue);
    expect(((doc['rows'] as Map)['claude'] as Map)['name'], 'Claude');
    // Deleting the phone source's opt-in clears its numbers.
    expect(await monitor.setEnabled('phone', false), isTrue);
    expect(prefs.getString(UsageWidgetSnapshot.key('phone')), isNull);
  });
}
