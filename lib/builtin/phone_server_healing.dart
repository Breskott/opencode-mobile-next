import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/while_away.dart';
import '../state/automation_policy.dart';
import '../state/connection.dart';
import '../state/lifecycle_report.dart';
import '../state/profiles.dart';
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
  static const ownerKey = 'oc.builtinServerOwner';

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

  Future<void> _claimProfile(ServerProfile profile) async {
    if (_disposed || !connection.isProfileReadable(profile.id)) {
      throw StateError('The server profile is unavailable.');
    }
    report.invalidate();
    recovery.setProfile(null);
    _ownerStorageFailed = true;
    final saved = await connection.store.prefs.setString(ownerKey, profile.id);
    if (!saved || _disposed || !connection.isProfileReadable(profile.id)) {
      throw StateError('The phone server setting could not be saved.');
    }
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
    connection.store.changes.removeListener(_syncProfile);
    connection.removeListener(_syncProfile);
    starter.beforeManualStart = null;
    recovery.removeListener(_recoveryChanged);
    recovery.dispose();
    report.dispose();
  }
}
