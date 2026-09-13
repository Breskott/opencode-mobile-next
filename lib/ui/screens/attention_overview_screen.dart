import 'package:flutter/material.dart';

import '../../domain/attention_item.dart';
import '../../state/attention_overview.dart';
import '../../state/connection.dart';
import '../widgets/product_states.dart';
import 'profile_monitor_screen.dart';
import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';

/// Local overview only. The host owns navigation and any profile-switch guard.
class AttentionOverviewScreen extends StatelessWidget {
  const AttentionOverviewScreen({
    super.key,
    required this.controller,
    this.onOpenProfile,
  });

  final ConnectionController controller;

  /// Called only after an explicit tap, with a still-readable saved profile ID.
  /// The host must revalidate the ID, use its existing safe switch flow (including
  /// any leave-active-work confirmation), and then open that profile's Activity.
  /// This screen never switches profiles or dispatches an approval itself.
  final void Function(String profileID)? onOpenProfile;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        lookupAppLocalizations(Localizations.localeOf(context)).attentionTitle,
      ),
      actions: [
        IconButton(
          icon: const Icon(AppIconography.settings),
          tooltip: lookupAppLocalizations(
            Localizations.localeOf(context),
          ).monitorConfigure,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileMonitorScreen(controller: controller),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          controller,
          controller.profileDataChanges,
        ]),
        builder: (context, _) {
          final l10n = lookupAppLocalizations(Localizations.localeOf(context));
          final overview = AttentionOverview.fromController(controller);
          if (overview.items.isEmpty) {
            return ProductEmptyState(
              icon: AppIconography.server,
              title: l10n.e7ProjectAttentionNoServers,
              message: l10n.e7ProjectAttentionNoServersDetail,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: overview.items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    lookupAppLocalizations(
                      Localizations.localeOf(context),
                    ).attentionDisclosure,
                  ),
                );
              }
              return _profileCard(context, overview.items[index - 1]);
            },
          );
        },
      ),
    ),
  );

  Widget _profileCard(BuildContext context, AttentionItem item) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.profileName.trim().isEmpty
                  ? l10n.e7ProjectAttentionSavedServer
                  : item.profileName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              item.isSelected
                  ? l10n.e7ProjectAttentionSelected
                  : l10n.e7ProjectAttentionInactive,
            ),
            const SizedBox(height: 8),
            Text(
              item.hasConnectionCache
                  ? l10n.e7ProjectAttentionCacheSource
                  : l10n.e7ProjectAttentionProfileSource,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              item.pendingRequests == null
                  ? l10n.e7ProjectAttentionPendingUnknown
                  : l10n.e7ProjectAttentionPendingKnown(item.pendingRequests!),
            ),
            const SizedBox(height: 4),
            Text(
              item.runningSessions == null
                  ? l10n.e7ProjectAttentionRunningUnknown
                  : l10n.e7ProjectAttentionRunningKnown(item.runningSessions!),
            ),
            const SizedBox(height: 4),
            Text(
              item.unreadSessions == null
                  ? l10n.e7ProjectAttentionUnreadUnknown
                  : l10n.e7ProjectAttentionUnreadKnown(item.unreadSessions!),
            ),
            const SizedBox(height: 12),
            if (onOpenProfile == null) ...[
              Text(
                lookupAppLocalizations(
                  Localizations.localeOf(context),
                ).attentionNavigationUnavailable,
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: onOpenProfile == null
                  ? null
                  : () {
                      if (controller.isProfileReadable(item.profileID) &&
                          controller.store.profiles.any(
                            (profile) => profile.id == item.profileID,
                          )) {
                        onOpenProfile!(item.profileID);
                      }
                    },
              child: Text(
                item.isSelected
                    ? l10n.e7ProjectAttentionOpen
                    : l10n.e7ProjectAttentionChoose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
