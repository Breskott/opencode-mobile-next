// Unit shared-usage-1 (docs/qa/revamp-shared-usage-1/README.md): the quota
// monitoring section of Usage -> Remaining, rebuilt from kit parts, and its
// gallery (phone 412x915 and 1280x800, light and dark; owner decision
// 2026-09-27: no Arabic galleries).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_usage_1_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/provider_quota_monitor.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/quota_monitor_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/kit/kit_gallery.dart';

final _en = lookupAppLocalizations(const Locale('en'));
const _baseUrl = 'http://192.168.1.20:4096';
const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Future<ConnectionController> _connection({bool monitored = true}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Workstation',
        'baseUrl': _baseUrl,
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
    if (monitored)
      ProviderQuotaMonitor.key('profile-1'): jsonEncode({
        'version': 1,
        'rules': {
          QuotaProvider.codex.name: QuotaMonitorRules(
            // Not this profile's source hash, so the monitor shows "source
            // changed" and never starts a read: no network (TEST-11).
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
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return ConnectionController(store);
}

/// A monitor whose Check now is held until the test lets it finish.
class _HeldMonitor extends ProviderQuotaMonitor {
  _HeldMonitor(ProfileStore store)
    : super(
        store: store,
        createGateway: (_, _) => throw StateError('no reads here'),
        isReadable: (_) => true,
        networkWifi: () async => true,
        alert: ({required profileID, required key, required token}) async =>
            false,
        dismiss: (_) async => true,
      );

  final checked = <QuotaMonitorTarget>[];
  final done = Completer<void>();

  @override
  Future<void> refreshSource(QuotaMonitorTarget target) {
    checked.add(target);
    return done.future;
  }
}

class _HeldConnection extends ConnectionController {
  _HeldConnection(super.store) : held = _HeldMonitor(store);
  final _HeldMonitor held;

  @override
  ProviderQuotaMonitor get quotaMonitor => held;
}

Widget _section(ConnectionController connection, {VoidCallback? onOpen}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: QuotaMonitorSection(
        controller: connection,
        onOpenNotifications: onOpen ?? () {},
      ),
    );

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: ListView(children: [child])),
);

Future<void> _finish(WidgetTester tester, ConnectionController c) async {
  await tester.pumpWidget(const SizedBox.shrink());
  c.quotaMonitor.dispose();
  c.dispose();
  await tester.pump();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('quota monitoring section', () {
    testWidgets('a monitored source shows its server, origin, state, '
        'threshold and actions', (tester) async {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await _connection();
      await tester.pumpWidget(_app(_section(c)));
      await tester.pumpAndSettle();

      expect(find.text(_en.quotaMonitorTitle), findsOneWidget);
      expect(
        find.text(_en.quotaSourceTitle('Workstation', _en.quotaCodex)),
        findsOneWidget,
      );
      expect(find.text(_baseUrl), findsOneWidget);
      expect(find.text(_en.quotaMonitorSourceChanged), findsOneWidget);
      expect(find.text(_en.quotaMonitorThreshold), findsOneWidget);
      expect(find.text(_en.quotaBudgetPercent('90')), findsOneWidget);
      // The page's own Refresh reads again; the card has none of its own.
      expect(find.text(_en.quotaRefresh), findsNothing);
      // Stop names the provider and server it acts on.
      expect(
        find.text(_en.quotaMonitorDisable(_en.quotaCodex, 'Workstation')),
        findsOneWidget,
      );
      expect(find.text(_en.quotaMonitorEmpty), findsNothing);
      // Quota alerts is a row that says what it opens.
      expect(find.text(_en.quotaAlertsRowTitle), findsOneWidget);
      expect(find.text(_en.quotaAlertsRowSupporting), findsOneWidget);
      // G1: a failed save is said in place, never a SnackBar.
      expect(find.byType(SnackBar), findsNothing);
      await _finish(tester, c);
    });

    testWidgets('the threshold menu saves only the threshold', (tester) async {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await _connection();
      await tester.pumpWidget(_app(_section(c)));
      await tester.pumpAndSettle();

      await tester.tap(_key('quota-threshold-profile-1-codex'));
      await tester.pumpAndSettle();
      // Every choice is offered, the current one checked.
      for (final value in ['50', '75', '90', '100']) {
        expect(find.text(_en.quotaBudgetPercent(value)), findsWidgets);
      }
      await tester.tap(find.text(_en.quotaBudgetPercent('75')).last);
      await tester.pumpAndSettle();

      final rules = c.quotaMonitor.rulesFor('profile-1', QuotaProvider.codex)!;
      expect(rules.threshold, 75);
      expect(rules.notifications, isTrue);
      expect(rules.wifiOnly, isTrue);
      expect(rules.quietStart, 22 * 60);
      expect(find.text(_en.quotaBudgetPercent('75')), findsOneWidget);
      await _finish(tester, c);
    });

    testWidgets('the source the page already shows is not listed again', (
      tester,
    ) async {
      final c = await _connection();
      await tester.pumpWidget(
        _app(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: QuotaMonitorSection(
              controller: c,
              onOpenNotifications: () {},
              shownAbove: const QuotaMonitorTarget(
                'profile-1',
                QuotaProvider.codex,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('quota-source-profile-1-codex'), findsNothing);
      // It is monitored, so the empty state does not claim otherwise.
      expect(find.text(_en.quotaMonitorEmpty), findsNothing);
      await _finish(tester, c);
    });

    testWidgets('Quota alerts opens the shared settings', (tester) async {
      final c = await _connection();
      var opened = 0;
      await tester.pumpWidget(_app(_section(c, onOpen: () => opened++)));
      await tester.pumpAndSettle();
      await tester.tap(_key('quota-monitor-notification-settings'));
      expect(opened, 1);
      await _finish(tester, c);
    });

    testWidgets('Check now reads that one source, named with its provider and '
        'server, and says so while it runs', (tester) async {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = await _connection();
      final c = _HeldConnection(base.store);
      base.dispose();
      await tester.pumpWidget(_app(_section(c)));
      await tester.pumpAndSettle();

      final row = _key('quota-check-now-profile-1-codex');
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            _en.quotaMonitorCheckNow(_en.quotaCodex, 'Workstation'),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pump();
      expect(c.held.checked, hasLength(1));
      expect(c.held.checked.single.profileID, 'profile-1');
      expect(c.held.checked.single.provider, QuotaProvider.codex);
      expect(
        find.descendant(of: row, matching: find.text(_en.quotaMonitorChecking)),
        findsOneWidget,
      );
      // One read at a time: a second tap while it runs does nothing.
      await tester.tap(row, warnIfMissed: false);
      await tester.pump();
      expect(c.held.checked, hasLength(1));

      c.held.done.complete();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row, matching: find.text(_en.quotaMonitorChecking)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      c.held.dispose();
      c.dispose();
      await tester.pump();
    });

    testWidgets('Stop monitoring removes the source and the empty state says '
        'how to add one', (tester) async {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await _connection();
      await tester.pumpWidget(_app(_section(c)));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(_en.quotaMonitorDisable(_en.quotaCodex, 'Workstation')),
      );
      // The save clears the source's device alert (a platform call) before
      // it notifies; let that real async work finish.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(c.quotaMonitor.sources, isEmpty);
      expect(find.text(_en.quotaMonitorEmpty), findsOneWidget);
      expect(find.text(_en.quotaMonitorThreshold), findsNothing);
      await _finish(tester, c);
    });
  });

  group('gallery', () {
    setUpAll(loadKitGalleryFonts);
    const sizes = {'': Size(412, 915), '_1280x800': Size(1280, 800)};
    for (final monitored in [true, false]) {
      final state = monitored ? 'source' : 'empty';
      for (final MapEntry(key: suffix, value: size) in sizes.entries) {
        for (final light in [true, false]) {
          final name =
              'goldens/usage_quota_monitor_$state${suffix}_'
              '${light ? 'light' : 'dark'}';
          testWidgets(name, (tester) async {
            final c = await _connection(monitored: monitored);
            await kitGalleryPart(
              tester,
              name: name,
              size: size,
              light: light,
              child: _section(c),
            );
            await _finish(tester, c);
          });
        }
      }
    }
  });
}
