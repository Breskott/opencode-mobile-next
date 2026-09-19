import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/provider_quota_monitor.dart';
import 'package:opencode_mobile/state/usage_overview.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/provider_quota_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';
import 'package:opencode_mobile/ui/widgets/quota_monitor_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'http://localhost');
  @override
  Future<Health> health() async => Health(healthy: true, version: 'fixture');
}

class _Repository extends ProductRepository implements UsageStatisticsGateway {
  bool supported = true;
  @override
  bool get usageStatisticsSupported => supported;
  @override
  Future<WorkspaceProject?> loadCurrentProject() async => null;
  @override
  Future<UsageStatistics> loadUsageStatistics(UsageQuery query) async =>
      UsageStatistics.fromJson(
        (jsonDecode(
              File('test/fixtures/api2/session_stats.json').readAsStringSync(),
            )
            as Map<String, dynamic>)['data'],
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection extends ConnectionController {
  _Connection(super.store);
  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;
  @override
  Future<ServerGateway?> prepareActionTransport() async => api;
}

Future<({_Connection connection, _Repository repository})> _harness({
  bool profile = true,
  bool monitoredSource = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (profile) ...{
      'oc.profiles': jsonEncode([
        {
          'id': 'profile-1',
          'name': 'Workstation',
          'baseUrl': 'http://localhost:4096',
          'username': '',
        },
      ]),
      'oc.activeProfile': 'profile-1',
    },
  });
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  await store.load();
  final repository = _Repository();
  final connection = _Connection(store)
    ..api = _Api()
    ..repository = repository
    ..status = StreamStatus.connected;
  if (monitoredSource) {
    // Written as the monitor itself stores a source, so the section has one
    // to show without a collector to read.
    await preferences.setString(
      ProviderQuotaMonitor.key('profile-1'),
      jsonEncode({
        'version': 1,
        'rules': {
          QuotaProvider.codex.name: QuotaMonitorRules(
            source: _hash,
            account: _hash,
            token: _hash,
            notifications: true,
            wifiOnly: true,
            quietStart: 22 * 60,
            quietEnd: 8 * 60,
            threshold: 90,
          ).toJson(),
        },
      }),
    );
  }
  return (connection: connection, repository: repository);
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

UsageOverview _overview(ConnectionController connection) => UsageOverview(
  connection,
  clock: () => DateTime(2026, 9, 5, 12),
  timezoneLoader: () async => 'Asia/Dubai',
);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _finish(WidgetTester tester, _Connection connection) async {
  await tester.pumpWidget(const SizedBox.shrink());
  connection.quotaMonitor.dispose();
  connection.dispose();
  await tester.pump();
}

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

  testWidgets('two sections: Spent first, Remaining one tap away', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness();
    final overview = _overview(h.connection);
    await tester.pumpWidget(
      _app(UsageHubScreen(controller: h.connection, usageOverview: overview)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(_en.settingsHubGroupUsage),
      ),
      findsOneWidget,
    );
    final spent = _key('usage-tab-spent'),
        remaining = _key('usage-tab-remaining');
    expect(
      tester.getTopLeft(spent).dx,
      lessThan(tester.getTopLeft(remaining).dx),
    );
    expect(find.text(_en.usageSectionSpent), findsOneWidget);
    expect(find.text(_en.usageSectionRemaining), findsOneWidget);

    // Spent is today's usage screen, embedded: same controls, same keys.
    expect(find.byType(UsageScreen), findsOneWidget);
    expect(_key('usage-content'), findsOneWidget);
    expect(_key('refresh-usage'), findsOneWidget);
    expect(_key('usage-range-today'), findsOneWidget);
    expect(_key('usage-total-cost'), findsOneWidget);
    // One app bar: the sections do not bring their own.
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(remaining);
    await tester.pumpAndSettle();
    expect(find.byType(ProviderQuotaScreen), findsOneWidget);
    expect(find.text(_en.quotaDescription), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    overview.dispose();
    await _finish(tester, h.connection);
  });

  testWidgets('an entry point can open straight at Remaining', (tester) async {
    final h = await _harness();
    final overview = _overview(h.connection);
    await tester.pumpWidget(
      _app(
        UsageHubScreen(
          controller: h.connection,
          usageOverview: overview,
          initialSection: UsageSection.remaining,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProviderQuotaScreen), findsOneWidget);
    expect(find.byType(UsageScreen), findsNothing);
    overview.dispose();
    await _finish(tester, h.connection);
  });

  testWidgets('each section is gated as its screen was', (tester) async {
    // No usage statistics: Remaining alone, no tab bar.
    var h = await _harness();
    h.repository.supported = false;
    expect(UsageHubScreen.sectionsFor(h.connection), [UsageSection.remaining]);
    await tester.pumpWidget(_app(UsageHubScreen(controller: h.connection)));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(_key('usage-section-remaining'), findsOneWidget);
    expect(_key('usage-section-spent'), findsNothing);
    await _finish(tester, h.connection);

    // No saved server: Spent alone.
    h = await _harness(profile: false);
    expect(UsageHubScreen.sectionsFor(h.connection), [UsageSection.spent]);
    final overview = _overview(h.connection);
    await tester.pumpWidget(
      _app(UsageHubScreen(controller: h.connection, usageOverview: overview)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(_key('usage-section-spent'), findsOneWidget);
    expect(_key('usage-section-remaining'), findsNothing);
    overview.dispose();
    await _finish(tester, h.connection);
  });

  testWidgets(
    'the hub has one Usage row, absent when neither section applies',
    (tester) async {
      var h = await _harness();
      await tester.pumpWidget(_app(SettingsScreen(controller: h.connection)));
      await tester.pumpAndSettle();
      final row = _key('settings-category-usage');
      expect(row, findsOneWidget);
      expect(_key('settings-category-quota'), findsNothing);
      expect(
        find.descendant(
          of: _key('settings-group-usage'),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            '${_en.usageSectionSpent} · ${_en.usageSectionRemaining}',
          ),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      // Not pumpAndSettle: Spent shows a progress bar while its first read
      // waits on the platform timezone, which a widget test never answers.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UsageHubScreen), findsOneWidget);
      await _finish(tester, h.connection);

      // Neither usage statistics nor a saved server: no row, and so no group.
      h = await _harness(profile: false);
      h.repository.supported = false;
      await tester.pumpWidget(_app(SettingsScreen(controller: h.connection)));
      await tester.pumpAndSettle();
      expect(_key('settings-category-usage'), findsNothing);
      expect(_key('settings-group-usage'), findsNothing);
      expect(find.text(_en.settingsHubGroupUsage), findsNothing);
      await _finish(tester, h.connection);
    },
  );

  testWidgets('Remaining keeps monitoring and the threshold; how it notifies '
      'is a link to Notifications', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness(monitoredSource: true);
    await tester.pumpWidget(
      _app(
        UsageHubScreen(
          controller: h.connection,
          initialSection: UsageSection.remaining,
          usageOverview: _overview(h.connection),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuotaMonitorSection), findsOneWidget);
    expect(h.connection.quotaMonitor.sources, hasLength(1));
    final threshold = _key('quota-threshold-profile-1-codex');
    expect(threshold, findsOneWidget);
    expect(find.text(_en.quotaMonitorDisable), findsOneWidget);
    // The three notification toggles moved to Notifications.
    expect(find.byType(Switch), findsNothing);
    expect(find.text(_en.quotaMonitorNotifications), findsNothing);
    expect(find.text(_en.quotaMonitorWifi), findsNothing);
    expect(find.text(_en.quotaMonitorQuiet), findsNothing);

    // Changing the threshold leaves the record's other fields alone.
    await tester.tap(threshold);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_en.quotaBudgetPercent('75')).last);
    await tester.pumpAndSettle();
    final rules = h.connection.quotaMonitor.rulesFor(
      'profile-1',
      QuotaProvider.codex,
    )!;
    expect(rules.threshold, 75);
    expect(rules.notifications, isTrue);
    expect(rules.wifiOnly, isTrue);
    expect(rules.quietStart, 22 * 60);

    await tester.tap(_key('quota-monitor-notification-settings'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
    // The legacy source's choices arrive there as the shared values.
    Switch toggle(String key) => tester.widget<Switch>(
      find.descendant(of: _key(key), matching: find.byType(Switch)),
    );
    expect(toggle('notify-quota-alerts').value, isTrue);
    expect(toggle('notify-quiet-hours').value, isTrue);
    expect(toggle('notify-wifi-only').value, isTrue);
    await _finish(tester, h.connection);
  });

  group('layout at 320 dp and 2.5x text', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('no overflow in ${locale.languageCode}', (tester) async {
        const phone = Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        addTearDown(tester.view.reset);
        final h = await _harness(monitoredSource: true);
        final overview = _overview(h.connection);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: phone,
              textScaler: TextScaler.linear(AppTheme.maxTextScale),
            ),
            child: _app(
              UsageHubScreen(controller: h.connection, usageOverview: overview),
              locale: locale,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(_key('usage-tab-spent'))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        // Both tab labels fit the bar.
        for (final key in ['usage-tab-spent', 'usage-tab-remaining']) {
          final box = tester.getRect(_key(key));
          expect(box.left, greaterThanOrEqualTo(0), reason: key);
          expect(box.right, lessThanOrEqualTo(phone.width), reason: key);
        }

        // Walk Spent to its end, then Remaining to its end.
        await tester.drag(_key('usage-content'), const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(_key('usage-tab-remaining'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final list = find.descendant(
          of: _key('usage-section-remaining'),
          matching: find.byType(ListView),
        );
        for (var i = 0; i < 12; i++) {
          await tester.drag(list, const Offset(0, -600));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(_key('quota-monitor-section'), findsOneWidget);
        overview.dispose();
        await _finish(tester, h.connection);
      });
    }
  });
}
