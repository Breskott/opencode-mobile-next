import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/product_repository.dart';
import '../../feedback/bug_report.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/external_agents.dart';
import '../../voice/model_manager.dart';
import '../../voice/notices.dart';
import '../../voice/voice_ui.dart';
import '../app_iconography.dart';
import '../desktop/desktop_interaction.dart';
import '../desktop/shortcuts.dart';
import '../screens/about_screen.dart';
import '../screens/agent_account_screen.dart';
import '../screens/app_diagnostics_screen.dart';
import '../screens/capabilities_screen.dart';
import '../screens/connection_help_screen.dart';
import '../screens/external_agents_screen.dart';
import '../screens/global_sessions_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/library_screen.dart';
import '../screens/profile_monitor_screen.dart';
import '../screens/project_hub_screen.dart';
import '../screens/saved_permissions_screen.dart';
import '../screens/server_capabilities_screen.dart';
import '../screens/session_import_screen.dart';
import '../screens/settings/plugins_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tailscale_setup_screen.dart';
import '../screens/team/team_home_screen.dart';
import '../screens/termux_processes_screen.dart';
import '../screens/termux_setup_screen.dart';
import '../screens/termux_storage_screen.dart';
import '../screens/usage_hub_screen.dart';
import '../widgets/pickers.dart';
import '../widgets/product_states.dart';
import '../widgets/safety_confirms.dart';
import '../widgets/transcript_display_toggles.dart';

/// What a result is, which decides the header it is listed under.
enum SearchEntryKind {
  /// A row of the Settings hub. The hub draws these itself, with live status.
  hubRow,

  /// Something inside a second-level settings screen ("Quiet hours").
  insideSettings,

  /// A place in the app: a tab, a Project tool, AI Team.
  destination,
}

/// Everything a gate or an open-callback may read. Kept in one object so a
/// test can describe a connection without building the app around it.
class SearchScope {
  SearchScope({
    required this.controller,
    PlatformCapabilities? platform,
    bool? desktop,
    bool? hasTeam,
    this.hasShell = false,
  }) : platform = platform ?? platformCapabilities,
       desktop = desktop ?? desktopInteractions,
       hasTeam = hasTeam ?? controller.orchestration != null;

  /// Reads the shell from [context]: the tabs can only be reached through the
  /// shell's signal bus, so without one the tab results are absent.
  factory SearchScope.of(
    BuildContext context,
    ConnectionController controller,
  ) => SearchScope(
    controller: controller,
    hasShell: AppShortcutScope.read(context) != null,
  );

  final ConnectionController controller;
  final PlatformCapabilities platform;
  final bool desktop;
  final bool hasShell;

  /// The AI Team plugin is set up for the connected server.
  final bool hasTeam;

  ServerCapabilities get capabilities => controller.capabilities;
}

typedef SearchGate = bool Function(SearchScope scope);
typedef SearchOpen =
    Future<void> Function(BuildContext context, SearchScope scope);

bool _always(SearchScope _) => true;

/// One findable thing. Plain data, so the conversation action registry
/// (UX plan phase 4) can add its own entries to the same list.
class SearchEntry {
  const SearchEntry({
    required this.id,
    required this.title,
    required this.keywords,
    required this.kind,
    required this.icon,
    required this.open,
    this.gate = _always,
    this.group,
    this.parent,
    this.pages = const [],
  });

  /// Stable. A hub row's id is its widget key.
  final String id;
  final String title;

  /// Extra words a person might type, including the retired nouns and the
  /// titles of the [pages] this door leads to.
  final String keywords;
  final SearchEntryKind kind;
  final IconData icon;

  /// Present or absent, never disabled (rule 7).
  final SearchGate gate;
  final SearchOpen open;

  /// The hub group a [SearchEntryKind.hubRow] is listed in.
  final SettingsGroup? group;

  /// Title of the screen that holds an [SearchEntryKind.insideSettings] entry.
  final String? parent;

  /// UI ledger page ids this entry opens or is the door to. The coverage test
  /// joins on these.
  final List<String> pages;

  bool matches(String query) {
    final haystack = '$title $keywords ${parent ?? ''}'.toLowerCase();
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(haystack.contains);
  }
}

