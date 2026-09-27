import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/app_diagnostics.dart';
import '../diagnostics/perf_trace.dart';
import '../diagnostics/report_problem_startup.dart';
import '../platform/app_exit.dart';
import '../state/profiles.dart';
import 'builtin_linux.dart';
import 'builtin_server.dart';
import 'team/builtin_team.dart';

final appLifecycleBridgeProvider = Provider<AppLifecycleBridge>(
  (ref) => AppLifecycleBridge(),
);

/// One per app: the start reads Android's record once, and the shell shows
/// the notice from the same object.
final appExitRecoveryProvider = Provider<AppExitRecovery>((ref) {
  final recovery = AppExitRecovery(
    bridge: ref.watch(appLifecycleBridgeProvider),
  );
  ref.onDispose(recovery.dispose);
  return recovery;
});

/// What the person is told once after Android ended the app while their
/// phone's OpenCode (and maybe the AI Team) ran inside it.
@immutable
class AppExitNotice {
  const AppExitNotice({
    required this.kind,
    required this.at,
    required this.teamStopped,
  });

  final AppExitKind kind;
  final DateTime at;
  final bool teamStopped;

  /// A crash is ours to fix, not a phone setting to change.
  bool get offersKeepAlive => kind != AppExitKind.crash;
}

/// On start: learns why the previous process ended and what ran in it,
/// brings back the built-in server (and the AI Team) Android stopped with
/// it, and holds the one-time notice.
///
/// The start itself is [BuiltinServerStarter]'s, the one path every screen
/// uses; the team follows it there ([BuiltinServerStarter.start]). When the
/// app opens on the in-app server the shell already starts it (main.dart's
/// `_autoStartThenConnect`), so this starts it only when another server is
/// selected.
class AppExitRecovery extends ChangeNotifier {
  AppExitRecovery({required this.bridge});

  final AppLifecycleBridge bridge;

  bool _ran = false;
  bool _disposed = false;
  AppExitNotice? _notice;
  AppLaunchReport? _report;

  /// The notice to show, until the person dismisses it.
  AppExitNotice? get notice => _notice;

  /// The last start's report, for diagnostics and tests.
  AppLaunchReport? get report => _report;

  void dismiss() {
    if (_notice == null) return;
    _notice = null;
    _notify();
  }

  /// Runs once per app process; later calls do nothing.
  ///
  /// A notable exit is also kept, typed, in the persisted problem report
  /// ([problemReport], by default [ReportProblemStartup.ready]), so it is
  /// still there after the next crash or restart.
  Future<void> runOnce({
    required ProfileStore store,
    required ServerProfile? active,
    required BuiltinServerStarter starter,
    AppDiagnosticsController? diagnostics,
    Future<ReportProblemStartup?>? problemReport,
  }) async {
    if (_ran) return;
    _ran = true;
    final report = await bridge.launchReport();
    _report = report;
    final serverWas = report.previousServices.contains(
      BuiltinLinux.serverServiceName,
    );
    final teamWas = report.previousServices.contains(BuiltinTeam.serviceName);
    final wasRunning = serverWas || teamWas;
    final exit = report.exit;
    PerfTrace.mark(
      'app.lastExit',
      attrs: {
        ...?exit?.traceAttrs,
        if (exit == null) 'kind': 'none',
        'server': serverWas,
        'team': teamWas,
      },
    );
    if (exit != null && exit.kind.notable) {
      diagnostics?.record(
        'Android ended the app (${exit.kind.name}): reason ${exit.reason}, '
        'subreason ${exit.subReason}, importance ${exit.importance}'
        '${wasRunning ? ', while ${report.previousServices.join(' and ')} ran' : ''}',
        null,
        source: 'android.exit',
        at: exit.timestamp,
      );
      unawaited(
        (problemReport ?? ReportProblemStartup.ready).then(
          (kept) => kept?.recordAndroidExit(exit),
          onError: (Object _) {},
        ),
      );
    }
    if (!wasRunning) return;
    if (exit != null && exit.kind.notable) {
      _notice = AppExitNotice(
        kind: exit.kind,
        at: exit.timestamp,
        teamStopped: teamWas,
      );
      _notify();
    }
    await _restart(
      store: store,
      active: active,
      starter: starter,
      team: teamWas,
    );
  }

  Future<void> _restart({
    required ProfileStore store,
    required ServerProfile? active,
    required BuiltinServerStarter starter,
    required bool team,
  }) async {
    if (looksLikeInAppServer(active)) {
      // The shell starts the server it opens on; nothing to add here.
      PerfTrace.mark('app.recover', attrs: {'by': 'shell', 'team': team});
      return;
    }
    final profile = _inAppProfile(store, team: team);
    if (profile == null) {
      PerfTrace.mark('app.recover', attrs: {'by': 'none', 'reason': 'profile'});
      return;
    }
    final started = await starter.autoStartIfStopped(profile);
    PerfTrace.mark(
      'app.recover',
      attrs: {
        'by': 'recovery',
        'started': started,
        'team': team && BuiltinTeam.isBuiltinConfig(profile.orchestration),
      },
    );
  }

  /// The saved in-app server; with the team, the one it belongs to.
  static ServerProfile? _inAppProfile(
    ProfileStore store, {
    required bool team,
  }) {
    final candidates = [
      for (final profile in store.profiles)
        if (looksLikeInAppServer(profile)) profile,
    ];
    if (candidates.isEmpty) return null;
    if (team) {
      for (final profile in candidates) {
        if (BuiltinTeam.isBuiltinConfig(profile.orchestration)) return profile;
      }
    }
    return candidates.first;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
