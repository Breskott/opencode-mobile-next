// Shared fixtures for the Usage screens' widget tests: a real
// UsageSubscriptionsController fed by one fake source, a real
// ConnectionController (only its store and shared notification rules are
// used) and a launcher that records where a sign-in was sent.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_signin_destination.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

final usageNow = DateTime(2026, 10, 13, 12);

const usageInApp = UsageConnection(
  id: 'inapp',
  name: 'In-app Ubuntu',
  kind: UsageConnectionKind.inAppUbuntu,
);
const usagePc = UsageConnection(
  id: 'pc',
  name: 'PC',
  kind: UsageConnectionKind.openCodeServer,
);
const usageLaptop = UsageConnection(
  id: 'laptop',
  name: 'Laptop',
  kind: UsageConnectionKind.openCodeServer,
);
const usagePhone = UsageConnection(
  id: UsageConnection.phoneId,
  name: '',
  kind: UsageConnectionKind.phoneAgents,
);

UsageWindow usageWindow(
  String id,
  double used,
  int seconds, {
  Duration resetIn = const Duration(hours: 2),
}) => UsageWindow(
  id: id,
  usedPercent: used,
  durationSeconds: seconds,
  resetsAt: usageNow.add(resetIn),
);

List<UsageWindow> usageBoth({double five = 18, double week = 41}) => [
  usageWindow('primary', five, 18000, resetIn: const Duration(minutes: 85)),
  usageWindow('secondary', week, 604800, resetIn: const Duration(days: 2)),
];

UsageReading usageReading(
  String provider,
  String connection, {
  String? account,
  UsageReadingStatus status = UsageReadingStatus.ok,
  List<UsageWindow>? windows,
  Duration age = const Duration(minutes: 2),
  UsageProblem? problem,
  String? plan,
}) => UsageReading(
  providerId: provider,
  displayName: provider,
  connectionId: connection,
  status: status,
  fetchedAt: usageNow.subtract(age),
  windows:
      windows ?? (status == UsageReadingStatus.ok ? usageBoth() : const []),
  accountRef: account,
  plan: plan,
  problem: problem,
  method: SignInMethod.plan,
);

class FakeUsageSource implements UsageSource {
  FakeUsageSource(this.result);
  UsageSourceResult result;
  int calls = 0;
  bool force = false;
  Completer<void>? hold;
  @override
  Future<UsageSourceResult> read(UsageReadContext context) async {
    calls++;
    force = context.force;
    if (hold != null) await hold!.future;
    return result;
  }
}

class FakeLauncher implements UsageSignInLauncher {
  final opened = <(UsageSignInDestination, String?)>[];
  UsageSignInOutcome outcome = UsageSignInOutcome.opened;
  @override
  Future<UsageSignInOutcome> open(
    BuildContext context,
    UsageSignInDestination destination, {
    ServerProfile? profile,
  }) async {
    opened.add((destination, profile?.id));
    return outcome;
  }
}

class UsageHarness {
  UsageHarness(this.connection, this.usage, this.source, this.launcher);
  final ConnectionController connection;
  final UsageSubscriptionsController usage;
  final FakeUsageSource source;
  final FakeLauncher launcher;
}

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Builds the harness. [connections] are the places the snapshot knows about;
/// every one but the phone is also a saved OpenCode server so a sign-in can
/// resolve its profile. The first refresh has not run: call
/// `harness.usage.refresh()` (or pump the Plans page, which does).
Future<UsageHarness> usageHarness({
  List<UsageConnection> connections = const [usageInApp],
  UsageSourceResult result = const UsageSourceResult(),
  Map<String, Object> prefs = const {},
  UsageReaderNotes? readerNotes,
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secure, (call) async => null);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null),
  );
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      for (final c in connections)
        if (c.id != UsageConnection.phoneId)
          {
            'id': c.id,
            'name': c.name,
            'baseUrl': 'http://${c.id}.example:4096',
            'username': '',
          },
    ]),
    ...prefs,
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final connection = ConnectionController(store);
  final source = FakeUsageSource(result);
  final usage = UsageSubscriptionsController(
    prefs: store.prefs,
    connections: () => connections,
    sources: [source],
    sharedRules: () => connection.sharedNotifyRules,
    setQuotaAlerts: (value) => connection.updateSharedNotifyRules(
      (rules) => rules.copyWith(quotaAlerts: value),
    ),
    clock: () => usageNow,
    readerNotes: readerNotes,
  );
  final harness = UsageHarness(connection, usage, source, FakeLauncher());
  _open.add(harness);
  return harness;
}

final _open = <UsageHarness>[];

/// `testWidgets` that also disposes every harness the test built. The
/// controller keeps a refresh timer while it lives, and a pending timer
/// fails the test before any `addTearDown` runs.
void usageTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final h in _open) {
        h.usage.dispose();
        h.connection.dispose();
      }
      _open.clear();
      await tester.pump();
    }
  });
}

Widget usageApp(Widget home, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void usagePhoneView(WidgetTester tester, {double height = 915}) {
  tester.view.physicalSize = Size(412, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Android-like capabilities so the quiet hours and Wi-Fi rows exist.
void usageAndroid() {
  debugPlatformCapabilities = const PlatformCapabilities.android();
  addTearDown(() => debugPlatformCapabilities = null);
}

Finder usageKey(String key) => find.byKey(ValueKey(key));
