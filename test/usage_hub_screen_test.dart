import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_overview.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/usage_ui_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));

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

Future<
  ({
    _Connection connection,
    _Repository repository,
    UsageSubscriptionsController usage,
  })
>
_harness({bool statistics = true, bool savedServer = true}) async {
  SharedPreferences.setMockInitialValues({
    if (savedServer)
      'oc.profiles': jsonEncode([
        {
          'id': 'profile-1',
          'name': 'Workstation',
          'baseUrl': 'http://localhost:4096',
          'username': '',
        },
      ]),
    if (savedServer) 'oc.activeProfile': 'profile-1',
  });
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  await store.load();
  final repository = _Repository()..supported = statistics;
  final connection = _Connection(store)
    ..api = _Api()
    ..repository = repository
    ..status = StreamStatus.connected;
  final usage = UsageSubscriptionsController(
    prefs: preferences,
    connections: () => const [usageInApp, usagePc],
    sources: [
      FakeUsageSource(
        UsageSourceResult(
          readings: [
            usageReading('codex', 'inapp', account: 'a', plan: 'plus'),
            usageReading(
              'glm',
              'inapp',
              account: 'b',
              windows: usageBoth(five: 100, week: 30),
            ),
            usageReading(
              'minimax',
              'pc',
              account: 'c',
              status: UsageReadingStatus.authRequired,
            ),
          ],
          signIns: const [
            UsageSignIn(providerId: 'claude', connectionId: 'pc'),
          ],
          authoritativeSignIns: {'pc'},
        ),
      ),
    ],
    sharedRules: () => connection.sharedNotifyRules,
    setQuotaAlerts: (value) => connection.updateSharedNotifyRules(
      (rules) => rules.copyWith(quotaAlerts: value),
    ),
    clock: () => usageNow,
  );
  return (connection: connection, repository: repository, usage: usage);
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

Future<void> _finish(
  WidgetTester tester,
  _Connection connection,
  UsageSubscriptionsController usage,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  usage.dispose();
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

  testWidgets('two sections: Plans first, Spending one tap away', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness();
    final overview = _overview(h.connection);
    await tester.pumpWidget(
      _app(
        UsageHubScreen(
          controller: h.connection,
          usage: h.usage,
          usageOverview: overview,
          clock: () => usageNow,
          prepare: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(KitTopBar),
        matching: find.text(_en.settingsHubGroupUsage),
      ),
      findsOneWidget,
    );
    final plans = _key('usage-tab-plans'),
        spending = _key('usage-tab-spending');
    expect(
      tester.getTopLeft(plans).dx,
      lessThan(tester.getTopLeft(spending).dx),
    );
    expect(find.text(_en.usageTabPlans), findsOneWidget);
    expect(find.text(_en.usageTabSpending), findsOneWidget);
    // Plans first, with its own top-bar Refresh.
    expect(_key('usage-plans'), findsOneWidget);
    expect(_key('plans-refresh'), findsOneWidget);
    expect(find.byType(KitTopBar), findsOneWidget);

    await tester.tap(spending);
    await tester.pumpAndSettle();
    // Spending is today's usage screen, embedded: same controls, same keys.
    expect(find.byType(UsageScreen), findsOneWidget);
    expect(_key('usage-content'), findsOneWidget);
    expect(_key('refresh-usage'), findsOneWidget);
    expect(_key('plans-refresh'), findsNothing);
    expect(_key('usage-range-thirtyDays'), findsOneWidget);
    expect(_key('usage-total-cost'), findsOneWidget);
    expect(find.byType(KitTopBar), findsOneWidget);
    overview.dispose();
    await _finish(tester, h.connection, h.usage);
  });

  testWidgets('an entry point can open straight at Spending', (tester) async {
    final h = await _harness();
    final overview = _overview(h.connection);
    await tester.pumpWidget(
      _app(
        UsageHubScreen(
          controller: h.connection,
          usage: h.usage,
          usageOverview: overview,
          initialSection: UsageSection.spending,
          prepare: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UsageScreen), findsOneWidget);
    expect(_key('refresh-usage'), findsOneWidget);
    overview.dispose();
    await _finish(tester, h.connection, h.usage);
  });

  testWidgets('Spending is absent where the server has no statistics, and '
      'with one section there is no tab strip', (tester) async {
    final h = await _harness(statistics: false);
    await tester.pumpWidget(
      _app(
        UsageHubScreen(
          controller: h.connection,
          usage: h.usage,
          clock: () => usageNow,
          prepare: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(UsageHubScreen.sectionsFor(h.connection), [UsageSection.plans]);
    expect(_key('usage-tab-plans'), findsNothing);
    expect(_key('usage-tab-spending'), findsNothing);
    expect(find.byType(UsageScreen), findsNothing);
    expect(_key('usage-plans'), findsOneWidget);
    expect(find.byType(KitTopBar), findsOneWidget);
    await _finish(tester, h.connection, h.usage);
  });

  testWidgets('each section is gated by what it needs: Plans a saved server, '
      'Spending usage statistics', (tester) async {
    final both = await _harness();
    expect(UsageHubScreen.sectionsFor(both.connection), [
      UsageSection.plans,
      UsageSection.spending,
    ]);
    final noStats = await _harness(statistics: false);
    expect(UsageHubScreen.sectionsFor(noStats.connection), [
      UsageSection.plans,
    ]);
    final noServer = await _harness(savedServer: false);
    expect(UsageHubScreen.sectionsFor(noServer.connection), [
      UsageSection.spending,
    ]);
    final nothing = await _harness(statistics: false, savedServer: false);
    expect(UsageHubScreen.sectionsFor(nothing.connection), isEmpty);
    await tester.pumpWidget(
      _app(
        UsageHubScreen(controller: nothing.connection, usage: nothing.usage),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('usage-hub-unavailable'), findsOneWidget);
    for (final h in [both, noStats, noServer, nothing]) {
      await _finish(tester, h.connection, h.usage);
    }
  });

  group('layout at 320 dp and 2.0x text', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('no overflow in ${locale.languageCode}', (tester) async {
        const phone = Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        addTearDown(tester.view.reset);
        final h = await _harness();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: phone,
              textScaler: TextScaler.linear(2.0),
            ),
            child: _app(
              UsageHubScreen(
                controller: h.connection,
                usage: h.usage,
                initialSection: UsageSection.plans,
                clock: () => usageNow,
                prepare: false,
              ),
              locale: locale,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(_key('usage-tab-plans'))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        // Cards for an exhausted plan, an expired sign-in and a sign-in no
        // reader reaches, all wrapping at 2.0x.
        final list = find.descendant(
          of: _key('usage-section-plans'),
          matching: find.byType(ListView),
        );
        for (var i = 0; i < 14; i++) {
          await tester.drag(list, const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        await _finish(tester, h.connection, h.usage);
      });
    }
  });
}
