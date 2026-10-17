import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/chat_feed.dart';
import '../../../domain/relative_age.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/factsbook/factsbook_flag.dart';
import '../../app_iconography.dart';
import '../../kit/kit.dart';
import '../../widgets/session_title.dart';
import '../agents/agent_notices.dart';
import '../factsbook/memory_section.dart';
import 'chats_host.dart';
import 'chats_project_sheet.dart';
import 'chats_sources_sheet.dart' show showChatsSourcesSheet;
import 'new_chat_screen.dart';

/// Chats home ("chats first, project as a setting"): every conversation on
/// the connected server in one list, grouped Needs you, Today, Earlier, with
/// the project as a small label on each row and as a filter, never a place
/// to enter first.
///
/// [initialFilter] lets old entry points (notifications, widgets, deep
/// links) land with Needs you or Running already on; a new value arriving
/// later replaces the filter. The server pill and search belong to the shell's
/// own bar; this screen draws none.
class ChatsHomeScreen extends ConsumerStatefulWidget {
  const ChatsHomeScreen({super.key, this.initialFilter});

  final ChatFeedFilter? initialFilter;

  @override
  ConsumerState<ChatsHomeScreen> createState() => _ChatsHomeScreenState();
}

final _noChanges = ValueNotifier<int>(0);

class _ChatsHomeScreenState extends ConsumerState<ChatsHomeScreen> {
  late ChatFeedFilter _filter = widget.initialFilter ?? ChatFeedFilter.all;

  /// Conversations already on screen: one that shows up later (read from
  /// another connection a moment after) arrives instead of popping in.
  final _seenRows = <String>{};
  String? _openingID;

