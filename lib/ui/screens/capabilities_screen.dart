import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import 'library_screen.dart';
import 'tools_screen.dart';

/// One tabbed home for the four server catalogs (commands, tools, skills,
/// references), built from kit parts only (screen-library-2).
///
/// Gates explain instead of vanishing (P7.4, STATE-12): a server that does
/// not share its catalog shows why on the whole page; a server that shares
/// its catalog but not its tool list keeps the Tools tab, which says why.
///
/// States: loaded (four tabs), tools not listed (Tools tab explains),
/// catalog not shared (page explains).
class CapabilitiesScreen extends StatefulWidget {
  final ConnectionController controller;

  /// The tab to open on, counted the way callers always have: Commands 0,
  /// Tools 1, Skills 2, References 3 where the server lists its tools, and
  /// without Tools (Skills 1, References 2) where it does not. The Tools
  /// tab now stays in both cases, so the count is mapped (see [_tabFor]).
  final int initialTab;

  const CapabilitiesScreen({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });

  @override
  State<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends State<CapabilitiesScreen> {
  static const _toolsTab = 1;
  static const _tabCount = 4;

  late int _index = _tabFor(widget.initialTab);

  /// Callers that knew Tools was missing counted Skills as 1: move them
  /// past the explained Tools tab so they land where they meant.
  int _tabFor(int requested) {
    final tools = widget.controller.capabilities.toolInventory;
    final index = !tools && requested >= _toolsTab ? requested + 1 : requested;
    return index.clamp(0, _tabCount - 1);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) {
    final l10n = _l10n(context);
    final controller = widget.controller;
    final capabilities = controller.capabilities;
    final serverName = controller.profile?.name;
    final topBar = KitTopBar(
      title: l10n.libraryCommandsToolsTitle,
      subtitle: serverName,
    );
    if (!capabilities.serverCatalog) {
      // Codex and Paseo keep their commands and skills to themselves: say
      // so, and which servers share them (P7.4).
      return KitScreen(
        topBar: topBar,
        width: KitScreenWidth.list,
        body: KitCapabilityExplainer.state(
          key: const ValueKey('capabilities-unavailable'),
          capability: 'flag:serverCatalog',
          serverName: serverName,
          size: KitStateSize.page,
          source: 'capabilities',
        ),
      );
    }
    final labels = [
      l10n.runResultsCommandsTitle,
      l10n.e7SettingsDetailUi25,
      l10n.e7SettingsDetailUi26,
      l10n.e7SettingsDetailUi27,
    ];
    return KitScreen(
      topBar: topBar,
      width: KitScreenWidth.list,
      body: KitTabSwitcher.tabs(
        semanticsLabel: l10n.libraryCommandsToolsTitle,
        index: _index,
        onSelected: (index) => setState(() => _index = index),
        tabs: [
          for (final label in labels)
            KitTab(key: ValueKey('capabilities-tab-$label'), label: label),
        ],
        children: [
          CommandsScreen(controller: controller, embedded: true),
          if (capabilities.toolInventory)
            ToolsScreen(controller: controller, embedded: true)
          else
            _ToolsNotListed(serverName: serverName),
          SkillsScreen(controller: controller, embedded: true),
          ReferencesScreen(controller: controller, embedded: true),
        ],
      ),
    );
  }
}

/// The Tools tab on a server that does not list its tools (OpenCode 2,
/// Codex, Paseo): why, and which servers do. No enable flow exists for
/// this capability, so it explains only (STATE-8: no dead button).
class _ToolsNotListed extends StatelessWidget {
  const _ToolsNotListed({required this.serverName});

  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final name = serverName?.trim();
    return ListView(
      padding: KitScreen.padding(context),
      children: [
        KitStateView.missing(
          key: const ValueKey('capabilities-tools-unavailable'),
          capability: 'server.oc1',
          icon: AppIconography.tools,
          title: name == null || name.isEmpty
              ? l10n.capabilitiesToolsMissingTitle
              : l10n.capabilitiesToolsMissingOnServer(name),
          why: KitCapabilityExplainer.whyOf(context, 'server.oc1'),
        ),
      ],
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
