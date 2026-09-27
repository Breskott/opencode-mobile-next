// P9.4 "Search that finds any setting": the shared index upgrade as a
// person uses it. Rows inside pages are found by their own words (vibration,
// heat, crash, battery), with one typo, in either language; the retired
// aliases lead nowhere; and a row result opens its page arrived at the row.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart' show Health;
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/server_gateway.dart'
    show ServerCapabilities;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/keep_running_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/search/search_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revamp/screen_system_1_fixtures.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// Answers the hub's health check without a network.
class _Api extends SystemApi {
  _Api() : super(ServerCapabilities.allV1);

  @override
  Future<Health> health() async => Health(healthy: true, version: '1.18.23');
}

/// A connected controller; [termux] adds the phone's own OpenCode, run by
/// Termux, as a saved server.
Future<ConnectionController> _controller({bool termux = true}) async {
  mockSecureStorage();
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Workstation',
        'baseUrl': 'http://localhost:4096',
        'username': '',
      },
      if (termux)
        {
          'id': 'profile-2',
          'name': 'This phone',
          'baseUrl': 'http://127.0.0.1:4096',
          'username': '',
        },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return ConnectionController(store)
    ..api = _Api()
    ..repository = SystemRepository()
    ..status = StreamStatus.connected;
}

SearchScope _scope(
  ConnectionController controller, {
  bool thermalGuard = true,
  PlatformCapabilities platform = const PlatformCapabilities.android(),
}) => SearchScope(
  controller: controller,
  platform: platform,
  hasShell: true,
  thermalGuard: thermalGuard,
);

List<String> _ids(
  ConnectionController controller,
  String query, {
  AppLocalizations? l10n,
  bool thermalGuard = true,
  PlatformCapabilities platform = const PlatformCapabilities.android(),
}) => [
  for (final entry in searchEntries(
    l10n ?? _en,
    _scope(controller, thermalGuard: thermalGuard, platform: platform),
    query,
  ))
    entry.id,
];

Finder _key(String key) => find.byKey(ValueKey(key));