/// The gated index: every entry the current connection and device can open.
List<SearchEntry> searchIndex(AppLocalizations l10n, SearchScope scope) => [
  for (final entry in allSearchEntries(l10n))
    if (entry.gate(scope)) entry,
];

/// [searchIndex] narrowed to [query]. Title matches come first, so typing a
/// screen's name puts that screen on top.
List<SearchEntry> searchEntries(
  AppLocalizations l10n,
  SearchScope scope,
  String query,
) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return const [];
  final matches = [
    for (final entry in searchIndex(l10n, scope))
      if (entry.matches(trimmed)) entry,
  ];
  int rank(SearchEntry entry) =>
      entry.title.toLowerCase().contains(trimmed) ? 0 : 1;
  // A stable sort: within a rank the index order (hub order) is kept.
  final indexed = [for (var i = 0; i < matches.length; i++) (i, matches[i])]
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final (_, entry) in indexed) entry];
}

Future<void> _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

SearchOpen _screen(Widget Function(SearchScope scope) build) =>
    (context, scope) => _push(context, build(scope));

/// Tabs live in the shell's first route. The same bus the desktop shortcuts
/// use pops whatever is above it and hands the shell the request.
SearchOpen _shell(Intent intent) => (context, scope) async {
  final signals = AppShortcutScope.read(context);
  if (signals == null) return;
  dispatchAtShellRoot(Navigator.of(context), signals, intent);
};

SearchOpen _projectTool(ProjectTool tool) =>
    (context, scope) => openProjectTool(context, scope.controller, tool);

bool _hasProjectTool(SearchScope scope, ProjectTool tool) =>
    scope.controller.isConnected &&
    ProjectHub.toolsFor(scope.capabilities).contains(tool);

bool _catalog(SearchScope scope) => scope.capabilities.serverCatalog;

/// The tab a catalog sits on depends on whether Tools is there at all.
int _capabilitiesTab(SearchScope scope, int withTools) =>
    scope.capabilities.toolInventory || withTools < 1
    ? withTools
    : withTools - 1;

Future<void> _openExternalAgents(
  BuildContext context,
  SearchScope scope,
) async {
  final profiles = scope.controller.store;
  final store = ExternalAgentStore(profiles.prefs, profiles.secure);
  try {
    await _push(context, ExternalAgentsScreen(store: store));
  } finally {
    store.dispose();
  }
}

