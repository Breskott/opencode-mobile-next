import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/external_agents.dart';
import '../kit/kit.dart';
import '../search/search_index.dart';
import 'external_agents_screen.dart';
import 'server_capabilities_screen.dart';

/// Settings › Tools (target-ia §1.3 row 7): everything the agent can use
/// besides the model, one row each: MCP servers, the server's commands,
/// skills, tools and references, plugins, and external agents. It replaces
/// the hub's separate MCP, Commands, Plugins and External agents rows.
///
/// Each row is its search entry, so search and this page cannot disagree.
/// A row the connected server cannot serve is absent, and one muted line
/// under the panel counts them and says why (the hub's rule).
///
/// States: all rows; catalog rows absent with the line (Codex, Paseo);
/// no saved server (External agents only).
class ToolsHubScreen extends StatefulWidget {
  const ToolsHubScreen({super.key, required this.controller});

  final ConnectionController controller;

  /// The rows in page order, by search entry id.
  static const rows = [
    'settings-mcp',
    'settings-commands-tools',
    'settings-category-plugins',
    'settings-external-agents',
  ];

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen> {
  Future<void> _open(SearchEntry entry, SearchScope scope) async {
    await entry.open(context, scope);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final scope = SearchScope.of(context, controller);
    final entries = {
      for (final entry in searchIndex(l10n, scope)) entry.id: entry,
    };
    final subtitles = {
      'settings-mcp': l10n.toolsHubMcpSubtitle,
      'settings-commands-tools': l10n.toolsHubCatalogSubtitle,
      'settings-category-plugins': l10n.toolsHubPluginsSubtitle,
      'settings-external-agents': l10n.toolsHubExternalAgentsSubtitle,
    };
    final hidden = controller.profile == null
        ? 0
        : allSearchEntries(l10n)
              .where(
                (entry) =>
                    ToolsHubScreen.rows.contains(entry.id) &&
                    entry.hiddenByServer(scope),
              )
              .length;
    final serverName = controller.profile?.name;
    return KitScreen(
      topBar: KitTopBar(title: l10n.settingsHubToolsRow, subtitle: serverName),
      width: KitScreenWidth.reading,
      body: ListView(
        key: const ValueKey('tools-hub'),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          KitRowGroup(
            children: [
              for (final id in ToolsHubScreen.rows)
                if (entries[id] case final entry?)
                  KitRow(
                    key: ValueKey(id),
                    leading: KitRow.icon(context, entry.icon),
                    title: entry.title,
                    supporting: TextSpan(text: subtitles[id]),
                    supportingMaxLines: 2,
                    trailing: const KitChevron(),
                    onTap: () => _open(entry, scope),
                  ),
            ],
          ),
          if (hidden > 0)
            KitGroupNote(
              key: const ValueKey('tools-hub-unavailable'),
              message: l10n.settingsHubUnavailableCount(hidden),
              action: KitAction(
                key: const ValueKey('tools-hub-unavailable-why'),
                label: l10n.settingsHubUnavailableWhy,
                onPressed: () => pushKitPage<void>(
                  context,
                  (_) => ServerCapabilitiesScreen(controller: controller),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens External agents with a store for as long as the page is open.
Future<void> openExternalAgents(
  BuildContext context,
  ConnectionController controller,
) async {
  final profiles = controller.store;
  final store = ExternalAgentStore(profiles.prefs, profiles.secure);
  try {
    await pushKitPage<void>(context, (_) => ExternalAgentsScreen(store: store));
  } finally {
    store.dispose();
  }
}

AppLocalizations _copy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
