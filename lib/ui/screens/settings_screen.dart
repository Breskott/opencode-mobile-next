import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api/provider_presentation.dart';
import '../../background/live_background.dart';
import '../../builtin/builtin_server.dart' show looksLikeInAppServer;
import '../../builtin/setup/phone_setup.dart';
import '../../builtin/setup/setup_contract.dart' show SetupProgress;
import '../../diagnostics/perf_trace.dart';
import '../../diagnostics/report_problem_startup.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/app_locale.dart' show AppLocaleStore;
import '../../state/connection.dart';
import '../../state/external_agents.dart';
import '../../state/offline_queue.dart';
import '../../state/phrase_chips.dart';
import '../../state/profile_monitor.dart';
import '../../state/phone_host.dart' show PhoneHostKind;
import '../../domain/settings_scope.dart';
import '../../state/profiles.dart';
import '../../state/settings_access.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import '../early_l10n.dart';
import '../kit/kit.dart';
import '../theme_packs.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/language_picker.dart'
    show languageChoiceLabel, languageChoiceNote;
import '../widgets/phone_server_card.dart' show serverDisplayName;
import '../widgets/product_states.dart';
import '../widgets/safety_confirms.dart';
import 'app_diagnostics_screen.dart' show reportProblemErrorCount;
import 'settings/ai_setup_screen.dart';
import 'settings/server_plugins_section.dart';
import 'automation_settings_screen.dart' show AutomationSettingsSection;
import 'keep_running_screen.dart' show KeepRunningSection;
import 'host_management_screen.dart';
import 'agents/agents_screen.dart' show AgentsScreen;
import 'servers_screen.dart' show ServersRouteRequest;
import 'capabilities_screen.dart' show openExternalAgents;
import '../widgets/pickers.dart' show showModelPicker;
import '../widgets/termux_running_server_entry.dart' show isPhoneOwnServer;
import 'server_capabilities_screen.dart';
import 'this_phone_screen.dart' show openThisPhone;
import '../widgets/team_discover.dart';
import '../search/search_index.dart';

import 'settings/live_background_screens.dart';
part 'settings/server_settings_screen.dart';
part 'settings/server_host_update.dart';
part 'settings/default_shell_row.dart';
part 'settings/phrase_chips_row.dart';
part 'settings/notifications_settings_screen.dart';
part 'settings/personal_settings_screens.dart';
part 'settings/hub_servers.dart';
part 'settings/server_page.dart';
part 'settings/agents_permissions_screens.dart';

AppLocalizations _settingsCopy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));

/// The groups of the Settings hub (Settings Standard G1-G6): five groups,
/// each answering one question, with a short plain label that never changes
/// with the server.
enum SettingsGroup {
  /// What am I connected to? Servers and this phone.
  connections('connections'),

  /// Who answers, with what, and what does it cost? Model, providers, usage,
  /// tools and agents.
  ai('ai'),

  /// How chats look and behave.
  chat('chat'),

  /// How the app behaves on this phone.
  thisApp('this-app'),

  /// Where do I get help? Setup guide, Report a problem and About.
  help('help');

  const SettingsGroup(this.slug);

  /// Stable name used in the `settings-group-<slug>` widget key.
  final String slug;
}

