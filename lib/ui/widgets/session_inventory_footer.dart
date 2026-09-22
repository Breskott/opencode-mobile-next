import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';

/// Shared continuation controls, including pages with no visible root chats.
class SessionInventoryFooter extends StatelessWidget {
  const SessionInventoryFooter({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = lookupAppLocalizations(Localizations.localeOf(context));
      final pinError = controller.pinnedSessionsLoadFailed;
      final error =
          controller.sessionsError ??
          controller.sessionsMoreError ??
          (pinError ? l10n.sessionPinsLoadFailed : null);
      final canContinue = controller.hasMoreSessions;
      final loading =
          controller.sessionsLoading || controller.sessionsLoadingMore;
      if (!controller.hasMoreSessions && error == null && !loading) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The button says what it does; a sentence repeating it under
            // a short list was noise. Only an error or loading is worth words.
            if (error != null || loading) ...[
              Text(
                error ?? l10n.e7WorkspaceLoadingSessions,
                style: error == null
                    ? null
                    : TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 6),
            ],
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if ((controller.sessionsError != null || pinError) && canContinue)
              TextButton(
                onPressed: loading ? null : controller.refreshSessions,
                child: Text(l10n.sessionsReload),
              ),
            TextButton(
              key: const ValueKey('session-inventory-more'),
              onPressed: loading
                  ? null
                  : (controller.sessionsError != null || pinError) &&
                        !canContinue
                  ? controller.refreshSessions
                  : controller.loadMoreSessions,
              child: Text(
                controller.sessionsNeedReload
                    ? l10n.sessionsReload
                    : controller.sessionsMoreError != null ||
                          ((controller.sessionsError != null || pinError) &&
                              !canContinue)
                    ? l10n.refreshRetry
                    : l10n.sessionsLoadMore,
              ),
            ),
          ],
        ),
      );
    },
  );
}
