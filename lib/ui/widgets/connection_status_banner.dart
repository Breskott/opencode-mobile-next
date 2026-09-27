import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/connection_status.dart';
import '../../state/connection.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'phone_server_card.dart' show serverDisplayName;
import 'work_status_line.dart' show confirmPhoneServerRestart;

/// The single presentation of the controller's connection snapshot. The
/// controller owns escalation; this adapter never starts a clock.
KitStatus? connectionKitStatus(
  BuildContext context,
  ConnectionController controller, {
  bool showChangeServer = true,
  String? note,
  bool serverOnThisPhone = false,
  Future<void> Function()? onRestartServer,
  BuildContext? Function()? actionContext,
}) {
  final snapshot = controller.connectionStatus;
  if (!snapshot.visible) return null;
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  BuildContext? target() => actionContext == null ? context : actionContext();
  void editServer() {
    final current = target();
    if (current != null && current.mounted) {
      unawaited(
        Navigator.of(current).pushNamed('/servers', arguments: 'edit-active'),
      );
    }
  }

  final server = snapshot.serverName.isEmpty ? 'OpenCode' : snapshot.serverName;
  if (snapshot.phase == ConnectionStatusPhase.credentialsRequired) {
    return KitStatus(
      kind: KitStatusKind.connection,
      id: 'connection:${snapshot.profileId}',
      key: const ValueKey('connection-status-banner'),
      icon: AppIconography.locked,
      tone: AppStatusTone.failure,
      message: snapshot.usesToken
          ? l10n.connectionTokenRejected
          : l10n.e7BannerReconnectPassword,
      supporting: note,
      action: KitAction(
        key: ValueKey(
          snapshot.usesToken ? 'banner-update-token' : 'banner-update-password',
        ),
        label: snapshot.usesToken
            ? l10n.updateConnectionToken
            : l10n.e7BannerUpdatePassword,
        onPressed: editServer,
      ),
    );
  }
  final message = switch (snapshot.phase) {
    ConnectionStatusPhase.connecting => l10n.e7SetupConnectingProfile(server),
    ConnectionStatusPhase.reconnecting => l10n.e7BannerReconnectingServer(
      server,
    ),
    _ =>
      serverOnThisPhone
          ? l10n.workServerNotAnsweringPhone
          : l10n.workServerNotAnswering(server),
  };
  final retry = snapshot.retrying
      ? null
      : KitAction(
          key: const ValueKey('connection-banner-retry'),
          label: l10n.connectionReconnectTo(
            serverDisplayName(
              controller.profile,
              l10n,
              among: controller.store.profiles,
            ),
          ),
          onPressed: () => unawaited(controller.retryConnection()),
        );
  final restart = serverOnThisPhone ? onRestartServer : null;
  final restartAction = restart == null || snapshot.retrying || snapshot.waiting
      ? null
      : KitAction(
          key: const ValueKey('connection-banner-restart'),
          label: l10n.workServerRestart,
          onPressed: () => unawaited(() async {
            final current = target();
            if (current == null ||
                !current.mounted ||
                !await confirmPhoneServerRestart(current)) {
              return;
            }
            await restart();
          }()),
        );
  final supporting = [
    if (snapshot.usesToken) l10n.codexDraftReconnectNotice,
    if (note != null && note.isNotEmpty) note,
  ];
  return KitStatus(
    kind: KitStatusKind.connection,
    id: 'connection:${snapshot.profileId}',
    key: const ValueKey('connection-status-banner'),
    icon: snapshot.waiting ? AppIconography.sync : AppIconography.cloudOff,
    tone: snapshot.waiting ? AppStatusTone.progress : AppStatusTone.failure,
    message: message,
    supporting: supporting.isEmpty ? null : supporting.join(' '),
    action: restartAction ?? retry,
    more: [
      if (restartAction != null && retry != null) retry,
      KitAction(
        key: const ValueKey('connection-banner-details'),
        label: l10n.e7BannerDetails,
        onPressed: () {
          final current = target();
          if (current != null && current.mounted) {
            unawaited(
              showConnectionDetailsSheet(
                current,
                controller,
                showChangeServer: showChangeServer,
              ),
            );
          }
        },
      ),
      if (showChangeServer)
        KitAction(
          key: const ValueKey('connection-banner-change-server'),
          label: l10n.e7BannerChangeServer,
          onPressed: () {
            final current = target();
            if (current != null && current.mounted) {
              unawaited(Navigator.of(current).pushNamed('/servers'));
            }
          },
        ),
    ],
  );
}

/// Compatibility host for embedded consumers. In a KitScreen it contributes
/// to the existing slot and never adds another row.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.controller,
    this.showChangeServer = true,
    this.note,
    this.serverOnThisPhone = false,
    this.onRestartServer,
  });
  final ConnectionController controller;
  final bool showChangeServer;
  final String? note;
  final bool serverOnThisPhone;
  final Future<void> Function()? onRestartServer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = connectionKitStatus(
        context,
        controller,
        showChangeServer: showChangeServer,
        note: note,
        serverOnThisPhone: serverOnThisPhone,
        onRestartServer: onRestartServer,
      );
      if (KitStatusLineSlot.existsAbove(context)) {
        return KitStatusContribution(
          status: status,
          child: const SizedBox.shrink(),
        );
      }
      return status == null
          ? const SizedBox.shrink()
          : KitStatusLine.of(status);
    },
  );
}

/// The connection's details: what is going on, the raw error, Try again and
/// (optionally) Change server. Shared by the shell banner and the Work tab's
/// status line.
///
/// The shared status line opens this kit sheet for technical details. Its
/// phase comes from the same controller snapshot; the raw error stays in
/// a [KitDetailsFold] (KIT-33), open and copyable here.
Future<void> showConnectionDetailsSheet(
  BuildContext context,
  ConnectionController controller, {
  bool showChangeServer = true,
}) {
  final snapshot = controller.connectionStatus;
  final manualRetry = snapshot.retrying;
  final reconnecting = snapshot.waiting;
  final error = controller.connectionError?.trim();
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final navigator = Navigator.of(context);
  return showKitSheet<void>(
    context,
    title: reconnecting ? l10n.mcpReconnecting : l10n.e7BannerLost,
    icon: reconnecting ? AppIconography.sync : AppIconography.cloudOff,
    // While a Try again is in flight nothing here would help: the words
    // say it is reconnecting.
    primary: manualRetry
        ? null
        : KitAction(
            label: l10n.isolatedTaskRetryOpen,
            onPressed: () {
              navigator.pop();
              unawaited(controller.retryConnection());
            },
          ),
    tertiary: [
      if (showChangeServer && !manualRetry)
        KitAction(
          label: l10n.e7BannerChangeServer,
          onPressed: () {
            navigator.pop();
            navigator.pushNamed('/servers');
          },
        ),
    ],
    body: (sheetContext) => Column(
      key: const ValueKey('connection-banner-details-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitText(
          reconnecting
              ? l10n.e7BannerCheckingExplanation
              : l10n.e7BannerStaleExplanation,
          tone: KitTextTone.secondary,
        ),
        if (error != null && error.isNotEmpty) ...[
          SizedBox(height: KitTokens.of(sheetContext).space3),
          // This sheet exists to show the details, so the fold starts
          // open; it gives the raw error its copy action (tinkerer).
          KitDetailsFold(text: error, initiallyExpanded: true),
        ],
      ],
    ),
  );
}
