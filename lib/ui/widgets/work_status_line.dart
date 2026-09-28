/// The Work tab's one status line (work-tab cleanup, 2026-09-24), drawn with
/// the kit's [KitStatusLine] (design standard §5).
///
/// At most one thing is said at a time, and only when there is something to
/// do about it, most urgent first:
///
/// The app-wide scope owns the connection. This contributes whatever the
/// screen passes in [WorkStatusLine.others], in its order:
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
import 'package:flutter/semantics.dart' show SemanticsService;

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../termux/bridge.dart' show TermuxBridgeException;
import '../../termux/processes.dart'
    show TermuxProcessStopResult, TermuxProcesses;
import '../app_theme.dart';
import '../kit/kit.dart';

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
///
/// Its one action stops that process ("Stop java"): the line already says
/// what it is doing, so the act that ends it lives on it, asked first with
/// [stopRunawayHelper]. A stop that did not end it keeps the line, in the
/// failure tone, with the same action to try again.
class WorkRunawayNotice {
  const WorkRunawayNotice({
    required this.identity,
    required this.helper,
    required this.busyFor,
    required this.onStop,
    required this.onDismiss,
    this.project,
    this.stopFailed = false,
  });

  /// Changes when the process does; a dismissal holds only for one identity.
  final Object identity;

  /// The process's own name ("java", "node"), as the phone reports it.
  final String helper;

  /// The project folder's name when the process runs inside one; null means
  /// the server or its projects folder, which is called "OpenCode".
  final String? project;

  /// Already formatted ("10 min").
  final String busyFor;

  /// Asks and stops; the watcher runs [stopRunawayHelper] with its context.
  final VoidCallback onStop;
  final VoidCallback onDismiss;

  /// The last stop did not end the process.
  final bool stopFailed;

  WorkStatus status(AppLocalizations l10n) => WorkStatus(
    id: 'runaway',
    icon: stopFailed ? AppIconography.warning : AppIconography.processor,
    tone: stopFailed ? AppStatusTone.failure : AppStatusTone.neutral,
    message: stopFailed
        ? l10n.workRunawayStopFailed(helper)
        : project == null
        ? l10n.workRunaway(busyFor)
        : l10n.workRunawayInProject(project!, busyFor),
    action: KitAction(
      key: const ValueKey('work-status-runaway-stop'),
      label: l10n.termuxProcsStopSemantics(helper),
      onPressed: onStop,
    ),
    onDismiss: onDismiss,
  );
}

/// How [stopRunawayHelper] ended.
enum RunawayStopOutcome {
  /// The person kept it running (cancelled the question).
  kept,

  /// The process ended.
  stopped,

  /// The stop did not end it (still running, refused, or the phone's tools
  /// did not answer).
  failed,
}

/// Asks before stopping the leftover process [pid] named [helper], stops
/// exactly that one with [TermuxProcesses.stopPid] ([stop] in tests), and
/// announces the result once to a screen reader: "Stopped java" or "Couldn't
/// stop java…". The line itself shows the rest: it goes away, or stays in
/// the failure tone.
Future<RunawayStopOutcome> stopRunawayHelper(
  BuildContext context, {
  required int pid,
  required String helper,
  Future<TermuxProcessStopResult> Function(int pid)? stop,
}) async {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final confirmed = await showKitConfirm(
    context,
    title: l10n.termuxProcsStopOneTitle(helper),
    body: l10n.safetyStopOrphanBody,
    confirmLabel: l10n.termuxProcsStopSemantics(helper),
    icon: AppIcons.stop,
    kind: KitConfirmKind.stop,
    // No undo, and it says so.
    consequenceItems: [KitConsequence(l10n.termuxProcsNoRestart)],
    sheetKey: const ValueKey('work-runaway-stop-confirm'),
    confirmKey: const ValueKey('work-runaway-stop-confirm-stop'),
  );
  if (!confirmed || !context.mounted) return RunawayStopOutcome.kept;
  final view = View.of(context);
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  RunawayStopOutcome outcome;
  try {
    final result = await (stop ?? TermuxProcesses.stopPid)(pid);
    outcome =
        result.remaining.isEmpty &&
            (result.endedCount > 0 || result.refused.isEmpty)
        ? RunawayStopOutcome.stopped
        : RunawayStopOutcome.failed;
  } on TermuxBridgeException {
    outcome = RunawayStopOutcome.failed;
  } on FormatException {
    outcome = RunawayStopOutcome.failed;
  }
  await SemanticsService.sendAnnouncement(
    view,
    outcome == RunawayStopOutcome.stopped
        ? l10n.workRunawayStopped(helper)
        : l10n.workRunawayStopFailed(helper),
    direction,
  );
  return outcome;
}

class WorkStatusLine extends StatelessWidget {
  const WorkStatusLine({
    super.key,
    required this.controller,
    required this.serverOnThisPhone,
    this.onRestartServer,
    this.others = const [],
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

  /// Kept for callers that diagnose stale lists; timing belongs to the
  /// controller snapshot, never to this screen.
  static bool serverLost(ConnectionController controller) =>
      !controller.connectionStatus.reachable &&
      controller.connectionStatus.visible;

  @override
  Widget build(BuildContext context) {
    WorkStatus? selected;
    for (final other in others) {
      if (other != null) {
        selected = other;
        break;
      }
    }
    final status = selected;
    return KitStatusContribution(
      status: status == null
          ? null
          : KitStatus(
              kind: KitStatusKind.work,
              id: 'work:${status.id}',
              key: ValueKey('work-status-${status.id}'),
              icon: status.icon,
              tone: status.tone,
              message: status.message,
              messageKey: status.messageKey,
              action: status.action,
              more: status.more,
              onDismiss: status.onDismiss,
            ),
      child: const SizedBox.shrink(),
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