Future<void> _openTranscriptDisplay(BuildContext context, SearchScope scope) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(l10n.chatUiTranscriptDisplay),
            // The same two stored values the conversation menu flips.
            TranscriptDisplayToggles(
              connection: scope.controller,
              reasoningExpanded: scope.controller.transcriptReasoningExpanded,
              timestampsVisible: scope.controller.transcriptTimestampsVisible,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openVoice(BuildContext context, SearchScope scope) async {
  try {
    final models = await VoiceModelManager.shared();
    if (!context.mounted) return;
    await showVoiceModelSetupSheet(context, models);
  } catch (error) {
    if (context.mounted) showProductError(context, error);
  }
}

Future<void> _disconnect(BuildContext context, SearchScope scope) async {
  final confirmed = await confirmDisconnectServer(context, scope.controller);
  if (!confirmed || !context.mounted) return;
  final navigator = Navigator.of(context);
  await scope.controller.disconnect();
  navigator.pushNamedAndRemoveUntil('/servers', (_) => false);
}

bool _canImport(SearchScope scope) {
  final repository = scope.controller.repository;
  return scope.capabilities.sessionImportExport &&
      repository is SessionImportGateway &&
      (repository as SessionImportGateway).sessionImportSupported;
}

/// Every entry, ungated, in the order results are listed: the hub's rows in
/// hub order, then what sits inside them, then the places.
List<SearchEntry> allSearchEntries(AppLocalizations l10n) {
  final notifications = l10n.settingsHubGroupNotifications;
  final appearance = l10n.e7AppearanceTitle;
  final usage = l10n.settingsHubGroupUsage;
  final commandsAndTools = l10n.libraryCommandsToolsTitle;
  final onThisPhone = l10n.onboardingTermuxSetup;
  return [
    // ---- Settings hub rows -------------------------------------------
    SearchEntry(
      id: 'settings-category-server',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.server,
      title: l10n.settingsHubThisServer,
      keywords:
          '${l10n.settingsHubSearchServerAliases} ${l10n.e7SettingsUi1} '
          '${l10n.e7SettingsUi65}',
      pages: const ['server-settings', 'host-management'],
      open: _screen(
        (scope) => ServerSettingsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-saved-servers',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.database,
      title: l10n.activitySavedServers,
      // The screen's own heading is the product name over "Servers".
      keywords:
          '${l10n.settingsHubSearchSavedServersAliases} ${l10n.attentionTitle} '
          '${l10n.openCodeConnectionLabel} — ${l10n.e7SetupServers}',
      // The servers screen also holds the scanner, the editor and the
      // all-servers attention sheet; this row is the one door to them.
      pages: const ['servers', 'attention-overview'],
      open: (context, _) => Navigator.of(context).pushNamed('/servers'),
    ),
    SearchEntry(
      id: 'settings-on-this-phone',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.phone,
      title: onThisPhone,
      keywords: l10n.settingsHubSearchPhoneAliases,
      pages: const ['termux-setup'],
      // Local Android tools belong to the phone, not the connected server's
      // capability set.
      gate: (scope) => scope.platform.supportsTermux,
      open: _screen((_) => const TermuxSetupScreen()),
    ),
    SearchEntry(
      id: 'settings-accounts',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.person,
      title: l10n.settingsHubAccounts,
      keywords:
          '${l10n.settingsHubSearchAccountsAliases} ${l10n.agentAccountTitle}',
      pages: const ['agent-account'],
      gate: (scope) =>
          scope.controller.isConnected && scope.capabilities.agentAccount,
      open: _screen(
        (scope) => AgentAccountScreen(connection: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-external-agents',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.support,
      title: l10n.a2aTitle,
      keywords: l10n.settingsHubSearchExternalAgentsAliases,
      pages: const ['external-agents'],
      open: _openExternalAgents,
    ),
    SearchEntry(
      id: 'settings-tailscale',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.network,
      title: l10n.tailscaleTitle,
      keywords: l10n.settingsHubSearchTailscaleAliases,
      pages: const ['tailscale-setup'],
      gate: (scope) => scope.platform.supportsTailscaleHandoff,
      open: _screen((_) => const TailscaleSetupScreen()),
    ),
    SearchEntry(
      id: 'settings-disconnect',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.connection,
      icon: AppIconography.unlink,
      title: l10n.e7SettingsUi8,
      keywords: l10n.settingsHubSearchDisconnectAliases,
      gate: (scope) => scope.controller.profile != null,
      open: _disconnect,
    ),
    SearchEntry(
      id: 'settings-model-and-mode',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.conversation,
      icon: AppIconography.model,
      title: l10n.settingsHubModelAndMode,
      keywords: l10n.settingsHubSearchModelModeAliases,
      open: (context, _) async => showModelPicker(context),
    ),
    SearchEntry(
      id: 'default-shell-settings-entry',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.conversation,
      icon: AppIconography.terminal,
      title: l10n.e7SettingsUi35,
      keywords: l10n.settingsHubSearchShellAliases,
      // Rule 7: absent where the server cannot change it. "Available on this
      // server" lists it under what this server does not offer.
      gate: (scope) => scope.capabilities.shellSettings,
      // The hub row is its own control; from anywhere else, open the hub at
      // the group that holds it.
      open: _screen(
        (scope) => SettingsScreen(
          controller: scope.controller,
          initialGroup: SettingsGroup.conversation,
        ),
      ),
    ),
    SearchEntry(
      id: 'saved-permissions-entry',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.conversation,
      icon: AppIconography.privacy,
      title: l10n.e7SettingsUi74,
      keywords: l10n.settingsHubSearchPermissionsAliases,
      pages: const ['saved-permissions'],
      open: _screen(
        (scope) => SavedPermissionsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-transcript-display',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.conversation,
      icon: AppIconography.clock,
      title: l10n.chatUiTranscriptDisplay,
      keywords: l10n.settingsHubSearchTranscriptAliases,
      open: _openTranscriptDisplay,
    ),
    SearchEntry(
      id: 'settings-voice',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.conversation,
      icon: AppIconography.policy,
      title: l10n.settingsHubVoice,
      keywords: l10n.settingsHubSearchVoiceAliases,
      // The speech models can neither download nor run off Android.
      gate: (scope) => scope.platform.supportsVoice,
      open: _openVoice,
    ),
    SearchEntry(
      id: 'settings-category-background',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.notifications,
      icon: AppIconography.notificationImportant,
      title: notifications,
      keywords: l10n.settingsHubSearchNotificationsAliases,
      pages: const ['notifications-settings'],
      open: _screen(
        (scope) => NotificationsSettingsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-category-appearance',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.appearance,
      icon: AppIconography.appearance,
      title: appearance,
      keywords: l10n.settingsHubSearchAppearanceAliases,
      pages: const ['appearance-settings'],
      open: _screen(
        (scope) => AppearanceSettingsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-models',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.agentSetup,
      icon: AppIconography.model,
      title: l10n.libraryModelsAgentsTitle,
      // The hub says "Models & agents"; the screen spells it out.
      keywords:
          '${l10n.settingsHubSearchModelsAliases} '
          '${l10n.e7LibraryModelsAndAgents}',
      pages: const ['catalog'],
      gate: _catalog,
      open: _screen((scope) => CatalogScreen(controller: scope.controller)),
    ),
    SearchEntry(
      id: 'settings-providers',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.agentSetup,
      icon: AppIconography.cloud,
      title: l10n.libraryProvidersTitle,
      keywords: l10n.settingsHubSearchProvidersAliases,
      pages: const ['integrations'],
      gate: _catalog,
      open: _screen(
        (scope) => IntegrationsScreen(
          controller: scope.controller,
          mode: IntegrationsMode.providers,
        ),
      ),
    ),
    SearchEntry(
      id: 'settings-mcp',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.agentSetup,
      icon: AppIconography.network,
      title: l10n.libraryMcpTitle,
      // "Add MCP server" is a button on this screen, so its title leads here.
      keywords:
          '${l10n.settingsHubSearchMcpAliases} ${l10n.mcpAdd} '
          '${l10n.e7LibraryMCPAndIntegrations}',
      pages: const ['integrations', 'mcp-setup'],
      gate: _catalog,
      open: _screen(
        (scope) => IntegrationsScreen(
          controller: scope.controller,
          mode: IntegrationsMode.mcp,
        ),
      ),
    ),
    SearchEntry(
      id: 'settings-commands-tools',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.agentSetup,
      icon: AppIconography.tools,
      title: commandsAndTools,
      keywords: l10n.settingsHubSearchCommandsAliases,
      pages: const ['capabilities'],
      gate: _catalog,
      open: _screen(
        (scope) => CapabilitiesScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-category-plugins',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.agentSetup,
      icon: AppIconography.extensions,
      title: l10n.teamUiPluginsTitle,
      keywords: l10n.settingsHubSearchPluginsAliases,
      pages: const ['plugins-settings'],
      // One Plugins screen: "In this app" needs a saved server, "On the
      // server" needs the plugin inventory. Either is enough for the row.
      gate: (scope) =>
          scope.controller.profile != null ||
          scope.capabilities.pluginInventory,
      open: _screen(
        (scope) => PluginsSettingsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'library-import-session',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.agentSetup,
      icon: AppIconography.fileUpload,
      title: l10n.importTitle,
      keywords: l10n.e7LibrarySearchImportAliases,
      pages: const ['session-import'],
      gate: _canImport,
      open: _screen(
        (scope) => SessionImportScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-category-usage',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.usage,
      icon: AppIconography.usage,
      title: usage,
      keywords: l10n.settingsHubSearchUsageAliases,
      pages: const ['usage-hub'],
      // "Spent" needs usage statistics, "Remaining" needs a saved server.
      gate: (scope) => UsageHubScreen.sectionsFor(scope.controller).isNotEmpty,
      open: _screen((scope) => UsageHubScreen(controller: scope.controller)),
    ),
    SearchEntry(
      id: 'settings-category-privacy',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.privacy,
      icon: AppIconography.privacy,
      title: l10n.settingsHubPrivacyRow,
      // Older drafts are listed from the conversation that owns them; the
      // local-data section here is where a person looks for them first.
      keywords:
          '${l10n.settingsHubSearchPrivacyAliases} ${l10n.legacyDraftsTitle}',
      pages: const ['privacy-settings'],
      open: _screen(
        (scope) => PrivacySettingsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-setup-guide',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.guide,
      title: l10n.onboardingSetupGuide,
      keywords: l10n.settingsHubSearchGuideAliases,
      pages: const ['guide'],
      open: _screen((_) => GuideScreen(embedded: false)),
    ),
    SearchEntry(
      id: 'settings-server-capabilities',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.checklist,
      title: l10n.capabilityScreenTitle,
      keywords: l10n.capabilityScreenAliases,
      pages: const ['server-capabilities'],
      // It describes the connected server, so there is nothing to show
      // without one.
      gate: (scope) => scope.controller.isConnected,
      open: _screen(
        (scope) => ServerCapabilitiesScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'library-keyboard-shortcuts',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.keyboard,
      title: l10n.e7LibraryKeyboardShortcuts,
      keywords: l10n.e7LibrarySearchShortcutsAliases,
      // The shortcut layer must be discoverable without already knowing a
      // shortcut, and means nothing without a keyboard.
      gate: (scope) => scope.desktop,
      open: (context, _) => showShortcutsHelp(context),
    ),
    SearchEntry(
      id: 'settings-show-tips-again',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.idea,
      title: l10n.discoverShowTipsAgain,
      keywords: l10n.discoverShowTipsAliases,
      // The hub row is the control itself; from anywhere else, open Help.
      open: _screen(
        (scope) => SettingsScreen(
          controller: scope.controller,
          initialGroup: SettingsGroup.help,
        ),
      ),
    ),
    SearchEntry(
      id: 'library-report-bug',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.bug,
      title: l10n.e7LibraryReportABug,
      keywords: l10n.settingsHubSearchBugAliases,
      open: (context, _) => openBugReport(context),
    ),
    SearchEntry(
      id: 'app-diagnostics-entry',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.privacy,
      title: l10n.e7SettingsUi88,
      keywords: l10n.settingsHubSearchDiagnosticsAliases,
      pages: const ['app-diagnostics'],
      open: _screen(
        (scope) => AppDiagnosticsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'settings-privacy-data-use',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: Icons.privacy_tip_outlined,
      title: l10n.e7SettingsUi92,
      keywords:
          '${l10n.settingsHubSearchAboutAliases} ${l10n.e7SettingsDetailUi17}',
      pages: const ['about', 'about-privacy-tab'],
      open: _screen((_) => const AboutScreen()),
    ),
    SearchEntry(
      id: 'settings-voice-notices',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.policy,
      title: l10n.e7SettingsUi94,
      keywords: l10n.settingsHubSearchAboutAliases,
      pages: const ['voice-notices'],
      gate: (scope) => scope.platform.supportsVoice,
      open: (context, _) async => showVoiceNotices(context),
    ),
    SearchEntry(
      id: 'settings-about-notices',
      kind: SearchEntryKind.hubRow,
      group: SettingsGroup.help,
      icon: AppIconography.info,
      title: l10n.e7SettingsUi96,
      keywords:
          '${l10n.settingsHubSearchAboutAliases} ${l10n.e7SettingsDetailUi18}',
      pages: const ['about', 'about-open-source-tab'],
      open: _screen((_) => const AboutScreen(initialTab: 1)),
    ),

    // ---- Inside second-level settings screens ------------------------
    SearchEntry(
      id: 'inside-notifications-what',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.notificationImportant,
      title: l10n.notifySectionWhat,
      parent: notifications,
      keywords: l10n.discoverNotifyWhatAliases,
      pages: const ['notifications-settings'],
      gate: (scope) => scope.platform.supportsNotifications,
      open: _screen(
        (scope) => NotificationsSettingsScreen(
          controller: scope.controller,
          initialSection: 'what',
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-notifications-quiet',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.clock,
      title: l10n.monitorQuiet,
      parent: notifications,
      keywords: l10n.discoverNotifyQuietAliases,
      pages: const ['notifications-settings'],
      // Quiet hours only silence notifications.
      gate: (scope) => scope.platform.supportsNotifications,
      open: _screen(
        (scope) => NotificationsSettingsScreen(
          controller: scope.controller,
          initialSection: 'quiet',
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-notifications-background',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.sync,
      title: l10n.e7SettingsUi25,
      parent: notifications,
      keywords: l10n.discoverNotifyBackgroundAliases,
      pages: const ['notifications-settings'],
      gate: (scope) => scope.platform.supportsBackgroundService,
      open: _screen(
        (scope) => NotificationsSettingsScreen(
          controller: scope.controller,
          initialSection: 'background',
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-notifications-servers',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.database,
      title: l10n.discoverNotifyServersTitle,
      parent: notifications,
      keywords: l10n.discoverNotifyServersAliases,
      pages: const ['notifications-settings'],
      gate: (scope) =>
          !scope.controller.isIsolated &&
          scope.controller.store.profiles.isNotEmpty,
      open: _screen(
        (scope) => NotificationsSettingsScreen(
          controller: scope.controller,
          initialSection: 'servers',
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-appearance-mode',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.contrast,
      title: l10n.e7SettingsUi69,
      parent: appearance,
      keywords: l10n.discoverAppearanceModeAliases,
      pages: const ['appearance-settings'],
      open: _screen(
        (scope) => AppearanceSettingsScreen(
          controller: scope.controller,
          initialSection: AppearanceSection.mode,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-appearance-language',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.globe,
      title: l10n.e7LocaleUiLanguage,
      parent: appearance,
      keywords: l10n.discoverLanguageAliases,
      pages: const ['appearance-settings'],
      open: _screen(
        (scope) => AppearanceSettingsScreen(
          controller: scope.controller,
          initialSection: AppearanceSection.language,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-appearance-theme',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.appearance,
      title: l10n.e7SettingsUi70,
      parent: appearance,
      keywords: l10n.discoverThemeAliases,
      pages: const ['appearance-settings'],
      open: _screen(
        (scope) => AppearanceSettingsScreen(
          controller: scope.controller,
          initialSection: AppearanceSection.theme,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-usage-spent',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.usage,
      title: l10n.usageSectionSpent,
      parent: usage,
      keywords: l10n.discoverSpentAliases,
      pages: const ['usage'],
      gate: (scope) => scope.controller.supportsUsageStatistics,
      open: _screen(
        (scope) => UsageHubScreen(
          controller: scope.controller,
          initialSection: UsageSection.spent,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-usage-budgets',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.usageRing,
      title: l10n.usageBudgetTitle,
      parent: usage,
      keywords: l10n.discoverBudgetAliases,
      pages: const ['usage'],
      gate: (scope) => scope.controller.supportsUsageStatistics,
      open: _screen(
        (scope) => UsageHubScreen(
          controller: scope.controller,
          initialSection: UsageSection.spent,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-usage-remaining',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.usageRing,
      title: l10n.usageSectionRemaining,
      parent: usage,
      keywords: l10n.discoverRemainingAliases,
      pages: const ['provider-quota'],
      gate: (scope) => scope.controller.profile != null,
      open: _screen(
        (scope) => UsageHubScreen(
          controller: scope.controller,
          initialSection: UsageSection.remaining,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-usage-quota-monitoring',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.notificationImportant,
      title: l10n.quotaMonitorTitle,
      parent: usage,
      keywords: l10n.discoverQuotaMonitorAliases,
      pages: const ['provider-quota'],
      gate: (scope) => scope.controller.profile != null,
      open: _screen(
        (scope) => UsageHubScreen(
          controller: scope.controller,
          initialSection: UsageSection.remaining,
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-capabilities-commands',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.play,
      title: l10n.runResultsCommandsTitle,
      parent: commandsAndTools,
      keywords:
          '${l10n.discoverCommandsAliases} ${l10n.e7LibraryServerCommands}',
      pages: const ['commands'],
      gate: _catalog,
      open: _screen(
        (scope) => CapabilitiesScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'inside-capabilities-tools',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.tools,
      title: l10n.e7SettingsDetailUi25,
      parent: commandsAndTools,
      keywords:
          '${l10n.discoverToolsAliases} ${l10n.e7LibraryToolsAndCapabilities}',
      pages: const ['tools'],
      gate: (scope) => _catalog(scope) && scope.capabilities.toolInventory,
      open: _screen(
        (scope) =>
            CapabilitiesScreen(controller: scope.controller, initialTab: 1),
      ),
    ),
    SearchEntry(
      id: 'inside-capabilities-skills',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.sparkle,
      title: l10n.e7SettingsDetailUi26,
      parent: commandsAndTools,
      keywords: l10n.discoverSkillsAliases,
      pages: const ['skills'],
      gate: _catalog,
      open: _screen(
        (scope) => CapabilitiesScreen(
          controller: scope.controller,
          initialTab: _capabilitiesTab(scope, 2),
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-capabilities-references',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.bookmarks,
      title: l10n.e7SettingsDetailUi27,
      parent: commandsAndTools,
      keywords: l10n.discoverReferencesAliases,
      pages: const ['references'],
      gate: _catalog,
      open: _screen(
        (scope) => CapabilitiesScreen(
          controller: scope.controller,
          initialTab: _capabilitiesTab(scope, 3),
        ),
      ),
    ),
    SearchEntry(
      id: 'inside-phone-running-now',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.processor,
      title: l10n.termuxProcsTitle,
      parent: onThisPhone,
      keywords: l10n.discoverRunningNowAliases,
      pages: const ['termux-processes'],
      gate: (scope) => scope.platform.supportsTermux,
      open: _screen((_) => const TermuxProcessesScreen()),
    ),
    SearchEntry(
      id: 'inside-phone-storage',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.database,
      title: l10n.termuxStorageTitle,
      parent: onThisPhone,
      keywords: l10n.discoverStorageAliases,
      pages: const ['termux-storage'],
      gate: (scope) => scope.platform.supportsTermux,
      open: _screen((_) => const TermuxStorageScreen()),
    ),
    SearchEntry(
      id: 'inside-servers-monitor',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.notificationImportant,
      title: l10n.monitorTitle,
      parent: l10n.activitySavedServers,
      keywords: l10n.discoverMonitorAliases,
      pages: const ['profile-monitor'],
      gate: (scope) =>
          !scope.controller.isIsolated &&
          scope.controller.store.profiles.isNotEmpty,
      open: _screen(
        (scope) => ProfileMonitorScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'inside-guide-connection-help',
      kind: SearchEntryKind.insideSettings,
      icon: AppIconography.supportQuestion,
      title: l10n.connectionHelpTitle,
      parent: l10n.onboardingSetupGuide,
      keywords: l10n.discoverConnectionHelpAliases,
      pages: const ['connection-help'],
      open: _screen((_) => const ConnectionHelpScreen()),
    ),

    // ---- Places ------------------------------------------------------
    SearchEntry(
      id: 'tab-work',
      kind: SearchEntryKind.destination,
      icon: AppIconography.workspace,
      title: l10n.shellTabWork,
      keywords: l10n.discoverWorkAliases,
      pages: const ['workspace'],
      gate: (scope) => scope.hasShell,
      open: _shell(const SelectDestinationIntent(0)),
    ),
    SearchEntry(
      id: 'tab-inbox',
      kind: SearchEntryKind.destination,
      icon: AppIconography.activity,
      title: l10n.shellTabInbox,
      keywords: l10n.discoverInboxAliases,
      pages: const ['activity'],
      gate: (scope) => scope.hasShell,
      open: _shell(const SelectDestinationIntent(1)),
    ),
    SearchEntry(
      id: 'tab-project',
      kind: SearchEntryKind.destination,
      icon: AppIconography.files,
      title: l10n.shellTabProject,
      keywords: l10n.discoverProjectAliases,
      pages: const ['project-hub'],
      gate: (scope) =>
          scope.hasShell && ProjectHub.isAvailable(scope.capabilities),
      open: _shell(const SelectDestinationIntent(2)),
    ),
    SearchEntry(
      id: 'tab-settings',
      kind: SearchEntryKind.destination,
      icon: AppIconography.settings,
      title: l10n.librarySettingsTitle,
      keywords: '',
      pages: const ['settings'],
      gate: (scope) => scope.hasShell,
      open: _shell(const SelectDestinationIntent(3)),
    ),
    SearchEntry(
      id: 'project-files',
      kind: SearchEntryKind.destination,
      icon: AppIconography.files,
      title: l10n.readerUiFiles,
      parent: l10n.shellTabProject,
      keywords: l10n.discoverFilesAliases,
      pages: const ['files'],
      // Files lives inside the Project tab, so it needs the shell too.
      gate: (scope) =>
          scope.hasShell && _hasProjectTool(scope, ProjectTool.files),
      open: _shell(const OpenProjectToolIntent(ProjectTool.files)),
    ),
    SearchEntry(
      id: 'project-changes',
      kind: SearchEntryKind.destination,
      icon: AppIconography.review,
      title: l10n.readerUiChanges,
      parent: l10n.shellTabProject,
      keywords: '${l10n.discoverChangesAliases} ${l10n.demoReviewChanges}',
      pages: const ['review-workspace'],
      gate: (scope) => _hasProjectTool(scope, ProjectTool.changes),
      open: _projectTool(ProjectTool.changes),
    ),
    SearchEntry(
      id: 'project-terminal',
      kind: SearchEntryKind.destination,
      icon: AppIconography.terminal,
      title: l10n.libraryTerminalTitle,
      parent: l10n.shellTabProject,
      keywords: l10n.discoverTerminalAliases,
      pages: const ['terminal'],
      gate: (scope) => _hasProjectTool(scope, ProjectTool.terminal),
      open: _projectTool(ProjectTool.terminal),
    ),
    SearchEntry(
      id: 'project-health',
      kind: SearchEntryKind.destination,
      icon: AppIconography.diagnostics,
      title: l10n.e7LibraryProjectHealth,
      parent: l10n.shellTabProject,
      keywords: l10n.discoverHealthAliases,
      pages: const ['project-health'],
      gate: (scope) => _hasProjectTool(scope, ProjectTool.health),
      open: _projectTool(ProjectTool.health),
    ),
    SearchEntry(
      id: 'project-worktrees',
      kind: SearchEntryKind.destination,
      icon: AppIconography.branch,
      title: l10n.e7LibraryWorktrees,
      parent: l10n.shellTabProject,
      keywords: l10n.discoverWorktreesAliases,
      pages: const ['worktrees'],
      gate: (scope) => _hasProjectTool(scope, ProjectTool.worktrees),
      open: _projectTool(ProjectTool.worktrees),
    ),
    SearchEntry(
      id: 'project-search',
      kind: SearchEntryKind.destination,
      icon: AppIconography.search,
      title: l10n.readerUiSearchFiles,
      parent: l10n.shellTabProject,
      keywords: l10n.discoverSearchFilesAliases,
      pages: const ['files'],
      gate: (scope) =>
          scope.hasShell && _hasProjectTool(scope, ProjectTool.search),
      open: _shell(const OpenProjectToolIntent(ProjectTool.search)),
    ),
    SearchEntry(
      id: 'all-conversations',
      kind: SearchEntryKind.destination,
      icon: AppIconography.searchList,
      title: l10n.globalSessionsTitle,
      parent: l10n.shellTabWork,
      keywords: l10n.discoverAllConversationsAliases,
      pages: const ['global-sessions'],
      gate: (scope) =>
          scope.controller.isConnected &&
          scope.capabilities.globalSessionSearch,
      open: _screen(
        (scope) => GlobalSessionsScreen(controller: scope.controller),
      ),
    ),
    SearchEntry(
      id: 'ai-team',
      kind: SearchEntryKind.destination,
      icon: AppIconography.agent,
      title: l10n.teamUiHomeTitle,
      parent: l10n.shellTabWork,
      keywords: l10n.discoverTeamAliases,
      pages: const [
        'team-home',
        'team-home-runs-tab',
        'team-home-agents-tab',
        'team-home-needs-you-tab',
      ],
      // Not in the index at all while the server has no plugin config.
      gate: (scope) => scope.hasTeam,
      open: (context, scope) {
        final team = scope.controller.orchestration;
        if (team == null) return Future<void>.value();
        return _push(context, TeamHomeScreen(controller: team));
      },
    ),
  ];
}
