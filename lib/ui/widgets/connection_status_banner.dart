import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/sse.dart';
import '../../state/connection.dart';
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit.dart';

/// The shell's connection line on the tabs that do not say it themselves
/// (design standard §5): one [KitStatusLine] with an icon, one line of words
/// and one action. The raw error and Change server live behind Details, in
/// the line's menu, so it never grows into a paragraph over the content it
/// sits on.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.controller,
    this.showChangeServer = true,
    this.note,
  });

  final ConnectionController controller;
  final bool showChangeServer;

  /// One optional extra line, e.g. how many drafts are queued for delivery.
  final String? note;

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
        tone: AppStatusTone.attention,
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
        tone: AppStatusTone.attention,
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
    final server = controller.profile?.name ?? 'OpenCode';
    final message = reconnecting
        ? l10n.e7BannerReconnectingServer(server)
        : l10n.e7BannerLost;
    final codexReconnect = controller.usesConnectionToken && reconnecting;
    final content = codexReconnect
        ? '$message\n${l10n.codexDraftReconnectNotice}${note == null || note!.isEmpty ? '' : '\n${note!}'}'
        : note == null || note!.isEmpty
        ? message
        : '$message\n${note!}';

    return KitStatusLine(
      key: const ValueKey('connection-status-banner'),
      // No spinner: the words say it is reconnecting; a spinner would run
      // silently for as long as the server is away (§4).
      icon: reconnecting ? AppIconography.sync : AppIconography.cloudOff,
      tone: reconnecting ? AppStatusTone.progress : AppStatusTone.attention,
      message: content,
      // While a Try again of the person's own is in flight the words say
      // so; a disabled "Retrying" button would be a status display (§2).
      action: manualRetry
          ? null
          : KitAction(
              label: l10n.isolatedTaskRetryOpen,
              onPressed: () => unawaited(controller.retryConnection()),
            ),
      more: [
        KitAction(
          key: const ValueKey('connection-banner-details'),
          label: l10n.e7BannerDetails,
          onPressed: () => showConnectionDetailsSheet(
            context,
            controller,
            showChangeServer: showChangeServer,
          ),
        ),
      ],
    );
  }
}

/// The connection's details: what is going on, the raw error, Try again and
/// (optionally) Change server. Shared by the shell banner and the Work tab's
/// status line.
Future<void> showConnectionDetailsSheet(
  BuildContext context,
  ConnectionController controller, {
  bool showChangeServer = true,
}) {
  final manualRetry = controller.manualReconnectInProgress;
  final reconnecting = controller.connectionLoading || manualRetry;
  final error = controller.connectionError?.trim();
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              key: const ValueKey('connection-banner-details-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  reconnecting ? l10n.mcpReconnecting : l10n.e7BannerLost,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  reconnecting
                      ? l10n.e7BannerCheckingExplanation
                      : l10n.e7BannerStaleExplanation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppTheme.monoFamily,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // While a Try again is in flight nothing here would help:
                // the words above say it is reconnecting.
                KitActionBlock(
                  primary: manualRetry
                      ? null
                      : KitAction(
                          label: l10n.isolatedTaskRetryOpen,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(controller.retryConnection());
                          },
                        ),
                  tertiary: [
                    if (showChangeServer && !manualRetry)
                      KitAction(
                        label: l10n.e7BannerChangeServer,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).pushNamed('/servers');
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
