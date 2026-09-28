import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart' show Health;
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/provider_quota_overview.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/provider_quota_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../tool/capture/fixtures.dart'
    show capturePng, captureTheme, loadCaptureFonts;
import 'provider_quota_test.dart' show providerQuotaFixture;

final _epoch = DateTime.utc(2026, 9, 6, 12);
final _l10n = lookupAppLocalizations(const Locale('en'));
const _password = 'fixture-only-quota-screen-password';
const _privateError = 'fixture-private-provider-error';
const _origin = 'https://collector.example:8443';

class _NoHttp extends HttpOverrides {
  int clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    throw StateError('Quota widget tests must not create HTTP clients');
  }
}

class _Gateway implements ProviderQuotaGateway {
  final result = Completer<ProviderQuotaSnapshot>();
  int reads = 0;
  int closes = 0;

  @override
  Future<ProviderQuotaSnapshot> readSnapshot() {
    reads++;
    return result.future;
  }

  @override
  void close() {
    closes++;
    // Intentionally still completable: cancellation must also reject late data.
  }
}

class _HealthGateway implements ServerGateway {
  int healthCalls = 0;

  @override
  Future<Health> health() async {
    healthCalls++;
    return Health(healthy: true, version: 'fixture-v1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected OpenCode call in a quota widget test');
}

class _Connection extends ConnectionController {
  _Connection(super.store);

  final healthGateway = _HealthGateway();
  bool allowSettingsHealth = false;
  int transportCalls = 0;
  int repositoryCalls = 0;
  int wakeCalls = 0;

  @override
  Future<ServerGateway?> prepareActionTransport() async {
    transportCalls++;
    if (allowSettingsHealth) return healthGateway;
    throw StateError('Quota must not use the OpenCode action transport');
  }

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async {
    repositoryCalls++;
    throw StateError('Quota must not read OpenCode provider configuration');
  }

  @override
  Future<void> resumeFromLifecycle() async {
    wakeCalls++;
    throw StateError('Quota must not wake or probe OpenCode');
  }

  void signal() => notifyListeners();
}

class _Harness {
  final _Connection connection;
  late final ProviderQuotaOverview overview;
  final gateways = <_Gateway>[];
  DateTime now = _epoch;

  _Harness(this.connection) {
    overview = ProviderQuotaOverview(
      connection,
      clock: () => now,
      gatewayFactory: (_) {
        final gateway = _Gateway();
        gateways.add(gateway);
        return gateway;
      },
    );
  }

  void disposeOverview() {
    overview.dispose();
    for (final gateway in gateways) {
      if (!gateway.result.isCompleted) {
        gateway.result.complete(_snapshot(at: now));
      }
    }
  }
}

/// An injected overview belongs to its caller, not ProviderQuotaScreen. Release
/// it on unmount, BEFORE the binding checks for pending timers: addTearDown
/// alone runs after those invariant checks.
class _OverviewOwner extends StatefulWidget {
  final ProviderQuotaOverview overview;
  final Widget child;

  const _OverviewOwner({required this.overview, required this.child});

  @override
  State<_OverviewOwner> createState() => _OverviewOwnerState();
}

class _OverviewOwnerState extends State<_OverviewOwner> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.overview.dispose();
    super.dispose();
  }
}

ProviderQuotaSnapshot _snapshot({
  double usedPercent = 25.5,
  QuotaProvider provider = QuotaProvider.codex,
  DateTime? at,
  void Function(Map<String, dynamic>)? configure,
}) {
  // Clone through JSON to model wire map types, without mutating the shared
  // handwritten fixture (whose tests are owned by the state agent).
  final value =
      jsonDecode(
            jsonEncode(
              providerQuotaFixture(
                fetchedAtMs: (at ?? _epoch).millisecondsSinceEpoch,
                provider: provider,
              ),
            ),
          )
          as Map<String, dynamic>;
  ((value['windows'] as List).first as Map<String, dynamic>)['usedPercent'] =
      usedPercent;
  configure?.call(value);
  return ProviderQuotaSnapshot.fromJson(value);
}

Finder get _readButton => find.byKey(const ValueKey('quota-read'));
Finder get _consentSwitch => find.byKey(const ValueKey('quota-consent'));
Finder get _retryButton => find.byKey(const ValueKey('quota-retry'));
Finder get _stopButton => find.byKey(const ValueKey('quota-stop'));
Finder get _refreshIcon => find.byKey(const ValueKey('quota-refresh'));
Finder get _primaryBar =>
    find.byKey(const ValueKey('quota-window-bar-primary'));