/// The one Settings hub: five groups of rows. Search is the header's
/// command launcher, which reads the same index. It is the
/// fourth tab of the shell ([embedded]) and the screen every other entry
/// point pushes, so a setting has exactly one home. Rows the connected server
/// cannot serve are absent, and the group says how many under its panel in
/// one muted line with a Why (target-ia §1.3); a group with no rows is
/// absent.
///
/// Kit only (screen-settings-1): a [KitScreen] with one [KitRowGroup] panel
/// per group. From expanded it
/// is [KitScreen.twoPane]: the groups are the list pane and the chosen
/// group's rows fill the detail pane; a row still opens its page.
/// Test seam: builds of the Settings hub.
@visibleForTesting
int settingsBuildCount = 0;

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
  final _groupKeys = {
    for (final group in SettingsGroup.values)
      group: GlobalKey(debugLabel: 'settings-group-${group.slug}'),
  };

  /// The tab is offstage (TickerMode off); notifications only mark it stale.
  bool _visible = true;

  /// The group in the detail pane (expanded and wider).
  SettingsGroup? _selected;

  PerfSpanHandle? _openSpan;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGroup;
    _openSpan = PerfTrace.begin('settings.open');
    widget.controller.addListener(_connectionChanged);
    widget.controller.profileMonitor.addListener(_connectionChanged);
    final initial = widget.initialGroup;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _groupKeys[initial]?.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    }
  }

  void _connectionChanged() {
    if (!mounted) return;
    if (!_visible) return;
    // The monitor can speak while another page is mid-build; redraw after.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_connectionChanged);
    widget.controller.profileMonitor.removeListener(_connectionChanged);
    _openSpan?.finish(attrs: {'outcome': 'closed'});
    super.dispose();
  }

  /// The Model row's value: the default model's name (the picker also
  /// sets its variant and agent). A model the person never chose is the
  /// server's own pick, and only then does the row say so.
  String _modelSummary(ConnectionController controller) {
    final copy = _settingsCopy(context);
    final selected = controller.selectedModel;
    if (selected == null) return copy.modelServerDefault;
    return controller.catalog?.models
            .where(
              (model) =>
                  model.providerID == selected.providerID &&
                  model.id == selected.modelID,
            )
            .firstOrNull
            ?.name ??
        readableModelLabel(selected.providerID, selected.modelID);
  }

  /// Runs an index entry, then redraws: most of them change something a row's
  /// value shows.
  Future<void> _openEntry(SearchEntry entry, SearchScope scope) async {
    await entry.open(context, scope);
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await pushKitPage<void>(context, (_) => screen);
    if (mounted) setState(() {});
  }

  /// The hub's layout: which index entries are rows, in which order, and what
  /// each shows beside its title. Titles, keywords, gates and what a tap does
  /// come from the search index, so the hub, its search and every other
  /// search surface cannot disagree. A row whose entry is gated out is absent.
  ///
  /// Rows are one line (Settings Standard D1): the name at the start, its
  /// state at the end. With several saved servers the server-owned rows say
  /// "By server" and open a page that lists each one (SC4).
  List<_HubGroup> _groups(
    ConnectionController controller,
    Map<String, SearchEntry> entries,
    SearchScope scope,
  ) {
    final copy = _settingsCopy(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final several = hasSeveralServers(controller);
    _HubRow? row(
      String id, {
      String? value,
      WidgetBuilder? builder,
      VoidCallback? onTap,
    }) {
      final entry = entries[id];
      if (entry == null) return null;
      return _HubRow(
        entry: entry,
        value: value,
        builder: builder,
        onTap: onTap ?? () => _openEntry(entry, scope),
      );
    }

    /// A server-owned row: "By server" once there are several, which opens
    /// the page that lists each server with its own answer.
    _HubRow? byServerRow(
      String id,
      ByServerKind kind, {
      String? single,
      VoidCallback? onTapSingle,
    }) => several
        ? row(
            id,
            value: copy.settingsV3ByServer,
            onTap: () =>
                _open(ByServerScreen(controller: controller, kind: kind)),
          )
        : row(id, value: single, onTap: onTapSingle);

    final profile = controller.profile;
    final titles = {
      SettingsGroup.connections: copy.settingsV3GroupConnections,
      SettingsGroup.ai: copy.settingsV3GroupAi,
      SettingsGroup.chat: copy.settingsV3GroupChat,
      SettingsGroup.thisApp: copy.settingsHubGroupThisApp,
      SettingsGroup.help: copy.settingsV3GroupHelp,
    };
    final serverName = profile == null
        ? null
        : serverDisplayName(profile, l10n, among: controller.store.profiles);
    final rows = <SettingsGroup, List<_HubRow?>>{
      SettingsGroup.connections: [
        row('settings-saved-servers', value: serversRowValue(controller, l10n)),
        row('settings-this-phone', value: phoneRowValue(controller, copy)),
      ],
      SettingsGroup.ai: [
        // The model new chats start with: its name, or "By server".
        byServerRow(
          'settings-model-and-mode',
          ByServerKind.model,
          single: profile == null ? null : _modelSummary(controller),
          onTapSingle: () => unawaited(
            showModelPicker(
              context,
              title: serverName == null
                  ? null
                  : copy.settingsV3ModelNewOn(serverName),
            ),
          ),
        ),
        byServerRow('settings-providers', ByServerKind.providers),
        row('settings-category-usage'),
        byServerRow('settings-tools', ByServerKind.tools),
        row('settings-agents'),
      ],
      SettingsGroup.chat: [
        // Two switches: the same stored values the conversation menu flips,
        // for every conversation on this device.
        row(
          'settings-show-reasoning',
          builder: (context) => KitSwitchRow(
            key: const ValueKey('settings-show-reasoning'),
            leading: KitRow.icon(context, AppIconography.idea),
            title: copy.settingsHubShowReasoning,
            value: controller.transcriptReasoningExpanded,
            onChanged: (value) =>
                unawaited(controller.setTranscriptReasoningExpanded(value)),
          ),
        ),
        row(
          'settings-show-timestamps',
          builder: (context) => KitSwitchRow(
            key: const ValueKey('settings-show-timestamps'),
            leading: KitRow.icon(context, AppIconography.clock),
            title: copy.settingsHubShowTimestamps,
            value: controller.transcriptTimestampsVisible,
            onChanged: (value) =>
                unawaited(controller.setTranscriptTimestampsVisible(value)),
          ),
        ),
        row(
          'settings-phrase-chips',
          builder: (_) => PhraseChipsSettingsRow(controller: controller),
        ),
        several
            ? byServerRow('default-shell-settings-entry', ByServerKind.shell)
            : row(
                'default-shell-settings-entry',
                builder: (_) => DefaultShellRow(controller: controller),
              ),
        row('settings-voice'),
        row('settings-automation'),
      ],
      SettingsGroup.thisApp: [
        row(
          'settings-category-notifications',
          value: notificationsRowValue(controller, copy),
        ),
        row(
          'settings-category-background',
          value: platformCapabilities.supportsBackgroundService
              ? _backgroundSummary(controller)
              : null,
        ),
        row(
          'settings-category-appearance',
          value: appearanceLabel(controller.appearance.value, context),
        ),
        row(
          'settings-category-language',
          builder: (_) => LanguageSettingsRow(controller: controller),
        ),
        row('settings-category-privacy'),
      ],
      SettingsGroup.help: [
        row('settings-setup-guide'),
        // Report a problem: every failure state offers it too; this row is
        // the deliberate path, with the count of errors kept (P8.2).
        row(
          'library-report-bug',
          builder: (context) => _ReportProblemRow(
            entry: entries['library-report-bug']!,
            controller: controller,
            onTap: () => _openEntry(entries['library-report-bug']!, scope),
          ),
        ),
        row('settings-about-notices'),
      ],
    };
    return [
      for (final group in SettingsGroup.values)
        _HubGroup(group, titles[group]!, rows[group]!.nonNulls.toList()),
    ];
  }

  /// The background state at a glance, so the hub says whether runs keep
  /// updating after the app closes without opening the page.
  String _backgroundSummary(ConnectionController controller) {
    final copy = _settingsCopy(context);
    final live = controller.backgroundLive;
    if (live.stoppedByAndroidTimeout) return copy.e7SettingsUi12;
    if (!controller.keepLiveInBackground) return copy.quotaBudgetOff;
    return live.active ? copy.e7SettingsUi14 : copy.e7SettingsUi15;
  }

  static IconData _groupIcon(SettingsGroup group) => switch (group) {
    SettingsGroup.connections => AppIconography.server,
    SettingsGroup.ai => AppIconography.model,
    SettingsGroup.chat => AppIconography.chat,
    SettingsGroup.thisApp => AppIconography.phone,
    SettingsGroup.help => AppIconography.support,
  };

  /// The one line under the groups for every row the connected server
  /// hides, with a Why that opens What this server supports (N6): rows never
  /// move, so how many are missing is said once, here.
  Widget? _unavailableNote(int hidden) {
    if (hidden == 0) return null;
    final copy = _settingsCopy(context);
    return KitGroupNote(
      key: const ValueKey('settings-unavailable'),
      message: copy.settingsHubUnavailableCount(hidden),
      action: KitAction(
        key: const ValueKey('settings-unavailable-why'),
        label: copy.settingsHubUnavailableWhy,
        onPressed: () => unawaited(
          _open(ServerCapabilitiesScreen(controller: widget.controller)),
        ),
      ),
    );
  }

  /// How many hub rows the connected server hides. Without a connection
  /// there is no server to blame.
  int _hiddenCount(ConnectionController controller, SearchScope scope) {
    if (!controller.isConnected) return 0;
    final copy = _settingsCopy(context);
    var hidden = 0;
    for (final entry in allSearchEntries(copy)) {
      if (entry.kind == SearchEntryKind.hubRow &&
          entry.group != null &&
          entry.hiddenByServer(scope)) {
        hidden++;
      }
    }
    return hidden;
  }

  /// One group: its rows on a panel under the group's name.
  Widget _groupView(
    ({_HubGroup group, List<_HubRow> rows}) entry, {
    required bool scrollTarget,
  }) {
    // Groups without a row are dropped before they get here.
    final panel = KitRowGroup(
      key: ValueKey('settings-group-${entry.group.group.slug}'),
      label: entry.group.title,
      children: [for (final row in entry.rows) row.build(context)],
    );
    return scrollTarget
        ? KeyedSubtree(key: _groupKeys[entry.group.group], child: panel)
        : panel;
  }

  /// "You can change some of these for one server": the saved servers, each
  /// opening its own page. Only once there are several (SC4); with one the
  /// server-owned rows open straight to it.
  Widget? _serversBlock(ConnectionController controller) {
    if (!hasSeveralServers(controller)) return null;
    return SettingsServersBlock(
      key: const ValueKey('settings-servers-block'),
      controller: controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    settingsBuildCount++;
    _visible = TickerMode.valuesOf(context).enabled;
    if (_openSpan != null) {
      final span = _openSpan!;
      _openSpan = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => span.finish());
    }
    final controller = widget.controller;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final copy = _settingsCopy(context);
    final tokens = KitTokens.of(context);
    final scope = SearchScope.of(context, controller);
    final entries = {
      for (final entry in searchIndex(copy, scope)) entry.id: entry,
    };
    final allGroups = [
      for (final group in _groups(controller, entries, scope))
        (group: group, rows: group.rows),
    ].where((entry) => entry.rows.isNotEmpty).toList();
    final groups = allGroups;
    final wide = KitScreen.showsDetail(context);
    final note = _unavailableNote(_hiddenCount(controller, scope));
    final serversBlock = _serversBlock(controller);

    // As a tab of the shell the page has no top bar, so it starts with its
    // own large title like Chats and Files do.
    final tabTitle = widget.embedded
        ? Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.gutter,
              tokens.space2,
              tokens.gutter,
              tokens.space2,
            ),
            child: Semantics(
              header: true,
              child: KitText(
                l10n.librarySettingsTitle,
                key: const ValueKey('settings-tab-title'),
                role: KitTextRole.largeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        : null;

    // Not a lazy list: every group must exist for an entry point to scroll
    // to it, and the hub is a few dozen plain rows. One Column child keeps
    // them all laid out inside the scroll view.
    Widget hubList({required bool scrollTargets}) => KitScrollArea(
      builder: (scrollController) => ListView(
        key: const ValueKey('settings-hub-list'),
        controller: scrollController,
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          ?tabTitle,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, entry) in groups.indexed) ...[
                if (index > 0) SizedBox(height: tokens.sectionGap),
                _groupView(entry, scrollTarget: scrollTargets),
              ],
              ?note,
              if (serversBlock != null) ...[
                SizedBox(height: tokens.sectionGap),
                serversBlock,
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
        width: KitScreenWidth.reading,
        body: hubList(scrollTargets: true),
      );
    }

    // Expanded and wider: the groups are the list, the chosen group fills
    // the detail pane.
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
        ?tabTitle,
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
        if (serversBlock != null) ...[
          SizedBox(height: tokens.sectionGap),
          serversBlock,
        ],
      ],
    );
    return KitScreen.twoPane(
      topBar: topBar,
      listPaneKey: const ValueKey('settings-list-pane'),
      detailPaneKey: const ValueKey('settings-detail-pane'),
      list: index,
      detail: selected == null
          ? null
          : ListView(
              key: ValueKey('settings-detail-${selected.group.group.slug}'),
              padding: EdgeInsetsDirectional.only(
                top: tokens.space5,
                bottom: KitScreen.endPadding(context),
              ),
              children: [_groupView(selected, scrollTarget: false), ?note],
            ),
      emptyDetail: KitStateView(
        key: const ValueKey('settings-detail-empty'),
        icon: AppIconography.search,
        title: l10n.settingsHubDetailEmpty,
      ),
    );
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

  /// The row, marked as the place a search result arrives at (KitArrival):
  /// the switches and the shell choice act here, so their results open the
  /// hub at them.
  Widget build(BuildContext context) => KitArrival(
    id: entry.id,
    child:
        builder?.call(context) ??
        _CategoryRow(
          rowKey: entry.id,
          icon: entry.icon,
          title: entry.title,
          value: value,
          onTap: onTap,
        ),
  );
}

