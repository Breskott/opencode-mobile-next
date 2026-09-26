import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../api/sse.dart';
import '../../state/connection.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_details_fold.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_status_line.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import 'work_status_line.dart' show confirmPhoneServerRestart;

/// The shell's connection line on the tabs that do not say it themselves
/// (design standard §5): one [KitStatusLine] with an icon, one line of words
/// and one action. The raw error and Change server live behind Details, in
/// the line's menu, so it never grows into a paragraph over the content it
/// sits on.
///
/// Kit only (shared-shell-1, map embedded-connection-status-banner "fix"):
/// the line's tones follow LOOK-4 (a lost server or a rejected password is a
/// failure, not "needs you"); Change server is in the line's menu, and when
/// the host says the server is this phone's own and hands over
/// [onRestartServer], the line offers Restart first, as the Work tab's line
/// does. The fixed "Reconnecting…, then isn't answering" stages belong to
/// slice-P4.4 (one connection status).
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

  /// One optional extra line, e.g. how many drafts are queued for delivery.
  final String? note;

  /// The server is the phone's own (Termux or in the app): it is named
  /// "OpenCode on this phone".
  final bool serverOnThisPhone;

  /// Restarts the phone's server; null when this server cannot be restarted
  /// from here. With [serverOnThisPhone], Restart becomes the line's action
  /// (after a confirmation) and Try again moves into its menu.
  final Future<void> Function()? onRestartServer;

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (controller.status == StreamStatus.connected) {
      return const SizedBox.shrink();
    }
    void editServer() =>
        Navigator.of(context).pushNamed('/servers', arguments: 'edit-active');

    // A rejected Codex token cannot self-heal through retries: surface the
    // one action that fixes it and keep it a line, never a modal.
    if (controller.passwordRejected && controller.usesConnectionToken) {
      return KitStatusLine(
        key: const ValueKey('connection-status-banner'),
        icon: AppIconography.locked,
        tone: AppStatusTone.failure,
        message: l10n.connectionTokenRejected,
        action: KitAction(
          key: const ValueKey('banner-update-token'),
          label: l10n.updateConnectionToken,
          onPressed: editServer,
        ),
      );
    }

    // A rotated v2 serve password cannot self-heal through retries: surface
    // the one action that fixes it and keep it a line, never a modal.
    if (controller.passwordRejected) {
      return KitStatusLine(
        key: const ValueKey('connection-status-banner'),
        icon: AppIconography.locked,
        tone: AppStatusTone.failure,
        message: note == null || note!.isEmpty
            ? l10n.e7BannerReconnectPassword
            : l10n.e7BannerReconnectPasswordNote(note!),
        action: KitAction(
          key: const ValueKey('banner-update-password'),
          label: l10n.e7BannerUpdatePassword,
          onPressed: editServer,
        ),
      );
    }

    final manualRetry = controller.manualReconnectInProgress;
    final reconnecting = controller.connectionLoading || manualRetry;
    final restart = serverOnThisPhone ? onRestartServer : null;
    final server = controller.profile?.name ?? 'OpenCode';
    final message = reconnecting
        ? l10n.e7BannerReconnectingServer(server)
        : restart != null
        ? l10n.workServerNotAnsweringPhone
        : l10n.e7BannerLost;
    final codexReconnect = controller.usesConnectionToken && reconnecting;
    final content = codexReconnect
        ? '$message\n${l10n.codexDraftReconnectNotice}${note == null || note!.isEmpty ? '' : '\n${note!}'}'
        : note == null || note!.isEmpty
        ? message
        : '$message\n${note!}';

    // While a Try again of the person's own is in flight the words say so;
    // a disabled "Retrying" button would be a status display (§2).
    final retry = manualRetry
        ? null
        : KitAction(
            key: const ValueKey('connection-banner-retry'),
            label: l10n.isolatedTaskRetryOpen,
            onPressed: () => unawaited(controller.retryConnection()),
          );
    // The phone's own server: the way out the app cannot take alone is a
    // restart, so it comes first (as on the Work tab's line).
    final restartAction = restart == null || manualRetry
        ? null
        : KitAction(
            key: const ValueKey('connection-banner-restart'),
            label: l10n.workServerRestart,
            onPressed: () => unawaited(_restart(context, restart)),
          );

    return KitStatusLine(
      key: const ValueKey('connection-status-banner'),
      // No spinner: the words say it is reconnecting; a spinner would run
      // silently for as long as the server is away (§4).
      icon: reconnecting ? AppIconography.sync : AppIconography.cloudOff,
      tone: reconnecting ? AppStatusTone.progress : AppStatusTone.failure,
      message: content,
      action: restartAction ?? retry,
      more: [
        if (restartAction != null && retry != null) retry,
        KitAction(
          key: const ValueKey('connection-banner-details'),
          label: l10n.e7BannerDetails,
          onPressed: () => showConnectionDetailsSheet(
            context,
            controller,
            showChangeServer: showChangeServer,
          ),
        ),
        if (showChangeServer)
          KitAction(
            key: const ValueKey('connection-banner-change-server'),
            label: l10n.e7BannerChangeServer,
            onPressed: () => Navigator.of(context).pushNamed('/servers'),
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
}

// revamp: merge-into:root-connecting (slice-P4.4)
/// The connection's details: what is going on, the raw error, Try again and
/// (optionally) Change server. Shared by the shell banner and the Work tab's
/// status line.
///
/// Kit only with the least change (MAP-1: this sheet merges into the
/// diagnosed connection card in slice-P4.4): the kit sheet frame, the words
/// as [KitText], and the raw error in a [KitDetailsFold] (KIT-33), open and
/// copyable there.
Future<void> showConnectionDetailsSheet(
  BuildContext context,
  ConnectionController controller, {
  bool showChangeServer = true,
}) {
  final manualRetry = controller.manualReconnectInProgress;
  final reconnecting = controller.connectionLoading || manualRetry;
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