Future<void> _frames(WidgetTester tester) async {
  // Bounded even when the controlled read leaves an indeterminate bar visible.
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finishRouteAnimation(
  WidgetTester tester,
  Animation<double> animation,
  AnimationStatus target,
) async {
  // A new route first lays out offstage and may start its ticker on a later
  // frame. Wait for THIS finite animation, not all frames from live widgets.
  for (var frame = 0; frame < 40 && animation.status != target; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    animation.status,
    target,
    reason: 'Navigation must finish within the bounded two-second frame budget',
  );
  // Let removal of a dismissed route reach the element tree.
  await tester.pump();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double alignment = 0,
}) async {
  if (target.evaluate().isEmpty) {
    // The list is lazy and, with the monitoring section at its end, long: a
    // row above the current position is not built. Search from the top.
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
  }
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      160,
      maxScrolls: 60,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: alignment);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _pumpHome(
  WidgetTester tester,
  Widget home, {
  ProviderQuotaOverview? ownedOverview,
  Size size = const Size(420, 1100),
  double textScale = 1,
  double keyboardInset = 0,
  Brightness brightness = Brightness.light,
  bool reducedMotion = false,
}) async {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: ownedOverview == null
          ? home
          : _OverviewOwner(overview: ownedOverview, child: home),
    ),
  );
  await _frames(tester);
}

Future<void> _pumpQuota(WidgetTester tester, _Harness h) => _pumpHome(
  tester,
  ProviderQuotaScreen(controller: h.connection, overview: h.overview),
  ownedOverview: h.overview,
);

Future<void> _consentAndRead(WidgetTester tester, _Harness h) async {
  final before = h.gateways.length;
  await _reveal(tester, _consentSwitch);
  await tester.tap(_consentSwitch);
  await tester.pump();
  expect(h.gateways, hasLength(before), reason: 'Consent alone is not a read');
  await _reveal(tester, _readButton);
  await tester.tap(_readButton);
  await tester.pump();
  expect(h.gateways, hasLength(before + 1));
  expect(h.gateways.last.reads, 1);
}

Future<void> _finishRead(
  WidgetTester tester,
  _Harness h,
  ProviderQuotaSnapshot snapshot,
) async {
  h.gateways.last.result.complete(snapshot);
  await _frames(tester);
}

Future<void> _refresh(WidgetTester tester, _Harness h) async {
  final before = h.gateways.length;
  await tester.tap(_refreshIcon);
  await tester.pump();
  expect(h.gateways, hasLength(before + 1));
}

void _expectNoPrivateCopy() {
  for (final value in [_password, _privateError, 'a' * 64]) {
    expect(find.textContaining(value), findsNothing);
  }
}

bool _focusWithin(Finder target) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element) return false;
  final elements = target.evaluate().toSet();
  var found = elements.contains(context);
  context.visitAncestorElements((element) {
    found = found || elements.contains(element);
    return !found;
  });
  return found;
}

