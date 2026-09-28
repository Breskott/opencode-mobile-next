import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/while_away.dart';
import '../state/automation_policy.dart';
import '../state/builtin_server_owner.dart';
import '../state/connection.dart';
import '../state/lifecycle_report.dart';
import '../state/profiles.dart';
import 'builtin_linux.dart';
import 'builtin_server.dart';
import 'builtin_server_recovery.dart';

/// App-lifetime owner: recovery does not depend on opening This phone.
final phoneServerHealingProvider = Provider<PhoneServerHealing>((ref) {
  final healing = PhoneServerHealing(
    connection: ref.read(connProvider),
    starter: ref.read(builtinServerStarterProvider),
    createRecovery: (record) => BuiltinServerRecovery(
      store: ref.read(connProvider).store,
      linux: ref.read(builtinLinuxProvider),
      starter: ref.read(builtinServerStarterProvider),
      onRestart: record,
    ),
  );
  ref.onDispose(healing.dispose);
  return healing;
});

class PhoneServerHealing {
  PhoneServerHealing({
    required this.connection,
    required this.starter,
    required BuiltinServerRecovery Function(BuiltinRestartRecorder)
    createRecovery,
  }) {
    recovery = createRecovery(_recordRestart);
    report = LifecycleReportController(linux: recovery.linux);
    recovery.addListener(_recoveryChanged);
    connection.store.changes.addListener(_syncProfile);
    connection.addListener(_syncProfile);
    starter.beforeManualStart = _claimProfile;
    _syncProfile();
    setForeground(
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  /// Shared runtime pointer; deletion clears the reference, not another profile.
  static const ownerKey = BuiltinServerOwner.key;

  final ConnectionController connection;
  final BuiltinServerStarter starter;
  late final BuiltinServerRecovery recovery;
  late final LifecycleReportController report;
  ServerProfile? _owner;
  int _reportedReadyCount = -1;
  bool _foreground = false;
  bool _disposed = false;
  bool _ownerStorageFailed = false;
  String? _lastConnectionAttempt;
  bool _launchStartUsed = false;
  Completer<void>? _foregroundWaiter;

  /// How long the launch start waits before its one retry.
  @visibleForTesting
  static Duration launchRetryDelay = const Duration(seconds: 2);

  Future<void> _claimProfile(ServerProfile profile) async {
    if (_disposed || !connection.isProfileReadable(profile.id)) {
      throw StateError('The server profile is unavailable.');
    }
    report.invalidate();
    recovery.setProfile(null);
    _ownerStorageFailed = true;
    await BuiltinServerOwner.forPreferences(connection.store.prefs).claim(
      profile.id,
      isReadable: () => !_disposed && connection.isProfileReadable(profile.id),
    );
    _ownerStorageFailed = false;
    _syncProfile();
  }

  void _syncProfile() {
    if (_disposed) return;
    final profiles = connection.store.profiles
        .where(looksLikeInAppServer)
        .where((profile) => connection.isProfileReadable(profile.id))
        .toList();
    final owner = connection.store.prefs.getString(ownerKey);
    // A legacy installation with multiple local profiles has no reliable
    // owner. An explicit Start selects it; choosing a remote profile does not.
    final selected = _ownerStorageFailed
        ? null
        : owner == null
        ? (profiles.length == 1 ? profiles.single : null)
        : profiles.where((profile) => profile.id == owner).firstOrNull;
    if (!identical(_owner, selected)) {
      _owner = selected;
      report.invalidate();
    }
    recovery.setProfile(selected);
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value) {
      _foregroundWaiter?.complete();
      _foregroundWaiter = null;
    }
    if (!value) report.invalidate();
    recovery.setForeground(value);
  }

  void _recoveryChanged() {
    final state = recovery.value;
    if (state.phase == BuiltinRecoveryPhase.checking) return;
    if (state.phase != BuiltinRecoveryPhase.ready) {
      report.invalidate();
      return;
    }
    if (!_foreground || _owner == null) return;
    unawaited(connectIfNeeded(_owner!));
    if (_reportedReadyCount != starter.readyCount ||
        report.value.readiness == LifecycleReadiness.unchecked) {
      _reportedReadyCount = starter.readyCount;
      unawaited(report.refresh(_owner));
    }
  }

  Future<bool> _recordRestart({
    required String profileId,
    required String eventId,
    required DateTime at,
  }) async {
    final recorded = await connection.recordServerAct(
      profileId: profileId,
      kind: AutomaticActKind.restart,
      eventId: eventId,
      at: at,
    );
    return recorded;
  }

  Future<void> check(ServerProfile profile) => recovery.check(profile);

  /// The app opened on this phone's own server (main.dart's
  /// `_autoStartThenConnect`): the person is about to use it, so a stopped
  /// server is started for them — once per app process, with one more try
  /// after a fast failure — and then connected.
  ///
  /// This is not crash healing. [recovery]'s durable budget bounds
  /// unattended restarts, and a confirmed automatic restart never gives an
  /// attempt back, so three launches used to exhaust it for good: the fourth
  /// cold start (or one inside the 15/30/45-second retry window) opened on
  /// "stopped" and waited for a tap (docs/qa/slice-qa-autostart-2026-09-28).
  /// Opening the app is the person's own act, like Start, so it goes through
  /// the starter's explicit path (which also resets that budget once the
  /// server answers). Explicit Stop still wins: a stopped intent, the
  /// restart policy being off, a running server or another start in flight
  /// all leave it alone. Foreground only; it never outlives the screen.
  Future<void> startForLaunch(ServerProfile profile) async {
    if (!_foreground) {
      // Android can report the first resume after the first frame.
      await (_foregroundWaiter ??= Completer<void>()).future;
    }
    if (_disposed) return;
    await check(profile);
    if (_disposed) return;
    if (!_launchStartUsed) {
      _launchStartUsed = true;
      // The recovery owner may have just tried and failed: then the launch
      // start is the one more try.
      var tries = starter.failureFor(profile) == null ? 2 : 1;
      while (tries > 0 && await _launchStartWanted(profile)) {
        tries--;
        final failure = await starter.start(profile);
        if (failure == null || !failure.retryable || tries == 0) break;
        await Future<void>.delayed(launchRetryDelay);
      }
    }
    if (!_disposed) await connectIfNeeded(profile);
  }

  Future<bool> _launchStartWanted(ServerProfile profile) async {
    if (_disposed ||
        !_foreground ||
        starter.starting ||
        connection.profile?.id != profile.id ||
        connection.hasConnectedServer ||
        !looksLikeInAppServer(profile) ||
        !AutomationPolicyController.forProfile(
          connection.store.prefs,
          profile.id,
        ).value.allows(AutomationBehavior.restartPhoneServer)) {
      return false;
    }
    final BuiltinLinuxStatus status;
    try {
      status = await recovery.linux.status();
    } on BuiltinLinuxException {
      return false;
    }
    starter.observeInstalled(status.installed);
    // Explicit Stop, notification Stop and the service timeout clear the
    // native intent: the person stopped it, so it stays stopped.
    return !_disposed &&
        _foreground &&
        status.installed &&
        !status.serverRunning &&
        status.serverRestartWanted &&
        !starter.starting;
  }

  /// Opening and confirmed recovery share one reconnect attempt per start.
  Future<void> connectIfNeeded(
    ServerProfile profile, {
    bool automatic = true,
  }) async {
    if (_disposed ||
        !_foreground ||
        connection.profile?.id != profile.id ||
        connection.api != null ||
        connection.hasConnectedServer ||
        starter.failureFor(profile) != null ||
        (automatic &&
            !AutomationPolicyController.forProfile(
              connection.store.prefs,
              profile.id,
            ).value.allows(AutomationBehavior.reconnect))) {
      return;
    }
    final attempt = '${profile.id}:${starter.readyCount}';
    if (_lastConnectionAttempt == attempt) return;
    _lastConnectionAttempt = attempt;
    await connection.connect(profile);
  }

  void dispose() {
    _disposed = true;
    _foregroundWaiter?.complete();
    _foregroundWaiter = null;
    connection.store.changes.removeListener(_syncProfile);
    connection.removeListener(_syncProfile);
    starter.beforeManualStart = null;
    recovery.removeListener(_recoveryChanged);
    recovery.dispose();
    report.dispose();
  }
}
