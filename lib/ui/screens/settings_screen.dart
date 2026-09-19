import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api/provider_presentation.dart';
import '../../background/live_background.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/offline_queue.dart';
import '../../state/profile_monitor.dart';
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../early_l10n.dart';
import '../theme_packs.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/language_picker.dart';
import '../widgets/product_states.dart';
import 'host_management_screen.dart';
import 'library_screen.dart';
import '../search/search_index.dart';
import 'usage_hub_screen.dart';

part 'settings/server_settings_screen.dart';
part 'settings/default_shell_row.dart';
part 'settings/notifications_settings_screen.dart';
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

  /// Runs an index entry, then redraws: most of them change something a row's
  /// subtitle shows.
  Future<void> _openEntry(SearchEntry entry, SearchScope scope) async {
    await entry.open(context, scope);
    if (mounted) setState(() {});
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

  /// The hub's layout: which index entries are rows, in which order, and what
  /// each shows beside its title. Titles, keywords, gates and what a tap does
  /// come from the search index, so the hub, its search and every other
  /// search surface cannot disagree. A row whose entry is gated out is absent.
  List<_HubGroup> _groups(
    ConnectionController controller,
    Map<String, SearchEntry> entries,
    SearchScope scope,
  ) {
    final copy = _settingsCopy(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    _HubRow? row(String id, {String? subtitle, WidgetBuilder? builder}) {
      final entry = entries[id];
      if (entry == null) return null;
      return _HubRow(
        entry: entry,
        subtitle: subtitle,
        builder: builder,
        onTap: () => _openEntry(entry, scope),
      );
    }

    final titles = {
      SettingsGroup.connection: copy.settingsHubGroupConnection,
      SettingsGroup.conversation: copy.settingsHubGroupConversation,
      SettingsGroup.notifications: copy.settingsHubGroupNotifications,
      SettingsGroup.appearance: copy.e7AppearanceTitle,
      SettingsGroup.agentSetup: copy.settingsHubGroupAgentSetup,
      SettingsGroup.usage: copy.settingsHubGroupUsage,
      SettingsGroup.privacy: copy.settingsHubGroupPrivacy,
      SettingsGroup.help: copy.settingsHubGroupHelp,
    };
    final rows = <SettingsGroup, List<_HubRow?>>{
      SettingsGroup.connection: [
        row(
          'settings-category-server',
          builder: (_) => _thisServerRow(controller),
        ),
        row('settings-saved-servers', subtitle: copy.e7SettingsUi64),
        row('settings-on-this-phone', subtitle: l10n.onboardingRunOnPhone),
        row('settings-accounts', subtitle: copy.settingsHubAccountsSubtitle),
        row('settings-external-agents'),
        row('settings-tailscale'),
        // Destructive rows come last in their group and stand apart from
        // the doors above (plan 5.7).
        row(
          'settings-disconnect',
          builder: (context) => Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              key: const ValueKey('settings-disconnect'),
              onPressed: () =>
                  _openEntry(entries['settings-disconnect']!, scope),
              icon: const Icon(AppIconography.unlink),
              label: Text(copy.e7SettingsUi8),
            ),
          ),
        ),
      ],
      SettingsGroup.conversation: [
        row(
          'settings-model-and-mode',
          subtitle: _modelAndModeSummary(controller),
        ),
        // Absent where the server cannot change it, like every other row
        // (rule 7). This used to stay visible-but-disabled so a vanished
        // setting would not read as a bug; Help → "Available on this server"
        // now carries that explanation for every hidden row at once.
        row(
          'default-shell-settings-entry',
          builder: (_) => DefaultShellRow(controller: controller),
        ),
        row('saved-permissions-entry', subtitle: copy.e7SettingsUi75),
        row(
          'settings-transcript-display',
          subtitle: copy.settingsHubTranscriptSubtitle,
        ),
        row('settings-voice', subtitle: copy.settingsHubVoiceSubtitle),
      ],
      SettingsGroup.notifications: [
        // One screen for everything that notifies. It stays off Android
        // too: saved-server monitoring and check-ins work in the open app
        // there, and the screen drops the rows that device cannot do. The
        // key predates the merge and is kept for tests and deep links.
        row(
          'settings-category-background',
          subtitle: platformCapabilities.supportsBackgroundService
              ? copy.notifyHubBackgroundSummary(_backgroundSummary(controller))
              : null,
        ),
      ],
      SettingsGroup.appearance: [
        row(
          'settings-category-appearance',
          subtitle:
              '${appearanceLabel(controller.appearance.value, context)} · ${themePackLabels[controller.themePack.value]}',
        ),
      ],
      SettingsGroup.agentSetup: [
        row(
          'settings-models',
          subtitle: l10n.settingsDiscoveryNewChatsModel(
            defaultModelLabel(controller, l10n),
          ),
        ),
        row('settings-providers'),
        row('settings-mcp'),
        row('settings-commands-tools'),
        row(
          'settings-category-plugins',
          subtitle: copy.teamUiPluginsHubSubtitle,
        ),
        row('library-import-session'),
      ],
      SettingsGroup.usage: [
        // The subtitle names the sections this connection really has.
        row(
          'settings-category-usage',
          subtitle: [
            for (final section in UsageHubScreen.sectionsFor(controller))
              switch (section) {
                UsageSection.spent => copy.usageSectionSpent,
                UsageSection.remaining => copy.usageSectionRemaining,
              },
          ].join(' · '),
        ),
      ],
      SettingsGroup.privacy: [row('settings-category-privacy')],
      SettingsGroup.help: [
        row('settings-setup-guide', subtitle: copy.e7SettingsUi91),
        // The explanation for every row the connected server hides.
        row(
          'settings-server-capabilities',
          subtitle: copy.capabilityScreenSubtitle,
        ),
        row('library-keyboard-shortcuts'),
        // The bug form lives in the failure states themselves; this row is
        // the deliberate path for everything noticed outside a failure.
        row('library-report-bug'),
        row(
          'app-diagnostics-entry',
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
                    _openEntry(entries['app-diagnostics-entry']!, scope),
              );
            },
          ),
        ),
        row('settings-privacy-data-use', subtitle: copy.e7SettingsUi93),
        // The voice notices cover models this build can neither download
        // nor run off Android; the general notices below still list every
        // component that ships here.
        row('settings-voice-notices', subtitle: copy.e7SettingsUi95),
        row('settings-about-notices', subtitle: copy.e7SettingsUi97),
      ],
    };
    return [
      for (final group in SettingsGroup.values)
        _HubGroup(group, titles[group]!, rows[group]!.nonNulls.toList()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final copy = _settingsCopy(context);
    final scope = SearchScope.of(context, controller);
    final entries = {
      for (final entry in searchIndex(copy, scope)) entry.id: entry,
    };
    // One index answers the hub's search: the rows it draws itself, what
    // sits inside their screens, and the places outside Settings.
    final searching = _query.isNotEmpty;
    final matches = searching
        ? searchEntries(copy, scope, _query)
        : const <SearchEntry>[];
    final matchedIds = {for (final entry in matches) entry.id};
    final groups = [
      for (final group in _groups(controller, entries, scope))
        (
          group: group,
          rows: searching
              ? group.rows
                    .where((row) => matchedIds.contains(row.entry.id))
                    .toList()
              : group.rows,
        ),
    ].where((entry) => entry.rows.isNotEmpty).toList();
    // This hub is the Settings tab, so that result would lead nowhere new.
    final others = [
      for (final entry in matches)
        if (entry.kind != SearchEntryKind.hubRow && entry.id != 'tab-settings')
          entry,
    ];
    final resultSections = [
      (
        slug: 'inside',
        title: copy.discoverSearchInsideSettings,
        entries: [
          for (final entry in others)
            if (entry.kind == SearchEntryKind.insideSettings) entry,
        ],
      ),
      (
        slug: 'places',
        title: copy.discoverSearchGoTo,
        entries: [
          for (final entry in others)
            if (entry.kind == SearchEntryKind.destination) entry,
        ],
      ),
    ].where((section) => section.entries.isNotEmpty).toList();
    final matchCount =
        groups.fold<int>(0, (total, entry) => total + entry.rows.length) +
        others.length;
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
            for (final section in resultSections)
              Column(
                key: ValueKey('search-results-${section.slug}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 4),
                    child: Semantics(
                      header: true,
                      child: Text(
                        section.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.mutedOf(theme),
                        ),
                      ),
                    ),
                  ),
                  for (final entry in section.entries)
                    _CategoryRow(
                      rowKey: 'search-result-${entry.id}',
                      icon: entry.icon,
                      title: entry.title,
                      subtitle: entry.parent == null
                          ? null
                          : copy.discoverSearchIn(entry.parent!),
                      onTap: () => _openEntry(entry, scope),
                    ),
                ],
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

/// One hub row: a search-index entry plus what only the hub shows beside
/// it (a live subtitle, or a row that draws itself).
class _HubRow {
  final SearchEntry entry;
  final String? subtitle;
  final VoidCallback onTap;

  /// A row that draws itself (live status, its own loading state, or the
  /// separated Disconnect button) but is searched like any other.
  final WidgetBuilder? builder;

  const _HubRow({
    required this.entry,
    required this.onTap,
    this.subtitle,
    this.builder,
  });

  Widget build(BuildContext context) =>
      builder?.call(context) ??
      _CategoryRow(
        rowKey: entry.id,
        icon: entry.icon,
        title: entry.title,
        subtitle: subtitle,
        onTap: onTap,
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
