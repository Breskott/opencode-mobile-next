import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api/provider_presentation.dart';
import '../../background/live_background.dart';
import '../../builtin/setup/phone_setup.dart';
import '../../builtin/setup/setup_contract.dart' show SetupProgress;
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/offline_queue.dart';
import '../../state/profile_monitor.dart';
import '../../state/phone_host.dart' show PhoneHostKind;
import '../../state/profiles.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../early_l10n.dart';
import '../kit/kit.dart';
import '../theme_packs.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/phone_server_card.dart' show serverDisplayName;
import '../widgets/product_states.dart';
import '../widgets/safety_confirms.dart';
import 'host_management_screen.dart';
import 'this_phone_screen.dart' show openThisPhone;
import '../widgets/team_discover.dart';
import '../search/search_index.dart';
import 'usage_hub_screen.dart';

part 'settings/server_settings_screen.dart';
part 'settings/default_shell_row.dart';
part 'settings/notifications_settings_screen.dart';
part 'settings/personal_settings_screens.dart';
part 'settings/help_settings_screen.dart';

AppLocalizations _settingsCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

/// The three groups of the Settings hub, as the approved canvas draws them
/// (docs/design/visual-language-2026-09-26/Settings.png): what belongs to
/// the connected server, under its name; what belongs to this phone; and a
/// last, unlabelled panel with Report a bug, Help and About.
enum SettingsGroup {
  /// Model, tools, the AI Team, what agents may do and the server itself,
  /// labelled with the server's name.
  server('server'),

  /// Notifications, voice, appearance, usage and privacy of this app.
  thisPhone('this-phone'),

  /// Report a bug, Help and About; no label.
  help('help');

  const SettingsGroup(this.slug);

  /// Stable name used in the `settings-group-<slug>` widget key.
  final String slug;
}