/// One settings row on the kit (design standard §6): an icon, the title, an
/// explanation of up to two lines or a short value at the end, and a
/// chevron when it opens a screen.
class _CategoryRow extends StatelessWidget {
  final String rowKey;

  /// Null on an inner page, whose rows carry no icon tile (R4).
  final IconData? icon;
  final String title;
  final String? subtitle;

  /// What the row is set to now, before the chevron ([KitRowValue]).
  final String? value;
  final VoidCallback? onTap;

  final bool enabled;

  /// A count badge before the chevron, with [badgeLabel] as its words.
  final int? badge;
  final String? badgeLabel;

  const _CategoryRow({
    required this.rowKey,
    this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.enabled = true,
    this.badge,
    this.badgeLabel,
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
      leading: icon == null ? null : KitRow.icon(context, icon!),
      title: title,
      titleMaxLines: large ? 2 : 1,
      supporting: subtitle == null ? null : TextSpan(text: subtitle),
      supportingMaxLines: 2,
      trailing: (badge ?? 0) > 0
          ? KitRowValue.count(badge!, badgeLabel ?? '$badge')
          : hasValue && !large
          ? KitRowValue(value)
          : const KitChevron(),
      enabled: enabled,
      onTap: onTap,
    );
  }
}

/// Settings' Report a problem row (P8.2): the one way in besides the
/// failure states, with a badge counting the errors kept on this phone.
class _ReportProblemRow extends StatelessWidget {
  const _ReportProblemRow({
    required this.entry,
    required this.controller,
    required this.onTap,
  });

  final SearchEntry entry;
  final ConnectionController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = _settingsCopy(context);
    final store = ReportProblemStartup.current?.report;
    return ListenableBuilder(
      listenable: Listenable.merge([controller.diagnostics, ?store]),
      builder: (context, _) {
        final count = reportProblemErrorCount(
          store: store,
          diagnostics: controller.diagnostics,
        );
        return _CategoryRow(
          rowKey: entry.id,
          icon: entry.icon,
          title: entry.title,
          badge: count,
          badgeLabel: copy.reportProblemErrorBadge(count),
          onTap: onTap,
        );
      },
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
