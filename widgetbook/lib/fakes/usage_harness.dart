// Fakes for the Usage screens, adapted from test/support/usage_ui_harness.dart
// (the app never imports test/ from lib/, and this package must not pull in
// flutter_test). A real UsageSubscriptionsController is fed by one fake
// source; a real ConnectionController supplies only its store and shared
// notification rules.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/domain/usage_subscriptions.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/usage_signin_destination.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_actions.dart';

import 'fake_app.dart';

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

UsageSourceResult usageResult({
  List<UsageReading> readings = const [],
  List<UsageSignIn> signIns = const [],
  Set<String> authoritative = const {},
  Set<String> unreached = const {},
}) => UsageSourceResult(
  readings: readings,
  signIns: signIns,
  authoritativeSignIns: authoritative,
  unreached: unreached,
);

class FakeUsageSource implements UsageSource {
  FakeUsageSource(this.result);
  UsageSourceResult result;

  /// While set, a read never finishes: the loading state.
  Completer<void>? hold;
  @override
  Future<UsageSourceResult> read(UsageReadContext context) async {
    if (hold != null) await hold!.future;
    return result;
  }
}

class FakeLauncher implements UsageSignInLauncher {
  @override
  Future<UsageSignInOutcome> open(
    BuildContext context,
    UsageSignInDestination destination, {
    ServerProfile? profile,
  }) async => UsageSignInOutcome.opened;
}

class UsageHarness implements SceneResource {
  UsageHarness(this.connection, this.usage, this.source, this.launcher);
  final ConnectionController connection;
  final UsageSubscriptionsController usage;
  final FakeUsageSource source;
  final FakeLauncher launcher;

  @override
  void dispose() {
    usage.dispose();
    connection.dispose();
  }
}

/// Builds the harness. [connections] are the places the snapshot knows about;
/// each is also a saved server so a sign-in can resolve its profile.
Future<UsageHarness> usageHarness({
  List<UsageConnection> connections = const [usageInApp],
  UsageSourceResult result = const UsageSourceResult(),
  Map<String, Object> prefs = const {},
  UsageReaderNotes? readerNotes,
  bool hold = false,
}) async {
  final app = await FakeApp.create(
    profiles: [
      for (final c in connections)
        if (c.id != UsageConnection.phoneId) FakeProfile(c.id, c.name),
    ],
    prefs: prefs,
  );
  final store = app.store;
  final connection = app.connection;
  final source = FakeUsageSource(result);
  if (hold) source.hold = Completer<void>();
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
  return UsageHarness(connection, usage, source, FakeLauncher());
}