/// The one Settings hub: a search field, then three groups of rows. It is the
/// fourth tab of the shell ([embedded]) and the screen every other entry
/// point pushes, so a setting has exactly one home. Rows the connected server
/// cannot serve are absent, and a group with no rows is absent.
///
/// Kit only (screen-settings-1): a [KitScreen] with a pinned
/// [KitSearchField] and one [KitRowGroup] panel per group. From expanded it
/// is [KitScreen.twoPane]: the groups are the list pane and the chosen
/// group's rows fill the detail pane; a row still opens its page. The new
/// Settings structure waits for slice-P3.10 (map proposal "redesign").
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

  /// The group in the detail pane (expanded and wider).
  SettingsGroup? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGroup;
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

  /// The Model row's value: the default model's name (the picker also
  /// sets its variant and agent).
  String _modelSummary(ConnectionController controller) {
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
    return model;
  }

  Future<void> _open(Widget screen) async {
    await pushKitPage<void>(context, (_) => screen);
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
      child: KitRow(
        key: const ValueKey('settings-category-server'),
        // Healthy is the success colour with its word; a failed check keeps
        // the neutral glyph and says so in words (LOOK-5).
        leading: KitRow.icon(
          context,
          AppIconography.server,
          color: healthy ? ThemeRoles.of(context).success : null,
        ),
        title: copy.settingsHubThisServer,
        // The group above is labelled with the server's name, so the row
        // says only how it is (R3).
        supporting: TextSpan(
          text: controller.profile == null ? copy.e7SettingsUi9 : status,
        ),
        supportingMaxLines: 2,
        // A failed probe offers the one fix in place; otherwise the row is a
        // plain door like its neighbours. The check itself shows as the
        // screen's one loading bar, not a spinner in the row.
        trailing: _healthError != null
            ? KitIconButton(
                key: const ValueKey('settings-server-try-again'),
                tooltip: copy.commonRetry,
                icon: AppIconography.retry,
                onPressed: _checkHealth,
              )
            : const KitChevron(),
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
    _HubRow? row(String id, {String? value, WidgetBuilder? builder}) {
      final entry = entries[id];
      if (entry == null) return null;
      return _HubRow(
        entry: entry,
        value: value,
        builder: builder,
        onTap: () => _openEntry(entry, scope),
      );
    }

    final profile = controller.profile;
    final titles = {
      // The server's own name, as the canvas labels it ("Laptop").
      SettingsGroup.server: profile == null
          ? copy.settingsHubThisServer
          : serverDisplayName(profile, l10n, among: controller.store.profiles),
      SettingsGroup.thisPhone: copy.settingsHubThisPhone,
      SettingsGroup.help: copy.settingsHubGroupHelp,
    };
    // Short values at the row's end instead of two-line subtitles (canvas):
    // "Claude Sonnet 4", "On", "Dark".
    final rows = <SettingsGroup, List<_HubRow?>>{
      SettingsGroup.server: [
        row('settings-model-and-mode', value: _modelSummary(controller)),
        row('settings-providers'),
        row('settings-mcp'),
        row('settings-commands-tools'),
        // The AI Team is findable here whether it is on or off, in the
        // state words Settings › Plugins uses (teamStateLine): "Turning
        // on…" while this phone installs it, "On · This phone", "Off".
        row(
          'settings-ai-team',
          builder: (context) {
            Widget build(SetupProgress? setup) => _CategoryRow(
              rowKey: 'settings-ai-team',
              icon: AppIconography.agent,
              title: l10n.teamUiHomeTitle,
              value: teamStateLine(l10n, controller, setup: setup),
              onTap: () => _openEntry(entries['settings-ai-team']!, scope),
            );

            if (profile == null ||
                teamServerKindOf(profile) != TeamServerKind.inApp) {
              return build(null);
            }
            return ValueListenableBuilder<SetupProgress>(
              valueListenable: PhoneSetup.engine.progress,
              builder: (context, setup, _) => build(setup),
            );
          },
        ),
        row('settings-category-plugins'),
        row('saved-permissions-entry'),
        // Absent where the server cannot change it, like every other row
        // (rule 7); Help › "Available on this server" explains every
        // hidden row at once.
        row(
          'default-shell-settings-entry',
          builder: (_) => DefaultShellRow(controller: controller),
        ),
        row('settings-accounts'),
        row(
          'settings-category-server',
          builder: (_) => _thisServerRow(controller),
        ),
        row('settings-saved-servers'),
      ],
      SettingsGroup.thisPhone: [
        // One screen for everything that notifies. The key predates the
        // merge and is kept for tests and deep links.
        row(
          'settings-category-background',
          value: platformCapabilities.supportsBackgroundService
              ? copy.notifyHubBackgroundSummary(_backgroundSummary(controller))
              : null,
        ),
        row('settings-keep-running'),
        row('settings-voice'),
        row(
          'settings-category-appearance',
          value: appearanceLabel(controller.appearance.value, context),
        ),
        row('settings-transcript-display'),
        // The value names the sections this connection really has.
        row(
          'settings-category-usage',
          value: [
            for (final section in UsageHubScreen.sectionsFor(controller))
              switch (section) {
                UsageSection.spent => copy.usageSectionSpent,
                UsageSection.remaining => copy.usageSectionRemaining,
              },
          ].join(' · '),
        ),
        row('settings-category-privacy'),
      ],
      SettingsGroup.help: [
        // The bug form lives in the failure states themselves; this row is
        // the deliberate path for everything noticed outside a failure.
        row('library-report-bug'),
        row('settings-help'),
        row('settings-about-notices'),
      ],
    };
    return [
      for (final group in SettingsGroup.values)
        _HubGroup(group, titles[group]!, rows[group]!.nonNulls.toList()),
    ];
  }

  static IconData _groupIcon(SettingsGroup group) => switch (group) {
    SettingsGroup.server => AppIconography.server,
    SettingsGroup.thisPhone => AppIconography.phone,
    SettingsGroup.help => AppIconography.support,
  };

  /// One group: its rows on a panel under the group's name.
  Widget _groupView(
    ({_HubGroup group, List<_HubRow> rows}) entry, {
    required bool scrollTarget,
  }) {
    // Groups without a row are dropped before they get here.
    final column = KitRowGroup(
      key: ValueKey('settings-group-${entry.group.group.slug}'),
      // The last panel needs no name: Report a bug, Help, About.
      label: entry.group.group == SettingsGroup.help ? null : entry.group.title,
      children: [for (final row in entry.rows) row.build(context)],
    );
    return scrollTarget
        ? KeyedSubtree(key: _groupKeys[entry.group.group], child: column)
        : column;
  }

  /// A search result section ("Inside settings", "Go to").
  Widget _resultSection(
    ({String slug, String title, List<SearchEntry> entries}) section,
    SearchScope scope,
  ) {
    final copy = _settingsCopy(context);
    return KitRowGroup(
      key: ValueKey('search-results-${section.slug}'),
      label: section.title,
      children: [
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final copy = _settingsCopy(context);
    final tokens = KitTokens.of(context);
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
    final allGroups = [
      for (final group in _groups(controller, entries, scope))
        (group: group, rows: group.rows),
    ].where((entry) => entry.rows.isNotEmpty).toList();
    final groups = [
      for (final entry in allGroups)
        (
          group: entry.group,
          rows: searching
              ? entry.rows
                    .where((row) => matchedIds.contains(row.entry.id))
                    .toList()
              : entry.rows,
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

    void clear() {
      _search.clear();
      setState(() => _query = '');
    }

    final search = KitSearchField(
      fieldKey: const Key('library-search'),
      controller: _search,
      label: l10n.librarySearchHint,
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
    );
    final wide = KitScreen.showsDetail(context);

    // Not a lazy list: every group must exist for an entry point to scroll
    // to it, and the hub is a few dozen plain rows. One Column child keeps
    // them all laid out inside the scroll view.
    Widget hubList({required bool scrollTargets}) => DesktopScrollbarArea(
      builder: (scrollController) => ListView(
        key: const ValueKey('settings-hub-list'),
        controller: scrollController,
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (searching && matchCount == 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
                  child: KitSearchNoMatch(
                    key: const Key('library-search-summary-none'),
                    query: _search.text.trim(),
                    onClear: clear,
                  ),
                ),
              if (searching && matchCount > 0)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: tokens.gutter,
                    end: tokens.gutter,
                    bottom: tokens.space4,
                  ),
                  child: KitText(
                    l10n.librarySearchResults(matchCount, _search.text.trim()),
                    key: const Key('library-search-summary'),
                    role: KitTextRole.secondary,
                  ),
                ),
              for (final (index, entry) in groups.indexed) ...[
                if (index > 0) SizedBox(height: tokens.sectionGap),
                _groupView(entry, scrollTarget: scrollTargets),
              ],
              for (final section in resultSections) ...[
                SizedBox(height: tokens.sectionGap),
                _resultSection(section, scope),
              ],
            ],
          ),
        ],
      ),
    );

    final topBar = widget.embedded
        ? null
        : KitTopBar(title: l10n.librarySettingsTitle);

    if (!wide) {
      return KitScreen(
        topBar: topBar,
        search: search,
        // The health check of "This server" is the one thing that loads here.
        loading: _checking,
        loadingLabel: copy.e7SettingsUi11,
        width: KitScreenWidth.reading,
        body: hubList(scrollTargets: true),
      );
    }

    // Expanded and wider: the groups are the list, the chosen group fills
    // the detail pane. A search shows its results in the list pane.
    final selected =
        allGroups
            .where((entry) => entry.group.group == _selected)
            .firstOrNull ??
        allGroups.firstOrNull;
    final index = ListView(
      key: const ValueKey('settings-group-index'),
      padding: EdgeInsetsDirectional.only(
        top: tokens.space2,
        bottom: KitScreen.endPadding(context),
      ),
      children: [
        KitRowGroup(
          children: [
            for (final entry in allGroups)
              KitRow(
                key: ValueKey('settings-index-${entry.group.group.slug}'),
                leading: KitRow.icon(context, _groupIcon(entry.group.group)),
                // Titles only, so they fit the index pane (R5).
                title: entry.group.title,
                selected: identical(entry, selected),
                trailing: const KitChevron(),
                onTap: () => setState(() => _selected = entry.group.group),
              ),
          ],
        ),
      ],
    );
    return KitScreen.twoPane(
      topBar: topBar,
      search: search,
      loading: _checking,
      loadingLabel: copy.e7SettingsUi11,
      listPaneKey: const ValueKey('settings-list-pane'),
      detailPaneKey: const ValueKey('settings-detail-pane'),
      list: searching ? hubList(scrollTargets: false) : index,
      detail: selected == null || searching
          ? null
          : ListView(
              key: ValueKey('settings-detail-${selected.group.group.slug}'),
              padding: EdgeInsetsDirectional.only(
                top: tokens.space5,
                bottom: KitScreen.endPadding(context),
              ),
              children: [_groupView(selected, scrollTarget: false)],
            ),
      emptyDetail: KitStateView(
        key: const ValueKey('settings-detail-empty'),
        icon: AppIconography.search,
        title: searching
            ? l10n.settingsHubDetailSearching
            : l10n.settingsHubDetailEmpty,
      ),
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

  /// What the row is set to now, at its end ("Claude Sonnet 4").
  final String? value;
  final VoidCallback onTap;

  /// A row that draws itself (live status or its own loading state) but is
  /// searched like any other.
  final WidgetBuilder? builder;

  const _HubRow({
    required this.entry,
    required this.onTap,
    this.value,
    this.builder,
  });

  Widget build(BuildContext context) =>
      builder?.call(context) ??
      _CategoryRow(
        rowKey: entry.id,
        icon: entry.icon,
        title: entry.title,
        value: value,
        onTap: onTap,
      );
}

/// One settings row on the kit (design standard §6): an icon, the title, an
/// explanation of up to two lines or a short value at the end, and a
/// chevron when it opens a screen.
class _CategoryRow extends StatelessWidget {
  final String rowKey;
  final IconData icon;
  final String title;
  final String? subtitle;

  /// What the row is set to now, before the chevron ([KitRowValue]).
  final String? value;
  final VoidCallback? onTap;

  /// False for a row that acts in place instead of opening something.
  final bool chevron;
  final bool enabled;

  const _CategoryRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.chevron = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final hasValue = value != null && value.isNotEmpty;
    // At large text the value moves under the title, so neither is cut to
    // a few letters (A11Y-8).
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final subtitle = hasValue && large ? value : this.subtitle;
    return KitRow(
      key: ValueKey(rowKey),
      leading: KitRow.icon(context, icon),
      title: title,
      titleMaxLines: large ? 2 : 1,
      supporting: subtitle == null ? null : TextSpan(text: subtitle),
      supportingMaxLines: 2,
      trailing: hasValue && !large
          ? KitRowValue(value, chevron: chevron)
          : chevron
          ? const KitChevron()
          : null,
      enabled: enabled,
      onTap: onTap,
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
