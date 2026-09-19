import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_theme.dart';
import 'confirm_sheet.dart';

// Confirmations for actions that interrupt running work or drop local state
// but are not irreversible. Each one lives here, rather than next to its
// button, because the same action is reachable from several surfaces and a
// copy that confirms in one place but not another teaches people to distrust
// both. Every sheet says concretely what stops or is lost.

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Disconnecting from the active server. The cost is counted rather than
/// described in the abstract: queued prompts and unsent drafts for this
/// server stop moving until it is connected again.
Future<bool> confirmDisconnectServer(
  BuildContext context,
  ConnectionController controller,
) {
  final l10n = _copy(context);
  final id = controller.profile?.id;
  final queued = id == null ? 0 : controller.queuedPromptCountForProfile(id);
  final drafts = id == null ? 0 : controller.draftCountForProfile(id);
  return showConfirmSheet(
    context,
    title: l10n.e7SettingsDisconnectTitle(
      controller.profile?.name ?? l10n.e7SettingsUi16,
    ),
    message: l10n.e7SettingsDisconnectBody(queued, drafts),
    confirmLabel: l10n.e7SettingsUi8,
    icon: AppIconography.unlink,
    destructive: true,
    sheetKey: const ValueKey('disconnect-confirm-sheet'),
    confirmKey: const ValueKey('confirm-disconnect'),
  );
}

/// Revoking a session's public link, which cuts off everyone holding it.
Future<bool> confirmStopSharing(BuildContext context) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.safetyStopSharingTitle,
    message: l10n.safetyStopSharingBody,
    confirmLabel: l10n.e7WorkspaceStopSharing,
    cancelLabel: l10n.safetyStopSharingKeep,
    icon: AppIconography.unlink,
    destructive: true,
    sheetKey: const ValueKey('stop-sharing-confirm-sheet'),
    confirmKey: const ValueKey('confirm-stop-sharing'),
  );
}

/// Stopping the server this app manages on the phone, which takes every
/// running agent turn down with it.
Future<bool> confirmStopLocalServer(BuildContext context) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.safetyStopLocalServerTitle,
    message: l10n.safetyStopLocalServerBody,
    confirmLabel: l10n.e7SetupStopLocal,
    cancelLabel: l10n.safetyStopLocalServerKeep,
    icon: AppIcons.stop,
    destructive: true,
    sheetKey: const ValueKey('stop-local-server-confirm-sheet'),
    confirmKey: const ValueKey('confirm-stop-local-server'),
  );
}

/// Restarting the phone's server interrupts whatever is running on it.
Future<bool> confirmRestartLocalServer(
  BuildContext context, {
  required int busyConversations,
}) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.termuxRestartTitle,
    message: [
      l10n.termuxRestartMessage,
      if (busyConversations > 0)
        l10n.termuxRestartBusyMessage(busyConversations),
    ].join('\n\n'),
    confirmLabel: l10n.termuxRestartConfirm,
    icon: AppIconography.restart,
    sheetKey: const ValueKey('restart-local-server-sheet'),
    confirmKey: const ValueKey('confirm-restart-local-server'),
  );
}

/// Stopping the Claude Code daemon on the phone. It has its own sheet rather
/// than the OpenCode server's because that copy names OpenCode, and a person
/// running both must be able to tell which one they are about to stop.
Future<bool> confirmStopLocalAgents(BuildContext context) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.localAgentStopTitle,
    message: l10n.localAgentStopBody,
    confirmLabel: l10n.phoneServerStop,
    cancelLabel: l10n.safetyStopLocalServerKeep,
    icon: AppIcons.stop,
    destructive: true,
    sheetKey: const ValueKey('stop-local-agents-confirm-sheet'),
    confirmKey: const ValueKey('confirm-stop-local-agents'),
  );
}

/// Restarting the Claude Code daemon interrupts whatever it is running.
Future<bool> confirmRestartLocalAgents(
  BuildContext context, {
  required int busyConversations,
}) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.localAgentRestartTitle,
    message: [
      l10n.localAgentRestartBody,
      if (busyConversations > 0)
        l10n.termuxRestartBusyMessage(busyConversations),
    ].join('\n\n'),
    confirmLabel: l10n.termuxRestartConfirm,
    icon: AppIconography.restart,
    sheetKey: const ValueKey('restart-local-agents-sheet'),
    confirmKey: const ValueKey('confirm-restart-local-agents'),
  );
}

/// Removing Claude Code from the phone. Says what goes and, because people
/// fear losing it, what stays: projects and the Claude sign-in.
Future<bool> confirmRemoveLocalAgents(BuildContext context) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.localAgentRemoveTitle,
    message: l10n.localAgentRemoveBody,
    confirmLabel: l10n.localAgentRemove,
    cancelLabel: l10n.localAgentRemoveKeep,
    icon: AppIconography.unlink,
    destructive: true,
    sheetKey: const ValueKey('remove-local-agents-confirm-sheet'),
    confirmKey: const ValueKey('confirm-remove-local-agents'),
  );
}

/// Disconnecting an MCP server removes its tools from agents mid-session.
Future<bool> confirmDisconnectMcp(
  BuildContext context, {
  required String serverName,
}) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.safetyMcpDisconnectTitle(serverName),
    message: l10n.safetyMcpDisconnectBody,
    confirmLabel: l10n.e7SettingsUi8,
    cancelLabel: l10n.safetyMcpDisconnectKeep,
    icon: AppIconography.unlink,
    destructive: true,
    sheetKey: const ValueKey('mcp-disconnect-confirm-sheet'),
    confirmKey: const ValueKey('confirm-mcp-disconnect'),
  );
}

/// Stopping one process on the phone. An orphan has nothing waiting on it,
/// but the classification is a heuristic, so it still gets a sheet; only the
/// body differs.
Future<bool> confirmStopProcess(
  BuildContext context, {
  required String processName,
  required bool orphan,
}) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.termuxProcsStopOneTitle(processName),
    message: orphan ? l10n.safetyStopOrphanBody : l10n.termuxProcsStopOneBody,
    confirmLabel: l10n.termuxProcsStop,
    cancelLabel: l10n.termuxProcsKeep,
    icon: AppIcons.stop,
    destructive: true,
    sheetKey: const Key('termux-procs-confirm'),
    confirmKey: const Key('termux-procs-confirm-stop'),
  );
}