Future<void> _tabTo(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 12 && !_focusWithin(target); attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(
    _focusWithin(target),
    isTrue,
    reason: 'Control must be keyboard reachable',
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const backgroundChannel = MethodChannel('oc/background');
  const termuxChannel = MethodChannel('oc/termux');
  late List<String> secureMethods;

  setUp(() {
    final previousPreferences = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previousPreferences;
      SharedPreferences.resetStatic();
    });
    SharedPreferences.setMockInitialValues({});

    final previousHttp = HttpOverrides.current;
    final http = _NoHttp();
    addTearDown(() => HttpOverrides.global = previousHttp);
    HttpOverrides.global = http;
    addTearDown(() => expect(http.clients, 0));

    secureMethods = [];
    final secureValues = <String, String>{};
    addTearDown(() => messenger.setMockMethodCallHandler(secureChannel, null));
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      secureMethods.add(call.method);
      final arguments = call.arguments as Map;
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'read':
          return secureValues[key];
        case 'write':
          secureValues[key] = arguments['value'] as String;
        case 'delete':
          secureValues.remove(key);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(backgroundChannel, null),
    );
    messenger.setMockMethodCallHandler(backgroundChannel, (_) async => null);
    var termuxCalls = 0;
    addTearDown(() => messenger.setMockMethodCallHandler(termuxChannel, null));
    messenger.setMockMethodCallHandler(termuxChannel, (_) async {
      termuxCalls++;
      throw StateError(
        'Quota UI must not read login files or install services',
      );
    });
    addTearDown(() => expect(termuxCalls, 0));

    // Restore even if a pause/loading assertion fails before its resumed step.
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  Future<_Harness> harness(
    WidgetTester tester, {
    void Function(ServerProfile)? configure,
  }) async {
    final store = ProfileStore(prefs: await SharedPreferences.getInstance());
    final profile = ServerProfile(
      id: 'quota-profile-a',
      name: 'Synthetic collector',
      baseUrl: _origin,
      username: 'fixture-user',
      password: _password,
    );
    configure?.call(profile);
    await store.upsert(profile);
    await store.upsert(
      ServerProfile(
        id: 'quota-profile-b',
        name: 'Other synthetic collector',
        baseUrl: 'https://other.example:8443',
        username: 'fixture-user',
        password: 'fixture-only-other-password',
      ),
    );
    await store.setActiveId(profile.id);
    final secureCallsAfterSetup = secureMethods.length;
    addTearDown(() {
      expect(secureMethods, hasLength(secureCallsAfterSetup));
      expect(secureMethods.where((method) => method == 'read'), isEmpty);
    });

    final connection = _Connection(store);
    addTearDown(connection.dispose);
    final h = _Harness(connection);
    addTearDown(h.disposeOverview);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      // The quota screens never read the repository. The Settings hub does,
      // exactly once, for its own Default shell row; that read is not quota's.
      expect(
        connection.repositoryCalls,
        connection.allowSettingsHealth ? 1 : 0,
      );
      expect(connection.wakeCalls, 0);
      expect(connection.transportCalls, connection.allowSettingsHealth ? 1 : 0);
    });
    return h;
  }

  testWidgets('first visit requires both consent and an explicit read', (
    tester,
  ) async {
    final h = await harness(tester);
    final prefs = h.connection.store.prefs;
    final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    await _pumpQuota(tester, h);

    expect(
      find.text(_l10n.quotaNeedsCollector('Synthetic collector')),
      findsOneWidget,
    );
    await _reveal(tester, find.byKey(const ValueKey('quota-details')));
    await tester.tap(find.text('Details'));
    await _frames(tester);
    // The collector's address is a technical value, in Details only.
    expect(find.textContaining(_origin), findsOneWidget);
    expect(find.textContaining(providerQuotaPath), findsOneWidget);
    expect(find.text(_l10n.quotaCollectorHowTo), findsOneWidget);
    expect(_l10n.quotaCollectorStepInstall('x'), isNot(contains('tool/quota')));
    await _reveal(tester, _consentSwitch);
    expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
    expect(tester.widget<KitButton>(_readButton).onPressed, isNull);
    expect(_refreshIcon, findsNothing);
    await _reveal(tester, _readButton);
    await tester.tap(_readButton);
    await tester.pump(const Duration(seconds: 2));
    expect(h.gateways, isEmpty);

    await _consentAndRead(tester, h);
    expect(h.overview.loading, isTrue);
    await _frames(tester);
    expect(
      tester.widget<KitTopBar>(find.byType(KitTopBar)).actions.single.onPressed,
      isNull,
    );
    expect(find.text(_l10n.quotaLoading), findsOneWidget);
    expect(tester.widget<KitScreen>(find.byType(KitScreen)).loading, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(h.gateways, hasLength(1), reason: 'No polling or duplicate read');
    await _finishRead(tester, h, _snapshot());
    expect(find.textContaining('About 75% left'), findsOneWidget);
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    _expectNoPrivateCopy();
  });

  testWidgets(
    'unsafe source configuration cannot enable consent or leak URL copy',
    (tester) async {
      final h = await harness(
        tester,
        configure: (profile) =>
            profile.baseUrl = '$_origin/?token=$_privateError',
      );
      await _pumpQuota(tester, h);
      await _reveal(tester, _consentSwitch);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quota-setup-needed')),
          matching: find.text(_l10n.quotaSetupNeeded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(_consentSwitch).onChanged, isNull);
      expect(tester.widget<KitButton>(_readButton).onPressed, isNull);
      expect(h.gateways, isEmpty);
      // Only the origin is shown, in Details; the query never is.
      await _reveal(tester, find.byKey(const ValueKey('quota-details')));
      await tester.tap(find.text('Details'));
      await _frames(tester);
      expect(find.textContaining(_origin), findsOneWidget);
      _expectNoPrivateCopy();
    },
  );

  for (final sample in [
    (used: 0.0, remaining: '100%', progress: 0.0, usedLabel: '0%'),
    (used: 100.0, remaining: '0%', progress: 1.0, usedLabel: '100%'),
    (used: 25.5, remaining: '75%', progress: .255, usedLabel: '25.5%'),
  ]) {
    testWidgets('${sample.used}% used displays ${sample.remaining} remaining', (
      tester,
    ) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot(usedPercent: sample.used));
      expect(
        find.textContaining('About ${sample.remaining} left'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          _l10n.quotaUsed(sample.usedLabel),
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<KitProgressRow>(_primaryBar).value,
        closeTo(sample.progress, .000001),
      );
      final progress = tester.getSemantics(_primaryBar).getSemanticsData();
      expect(progress.label, contains('About ${sample.remaining} left'));
      expect(progress.label, contains('${sample.usedLabel} used'));
      expect(find.text(_l10n.quotaUseBlocked), findsNothing);
      _expectNoPrivateCopy();
    });
  }

  testWidgets(
    'missing windows and explicit null reset replace old measurements honestly',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot());
      expect(find.textContaining('5-hour window'), findsOneWidget);

      await _refresh(tester, h);
      await _finishRead(
        tester,
        h,
        _snapshot(
          configure: (value) {
            final primary =
                (value['windows'] as List).first as Map<String, dynamic>;
            primary['durationSeconds'] = null;
            primary['resetsAtMs'] = null;
          },
        ),
      );
      expect(find.textContaining('About 75% left'), findsOneWidget);
      expect(find.byType(KitProgressRow), findsOneWidget);
      expect(find.textContaining('resets'), findsNothing);
      expect(find.textContaining('Reported reset:'), findsNothing);
      expect(find.textContaining('5-hour window'), findsNothing);

      await _refresh(tester, h);
      await _finishRead(
        tester,
        h,
        _snapshot(
          configure: (value) {
            value['windows'] = <Map<String, dynamic>>[
              {
                'id': 'primary',
                'status': 'missing',
                'usedPercent': null,
                'durationSeconds': null,
                'resetsAtMs': null,
              },
              {'id': 'secondary', 'status': 'missing'},
            ];
          },
        ),
      );
      // Windows the collector did not report are left out; the reading
      // says in words that no limit was reported (slice-close-misc).
      expect(
        find.text(
          _l10n.quotaCollectorNoWindows(
            _l10n.quotaCodex,
            'Synthetic collector',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('resets'), findsNothing);
      expect(find.byType(KitProgressRow), findsNothing);
      expect(find.textContaining('% left'), findsNothing);

      await _refresh(tester, h);
      await _finishRead(
        tester,
        h,
        _snapshot(
          configure: (value) {
            value['windows'] = <Map<String, dynamic>>[];
          },
        ),
      );
      expect(
        find.text(
          _l10n.quotaCollectorNoWindows(
            _l10n.quotaCodex,
            'Synthetic collector',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(KitProgressRow), findsNothing);
    },
  );

  testWidgets(
    'failed refresh retains a labelled stale result and retry replaces it',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      final previous = _snapshot();
      await _finishRead(tester, h, previous);
      await _refresh(tester, h);
      expect(find.textContaining('About 75% left'), findsOneWidget);
      h.gateways.last.result.completeError(StateError(_privateError));
      await _frames(tester);

      expect(find.text(_l10n.quotaUnavailable), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quota-stale')),
          matching: find.text(_l10n.quotaStale),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('About 75% left'), findsOneWidget);
      expect(h.overview.snapshot, same(previous));
      _expectNoPrivateCopy();
      await _reveal(tester, _retryButton);
      await tester.tap(_retryButton);
      await tester.pump();
      expect(h.gateways, hasLength(3));
      await _finishRead(tester, h, _snapshot(usedPercent: 50));
      expect(find.textContaining('About 50% left'), findsOneWidget);
      expect(find.textContaining('About 75% left'), findsNothing);
      expect(find.text(_l10n.quotaUnavailable), findsNothing);
      expect(find.text(_l10n.quotaStale), findsNothing);
    },
  );

  testWidgets(
    'provider statuses and account mismatch replace allowances with safe copy',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot());
      final cases = [
        (
          ProviderQuotaStatus.ok,
          QuotaAccountStatus.mismatch,
          _l10n.quotaAccountUnverified,
        ),
        (
          ProviderQuotaStatus.ok,
          QuotaAccountStatus.unverified,
          _l10n.quotaAccountUnverified,
        ),
        (
          ProviderQuotaStatus.unconfigured,
          QuotaAccountStatus.unverified,
          _l10n.quotaUnconfigured,
        ),
        (
          ProviderQuotaStatus.unsupported,
          QuotaAccountStatus.unverified,
          _l10n.quotaProviderUnsupported,
        ),
        (
          ProviderQuotaStatus.authRequired,
          QuotaAccountStatus.unverified,
          _l10n.quotaProviderAuth,
        ),
        (
          ProviderQuotaStatus.rateLimited,
          QuotaAccountStatus.unverified,
          _l10n.quotaRateLimited,
        ),
        (
          ProviderQuotaStatus.unavailable,
          QuotaAccountStatus.unverified,
          _l10n.quotaUnavailable,
        ),
        (
          ProviderQuotaStatus.invalidResponse,
          QuotaAccountStatus.unverified,
          _l10n.quotaInvalidResponse,
        ),
      ];
      for (final (status, account, label) in cases) {
        await _refresh(tester, h);
        await _finishRead(
          tester,
          h,
          _snapshot(
            configure: (value) {
              value['status'] = status.name;
              value['freshness'] = 'none';
              value['ordinaryUsageAllowed'] = null;
              value['windows'] = <Map<String, dynamic>>[];
              value['account'] = <String, dynamic>{'status': account.name};
              value['error'] = _privateError;
            },
          ),
        );
        expect(
          find.text(label),
          findsOneWidget,
          reason: '${status.name}/${account.name}',
        );
        expect(find.text(_l10n.quotaCollectorAuth), findsNothing);
        expect(find.textContaining('from the quota collector'), findsNothing);
        expect(find.textContaining('% left'), findsNothing);
        expect(find.byType(KitProgressRow), findsNothing);
        _expectNoPrivateCopy();
      }
    },
  );

  testWidgets(
    'collector failures use retry copy distinct from provider sign-in and raw errors',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      final cases = <(Object, String)>[
        (
          const ProviderQuotaFailure(QuotaFailureKind.collectorAuth),
          _l10n.quotaCollectorAuth,
        ),
        (
          const ProviderQuotaFailure(QuotaFailureKind.unsupported),
          _l10n.quotaNeedsCollector('Synthetic collector'),
        ),
        (
          const ProviderQuotaFailure(QuotaFailureKind.unavailable),
          _l10n.quotaUnavailable,
        ),
        (
          const ProviderQuotaFailure(QuotaFailureKind.invalidResponse),
          _l10n.quotaInvalidResponse,
        ),
        (
          const FormatException(_privateError, _password),
          _l10n.quotaInvalidResponse,
        ),
        (StateError(_privateError), _l10n.quotaUnavailable),
      ];
      for (var index = 0; index < cases.length; index++) {
        if (index != 0) await _refresh(tester, h);
        h.gateways.last.result.completeError(cases[index].$1);
        await _frames(tester);
        expect(find.text(cases[index].$2), findsOneWidget);
        expect(find.text(_l10n.quotaProviderAuth), findsNothing);
        expect(find.byType(KitProgressRow), findsNothing);
        // A missing collector is not retried: nothing to retry until it
        // is installed, and the top bar keeps Refresh (slice-close-misc).
        final missing =
            cases[index].$1 is ProviderQuotaFailure &&
            (cases[index].$1 as ProviderQuotaFailure).kind ==
                QuotaFailureKind.unsupported;
        expect(_retryButton, missing ? findsNothing : findsOneWidget);
        _expectNoPrivateCopy();
      }
    },
  );

  for (final changeProfile in [false, true]) {
    testWidgets(
      '${changeProfile ? 'profile' : 'location'} change drops the snapshot and rejects a late read',
      (tester) async {
        final h = await harness(tester);
        await _pumpQuota(tester, h);
        await _consentAndRead(tester, h);
        await _finishRead(tester, h, _snapshot());
        await _refresh(tester, h);
        final oldRead = h.gateways.last;
        if (changeProfile) {
          await h.connection.store.setActiveId('quota-profile-b');
        } else {
          h.connection.locationRevision++;
        }
        h.connection.signal();
        await _frames(tester);
        expect(find.text(_l10n.quotaSourceChanged), findsOneWidget);
        expect(find.textContaining('% left'), findsNothing);
        expect(_refreshIcon, findsNothing);
        expect(_stopButton, findsNothing);
        expect(h.overview.snapshot, isNull);
        expect(h.overview.consented, isFalse);
        expect(oldRead.closes, 1);
        oldRead.result.complete(_snapshot(usedPercent: 1));
        await _frames(tester);
        expect(find.textContaining('About 99% left'), findsNothing);
        expect(h.gateways, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'stop using the collector cancels reads and requires fresh switch consent',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot());
      await _refresh(tester, h);
      final cancelled = h.gateways.last;
      await _reveal(tester, _stopButton);
      await tester.tap(_stopButton);
      await _frames(tester);

      expect(h.overview.snapshot, isNull);
      expect(h.overview.consented, isFalse);
      expect(cancelled.closes, 1);
      expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
      expect(tester.widget<KitButton>(_readButton).onPressed, isNull);
      cancelled.result.complete(_snapshot(usedPercent: 1));
      await _frames(tester);
      expect(find.textContaining('% left'), findsNothing);
      expect(h.gateways, hasLength(2));
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot(usedPercent: 50));
      expect(find.textContaining('About 50% left'), findsOneWidget);
    },
  );

  testWidgets(
    'backgrounding cancels the read and resume waits for manual retry',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot());
      await _refresh(tester, h);
      final cancelled = h.gateways.last;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(cancelled.closes, 1);
      expect(h.overview.canRead, isFalse);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quota-stale')),
          matching: find.text(_l10n.quotaStale),
        ),
        findsOneWidget,
      );
      cancelled.result.complete(_snapshot(usedPercent: 1));
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester);
      expect(h.gateways, hasLength(2));
      expect(find.textContaining('About 75% left'), findsOneWidget);
      expect(find.textContaining('About 99% left'), findsNothing);
      await _refresh(tester, h);
      await _finishRead(tester, h, _snapshot(usedPercent: 50));
      expect(find.textContaining('About 50% left'), findsOneWidget);
    },
  );

  for (final pending in [false, true]) {
    testWidgets(
      'ending an injected visit cancels expiry${pending ? ' and a pending read' : ''}',
      (tester) async {
        final h = await harness(tester);
        await _pumpQuota(tester, h);
        await _consentAndRead(tester, h);
        await _finishRead(tester, h, _snapshot());
        if (pending) await _refresh(tester, h);
        final last = h.gateways.last;
        await tester.pumpWidget(const SizedBox.shrink());
        // _OverviewOwner, not the screen, releases this supplied overview.
        expect(last.closes, 1);
        if (pending) last.result.complete(_snapshot(usedPercent: 1));
        await tester.pump();
        expect(h.overview.snapshot, isNull);
        expect(h.overview.consented, isFalse);
        expect(tester.takeException(), isNull);
        // Do not advance past expiry: the binding must detect a leaked timer.
      },
    );
  }

  testWidgets(
    'passing a reported reset marks stale without refilling or polling',
    (tester) async {
      final h = await harness(tester);
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(
        tester,
        h,
        _snapshot(
          usedPercent: 100,
          configure: (value) {
            ((value['windows'] as List).first
                as Map<String, dynamic>)['resetsAtMs'] = h.now
                .add(const Duration(seconds: 2))
                .millisecondsSinceEpoch;
          },
        ),
      );
      expect(find.textContaining('About 0% left'), findsOneWidget);
      expect(find.textContaining(_l10n.quotaAnswerResetPassed), findsNothing);
      h.now = h.now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(_l10n.quotaAnswerResetPassed), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quota-stale')),
          matching: find.text(_l10n.quotaStale),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('About 0% left'), findsOneWidget);
      expect(find.textContaining('About 100% left'), findsNothing);
      expect(tester.widget<KitProgressRow>(_primaryBar).value, 1);
      expect(h.gateways, hasLength(1));
    },
  );

  testWidgets(
    '360x740 at 2.5x with a 320dp keyboard keeps every action reachable',
    (tester) async {
      final h = await harness(tester);
      await _pumpHome(
        tester,
        ProviderQuotaScreen(controller: h.connection, overview: h.overview),
        ownedOverview: h.overview,
        size: const Size(360, 740),
        textScale: 2.5,
        keyboardInset: 320,
        reducedMotion: true,
      );
      final media = MediaQuery.of(
        tester.element(find.byType(ProviderQuotaScreen)),
      );
      expect(media.size, const Size(360, 740));
      expect(media.textScaler.scale(16), 40);
      expect(media.viewInsets.bottom, 320);
      expect(media.disableAnimations, isTrue);

      await _consentAndRead(tester, h);
      await _reveal(tester, _stopButton);
      expect(tester.getRect(_stopButton).bottom, lessThanOrEqualTo(420));
      h.gateways.last.result.completeError(StateError(_privateError));
      await _frames(tester);
      await _reveal(tester, _retryButton);
      expect(tester.getRect(_retryButton).bottom, lessThanOrEqualTo(420));
      expect(_refreshIcon.hitTestable(), findsOneWidget);
      await tester.tap(_retryButton);
      await tester.pump();
      await _finishRead(tester, h, _snapshot());
      await _reveal(tester, find.textContaining('About 75% left'));
      await _reveal(tester, _stopButton);
      await tester.tap(_stopButton);
      await _frames(tester);
      await _reveal(tester, _consentSwitch);
      expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
      await _reveal(tester, _readButton);
      expect(tester.getRect(_readButton).bottom, lessThanOrEqualTo(420));
      expect(tester.widget<KitButton>(_readButton).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard consent and read remain separate accessible actions', (
    tester,
  ) async {
    final h = await harness(tester);
    await _pumpQuota(tester, h);
    await _reveal(tester, _consentSwitch);
    await _tabTo(tester, _consentSwitch);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(tester.widget<Switch>(_consentSwitch).value, isTrue);
    expect(h.gateways, isEmpty);
    await _tabTo(tester, _readButton);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.gateways, hasLength(1));
    await _finishRead(tester, h, _snapshot());
    expect(find.textContaining('About 75% left'), findsOneWidget);
  });

  testWidgets(
    'MiniMax requires consent and identifies its subscription-key source',
    (tester) async {
      final h = await harness(tester);
      await _pumpHome(
        tester,
        ProviderQuotaScreen(controller: h.connection, overview: h.overview),
        ownedOverview: h.overview,
        size: const Size(420, 1600),
      );
      final minimax = find.byKey(const ValueKey('quota-provider-minimax'));
      await _reveal(tester, minimax);
      await tester.tap(minimax);
      await _frames(tester);
      expect(h.gateways, isEmpty);
      expect(h.overview.consented, isFalse);
      await _reveal(tester, find.byKey(const ValueKey('quota-details')));
      await tester.tap(find.text('Details'));
      await _frames(tester);
      expect(find.textContaining('/ocmn/quota/v1/minimax'), findsOneWidget);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot(provider: QuotaProvider.minimax));
      expect(
        find.text(
          _l10n.quotaCollectorFrom(_l10n.quotaMiniMax, 'Synthetic collector'),
        ),
        findsOneWidget,
      );
      // The source-bound caveat is technical: it is said in Details.
      await _reveal(tester, find.byKey(const ValueKey('quota-details')));
      if (find.text(_l10n.quotaMiniMaxSourceBound).evaluate().isEmpty) {
        await tester.tap(find.text('Details'));
        await _frames(tester);
      }
      expect(find.text(_l10n.quotaMiniMaxSourceBound), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} quota semantics and 48dp targets survive reduced motion',
      (tester) async {
        final h = await harness(tester);
        // testWidgets enables and owns the semantics handle for this test.
        await _pumpHome(
          tester,
          ProviderQuotaScreen(controller: h.connection, overview: h.overview),
          ownedOverview: h.overview,
          size: const Size(420, 1400),
          brightness: brightness,
          reducedMotion: true,
        );
        await _consentAndRead(tester, h);
        await _finishRead(tester, h, _snapshot());
        await tester.pump(const Duration(seconds: 1));
        final progress = tester.getSemantics(_primaryBar).getSemanticsData();
        expect(progress.label, contains('About 75% left'));
        expect(progress.label, contains('25.5% used'));
        expect(_refreshIcon.hitTestable(), findsOneWidget);
        expect(_stopButton.hitTestable(), findsOneWidget);
        expect(tester.getSize(_stopButton).height, greaterThanOrEqualTo(48));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.widget<KitProgressRow>(_primaryBar).value, .255);
        expect(h.gateways, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'replacing the screen controller never reuses the prior visit consent or snapshot',
    (tester) async {
      final first = await harness(tester);
      final second = _Harness(_Connection(first.connection.store));
      addTearDown(second.connection.dispose);
      final current = ValueNotifier(first);
      addTearDown(current.dispose);
      try {
        await _pumpHome(
          tester,
          ValueListenableBuilder<_Harness>(
            valueListenable: current,
            builder: (context, h, _) => ProviderQuotaScreen(
              controller: h.connection,
              overview: h.overview,
            ),
          ),
        );
        await _consentAndRead(tester, first);
        await _finishRead(tester, first, _snapshot());
        current.value = second;
        await _frames(tester);
        expect(find.textContaining('from the quota collector'), findsNothing);
        expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
        expect(second.gateways, isEmpty);
        expect(second.overview.consented, isFalse);
      } finally {
        first.disposeOverview();
        second.disposeOverview();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'changing provider requires fresh consent and never relabels a late Codex read',
    (tester) async {
      final h = await harness(tester);
      await _pumpHome(
        tester,
        ProviderQuotaScreen(controller: h.connection, overview: h.overview),
        ownedOverview: h.overview,
        size: const Size(420, 1600),
      );
      await _consentAndRead(tester, h);
      final old = h.gateways.last;
      final claude = find.byKey(const ValueKey('quota-provider-claude'));
      await _reveal(tester, claude);
      await tester.tap(claude);
      await _frames(tester);
      expect(old.closes, 1);
      expect(h.overview.consented, isFalse);
      expect(_consentSwitch, findsNothing);
      expect(find.text(_l10n.quotaClaudeUnavailable), findsOneWidget);
      old.result.complete(_snapshot());
      await _frames(tester);
      expect(find.textContaining('from the quota collector'), findsNothing);
      expect(h.gateways, hasLength(1));
      await h.overview.allowAndRefresh();
      await _frames(tester);
      expect(h.gateways, hasLength(1));
      expect(_readButton, findsNothing);
      expect(find.textContaining('from the quota collector'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} Claude stays unavailable and returning to Codex requires fresh consent at 360x740 and 2.5x',
      (tester) async {
        final h = await harness(tester);
        await _pumpHome(
          tester,
          ProviderQuotaScreen(controller: h.connection, overview: h.overview),
          ownedOverview: h.overview,
          size: const Size(360, 740),
          textScale: 2.5,
          keyboardInset: 320,
          brightness: brightness,
          reducedMotion: true,
        );
        await _consentAndRead(tester, h);
        await _finishRead(tester, h, _snapshot());
        // Reposition without a pull-to-refresh gesture: this case tests
        // provider selection, which must never dispatch another quota read.
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await _frames(tester);
        final claude = find.byKey(const ValueKey('quota-provider-claude'));
        await _reveal(tester, claude);
        expect(tester.getSize(claude).height, greaterThanOrEqualTo(48));
        // The segmented group has one Tab stop; arrows reach its other choices.
        await _tabTo(
          tester,
          find.byKey(const ValueKey('quota-provider-codex')),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(_focusWithin(claude), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await _frames(tester);
        expect(h.overview.provider, QuotaProvider.claude);
        expect(h.overview.consented, isFalse);
        expect(h.overview.snapshot, isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        final notice = find.text(_l10n.quotaClaudeUnavailable);
        // This paragraph is taller than the keyboard-reduced viewport. Center
        // it for the hit-test without requiring all of its text to fit at once.
        await _reveal(tester, notice, alignment: .5);
        expect(
          tester.getSemantics(notice),
          isSemantics(label: _l10n.quotaClaudeUnavailable, isLiveRegion: true),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(_consentSwitch, findsNothing);
        expect(_readButton, findsNothing);
        expect(_retryButton, findsNothing);
        expect(_stopButton, findsNothing);
        expect(_refreshIcon, findsNothing);
        expect(h.gateways, hasLength(1));
        expect(h.gateways.single.reads, 1);

        // Reposition without a pull-to-refresh gesture: this case tests
        // provider selection, which must never dispatch another quota read.
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await _frames(tester);
        final codex = find.byKey(const ValueKey('quota-provider-codex'));
        await _reveal(tester, codex);
        await _tabTo(tester, claude);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(_focusWithin(codex), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await _frames(tester);
        expect(h.overview.provider, QuotaProvider.codex);
        expect(h.overview.consented, isFalse);
        await _reveal(tester, _consentSwitch);
        expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
        await _reveal(tester, _readButton);
        expect(tester.widget<KitButton>(_readButton).onPressed, isNull);
        expect(h.gateways, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Settings opens Usage at Remaining for a saved v1 profile without quota probing',
    (tester) async {
      final h = await harness(tester);
      h.connection.allowSettingsHealth = true;
      expect(h.connection.serverFlavor.name, 'v1');
      expect(h.connection.supportsUsageStatistics, isFalse);
      await _pumpHome(tester, SettingsScreen(controller: h.connection));
      expect(h.connection.healthGateway.healthCalls, 1);
      // One Usage row; a v1 server has no "Spent", so the screen is the
      // Remaining section alone, with no tab bar.
      expect(
        find.byKey(const ValueKey('settings-category-quota')),
        findsNothing,
      );
      final quotaRow = find.byKey(const ValueKey('settings-category-usage'));
      final quotaPageIncludingTransition = find.byType(
        ProviderQuotaScreen,
        skipOffstage: false,
      );
      await _reveal(tester, quotaRow);
      await tester.tap(quotaRow);
      await tester.pump();
      final quotaRoute = ModalRoute.of(
        tester.element(quotaPageIncludingTransition),
      )!;
      final quotaAnimation = quotaRoute.animation!;
      await _finishRouteAnimation(
        tester,
        quotaAnimation,
        AnimationStatus.completed,
      );
      expect(find.byType(ProviderQuotaScreen), findsOneWidget);
      expect(find.byType(UsageHubScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('usage-section-remaining')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('usage-section-spent')), findsNothing);
      expect(find.byType(KitTabSwitcher), findsNothing);
      expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
      expect(tester.widget<KitButton>(_readButton).onPressed, isNull);
      expect(h.gateways, isEmpty);
      await tester.pageBack();
      await tester.pump();
      await _finishRouteAnimation(
        tester,
        quotaAnimation,
        AnimationStatus.dismissed,
      );
      expect(quotaPageIncludingTransition, findsNothing);
      await _reveal(tester, quotaRow);
      await tester.tap(quotaRow);
      await tester.pump();
      final reopenedRoute = ModalRoute.of(
        tester.element(quotaPageIncludingTransition),
      )!;
      await _finishRouteAnimation(
        tester,
        reopenedRoute.animation!,
        AnimationStatus.completed,
      );
      expect(tester.widget<Switch>(_consentSwitch).value, isFalse);
      expect(_refreshIcon, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monitoring requires separate consent and is reviewed and disabled in place',
    (tester) async {
      final h = await harness(tester);
      h.now = DateTime.now();
      await _pumpQuota(tester, h);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot(at: h.now));
      expect(h.connection.quotaMonitor.sources, isEmpty);
      // One row names what it turns on and what that does; no sheet or
      // dialog asks again (the enrol dialog merged into the page,
      // slice-P3.11a).
      final enable = find.byKey(const ValueKey('quota-enable-monitoring'));
      await _reveal(tester, enable);
      expect(
        find.text(
          _l10n.quotaMonitorOffer(_l10n.quotaCodex, 'Synthetic collector'),
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(enable);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(h.connection.quotaMonitor.sources, hasLength(1));
      final rules = h.connection.quotaMonitor.rulesFor(
        'quota-profile-a',
        QuotaProvider.codex,
      )!;
      expect(rules.notifications, isFalse);
      // Alerts, Wi-Fi only and quiet hours are not asked here, nor offered on
      // the source: they are shared and live in Notifications.
      expect(find.byType(Switch), findsNothing);
      // The threshold stays with the source.
      expect(
        find.byKey(
          const ValueKey('quota-threshold-quota-profile-a-codex'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(h.connection.store.activeId, 'quota-profile-a');
      final disable = find.text(
        _l10n.quotaMonitorDisable(_l10n.quotaCodex, 'Synthetic collector'),
      );
      await _reveal(tester, disable);
      await tester.tap(disable);
      await tester.pumpAndSettle();
      expect(h.connection.quotaMonitor.sources, isEmpty);
      h.connection.quotaMonitor.dispose();
    },
  );

  final capturePath = Platform.environment['OC_QUOTA_CAPTURE'];
  testWidgets(
    'synthetic remaining usage rendered preview',
    (tester) async {
      // Opt-in only, with a pre-existing output directory. This is a synthetic
      // widget rendering, not a device capture or an automatically updated golden.
      final output = File(capturePath!);
      expect(
        output.parent.existsSync(),
        isTrue,
        reason:
            'Verify/create the capture parent before setting OC_QUOTA_CAPTURE',
      );
      final h = await harness(tester);
      await loadCaptureFonts();
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 1100);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: captureTheme(light: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: _OverviewOwner(
              overview: h.overview,
              child: ProviderQuotaScreen(
                controller: h.connection,
                overview: h.overview,
              ),
            ),
          ),
        ),
      );
      await _frames(tester);
      await _consentAndRead(tester, h);
      await _finishRead(tester, h, _snapshot());
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('About 75% left'), findsOneWidget);
      // An unreported window is left out (slice-close-misc).
      expect(find.text('Not reported'), findsNothing);
      _expectNoPrivateCopy();
      expect(tester.takeException(), isNull);
      final png = await capturePng(tester, boundary, pixelRatio: 1);
      expect(png, isNotEmpty);
      output.writeAsBytesSync(png, flush: true);
    },
    skip: capturePath == null || capturePath.trim().isEmpty,
  );
}
