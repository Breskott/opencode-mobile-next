import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api/provider_presentation.dart';
import '../../background/live_background.dart';
import '../../feedback/bug_report.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/external_agents.dart';
import '../../state/offline_queue.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../../voice/model_manager.dart';
import '../../voice/notices.dart';
import '../../voice/voice_ui.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../desktop/shortcuts.dart';
import '../early_l10n.dart';
import '../theme_packs.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/language_picker.dart';
import '../widgets/pickers.dart';
import '../widgets/product_states.dart';
import '../widgets/safety_confirms.dart';
import '../widgets/transcript_display_toggles.dart';
import 'about_screen.dart';
import 'agent_account_screen.dart';
import 'app_diagnostics_screen.dart';
import 'capabilities_screen.dart';
import 'external_agents_screen.dart';
import 'guide_screen.dart';
import 'host_management_screen.dart';
import 'library_screen.dart';
import 'provider_quota_screen.dart';
import 'saved_permissions_screen.dart';
import 'session_import_screen.dart';
import 'settings/plugins_screen.dart';
import 'tailscale_setup_screen.dart';
import 'terminal_screen.dart';
import 'termux_setup_screen.dart';
import 'usage_screen.dart';

part 'settings/server_settings_screen.dart';
part 'settings/default_shell_row.dart';
part 'settings/background_settings_screen.dart';
part 'settings/personal_settings_screens.dart';

AppLocalizations _settingsCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

/// The eight groups of the Settings hub, in the order a person needs them
/// (UX reorganization plan, section 5.7).
enum SettingsGroup {
  connection('connection'),
  conversation('conversation-defaults'),
  notifications('notifications'),
  appearance('appearance'),
  agentSetup('agent-setup'),
  usage('usage'),
  privacy('privacy'),
  help('help');

  const SettingsGroup(this.slug);

  /// Stable name used in the `settings-group-<slug>` widget key.
  final String slug;
}

/// The one Settings hub: a search field, then eight groups of rows. It is the
/// fourth tab of the shell ([embedded]) and the screen every other entry
/// point pushes, so a setting has exactly one home. Rows the connected server
/// cannot serve are absent, and a group with no rows is absent.
class SettingsScreen extends StatefulWidget {
  final ConnectionController controller;

  /// True inside the shell's tab view, which already supplies the app bar.
  final bool embedded;

  /// A group to scroll to on open, for entry points that mean one area.
  final SettingsGroup? initialGroup;

