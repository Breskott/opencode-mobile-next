import 'package:flutter/material.dart';

import '../../domain/server_gateway.dart' show ServerCapabilities;
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../widgets/product_states.dart';

/// Where a feature's answer comes from, which decides the heading an absent
/// one is listed under: the server cannot do it, or this device cannot.
enum ServerFeatureSource { server, device }

/// What [ServerFeature.available] may read.
typedef ServerFeatureFacts = ({
  ServerCapabilities server,
  PlatformCapabilities device,
  bool usageStatistics,
});

/// One thing the app can do, in the person's words. Plain data, so the list
/// can be tested against a capability set without a widget.
class ServerFeature {
  const ServerFeature({
    required this.id,
    required this.title,
    required this.detail,
    required this.available,
    this.source = ServerFeatureSource.server,
  });

  final String id;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) detail;
  final bool Function(ServerFeatureFacts facts) available;
  final ServerFeatureSource source;
}

/// Every feature that rule 7 can hide, in the order a person meets them:
/// project tools, then what a conversation can do, then setup. A backend
/// name never appears here; the only proper noun on the screen is the
/// server's own name.
final List<ServerFeature> serverFeatures = [
  ServerFeature(
    id: 'files',
    title: (l10n) => l10n.capabilityFiles,
    detail: (l10n) => l10n.capabilityFilesDetail,
    available: (facts) => facts.server.fileBrowsing,
  ),
  ServerFeature(
    id: 'changes',
    title: (l10n) => l10n.capabilityChanges,
    detail: (l10n) => l10n.capabilityChangesDetail,
    // Either door is enough: a conversation's own diff, or the project's
    // working tree through the file API.
    available: (facts) => facts.server.sessionDiff || facts.server.fileBrowsing,
  ),
  ServerFeature(
    id: 'terminal',
    title: (l10n) => l10n.capabilityTerminal,
    detail: (l10n) => l10n.capabilityTerminalDetail,
    available: (facts) => facts.server.terminal,
  ),
  ServerFeature(
    id: 'shell',
    title: (l10n) => l10n.capabilityShell,
    detail: (l10n) => l10n.capabilityShellDetail,
    available: (facts) => facts.server.shellSettings,
  ),
  ServerFeature(
    id: 'projects',
    title: (l10n) => l10n.capabilityProjects,
    detail: (l10n) => l10n.capabilityProjectsDetail,
    available: (facts) => facts.server.projectManagement,
  ),
  ServerFeature(
    id: 'worktrees',
    title: (l10n) => l10n.capabilityWorktrees,
    detail: (l10n) => l10n.capabilityWorktreesDetail,
    available: (facts) => facts.server.projectManagement,
  ),
  ServerFeature(
    id: 'cloud-environments',
    title: (l10n) => l10n.capabilityCloud,
    detail: (l10n) => l10n.capabilityCloudDetail,
    available: (facts) => facts.server.managedWorkspaces,
  ),
  ServerFeature(
    id: 'attachments',
    title: (l10n) => l10n.capabilityAttachments,
    detail: (l10n) => l10n.capabilityAttachmentsDetail,
    available: (facts) => facts.server.promptAttachments,
  ),
  ServerFeature(
    id: 'subagents',
    title: (l10n) => l10n.capabilitySubagents,
    detail: (l10n) => l10n.capabilitySubagentsDetail,
    available: (facts) => facts.server.promptAgentMentions,
  ),
  ServerFeature(
    id: 'compact',
    title: (l10n) => l10n.capabilityCompact,
    detail: (l10n) => l10n.capabilityCompactDetail,
    available: (facts) => facts.server.sessionCompact,
  ),
  ServerFeature(
    id: 'share',
    title: (l10n) => l10n.capabilityShare,
    detail: (l10n) => l10n.capabilityShareDetail,
    available: (facts) => facts.server.sessionShare,
  ),
  ServerFeature(
    id: 'fork',
    title: (l10n) => l10n.capabilityFork,
    detail: (l10n) => l10n.capabilityForkDetail,
    available: (facts) => facts.server.sessionFork,
  ),
  ServerFeature(
    id: 'revert',
    title: (l10n) => l10n.capabilityRevert,
    detail: (l10n) => l10n.capabilityRevertDetail,
    available: (facts) => facts.server.sessionRevert,
  ),
  ServerFeature(
    id: 'archive',
    title: (l10n) => l10n.capabilityArchive,
    detail: (l10n) => l10n.capabilityArchiveDetail,
    available: (facts) => facts.server.sessionArchive,
  ),
  ServerFeature(
    id: 'todos',
    title: (l10n) => l10n.capabilityTodos,
    detail: (l10n) => l10n.capabilityTodosDetail,
    available: (facts) => facts.server.sessionTodos,
  ),
  ServerFeature(
    id: 'notes',
    title: (l10n) => l10n.capabilityNotes,
    detail: (l10n) => l10n.capabilityNotesDetail,
    available: (facts) => facts.server.sessionNotes,
  ),
  ServerFeature(
    id: 'import-export',
    title: (l10n) => l10n.capabilityImportExport,
    detail: (l10n) => l10n.capabilityImportExportDetail,
    available: (facts) => facts.server.sessionImportExport,
  ),
  ServerFeature(
    id: 'all-conversations',
    title: (l10n) => l10n.capabilitySearchAll,
    detail: (l10n) => l10n.capabilitySearchAllDetail,
    available: (facts) => facts.server.globalSessionSearch,
  ),
  ServerFeature(
    id: 'always-allow',
    title: (l10n) => l10n.capabilityAlwaysAllow,
    detail: (l10n) => l10n.capabilityAlwaysAllowDetail,
    available: (facts) => facts.server.persistentPermissionGrants,
  ),
  ServerFeature(
    id: 'send-later',
    title: (l10n) => l10n.capabilityOfflineQueue,
    detail: (l10n) => l10n.capabilityOfflineQueueDetail,
    available: (facts) => facts.server.offlinePromptQueue,
  ),
  ServerFeature(
    id: 'continue-on-computer',
    title: (l10n) => l10n.capabilityContinueOnComputer,
    detail: (l10n) => l10n.capabilityContinueOnComputerDetail,
    available: (facts) => facts.server.cliSessionResume,
  ),
  ServerFeature(
    id: 'models',
    title: (l10n) => l10n.capabilityModels,
    detail: (l10n) => l10n.capabilityModelsDetail,
    available: (facts) => facts.server.serverCatalog,
  ),
  ServerFeature(
    id: 'skills',
    title: (l10n) => l10n.capabilitySkills,
    detail: (l10n) => l10n.capabilitySkillsDetail,
    available: (facts) => facts.server.serverCatalog,
  ),
  ServerFeature(
    id: 'mcp',
    title: (l10n) => l10n.capabilityMcp,
    detail: (l10n) => l10n.capabilityMcpDetail,
    available: (facts) => facts.server.serverCatalog,
  ),
  ServerFeature(
    id: 'plugins',
    title: (l10n) => l10n.capabilityPlugins,
    detail: (l10n) => l10n.capabilityPluginsDetail,
    available: (facts) => facts.server.pluginInventory,
  ),
  ServerFeature(
    id: 'usage',
    title: (l10n) => l10n.capabilityUsage,
    detail: (l10n) => l10n.capabilityUsageDetail,
    available: (facts) => facts.usageStatistics,
  ),
  ServerFeature(
    id: 'server-updates',
    title: (l10n) => l10n.capabilityServerUpdates,
    detail: (l10n) => l10n.capabilityServerUpdatesDetail,
    available: (facts) => facts.server.remoteUpgrade,
  ),
  // What the device decides. On a phone these are all "Available here"; the
  // third heading only exists where one of them is missing.
  ServerFeature(
    id: 'background-notifications',
    source: ServerFeatureSource.device,
    title: (l10n) => l10n.capabilityBackgroundNotifications,
    detail: (l10n) => l10n.capabilityBackgroundNotificationsDetail,
    available: (facts) =>
        facts.device.supportsNotifications &&
        facts.device.supportsBackgroundService,
  ),
  ServerFeature(
    id: 'on-this-phone',
    source: ServerFeatureSource.device,
    title: (l10n) => l10n.capabilityOnThisPhone,
    detail: (l10n) => l10n.capabilityOnThisPhoneDetail,
    available: (facts) => facts.device.supportsTermux,
  ),
  ServerFeature(
    id: 'voice',
    source: ServerFeatureSource.device,
    title: (l10n) => l10n.capabilityVoice,
    detail: (l10n) => l10n.capabilityVoiceDetail,
    available: (facts) => facts.device.supportsVoice,
  ),
];

