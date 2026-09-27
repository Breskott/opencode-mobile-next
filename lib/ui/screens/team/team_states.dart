/// The whole-screen states the AI Team screens share (design standard §3,
/// §4): connecting, not answering after 8 s, and the honest errors. The
/// home, the run and the agent screen each showed the same three states
/// with their own spinner and error block; they now come from here, as
/// [KitStateView] pages under the screen's one [KitLoadingBar].
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_scenes.dart';
import '../../widgets/grace_timer.dart';
import '../../widgets/team_vocabulary.dart';

/// Whether [controller] has nothing to show because it failed: the probe
/// failed, or it is ready with no data and an error.
bool teamScreenFailed(OrchestrationController controller) =>
    controller.phase == OrchestrationPhase.failed ||
    (controller.phase == OrchestrationPhase.ready &&
        !controller.snapshot.hasData &&
        controller.lastError != null);

/// Whether [controller] is still getting its first data.
bool teamScreenLoading(OrchestrationController controller) =>
    !teamScreenFailed(controller) &&
    !(controller.phase == OrchestrationPhase.ready &&
        controller.snapshot.hasData);

/// The state page for [controller] while it cannot show data, or null once
/// it can. Keys: `<prefix>-error`, `<prefix>-loading` and, after 8 s of
/// connecting, `<prefix>-not-answering`.
Widget? teamScreenState(
  BuildContext context, {
  required OrchestrationController controller,
  required String keyPrefix,
  required VoidCallback? onRetry,
}) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final retry = KitAction(
    key: ValueKey('$keyPrefix-retry'),
    label: l10n.teamUiCardRetry,
    onPressed: onRetry,
    icon: AppIcons.retry,
  );
  if (teamScreenFailed(controller)) {
    final error = controller.lastError;
    final (icon, tone, title) = teamErrorState(l10n, error?.kind);
    final details = error?.message.trim();
    // The host is starting: the team wakes up while the person waits.
    final starting = error?.kind == OrchestrationErrorKind.cityNotRunning;
    return KitStateView(
      key: ValueKey('$keyPrefix-error'),
      icon: icon,
      tone: tone,
      illustration: starting ? const TeamWakingScene() : null,
      illustrationAmbient: starting,
      title: title,
      body: teamErrorCopy(l10n, error?.kind),
      primary: retry,
      details: details == null || details.isEmpty ? null : details,
    );
  }
  if (teamScreenLoading(controller)) {
    return GraceTimer(
      waiting: true,
      builder: (context, overdue) => overdue
          ? KitStateView(
              key: ValueKey('$keyPrefix-not-answering'),
              icon: AppIconography.cloudOff,
              tone: AppStatusTone.attention,
              title: l10n.teamUiStateNotAnsweringTitle,
              // What to check, where the team runs (P3.4): the phone's
              // team is still starting; a computer must be on and online.
              body: teamNotAnsweringBody(l10n, controller),
              secondary: retry,
            )
          : KitStateView(
              key: ValueKey('$keyPrefix-loading'),
              icon: AppIconography.agent,
              tone: AppStatusTone.progress,
              title: l10n.teamUiCardLoading,
            ),
    );
  }
  return null;
}

/// The not-answering page's one sentence: what the app does and what to
/// check where this team runs.
String teamNotAnsweringBody(
  AppLocalizations l10n,
  OrchestrationController controller,
) => switch (controller.host?.hostMode ?? controller.config.hostMode) {
  OrchestrationHostMode.phone => l10n.teamUiStateNotAnsweringPhone,
  OrchestrationHostMode.computer => switch (teamComputerName(controller)) {
    final name? => l10n.teamUiStateNotAnsweringComputerNamed(name),
    null => l10n.teamUiStateNotAnsweringComputer,
  },
};

/// The icon, tone and one-line title of an error kind; the body is
/// [teamErrorCopy].
(IconData, AppStatusTone, String) teamErrorState(
  AppLocalizations l10n,
  OrchestrationErrorKind? kind,
) => switch (kind) {
  OrchestrationErrorKind.notGasCity => (
    AppIconography.agent,
    AppStatusTone.neutral,
    l10n.teamUiStateNotGasCityTitle,
  ),
  OrchestrationErrorKind.cityNotRunning => (
    AppIconography.waiting,
    AppStatusTone.progress,
    l10n.teamUiStateStartingTitle,
  ),
  OrchestrationErrorKind.plainHttpRefused => (
    AppIconography.secureNetwork,
    AppStatusTone.attention,
    l10n.teamUiStatePlainHttpTitle,
  ),
  OrchestrationErrorKind.unreachable ||
  OrchestrationErrorKind.readFailed ||
  null => (
    AppIconography.cloudOff,
    AppStatusTone.attention,
    l10n.teamUiStateUnreachableTitle,
  ),
};

/// The one status line of a working AI Team screen (§5): data from before
/// the host stopped answering, or a refresh that failed. Null when the data
/// is current. Keys: `<prefix>-stale`, `<prefix>-refresh-failed`.
Widget? teamStatusLine(
  BuildContext context, {
  required OrchestrationController controller,
  required String keyPrefix,
  required VoidCallback? onRetry,
}) {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final at = controller.lastRefreshedAt;
  final action = KitAction(
    key: ValueKey('$keyPrefix-status-retry'),
    label: l10n.teamUiCardRetry,
    onPressed: onRetry,
  );
  if (controller.isStale) {
    return KitStatusLine(
      key: ValueKey('$keyPrefix-stale'),
      icon: AppIconography.cloudOff,
      tone: AppStatusTone.attention,
      message: l10n.teamUiCardStale(
        at == null ? '' : teamClockLabel(context, at),
      ),
      action: action,
    );
  }
  if (controller.lastError?.kind == OrchestrationErrorKind.readFailed &&
      at != null) {
    return KitStatusLine(
      key: ValueKey('$keyPrefix-refresh-failed'),
      icon: AppIconography.warning,
      tone: AppStatusTone.attention,
      message: l10n.teamUiCardRefreshFailed(teamClockLabel(context, at)),
      action: action,
    );
  }
  return null;
}
