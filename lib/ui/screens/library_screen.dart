import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/mcp_oauth.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../domain/server_gateway.dart' show StreamStatus;
import '../../api/provider_presentation.dart';
import '../../feedback/bug_report.dart';
import '../../api/product_repository.dart';
import '../../state/connection.dart';
import '../../state/pending_auth.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../desktop/shortcuts.dart';
import '../widgets/file_preview.dart';
import '../widgets/external_link.dart';
import '../widgets/connect_methods.dart';
import '../widgets/info_label.dart';
import '../widgets/provider_logo.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/product_states.dart';
import '../widgets/run_command_dialog.dart';
import '../widgets/pickers.dart';
import 'capabilities_screen.dart';
import 'guide_screen.dart';
import 'mcp_setup_screen.dart';
import 'settings_screen.dart';
import 'session_import_screen.dart';
import 'terminal_screen.dart';
import 'termux_setup_screen.dart';
import 'plugins_screen.dart';

part 'library/catalog_screen.dart';
part 'library/integrations_screen.dart';
part 'library/integration_tiles.dart';
part 'library/credential_sheet.dart';
part 'library/command_auth_sheet.dart';
part 'library/pending_auth_recovery.dart';
part 'library/commands_screen.dart';
part 'library/skills_screen.dart';
part 'library/skill_activation.dart';
part 'library/references_screen.dart';