/// Settings → Help → "Available on this server": the explanation for every
/// row rule 7 hides. A feature the connected server cannot do is absent from
/// the menus and tabs, so this is the one place that says so.
class ServerCapabilitiesScreen extends StatelessWidget {
  const ServerCapabilitiesScreen({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.capabilityScreenTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final ServerFeatureFacts facts = (
            server: controller.capabilities,
            device: platformCapabilities,
            usageStatistics: controller.supportsUsageStatistics,
          );
          final available = [
            for (final feature in serverFeatures)
              if (feature.available(facts)) feature,
          ];
          List<ServerFeature> missing(ServerFeatureSource source) => [
            for (final feature in serverFeatures)
              if (!feature.available(facts) && feature.source == source)
                feature,
          ];
          final onServer = missing(ServerFeatureSource.server);
          final onDevice = missing(ServerFeatureSource.device);
          return DesktopScrollbarArea(
            builder: (scrollController) => ListView(
              controller: scrollController,
              key: const ValueKey('server-capabilities'),
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
                  child: Text(
                    l10n.capabilityScreenIntro(
                      controller.profile?.name ?? l10n.e7SettingsUi9,
                    ),
                    key: const ValueKey('server-capabilities-intro'),
                  ),
                ),
                _Group(
                  slug: 'available',
                  title: l10n.capabilityGroupAvailable,
                  features: available,
                  present: true,
                ),
                if (onServer.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      16,
                      16,
                      0,
                    ),
                    child: Text(
                      l10n.capabilityAllAvailable,
                      key: const ValueKey('server-capabilities-all'),
                    ),
                  )
                else
                  _Group(
                    slug: 'unavailable',
                    title: l10n.capabilityGroupUnavailable,
                    features: onServer,
                    present: false,
                  ),
                if (onDevice.isNotEmpty)
                  _Group(
                    slug: 'device',
                    title: l10n.capabilityGroupDevice,
                    features: onDevice,
                    present: false,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.slug,
    required this.title,
    required this.features,
    required this.present,
  });

  final String slug;
  final String title;
  final List<ServerFeature> features;
  final bool present;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Column(
      key: ValueKey('capabilities-$slug'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        for (final feature in features)
          // Read-only rows: nothing here is a control, so nothing looks
          // tappable or disabled.
          ListTile(
            key: ValueKey('capability-$slug-${feature.id}'),
            leading: Icon(
              present ? AppIconography.check : AppIconography.blocked,
              color: present ? AppTheme.successOf(theme) : muted,
            ),
            title: Text(feature.title(l10n)),
            subtitle: Text(feature.detail(l10n)),
          ),
      ],
    );
  }
}