/// The arrival wash's opacity around the row keyed [row], or null.
double? _wash(WidgetTester tester, String row) {
  final opacity = find.descendant(
    of: find.ancestor(of: _key(row), matching: find.byType(KitArrival)),
    matching: find.byType(AnimatedOpacity),
  );
  if (opacity.evaluate().isEmpty) return null;
  return tester.widget<AnimatedOpacity>(opacity.first).opacity;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugPlatformCapabilities = const PlatformCapabilities.android());
  tearDown(() => debugPlatformCapabilities = null);

  group('the rows a person names', () {
    test('vibration, heat, crash and battery lead to their rows', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      for (final (query, id) in [
        ('vibration', 'inside-appearance-vibration'),
        ('heat', 'inside-keep-running-thermal'),
        ('crash', 'inside-phone-crash-recovery'),
        ('battery', 'inside-keep-running-battery'),
        ('glass', 'inside-appearance-glass'),
        ('animations', 'inside-appearance-motion'),
        ('confetti', 'inside-appearance-celebrations'),
      ]) {
        expect(_ids(controller, query).first, id, reason: query);
      }
      // "crash" also finds what went wrong, after the restart itself.
      expect(_ids(controller, 'crash'), contains('library-report-bug'));
      final byId = {
        for (final entry in searchIndex(_en, _scope(controller)))
          entry.id: entry,
      };
      final vibration = byId['inside-appearance-vibration']!;
      expect(vibration.target?.pageId, 'appearance-settings');
      expect(vibration.target?.rowId, 'effects-vibration');
      expect(vibration.parent, contains(_en.effectsSection));
      expect(
        byId['inside-keep-running-thermal']!.target?.rowId,
        'keep-running-thermal',
      );
      expect(
        byId['inside-phone-crash-recovery']!.target?.rowId,
        'managed-recovery-option',
      );
    });

    test('one typo and a word begun still find the row', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      for (final query in ['vibraton', 'vibartion', 'VIBRA', 'batery']) {
        expect(
          _ids(controller, query).first,
          query.toLowerCase().startsWith('vib')
              ? 'inside-appearance-vibration'
              : 'inside-keep-running-battery',
          reason: query,
        );
      }
      expect(_ids(controller, 'vibration banana'), isEmpty);
      expect(_ids(controller, '  '), isEmpty);
    });

    test('bilingual aliases are kept, whichever language is shown', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final ar = lookupAppLocalizations(const Locale('ar'));
      // Arabic words while the app is in English, and back.
      expect(_ids(controller, 'اهتزاز').first, 'inside-appearance-vibration');
      expect(_ids(controller, 'حرارة').first, 'inside-keep-running-thermal');
      expect(
        _ids(controller, ar.settingsHubGroupNotifications),
        contains('settings-category-background'),
      );
      expect(
        _ids(controller, 'vibration', l10n: ar).first,
        'inside-appearance-vibration',
      );
      expect(
        _ids(controller, 'quiet hours', l10n: ar),
        contains('inside-notifications-quiet'),
      );
    });

    test('rows the phone does not have stay absent', () async {
      final controller = await _controller(termux: false);
      addTearDown(controller.dispose);
      // No heat guard running: no heat row (Keep running hides its switch).
      expect(
        _ids(controller, 'heat', thermalGuard: false),
        isNot(contains('inside-keep-running-thermal')),
      );
      // No Termux server: "crash" still finds the app's diagnostics.
      expect(_ids(controller, 'crash'), ['library-report-bug']);
      // A computer: neither Keep running nor its rows.
      final desktop = _ids(
        controller,
        'battery',
        platform: const PlatformCapabilities.linuxDesktop(),
      );
      expect(desktop, isNot(contains('inside-keep-running-battery')));
      expect(desktop, isNot(contains('settings-keep-running')));
    });

    test('the dead aliases lead nowhere', () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      // Appearance has no text-size control; Privacy does not hold older
      // drafts; battery is Keep running's, not Notifications'.
      expect(
        _ids(controller, 'font'),
        isNot(contains('settings-category-appearance')),
      );
      expect(
        _ids(controller, 'text size'),
        isNot(contains('settings-category-appearance')),
      );
      expect(
        _ids(controller, 'Older drafts'),
        isNot(contains('settings-category-privacy')),
      );
      final battery = _ids(controller, 'battery');
      expect(battery, isNot(contains('settings-category-background')));
      expect(battery, isNot(contains('inside-notifications-background')));
    });
  });

  group('arrival', () {
    Widget app(ConnectionController controller) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(controller: controller),
      ),
    );

    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byKey(const Key('library-search')), query);
      // The field reports once typing settles.
      await tester.pump(KitMotion.typingSettle);
      await tester.pump();
    }

    void phone(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(390, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('vibration opens Appearance at the Vibration row, once', (
      tester,
    ) async {
      phone(tester);
      // One saved server: no background monitor timers.
      final controller = await _controller(termux: false);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();

      await search(tester, 'vibraton');
      final result = _key('search-result-inside-appearance-vibration');
      expect(result, findsOneWidget);
      expect(
        find.descendant(
          of: result,
          matching: find.textContaining(_en.effectsSection),
        ),
        findsOneWidget,
      );
      await tester.tap(result);
      await tester.pumpAndSettle();

      expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
      final row = tester.getRect(_key('effects-vibration'));
      expect(row.top, greaterThanOrEqualTo(0));
      expect(row.bottom, lessThanOrEqualTo(700));
      expect(_wash(tester, 'effects-vibration'), 1);
      // Only that row.
      expect(_wash(tester, 'effects-glass'), isNull);

      await tester.pump(KitArrival.hold);
      await tester.pumpAndSettle();
      expect(_wash(tester, 'effects-vibration'), 0);
    });

    testWidgets('battery opens Keep running at the battery step', (
      tester,
    ) async {
      phone(tester);
      mockKeepAlive(maker: 'Xiaomi');
      addTearDown(clearKeepAliveMock);
      // One saved server: no background monitor timers.
      final controller = await _controller(termux: false);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();

      await search(tester, 'battery');
      await tester.tap(_key('search-result-inside-keep-running-battery'));
      await tester.pumpAndSettle();

      expect(find.byType(KeepRunningScreen), findsOneWidget);
      expect(_key('keep-running-battery'), findsOneWidget);
      expect(_wash(tester, 'keep-running-battery'), 1);
      expect(_wash(tester, 'keep-running-autostart'), isNull);
      await tester.pump(KitArrival.hold);
      await tester.pumpAndSettle();
    });
  });
}