class LibraryScreen extends StatefulWidget {
  final ConnectionController controller;
  const LibraryScreen({super.key, required this.controller});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String _query = '';
  ConnectionController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        // Local Android tools belong to the phone, not the connected server's
        // capability set. Keep this entry visible even on a remote profile.
        final phoneTools = <_DestinationRow>[
          if (platformCapabilities.supportsTermux)
            _DestinationRow(
              icon: AppIconography.phone,
              title: l10n.onboardingTermuxSetup,
              subtitle: l10n.onboardingRunOnPhone,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchPhoneAliases,
              onTap: () => _open(context, const TermuxSetupScreen()),
            ),
        ].where((row) => row.matches(_query)).toList();
        final group0 = <_DestinationRow>[
          if (controller.capabilities.serverCatalog) ...[
            _DestinationRow(
              primary: true,
              icon: AppIconography.model,
              title: l10n.libraryModelsAgentsTitle,
              subtitle: l10n.settingsDiscoveryNewChatsModel(
                _defaultModelLabel(controller, l10n),
              ),
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchModelAliases,
              onTap: () =>
                  _open(context, CatalogScreen(controller: controller)),
            ),
            _DestinationRow(
              icon: AppIconography.cloud,
              title: l10n.libraryProvidersTitle,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchProviderAliases,
              onTap: () => _open(
                context,
                IntegrationsScreen(
                  controller: controller,
                  mode: IntegrationsMode.providers,
                ),
              ),
            ),
            _DestinationRow(
              icon: AppIconography.network,
              title: l10n.libraryMcpTitle,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchMcpAliases,
              onTap: () => _open(
                context,
                IntegrationsScreen(
                  controller: controller,
                  mode: IntegrationsMode.mcp,
                ),
              ),
            ),
            _DestinationRow(
              icon: AppIconography.tools,
              title: l10n.libraryCommandsToolsTitle,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchCommandsAliases,
              onTap: () =>
                  _open(context, CapabilitiesScreen(controller: controller)),
            ),
          ],
          if (controller.capabilities.pluginInventory)
            _DestinationRow(
              icon: AppIconography.extensions,
              title: l10n.pluginsTitle,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchPluginsAliases,
              onTap: () =>
                  _open(context, PluginsScreen(controller: controller)),
            ),
          // §5: Terminal gives up its navigation slot to Activity and
          // is reached from here (and from a session) instead.
          if (controller.capabilities.terminal)
            _DestinationRow(
              key: const ValueKey('library-terminal'),
              primary: true,
              icon: AppIconography.terminal,
              title: l10n.libraryTerminalTitle,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchTerminalAliases,
              onTap: () => _open(context, TerminalPage(controller: controller)),
            ),
        ].where((card) => card.matches(_query)).toList();
        final group1 = <_DestinationRow>[
          if (controller.capabilities.sessionImportExport &&
              controller.repository is SessionImportGateway &&
              (controller.repository as SessionImportGateway)
                  .sessionImportSupported)
            _DestinationRow(
              key: const ValueKey('library-import-session'),
              icon: AppIconography.fileUpload,
              title: l10n.importTitle,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchImportAliases,
              onTap: () =>
                  _open(context, SessionImportScreen(controller: controller)),
            ),
          _DestinationRow(
            primary: true,
            icon: AppIconography.settings,
            title: l10n.librarySettingsTitle,
            keywords: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibrarySearchSettingsAliases,
            onTap: () => _open(context, SettingsScreen(controller: controller)),
          ),
          _DestinationRow(
            icon: AppIconography.guide,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).onboardingSetupGuide,
            keywords: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibrarySearchGuideAliases,
            onTap: () => _open(context, const GuideScreen()),
          ),
          // The bug form lives in the failure states themselves; this
          // card is the deliberate path for everything a user notices
          // outside a failure surface.
          _DestinationRow(
            key: const ValueKey('library-report-bug'),
            icon: AppIconography.bug,
            title: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibraryReportABug,
            keywords: lookupAppLocalizations(
              Localizations.localeOf(context),
            ).e7LibrarySearchBugAliases,
            onTap: () => unawaited(openBugReport(context)),
          ),
          // The shortcut layer must be discoverable without already
          // knowing a shortcut.
          if (desktopInteractions)
            _DestinationRow(
              key: const ValueKey('library-keyboard-shortcuts'),
              icon: AppIconography.keyboard,
              title: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibraryKeyboardShortcuts,
              keywords: lookupAppLocalizations(
                Localizations.localeOf(context),
              ).e7LibrarySearchShortcutsAliases,
              onTap: () => unawaited(showShortcutsHelp(context)),
            ),
        ].where((card) => card.matches(_query)).toList();
        // Audit UX-P0-01: no Mission Control or Requests card here. Pending
        // work has exactly one home — the Activity destination and its badge.
        return DesktopScrollbarArea(
          builder: (scrollController) => ListView(
            controller: scrollController,
            padding: EdgeInsetsDirectional.fromSTEB(
              12,
              8,
              12,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
                child: TextField(
                  key: const Key('library-search'),
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: l10n.librarySearchHint,
                    prefixIcon: const Icon(AppIconography.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.commonClearSearch,
                            icon: const Icon(AppIconography.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              ...phoneTools,
              _DestinationGroup(
                title: l10n.libraryBrowseSection,
                cards: [
                  ...group1.where((row) => row.primary),
                  ...group0.where((row) => row.primary),
                ],
              ),
              _DestinationGroup(
                title: l10n.calmMoreToolsAndHelp,
                collapsible: _query.isEmpty,
                cards: [
                  ...group0.where((row) => !row.primary),
                  ...group1.where((row) => !row.primary),
                ],
              ),
              if (_query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.librarySearchResults(
                      phoneTools.length + group0.length + group1.length,
                      _search.text.trim(),
                    ),
                    key: const Key('library-search-summary'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

/// Keep the default visible in its destination, using the catalog display name.
String _defaultModelLabel(
  ConnectionController controller,
  AppLocalizations l10n,
) {
  final model = controller.selectedModel;
  if (model == null) return l10n.libraryNoModel;
  final catalogModel = controller.catalog?.models
      .where(
        (candidate) =>
            candidate.providerID == model.providerID &&
            candidate.id == model.modelID,
      )
      .firstOrNull;
  return catalogModel?.name.trim().isNotEmpty == true
      ? catalogModel!.name
      : presentedModelLabel(model.providerID, model.modelID);
}

/// Grouped rows let people scan destinations without a grid of empty tiles.
/// Intrinsic row heights also accommodate large text without truncating labels.
class _DestinationGroup extends StatelessWidget {
  final List<_DestinationRow> cards;
  final String title;
  final bool collapsible;

  const _DestinationGroup({
    required this.cards,
    required this.title,
    this.collapsible = false,
  });

  @override
  Widget build(BuildContext context) {
    final matches = cards;
    if (matches.isEmpty) return const SizedBox.shrink();
    if (collapsible) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ExpansionTile(
          key: const PageStorageKey('library-tools-and-help'),
          title: Text(title),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          children: matches,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < matches.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 60, endIndent: 16),
                matches[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String keywords;
  final String? subtitle;
  final VoidCallback onTap;
  final bool primary;

  const _DestinationRow({
    super.key,
    required this.icon,
    required this.title,
    this.keywords = '',
    this.subtitle,
    this.primary = false,
    required this.onTap,
  });

  bool matches(String query) => query
      .split(RegExp(r'\s+'))
      .every((word) => '$title $keywords'.toLowerCase().contains(word));

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: subtitle == null ? 56 : 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 32,
      horizontalTitleGap: 12,
      leading: SizedBox.square(dimension: 32, child: Icon(icon, size: 24)),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(AppIconography.chevronRight, size: 20),
      onTap: onTap,
    );
  }
}