  const SettingsScreen({
    super.key,
    required this.controller,
    this.embedded = false,
    this.initialGroup,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  final _groupKeys = {
    for (final group in SettingsGroup.values)
      group: GlobalKey(debugLabel: 'settings-group-${group.slug}'),
  };
  String _query = '';
  Health? _health;
  String? _healthError;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_connectionChanged);
    _checkHealth();
    final initial = widget.initialGroup;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _groupKeys[initial]?.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    }
  }

  void _connectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkHealth() async {
    // Runs from initState, so inherited lookups are not yet allowed.
    final copy = earlyAppLocalizations(context);
    if (_checking) return;
    setState(() {
      _checking = true;
      _healthError = null;
    });
    try {
      final api = await widget.controller.prepareActionTransport();
      if (api == null) {
        throw ProductException(copy.e7SettingsUi18);
      }
      final health = await api.health();
      if (mounted) setState(() => _health = health);
    } catch (error) {
      if (mounted) setState(() => _healthError = productErrorText(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// The background state at a glance, so the hub says whether runs keep
  /// updating after the app closes without opening the page.
  String _backgroundSummary(ConnectionController controller) {
    final live = controller.backgroundLive;
    if (live.stoppedByAndroidTimeout) {
      return _settingsCopy(context).e7SettingsUi12;
    }
    if (!controller.keepLiveInBackground) {
      return _settingsCopy(context).quotaBudgetOff;
    }
    return live.active
        ? _settingsCopy(context).e7SettingsUi14
        : _settingsCopy(context).e7SettingsUi15;
  }

  /// "Model and mode" is one row: the model, its variant and the agent are
  /// chosen together in the same picker, so they read as one default.
  String _modelAndModeSummary(ConnectionController controller) {
    final copy = _settingsCopy(context);
    final selected = controller.selectedModel;
    final model = selected == null
        ? copy.modelServerDefault
        : controller.catalog?.models
                  .where(
                    (model) =>
                        model.providerID == selected.providerID &&
                        model.id == selected.modelID,
                  )
                  .firstOrNull
                  ?.name ??
              presentedModelLabel(selected.providerID, selected.modelID);
    return [
      model,
      if (selected != null && controller.selectedVariant.isNotEmpty)
        controller.selectedVariant,
      if (controller.selectedAgent.isNotEmpty) controller.selectedAgent,
    ].join(' · ');
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Future<void> _openExternalAgents() async {
    final profiles = widget.controller.store;
    final store = ExternalAgentStore(profiles.prefs, profiles.secure);
    try {
      await _open(ExternalAgentsScreen(store: store));
    } finally {
      store.dispose();
    }
  }

  Future<void> _openTranscriptDisplay() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(_settingsCopy(context).chatUiTranscriptDisplay),
            // The same two stored values the conversation menu flips.
            TranscriptDisplayToggles(
              connection: widget.controller,
              reasoningExpanded: widget.controller.transcriptReasoningExpanded,
              timestampsVisible: widget.controller.transcriptTimestampsVisible,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openVoice() async {
    try {
      final models = await VoiceModelManager.shared();
      if (!mounted) return;
      await showVoiceModelSetupSheet(context, models);
    } catch (error) {
      if (mounted) showProductError(context, error);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await confirmDisconnectServer(context, widget.controller);
    if (!confirmed || !mounted) return;
    await widget.controller.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/servers', (_) => false);
  }

  Widget _thisServerRow(ConnectionController controller) {
    final copy = _settingsCopy(context);
    final theme = Theme.of(context);
    final healthy = _health?.healthy == true;
    final status = _checking
        ? copy.e7SettingsUi11
        : _healthError != null
        ? copy.e7SettingsHealthError(_healthError!)
        : healthy
        ? copy.e7SettingsHealthVersion(
            _health?.version ?? controller.version ?? copy.e7SettingsUi17,
          )
        : copy.e7SettingsVersion(controller.version ?? copy.e7SettingsUi17);
    return KeyedSubtree(
      key: const ValueKey('settings-connection-summary'),
      child: ListTile(
        key: const ValueKey('settings-category-server'),
        minTileHeight: 72,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        minLeadingWidth: 32,
        horizontalTitleGap: 12,
        leading: _CategoryIcon(
          icon: AppIconography.server,
          color: healthy
              ? AppTheme.successOf(theme)
              : _healthError != null
              ? theme.colorScheme.error
              : null,
        ),
        title: Text(copy.settingsHubThisServer),
        subtitle: Text(
          copy.settingsHubThisServerStatus(
            controller.profile?.name ?? copy.e7SettingsUi9,
            status,
          ),
        ),
        // A failed probe offers the one fix in place; otherwise the row is a
        // plain door like its neighbours.
        trailing: _checking
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _healthError != null
            ? IconButton(
                key: const ValueKey('settings-server-try-again'),
                tooltip: copy.commonRetry,
                onPressed: _checkHealth,
                icon: const Icon(AppIconography.retry),
              )
            : const Icon(AppIconography.chevronRight, size: 20),
        onTap: () => _open(ServerSettingsScreen(controller: controller)),
      ),
    );
  }

  List<_HubGroup> _groups(ConnectionController controller) {
    final copy = _settingsCopy(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final capabilities = controller.capabilities;
    final profile = controller.profile;
    final repository = controller.repository;
    final canImport =
        capabilities.sessionImportExport &&
        repository is SessionImportGateway &&
        (repository as SessionImportGateway).sessionImportSupported;
    return [
      _HubGroup(SettingsGroup.connection, copy.settingsHubGroupConnection, [
        _HubRow.custom(
          title: copy.settingsHubThisServer,
          keywords: copy.settingsHubSearchServerAliases,
          builder: (_) => _thisServerRow(controller),
        ),
        _HubRow(
          rowKey: 'settings-saved-servers',
          icon: AppIconography.database,
          title: l10n.activitySavedServers,
          subtitle: copy.e7SettingsUi64,
          keywords: copy.settingsHubSearchSavedServersAliases,
          onTap: () => Navigator.of(context).pushNamed('/servers'),
        ),
        // Local Android tools belong to the phone, not the connected server's
        // capability set. Keep this entry visible even on a remote profile.
        if (platformCapabilities.supportsTermux)
          _HubRow(
            rowKey: 'settings-on-this-phone',
            icon: AppIconography.phone,
            title: l10n.onboardingTermuxSetup,
            subtitle: l10n.onboardingRunOnPhone,
            keywords: copy.settingsHubSearchPhoneAliases,
            onTap: () => _open(const TermuxSetupScreen()),
          ),
        if (controller.isConnected && capabilities.agentAccount)
          _HubRow(
            rowKey: 'settings-accounts',
            icon: AppIconography.person,
            title: copy.settingsHubAccounts,
            subtitle: copy.settingsHubAccountsSubtitle,
            keywords: copy.settingsHubSearchAccountsAliases,
            onTap: () => _open(AgentAccountScreen(connection: controller)),
          ),
        _HubRow(
          rowKey: 'settings-external-agents',
          icon: AppIconography.support,
          title: l10n.a2aTitle,
          keywords: copy.settingsHubSearchExternalAgentsAliases,
          onTap: _openExternalAgents,
        ),
        if (platformCapabilities.supportsTailscaleHandoff)
          _HubRow(
            rowKey: 'settings-tailscale',
            icon: AppIconography.network,
            title: l10n.tailscaleTitle,
            keywords: copy.settingsHubSearchTailscaleAliases,
            onTap: () => _open(const TailscaleSetupScreen()),
          ),
        // Destructive rows come last in their group and stand apart from
        // the doors above (plan 5.7).
        if (profile != null)
          _HubRow.custom(
            title: copy.e7SettingsUi8,
            keywords: copy.settingsHubSearchDisconnectAliases,
            builder: (context) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                key: const ValueKey('settings-disconnect'),
                onPressed: _disconnect,
                icon: const Icon(AppIconography.unlink),
                label: Text(copy.e7SettingsUi8),
              ),
            ),
          ),
      ]),
      _HubGroup(SettingsGroup.conversation, copy.settingsHubGroupConversation, [
        _HubRow(
          rowKey: 'settings-model-and-mode',
          icon: AppIconography.model,
          title: copy.settingsHubModelAndMode,
          subtitle: _modelAndModeSummary(controller),
          keywords: copy.settingsHubSearchModelModeAliases,
          onTap: () => showModelPicker(context),
        ),
        // §7 row 22 of the OpenCode 2 port keeps this one row visible but
        // disabled with its reason, because a setting that was there
        // yesterday and vanished reads as a bug. Everything else the server
        // cannot serve is absent.
        _HubRow.custom(
          title: copy.e7SettingsUi35,
          keywords: copy.settingsHubSearchShellAliases,
          builder: (_) => capabilities.shellSettings
              ? DefaultShellRow(controller: controller)
              : ListTileTheme.merge(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  minLeadingWidth: 32,
                  horizontalTitleGap: 12,
                  child: GatedRowTile(
                    feature: 'shell-settings',
                    title: copy.e7SettingsUi35,
                    explainer: copy.e7SettingsUi40,
                    leading: const _CategoryIcon(icon: AppIconography.terminal),
                  ),
                ),
        ),
        _HubRow(
          rowKey: 'saved-permissions-entry',
          icon: AppIconography.privacy,
          title: copy.e7SettingsUi74,
          subtitle: copy.e7SettingsUi75,
          keywords: copy.settingsHubSearchPermissionsAliases,
          onTap: () => _open(SavedPermissionsScreen(controller: controller)),
        ),
        _HubRow(
          rowKey: 'settings-transcript-display',
          icon: AppIconography.clock,
          title: copy.chatUiTranscriptDisplay,
          subtitle: copy.settingsHubTranscriptSubtitle,
          keywords: copy.settingsHubSearchTranscriptAliases,
          onTap: _openTranscriptDisplay,
        ),
        // The speech models can neither download nor run off Android.
        if (platformCapabilities.supportsVoice)
          _HubRow(
            rowKey: 'settings-voice',
            icon: AppIconography.policy,
            title: copy.settingsHubVoice,
            subtitle: copy.settingsHubVoiceSubtitle,
            keywords: copy.settingsHubSearchVoiceAliases,
            onTap: _openVoice,
          ),
      ]),
      _HubGroup(
        SettingsGroup.notifications,
        copy.settingsHubGroupNotifications,
        [
          // The live background service and its notifications are Android
          // platform features; the row hides elsewhere.
          if (platformCapabilities.supportsBackgroundService)
            _HubRow(
              rowKey: 'settings-category-background',
              icon: AppIconography.notificationImportant,
              title: copy.e7SettingsUi3,
              subtitle: _backgroundSummary(controller),
              keywords: copy.settingsHubSearchNotificationsAliases,
              onTap: () =>
                  _open(BackgroundSettingsScreen(controller: controller)),
            ),
        ],
      ),
      _HubGroup(SettingsGroup.appearance, copy.e7AppearanceTitle, [
        _HubRow(
          rowKey: 'settings-category-appearance',
          icon: AppIconography.appearance,
          title: copy.e7AppearanceTitle,
          subtitle:
              '${appearanceLabel(controller.appearance.value, context)} · ${themePackLabels[controller.themePack.value]}',
          keywords: copy.settingsHubSearchAppearanceAliases,
          onTap: () => _open(AppearanceSettingsScreen(controller: controller)),
        ),
      ]),
      _HubGroup(SettingsGroup.agentSetup, copy.settingsHubGroupAgentSetup, [
        if (capabilities.serverCatalog) ...[
          _HubRow(
            rowKey: 'settings-models',
            icon: AppIconography.model,
            title: l10n.libraryModelsAgentsTitle,
            subtitle: l10n.settingsDiscoveryNewChatsModel(
              defaultModelLabel(controller, l10n),
            ),
            keywords: copy.settingsHubSearchModelsAliases,
            onTap: () => _open(CatalogScreen(controller: controller)),
          ),
          _HubRow(
            rowKey: 'settings-providers',
            icon: AppIconography.cloud,
            title: l10n.libraryProvidersTitle,
            keywords: copy.settingsHubSearchProvidersAliases,
            onTap: () => _open(
              IntegrationsScreen(
                controller: controller,
                mode: IntegrationsMode.providers,
              ),
            ),
          ),
          _HubRow(
            rowKey: 'settings-mcp',
            icon: AppIconography.network,
            title: l10n.libraryMcpTitle,
            keywords: copy.settingsHubSearchMcpAliases,
            onTap: () => _open(
              IntegrationsScreen(
                controller: controller,
                mode: IntegrationsMode.mcp,
              ),
            ),
          ),
          _HubRow(
            rowKey: 'settings-commands-tools',
            icon: AppIconography.tools,
            title: l10n.libraryCommandsToolsTitle,
            keywords: copy.settingsHubSearchCommandsAliases,
            onTap: () => _open(CapabilitiesScreen(controller: controller)),
          ),
        ],
        // One Plugins screen: "In this app" needs a saved server, "On the
        // server" needs the plugin inventory. Either is enough for the row.
        if (profile != null || capabilities.pluginInventory)
          _HubRow(
            rowKey: 'settings-category-plugins',
            icon: AppIconography.extensions,
            title: copy.teamUiPluginsTitle,
            subtitle: copy.teamUiPluginsHubSubtitle,
            keywords: copy.settingsHubSearchPluginsAliases,
            onTap: () => _open(PluginsSettingsScreen(controller: controller)),
          ),
        if (canImport)
          _HubRow(
            rowKey: 'library-import-session',
            icon: AppIconography.fileUpload,
            title: l10n.importTitle,
            keywords: l10n.e7LibrarySearchImportAliases,
            onTap: () => _open(SessionImportScreen(controller: controller)),
          ),
        // Terminal belongs to the Project tab (phase 3). Until that tab
        // exists it stays here, last, so nothing is lost.
        if (capabilities.terminal)
          _HubRow(
            rowKey: 'library-terminal',
            icon: AppIconography.terminal,
            title: l10n.libraryTerminalTitle,
            keywords: l10n.e7LibrarySearchTerminalAliases,
            onTap: () => _open(TerminalPage(controller: controller)),
          ),
      ]),
      _HubGroup(SettingsGroup.usage, copy.settingsHubGroupUsage, [
        if (controller.supportsUsageStatistics)
          _HubRow(
            rowKey: 'settings-category-usage',
            icon: AppIconography.usage,
            title: l10n.usageTitle,
            keywords: copy.settingsHubSearchUsageAliases,
            onTap: () => _open(UsageScreen(controller: controller)),
          ),
        if (profile != null)
          _HubRow(
            rowKey: 'settings-category-quota',
            icon: AppIconography.speed,
            title: l10n.quotaTitle,
            subtitle: l10n.quotaSettingsSummary,
            keywords: copy.settingsHubSearchUsageAliases,
            onTap: () => _open(ProviderQuotaScreen(controller: controller)),
          ),
      ]),
      _HubGroup(SettingsGroup.privacy, copy.settingsHubGroupPrivacy, [
        _HubRow(
          rowKey: 'settings-category-privacy',
          icon: AppIconography.privacy,
          title: copy.settingsHubPrivacyRow,
          keywords: copy.settingsHubSearchPrivacyAliases,
          onTap: () => _open(PrivacySettingsScreen(controller: controller)),
        ),
      ]),
      _HubGroup(SettingsGroup.help, copy.settingsHubGroupHelp, [
        _HubRow(
          rowKey: 'settings-setup-guide',
          icon: AppIconography.guide,
          title: copy.onboardingSetupGuide,
          subtitle: copy.e7SettingsUi91,
          keywords: copy.settingsHubSearchGuideAliases,
          onTap: () => _open(GuideScreen(embedded: false)),
        ),
        // The shortcut layer must be discoverable without already knowing a
        // shortcut.
        if (desktopInteractions)
          _HubRow(
            rowKey: 'library-keyboard-shortcuts',
            icon: AppIconography.keyboard,
            title: l10n.e7LibraryKeyboardShortcuts,
            keywords: l10n.e7LibrarySearchShortcutsAliases,
            onTap: () => unawaited(showShortcutsHelp(context)),
          ),
        // The bug form lives in the failure states themselves; this row is
        // the deliberate path for everything noticed outside a failure.
        _HubRow(
          rowKey: 'library-report-bug',
          icon: AppIconography.bug,
          title: l10n.e7LibraryReportABug,
          keywords: copy.settingsHubSearchBugAliases,
          onTap: () => unawaited(openBugReport(context)),
        ),
        _HubRow.custom(
          title: copy.e7SettingsUi88,
          keywords: copy.settingsHubSearchDiagnosticsAliases,
          builder: (context) => ListenableBuilder(
            listenable: controller.diagnostics,
            builder: (context, _) {
              final count = controller.diagnostics.count;
              return _CategoryRow(
                rowKey: 'app-diagnostics-entry',
                icon: AppIconography.privacy,
                title: copy.e7SettingsUi88,
                subtitle: count == 0
                    ? copy.e7SettingsUi89
                    : copy.e7SettingsDiagnosticCount(count),
                onTap: () =>
                    _open(AppDiagnosticsScreen(controller: controller)),
              );
            },
          ),
        ),
        _HubRow(
          rowKey: 'settings-privacy-data-use',
          icon: Icons.privacy_tip_outlined,
          title: copy.e7SettingsUi92,
          subtitle: copy.e7SettingsUi93,
          keywords: copy.settingsHubSearchAboutAliases,
          onTap: () => _open(const AboutScreen()),
        ),
        // The voice notices cover models this build can neither download
        // nor run off Android; the general notices below still list every
        // component that ships here.
        if (platformCapabilities.supportsVoice)
          _HubRow(
            rowKey: 'settings-voice-notices',
            icon: AppIconography.policy,
            title: copy.e7SettingsUi94,
            subtitle: copy.e7SettingsUi95,
            keywords: copy.settingsHubSearchAboutAliases,
            onTap: () => showVoiceNotices(context),
          ),
        _HubRow(
          rowKey: 'settings-about-notices',
          icon: AppIconography.info,
          title: copy.e7SettingsUi96,
          subtitle: copy.e7SettingsUi97,
          keywords: copy.settingsHubSearchAboutAliases,
          onTap: () => _open(const AboutScreen(initialTab: 1)),
        ),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final groups = [
      for (final group in _groups(controller))
        (
          group: group,
          rows: group.rows.where((row) => row.matches(_query)).toList(),
        ),
    ].where((entry) => entry.rows.isNotEmpty).toList();
    final matchCount = groups.fold<int>(
      0,
      (total, entry) => total + entry.rows.length,
    );
    // Not a lazy list: every group must exist for an entry point to scroll
    // to it, and the hub is a few dozen plain rows.
    final body = DesktopScrollbarArea(
      builder: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsetsDirectional.fromSTEB(
          12,
          8,
          12,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 4),
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
            for (final entry in groups)
              KeyedSubtree(
                key: _groupKeys[entry.group.group],
                child: Column(
                  key: ValueKey('settings-group-${entry.group.group.slug}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        4,
                        20,
                        4,
                        4,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          entry.group.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.mutedOf(theme),
                          ),
                        ),
                      ),
                    ),
                    for (final row in entry.rows) row.build(context),
                  ],
                ),
              ),
            if (_query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  matchCount == 0
                      ? _settingsCopy(
                          context,
                        ).settingsHubNoResults(_search.text.trim())
                      : l10n.librarySearchResults(
                          matchCount,
                          _search.text.trim(),
                        ),
                  key: const Key('library-search-summary'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.librarySettingsTitle)),
      body: body,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_connectionChanged);
    _search.dispose();
    super.dispose();
  }
}

class _HubGroup {
  final SettingsGroup group;
  final String title;
  final List<_HubRow> rows;

  const _HubGroup(this.group, this.title, this.rows);
}

/// One searchable hub row. Search reads [title] and [keywords]; the keywords
/// also name what sits inside the row's second-level screen, so "quiet hours"
/// or "language" finds the door to it.
class _HubRow {
  final String? rowKey;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String keywords;
  final VoidCallback? onTap;
  final WidgetBuilder? builder;

  const _HubRow({
    required String this.rowKey,
    required IconData this.icon,
    required this.title,
    required this.keywords,
    required VoidCallback this.onTap,
    this.subtitle,
  }) : builder = null;

  /// A row that draws itself (live status, its own loading state, or the
  /// separated Disconnect button) but is searched like any other.
  const _HubRow.custom({
    required this.title,
    required this.keywords,
    required WidgetBuilder this.builder,
  }) : rowKey = null,
       icon = null,
       subtitle = null,
       onTap = null;

  bool matches(String query) => query
      .split(RegExp(r'\s+'))
      .every((word) => '$title $keywords'.toLowerCase().contains(word));

  Widget build(BuildContext context) =>
      builder?.call(context) ??
      _CategoryRow(
        rowKey: rowKey!,
        icon: icon!,
        title: title,
        subtitle: subtitle,
        onTap: onTap!,
      );
}

class _CategoryRow extends StatelessWidget {
  final String rowKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(rowKey),
      minTileHeight: subtitle == null ? 56 : 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 32,
      horizontalTitleGap: 12,
      leading: _CategoryIcon(icon: icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(AppIconography.chevronRight, size: 20),
      onTap: onTap,
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _CategoryIcon({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return SizedBox.square(
      dimension: 32,
      child: Icon(icon, size: 24, color: tint),
    );
  }
}

class _ShellChoice {
  final String id;
  final String value;
  final String label;
  final bool terminalOnly;

  const _ShellChoice({
    required this.id,
    required this.value,
    required this.label,
    required this.terminalOnly,
  });
}
