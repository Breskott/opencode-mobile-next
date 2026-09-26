/// The Work tab's one status line (work-tab cleanup, 2026-09-24), drawn with
/// the kit's [KitStatusLine] (design standard §5).
///
/// At most one thing is said at a time, and only when there is something to
/// do about it, most urgent first:
///
/// 1. the server is not answering (after [notAnsweringGrace], or at once
///    when the last attempt already failed);
/// 2. whatever the screen passes in [WorkStatusLine.others], in its order:
///    the project list failed, the waiting requests could not be refreshed
///    ("may be out of date"), a leftover process burning CPU, a location
///    notice.
///
/// Nothing here knows which kind of server this is: the screen says whether
/// the server runs on this phone and hands over a restart when it can
/// restart it.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/sse.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'connection_status_banner.dart' show showConnectionDetailsSheet;
import 'grace_timer.dart';

/// What the line can say.
class WorkStatus {
  const WorkStatus({
    required this.id,
    required this.message,
    this.icon = AppIconography.info,
    this.tone = AppStatusTone.neutral,
    this.action,
    this.more = const [],
    this.onDismiss,
    this.messageKey,
  });

  /// Stable name of the kind of status, for keys and tests.
  final String id;
  final String message;
  final IconData icon;
  final AppStatusTone tone;
  final KitAction? action;
  final List<KitAction> more;

  /// Only when dismissing changes nothing real.
  final VoidCallback? onDismiss;
  final Key? messageKey;
}

/// A process on the phone that keeps using the CPU with nothing waiting on
/// it, as a platform watcher reports it (see `termux_phone_tools.dart`).
class WorkRunawayNotice {
  const WorkRunawayNotice({
    required this.identity,
    required this.busyFor,
    required this.onOpen,
    required this.onDismiss,
    this.project,
  });

  /// Changes when the process does; a dismissal holds only for one identity.
  final Object identity;

  /// The project folder's name when the process runs inside one; null means
  /// the server or its projects folder, which is called "OpenCode".
  final String? project;

  /// Already formatted ("10 min").
  final String busyFor;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  WorkStatus status(AppLocalizations l10n) => WorkStatus(
    id: 'runaway',
    icon: AppIconography.processor,
    tone: AppStatusTone.neutral,
    message: project == null
        ? l10n.workRunaway(busyFor)
        : l10n.workRunawayInProject(project!, busyFor),
    action: KitAction(
      key: const ValueKey('work-status-runaway-open'),
      label: l10n.workRunawaySee,
      onPressed: onOpen,
    ),
    onDismiss: onDismiss,
  );
}

class WorkStatusLine extends StatelessWidget {
  const WorkStatusLine({
    super.key,
    required this.controller,
    required this.serverOnThisPhone,
    this.onRestartServer,
    this.others = const [],
    this.grace = notAnsweringGrace,
  });

  final ConnectionController controller;

  /// The server is the phone's own (Termux or in the app): it is named
  /// "OpenCode on this phone" and offers Restart.
  final bool serverOnThisPhone;

  /// Restarts the phone's server; null when this server cannot be
  /// restarted from here.
  final Future<void> Function()? onRestartServer;

  /// Lower-priority statuses, most urgent first; nulls are skipped.
  final List<WorkStatus?> others;
  final Duration grace;

  /// Not connected, and not for a reason the shell banner owns (a rejected
  /// password or token has its own fix there).
  static bool serverLost(ConnectionController controller) =>
      controller.status != StreamStatus.connected &&
      !controller.passwordRejected;

  /// The last attempt ended and nothing is in flight: say so at once.
  static bool _failed(ConnectionController controller) =>
      controller.status == StreamStatus.disconnected &&
      controller.connectionError != null &&
      !controller.manualReconnectInProgress;

  WorkStatus _serverStatus(BuildContext context, AppLocalizations l10n) {
    final retrying = controller.manualReconnectInProgress;
    final restart = onRestartServer;
    final retry = KitAction(
      key: const ValueKey('work-status-retry'),
      label: retrying ? l10n.e7BannerRetrying : l10n.commonRetry,
      onPressed: retrying
          ? null
          : () => unawaited(controller.retryConnection()),
    );
    // The app keeps retrying by itself; for the phone's own server the way
    // out it cannot take alone is a restart, so that comes first.
    if (serverOnThisPhone && restart != null) {
      return WorkStatus(
        id: 'server',
        icon: AppIconography.cloudOff,
        tone: AppStatusTone.failure,
        message: l10n.workServerNotAnsweringPhone,
        action: KitAction(
          key: const ValueKey('work-status-restart'),
          label: l10n.workServerRestart,
          onPressed: () => unawaited(_restart(context, restart)),
        ),
        more: [retry],
      );
    }
    return WorkStatus(
      id: 'server',
      icon: AppIconography.cloudOff,
      tone: AppStatusTone.failure,
      message: serverOnThisPhone
          ? l10n.workServerNotAnsweringPhone
          : l10n.workServerNotAnswering(controller.profile?.name ?? 'OpenCode'),
      action: retry,
      more: [
        KitAction(
          key: const ValueKey('work-status-details'),
          label: l10n.e7BannerDetails,
          onPressed: () =>
              unawaited(showConnectionDetailsSheet(context, controller)),
        ),
      ],
    );
  }

  static Future<void> _restart(
    BuildContext context,
    Future<void> Function() restart,
  ) async {
    if (!await confirmPhoneServerRestart(context)) return;
    await restart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final lost = serverLost(controller);
        return GraceTimer(
          waiting: lost,
          grace: grace,
          restartKey: controller.connectionAttemptRevision,
          builder: (context, overdue) {
            WorkStatus? status;
            if (lost && (overdue || _failed(controller))) {
              status = _serverStatus(context, l10n);
            } else {
              for (final other in others) {
                if (other != null) {
                  status = other;
                  break;
                }
              }
            }
            if (status == null) return const SizedBox.shrink();
            return KitStatusLine(
              key: ValueKey('work-status-${status.id}'),
              icon: status.icon,
              tone: status.tone,
              message: status.message,
              messageKey: status.messageKey,
              action: status.action,
              more: status.more,
              onDismiss: status.onDismiss,
            );
          },
        );
      },
    );
  }
}

/// Asks before restarting the phone's server: a turn in progress stops.
/// Neutral (LOOK-5): a restart is not a loss; the cancel word is "Cancel".
Future<bool> confirmPhoneServerRestart(BuildContext context) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return showKitConfirm(
    context,
    icon: AppIconography.retry,
    title: l10n.workServerRestartTitle,
    body: l10n.workServerRestartBody,
    confirmLabel: l10n.workServerRestart,
    confirmKey: const ValueKey('work-server-restart-confirm'),
  );
}