  /// The row whose conversation is opening now (not while a question
  /// about it is asked): it says Opening… and the bar runs.
  String? _openingShown;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // Phone agents' conversations (Claude Code, …) come from their helper:
    // reading the rows starts it if Android stopped it, so they show here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final agents = ref.read(chatsHostProvider).agents;
      if (agents != null && agents.phoneAgentsAvailable) {
        unawaited(agents.refreshAgentRows());
      }
    });
  }

  @override
  void didUpdateWidget(ChatsHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialFilter;
    if (next != null && next != oldWidget.initialFilter) _filter = next;
  }

  bool get _statusFiltered => _filter.needsYou || _filter.running;

  void _toggleNeedsYou() =>
      setState(() => _filter = _filter.copyWith(needsYou: !_filter.needsYou));

  void _toggleRunning() =>
      setState(() => _filter = _filter.copyWith(running: !_filter.running));

  void _clearFilters() => setState(() => _filter = ChatFeedFilter.all);

  Future<void> _pickProject(ChatsHost host) async {
    final source = host.source;
    final choice = await showChatsProjectSheet(
      context,
      projects: source.projectSummaries,
      allCount: source.chatFeed().items.length,
      selectedDirectory: _filter.projectDirectory,
      otherFoldersCount: source
          .chatFeed(const ChatFeedFilter(otherFolders: true))
          .items
          .length,
      otherFoldersSelected: _filter.otherFolders,
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case ChatsAllProjects():
        setState(
          () => _filter = _filter.copyWith(
            clearProject: true,
            otherFolders: false,
          ),
        );
      case ChatsOtherFolders():
        setState(
          () => _filter = _filter.copyWith(
            clearProject: true,
            otherFolders: true,
          ),
        );
      case ChatsOneProject(:final directory):
        setState(
          () => _filter = _filter.copyWith(
            projectDirectory: directory,
            otherFolders: false,
          ),
        );
      case ChatsOpenProject():
        // The first sheet is closed; this is a second, never on top of it.
        final directory = await host.openProject(context);
        if (!mounted || directory == null) return;
        if (source.isTemporaryProject(directory)) return;
        setState(
          () => _filter = _filter.copyWith(
            projectDirectory: directory,
            otherFolders: false,
          ),
        );
    }
  }

  Future<void> _open(ChatsHost host, ChatFeedItem item) async {
    if (_openingID != null) return;
    setState(() {
      _openingID = item.sessionID;
      _notice = null;
    });
    String? problem;
    final notice = host.agents?.agentResumeNotice(item);
    if (notice != null && notice.requiresAcknowledgement) {
      // The old conversation cannot reopen: say what happens first, and
      // change nothing until the person agrees.
      final l10n = AppLocalizations.of(context);
      final agree = await showKitConfirm(
        context,
        title: l10n.agentsResumeNoticeTitle,
        body: l10n.agentsResumeNoticeBody(
          KitBidi.auto(item.agentLabel ?? item.agentId),
        ),
        confirmLabel: l10n.agentsStartNew,
        cancelLabel: l10n.agentsCancel,
        confirmKey: const ValueKey('agents-start-new'),
      );
      if (!mounted) return;
      if (agree) setState(() => _openingShown = item.sessionID);
      problem = agree ? await host.openNewChatReplacing(context, item) : null;
      if (agree) unawaited(host.source.refreshChatFeed());
    } else {
      setState(() => _openingShown = item.sessionID);
      problem = await host.openChat(context, item);
    }
    if (!mounted) return;
    setState(() {
      _openingID = null;
      _openingShown = null;
      _notice = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(chatsHostProvider);
    return ListenableBuilder(
      listenable: host.listenable ?? _noChanges,
      builder: (context, _) => _body(context, host),
    );
  }

  Widget _body(BuildContext context, ChatsHost host) {
    final l10n = AppLocalizations.of(context);
    final source = host.source;
    final tokens = KitTokens.of(context);
    final snapshot = source.chatFeed(_filter);
    final projects = source.projectSummaries;
    final projectDirectory = _filter.projectDirectory;
    final projectName = projectDirectory == null
        ? null
        : _nameOf(projectDirectory, projects);
    // The Needs you count follows the project filter, not the status chips.
    final listSources = host.listSources;
    final connections = listSources?.chatListSources ?? const [];
    final shownConnections = connections
        .where((connection) => connection.shown)
        .length;
    final needsCount = source
        .chatFeed(
          ChatFeedFilter(
            projectDirectory: projectDirectory,
            otherFolders: _filter.otherFolders,
          ),
        )
        .items
        .where((item) => item.status == ChatStatus.needsYou)
        .length;

    // The one project a server that cannot list across projects shows.
    final onlyName =
        projectName ??
        (snapshot.items.isNotEmpty
            ? snapshot.items.first.projectName
            : projects.isNotEmpty
            ? projects.first.name
            : null);

    final header = <Widget>[
      Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.gutter,
          tokens.space2,
          tokens.gutter,
          tokens.space2,
        ),
        // A page title never breaks mid-word: past 1.5x it stops growing.
        child: KitText.capScale(
          max: 1.5,
          child: KitText(
            l10n.chatsHomeTitle,
            role: KitTextRole.largeTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      KitFilterChips(
        chips: [
          KitChip.summary(
            key: const ValueKey('chats-filter-project'),
            label: _filter.otherFolders
                ? l10n.chatsHomeOtherFolders
                : projectName == null
                ? l10n.chatsHomeAllProjects
                : KitBidi.auto(projectName),
            expanded: false,
            tone: projectName == null && !_filter.otherFolders
                ? KitChipTone.neutral
                : KitChipTone.active,
            onPressed: () => unawaited(_pickProject(host)),
          ),
          // Which connections' conversations show, once there is more than
          // one (Termux beside the in-app Ubuntu, the agents).
          if (listSources != null && connections.length > 1)
            KitChip.summary(
              key: const ValueKey('chats-filter-sources'),
              label: shownConnections == connections.length
                  ? l10n.chatsSourcesAll
                  : l10n.chatsSourcesSome(shownConnections, connections.length),
              expanded: false,
              tone: shownConnections == connections.length
                  ? KitChipTone.neutral
                  : KitChipTone.active,
              onPressed: () => unawaited(
                showChatsSourcesSheet(
                  context,
                  sources: listSources,
                  nameOf: (source) =>
                      host.connectionName(context, source.id, source.name),
                ),
              ),
            ),
          KitFilterChip(
            key: const ValueKey('chats-filter-needs-you'),
            label: needsCount > 0
                ? l10n.chatsHomeNeedsYouCount(needsCount)
                : l10n.chatsHomeNeedsYou,
            needsYou: true,
            selected: _filter.needsYou,
            onPressed: _toggleNeedsYou,
          ),
          KitFilterChip(
            key: const ValueKey('chats-filter-running'),
            label: l10n.chatsHomeRunning,
            selected: _filter.running,
            onPressed: _toggleRunning,
          ),
        ],
      ),
    ];

    // The quiet lines and notices scroll with the feed: they never take the
    // fixed header, so a small or landscape screen keeps its rows.
    final notices = <Widget>[
      if (!snapshot.acrossProjects && onlyName != null)
        _QuietLine(
          key: const ValueKey('chats-only-project'),
          text: l10n.chatsHomeOnlyProject(KitBidi.auto(onlyName)),
        ),
      // A server the list shows but can't reach is named; the connections
      // chip has its Try again.
      if (snapshot.unreachableServers.isNotEmpty)
        _QuietLine(
          key: const ValueKey('chats-unreachable'),
          text: l10n.chatsHomeUnreachable(
            KitBidi.auto(
              [
                for (final id in snapshot.unreachableServers)
                  host.connectionName(context, id, 'OpenCode'),
              ].join(', '),
            ),
          ),
        )
      else if (!snapshot.complete)
        _QuietLine(
          key: const ValueKey('chats-incomplete'),
          text: l10n.chatsHomeIncomplete,
        ),
      // Rows show while an agent's own conversations are still being read:
      // more are on the way, said before they arrive.
      if (snapshot.stillLoading.isNotEmpty ||
          snapshot.stillLoadingServers.isNotEmpty)
        _QuietLine(
          key: const ValueKey('chats-still-loading'),
          text: l10n.chatsHomeStillLoading(
            KitBidi.auto(
              [
                for (final id in snapshot.stillLoadingServers)
                  host.connectionName(context, id, 'OpenCode'),
                ...snapshot.stillLoading,
              ].join(', '),
            ),
          ),
        ),
      if (_notice != null)
        _QuietLine(key: const ValueKey('chats-notice'), text: _notice!),
      // The leftover-process notice: a quiet status with its Stop, drawn
      // only while the phone's watcher reports a helper.
      host.leftoverNotice(context),
      // Quiet lines about the agents on this phone, each with its action.
      AgentStatusNotices(host: host),
    ];
    final list = _list(context, host, snapshot, projectName, notices);
    final screen = KitScreen(
      header: header,
      // The bar keeps moving while more conversations are on the way.
      loading:
          (snapshot.loading && snapshot.items.isEmpty) ||
          _openingShown != null ||
          snapshot.stillLoading.isNotEmpty ||
          snapshot.stillLoadingServers.isNotEmpty,
      loadingLabel: l10n.chatsHomeTitle,
      body: KitRefresh(onRefresh: source.refreshChatFeed, child: list),
    );
    // Every empty state already offers its one primary action (Start a
    // conversation, Clear filters, Start in this project): no second one.
    final plainEmpty = snapshot.items.isEmpty && !snapshot.loading;
    if (plainEmpty) return screen;
    return KitFloatingAction(
      buttonKey: const ValueKey('chats-new-chat'),
      label: l10n.chatsHomeNewChat,
      icon: AppIconography.add,
      onPressed: () => unawaited(
        showNewChat(
          context,
          directory: projectDirectory ?? source.lastUsedProjectDirectory,
        ),
      ),
      child: screen,
    );
  }

  Widget _list(
    BuildContext context,
    ChatsHost host,
    ChatFeedSnapshot snapshot,
    String? projectName,
    List<Widget> notices,
  ) {
    final l10n = AppLocalizations.of(context);
    final tokens = KitTokens.of(context);
    final items = snapshot.items;
    final end = KitScreen.endPadding(context) + KitFloatingAction.clearance;
    // The developer flag shows FactsBook's Memory section under Needs you.
    final memory = ref.watch(factsBookEnabledProvider);
    if (items.isEmpty) {
      if (snapshot.loading) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: tokens.space3),
          children: [...notices, const KitSkeletonRows()],
        );
      }
      final KitStateView state;
      if (_statusFiltered) {
        state = KitStateView(
          key: const ValueKey('chats-empty-filtered'),
          icon: AppIconography.search,
          title: l10n.chatsHomeNoMatchTitle,
          body: l10n.chatsHomeNoMatchBody,
          primary: KitAction(
            key: const ValueKey('chats-clear-filters'),
            label: l10n.chatsHomeClearFilters,
            onPressed: _clearFilters,
          ),
        );
      } else if (projectName != null) {
        state = KitStateView(
          key: const ValueKey('chats-empty-project'),
          icon: AppIconography.chat,
          title: l10n.chatsHomeProjectEmptyTitle(KitBidi.auto(projectName)),
          primary: KitAction(
            key: const ValueKey('chats-start-in-project'),
            label: l10n.chatsHomeStartChatIn(KitBidi.auto(projectName)),
            onPressed: () => unawaited(
              showNewChat(context, directory: _filter.projectDirectory),
            ),
          ),
        );
      } else {
        state = KitStateView(
          key: const ValueKey('chats-empty'),
          icon: AppIconography.chat,
          title: l10n.chatsHomeEmptyTitle,
          body: l10n.chatsHomeEmptyBody,
          primary: KitAction(
            key: const ValueKey('chats-start-chat'),
            label: l10n.chatsHomeStartChat,
            onPressed: () => unawaited(
              showNewChat(
                context,
                directory: host.source.lastUsedProjectDirectory,
              ),
            ),
          ),
        );
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ...notices,
          if (memory) const FactsBookMemorySection(),
          state,
        ],
      );
    }

    final now = clock.now();
    bool today(ChatFeedItem item) {
      final at = item.lastActivity.toLocal();
      final n = now.toLocal();
      return at.year == n.year && at.month == n.month && at.day == n.day;
    }

    // The first rows painted are simply there; only later ones arrive.
    if (_seenRows.isEmpty && items.isNotEmpty) {
      _seenRows.addAll(
        host.source
            .chatFeed(const ChatFeedFilter(includeSubagents: true))
            .items
            .map((item) => item.identity),
      );
    }
    // The agent's name shows only when the feed mixes agents or servers;
    // beside another server, OpenCode's rows name theirs.
    final servers = items.any(
      (item) => item.sourceId?.startsWith('profile:') ?? false,
    );
    final showAgent =
        servers || items.map((item) => item.agentId).toSet().length > 1;

    // A chat that needs you sorts first inside its time group; its amber
    // word and the chip already say it, so it has no group of its own.
    List<ChatFeedItem> needsFirst(Iterable<ChatFeedItem> group) => [
      for (final item in group)
        if (item.status == ChatStatus.needsYou) item,
      for (final item in group)
        if (item.status != ChatStatus.needsYou) item,
    ];
    final todays = needsFirst([
      for (final item in items)
        if (today(item) || item.lastActivity.isAfter(now)) item,
    ]);
    final earlier = needsFirst([
      for (final item in items)
        if (!(today(item) || item.lastActivity.isAfter(now))) item,
    ]);

    // The notices above it are not a section to separate from: the first
    // label keeps the zero gap it had when they sat in the fixed header.
    Widget section(
      String label,
      List<ChatFeedItem> group, {
      bool first = false,
    }) => KitSliverRowGroup(
      label: label,
      gapBefore: first ? 0 : null,
      leadingIcons: false,
      itemCount: group.length,
      itemBuilder: (context, index) {
        final item = group[index];
        final row = _row(
          context,
          host,
          item,
          now,
          showAgent: showAgent,
          servers: servers,
        );
        // A conversation waiting on the person answers here: its request
        // card under the row (with Undo), no need to open it.
        final request = item.status == ChatStatus.needsYou
            ? host.listRequest(context, item)
            : null;
        final shown = request == null
            ? row
            : Column(
                key: ValueKey('chats-row-request-${item.sessionID}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  row,
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: tokens.gutter,
                      end: tokens.gutter,
                      bottom: tokens.space3,
                    ),
                    child: request,
                  ),
                ],
              );
        return KeyedSubtree(
          key: ValueKey('chats-row-${item.sessionID}'),
          child: _seenRows.add(item.identity)
              ? KitEntrance(child: shown)
              : shown,
        );
      },
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList.list(children: notices),
        if (memory) const SliverToBoxAdapter(child: FactsBookMemorySection()),
        if (todays.isNotEmpty)
          section(l10n.chatsHomeToday, todays, first: true),
        if (earlier.isNotEmpty)
          section(l10n.chatsHomeEarlier, earlier, first: todays.isEmpty),
        SliverToBoxAdapter(child: SizedBox(height: end)),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ChatsHost host,
    ChatFeedItem item,
    DateTime now, {
    required bool showAgent,
    bool servers = false,
  }) {
    final l10n = AppLocalizations.of(context);
    // The row being opened says so (an old Claude conversation takes a
    // few seconds to reopen on its helper).
    final opening = _openingShown == item.sessionID;
    final cantReopen =
        host.agents?.agentResumeNotice(item).requiresAcknowledgement ?? false;
    // A state shows only when it matters; an ordinary conversation is just
    // its project and time.
    final (String? state, KitFeedStateTone tone) = opening
        ? (l10n.chatsHomeOpening, KitFeedStateTone.running)
        : switch (item.status) {
            ChatStatus.needsYou => (
              l10n.chatsHomeNeedsYou,
              KitFeedStateTone.needsYou,
            ),
            ChatStatus.running => (
              l10n.chatsHomeRowWorking,
              KitFeedStateTone.running,
            ),
            ChatStatus.failed => (l10n.chatsHomeFailed, KitFeedStateTone.quiet),
            _ when cantReopen => (
              l10n.agentsStateCantReopen,
              KitFeedStateTone.quiet,
            ),
            _ => (null, KitFeedStateTone.quiet),
          };
    return KitFeedItem(
      project: item.projectName,
      // The agent's name leads the meta line when it is not the default
      // OpenCode; beside another server, OpenCode's rows name theirs.
      agent:
          item.agentLabel ??
          (showAgent && servers && item.sourceLabel != null
              ? _serverOf(context, host, item)
              : null),
      // The server's dated placeholder reads "New conversation" (F3).
      title: presentedSessionTitleText(item.title, l10n: l10n),
      state: state,
      stateTone: tone,
      time: relativeAgeLabel(
        now.difference(item.lastActivity),
        at: item.lastActivity,
        l10n: l10n,
      ),
      tappableKey: opening ? const ValueKey('chats-row-opening') : null,
      onTap: () => unawaited(_open(host, item)),
    );
  }

  /// The server an OpenCode row runs on, named as the switcher names it.
  static String _serverOf(
    BuildContext context,
    ChatsHost host,
    ChatFeedItem item,
  ) {
    final source = item.sourceId ?? '';
    final id = source.startsWith('profile:')
        ? source.substring('profile:'.length)
        : host.listSources?.chatListSources
                  .where((connection) => connection.main)
                  .firstOrNull
                  ?.id ??
              '';
    return host.connectionName(context, id, item.sourceLabel ?? 'OpenCode');
  }

  static String _nameOf(String directory, List<ProjectSummary> projects) {
    for (final project in projects) {
      if (project.directory == directory) return project.name;
    }
    final parts = directory.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? directory : parts.last;
  }
}

/// One quiet line under the filters (partial data, a note).
class _QuietLine extends StatelessWidget {
  const _QuietLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space1,
        tokens.gutter,
        tokens.space1,
      ),
      child: KitText(
        text,
        role: KitTextRole.caption,
        tone: KitTextTone.secondary,
      ),
    );
  }
}
