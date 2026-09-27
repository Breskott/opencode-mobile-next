import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builtin/app_exit_recovery.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/app_exit.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../screens/keep_running_screen.dart';

/// "at 00:06" today, "on Sep 25 at 20:19" before today.
String appExitTimeText(
  BuildContext context,
  AppLocalizations l10n,
  DateTime at, {
  DateTime? now,
}) {
  final material = MaterialLocalizations.of(context);
  final local = at.toLocal();
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final today = (now ?? DateTime.now()).toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return sameDay
      ? l10n.appExitAtTime(time)
      : l10n.appExitOnDay(material.formatShortMonthDay(local), time);
}

/// The notice's one sentence: what ended the app, what stopped with it and
/// that it is coming back.
String appExitMessage(AppLocalizations l10n, AppExitNotice notice, String at) {
  final what = switch (notice.kind) {
    AppExitKind.lowMemory => l10n.appExitLowMemory(at),
    AppExitKind.crash => l10n.appExitCrashed(at),
    AppExitKind.killed => l10n.appExitKilled(at),
    _ => l10n.appExitForceStopped(at),
  };
  return notice.teamStopped
      ? l10n.appExitServerAndTeamStopped(what)
      : l10n.appExitServerStopped(what);
}

/// Shown once in the shell after Android ended the app while the phone's
/// OpenCode ran in it; nothing after a normal exit or an update
/// ([AppExitRecovery]). It folds away when dismissed.
class AppExitNoticeLine extends ConsumerWidget {
  const AppExitNoticeLine({super.key, this.now});

  /// For tests: the moment "today" is measured from.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = ref.watch(appExitRecoveryProvider);
    return ListenableBuilder(
      listenable: recovery,
      builder: (context, _) {
        final notice = recovery.notice;
        if (notice == null) return const KitReveal(child: null);
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        final at = appExitTimeText(context, l10n, notice.at, now: now);
        return KitReveal(
          child: Padding(
            key: const ValueKey('app-exit-notice'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 4),
            child: KitNotice(
              tone: AppStatusTone.attention,
              icon: AppIconography.restart,
              message: appExitMessage(l10n, notice, at),
              actions: [
                if (notice.offersKeepAlive)
                  KitAction(
                    key: const ValueKey('app-exit-keep-running'),
                    label: l10n.appExitKeepRunning,
                    onPressed: () => openKeepRunningScreen(context),
                  ),
              ],
              onDismiss: recovery.dismiss,
            ),
          ),
        );
      },
    );
  }
}

/// App-wide condition: the same notice survives route and tab changes.
KitStatus? appExitKitStatus(
  BuildContext context,
  AppExitRecovery recovery, {
  DateTime? now,
  BuildContext? Function()? actionContext,
}) {
  final notice = recovery.notice;
  if (notice == null) return null;
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return KitStatus(
    kind: KitStatusKind.appStopped,
    id: 'app-stopped',
    key: const ValueKey('app-exit-notice'),
    icon: AppIconography.restart,
    tone: AppStatusTone.neutral,
    message: appExitMessage(
      l10n,
      notice,
      appExitTimeText(context, l10n, notice.at, now: now),
    ),
    action: notice.offersKeepAlive
        ? KitAction(
            key: const ValueKey('app-exit-keep-running'),
            label: l10n.appExitKeepRunning,
            onPressed: () {
              final current = actionContext == null ? context : actionContext();
              if (current != null && current.mounted) {
                openKeepRunningScreen(current);
              }
            },
          )
        : null,
    onDismiss: recovery.dismiss,
  );
}
