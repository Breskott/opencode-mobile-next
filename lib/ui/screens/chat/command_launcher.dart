part of '../chat_screen.dart';

enum _ChatCommandAction {
  newSession,
  sessions,
  workspaces,
  move,
  warp,
  files,
  projectHealth,
  promptEditor,
  terminal,
  model,
  integrations,
  mcpServers,
  organization,
  skills,
  tools,
  references,
  status,
  diagnostics,
  appearance,
  diff,
  context,
  share,
  unshare,
  rename,
  timeline,
  fork,
  compact,
  thinking,
  timestamps,
  undo,
  redo,
  copy,
  export,
  help,
}

class _ChatCommand {
  const _ChatCommand._({
    required this.slash,
    required this.aliases,
    required this.title,
    required this.description,
    required this.group,
    required this.enabled,
    this.action,
    this.serverCommand,
  });

  factory _ChatCommand.mobile({
    required String slash,
    List<String> aliases = const [],
    required String title,
    required String description,
    required String group,
    required _ChatCommandAction action,
    bool enabled = true,
  }) => _ChatCommand._(
    slash: slash,
    aliases: aliases,
    title: title,
    description: description,
    group: group,
    enabled: enabled,
    action: action,
  );

  factory _ChatCommand.server(CommandInfo command, AppLocalizations strings) =>
      _ChatCommand._(
        slash: command.name,
        aliases: const [],
        title: command.name,
        description:
            command.description ??
            command.agent ??
            strings.chatUiOpenCodeServerCommand,
        group: strings.chatUiServerCommands,
        enabled: true,
        serverCommand: command,
      );

  final String slash;
  final List<String> aliases;
  final String title;
  final String description;
  final String group;
  final bool enabled;
  final _ChatCommandAction? action;
  final CommandInfo? serverCommand;

  bool matches(String name) =>
      slash.toLowerCase() == name ||
      aliases.any((alias) => alias.toLowerCase() == name);

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase().replaceFirst('/', '');
    if (normalized.isEmpty) return true;
    return slash.toLowerCase().contains(normalized) ||
        aliases.any((alias) => alias.toLowerCase().contains(normalized)) ||
        title.toLowerCase().contains(normalized) ||
        description.toLowerCase().contains(normalized);
  }

  int scoreFor(String query) {
    final normalized = query.trim().toLowerCase().replaceFirst('/', '');
    if (normalized.isEmpty) return 0;
    final command = slash.toLowerCase();
    final normalizedAliases = aliases.map((alias) => alias.toLowerCase());
    if (command == normalized) return 0;
    if (command.startsWith(normalized)) return 1;
    if (normalizedAliases.any((alias) => alias == normalized)) return 2;
    if (normalizedAliases.any((alias) => alias.startsWith(normalized))) {
      return 3;
    }
    if (title.toLowerCase().startsWith(normalized)) return 4;
    if (command.contains(normalized)) return 5;
    if (title.toLowerCase().contains(normalized)) return 6;
    return 7;
  }
}

enum _ComposerToolTab { commands, agents }

/// Commands and agents (map `command-launcher-sheet`): the app's actions and
/// this server's commands, and, where the server takes `@agent` mentions,
/// the subagents a prompt can be handed to. It opens from the "+" sheet's
/// "Commands and agents" row, from "/" and "@" in the composer, and from
/// Ctrl+K.
///
/// Kit-only rebuild of today's layout (MAP-1 `redesign`): the
/// plain-language action launcher fed by each agent's own command
/// catalogue is deferred to its wave-3 slice (QA record). What this build
/// already fixes: the title names the door that opened it, an action reads
/// by its name first with its slash word as a trailing hint, the "mobile"
/// tag is gone, a search with no match says so with Clear search, and a
/// session whose agent cannot list its own commands (Codex, Claude Code)
/// says so instead of staying silent (STATE-12).
class _CommandLauncherSheet extends StatefulWidget {
  const _CommandLauncherSheet({
    required this.controller,
    required this.initialTab,
    required this.commands,
    required this.agents,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onSelected,
    required this.onAgentSelected,
  });

  final ConnectionController controller;
  final _ComposerToolTab initialTab;
  final List<_ChatCommand> Function() commands;
  final List<CatalogAgent> Function() agents;
  final bool Function() loading;
  final Object? Function() error;
  final Future<void> Function() onRefresh;
  final ValueChanged<_ChatCommand> onSelected;
  final ValueChanged<CatalogAgent> onAgentSelected;

  @override
  State<_CommandLauncherSheet> createState() => _CommandLauncherSheetState();
}

class _CommandLauncherSheetState extends State<_CommandLauncherSheet> {
  final _search = TextEditingController();
  late _ComposerToolTab _tab = widget.initialTab;

  bool get _agentsOffered => widget.controller.capabilities.promptAgentMentions;

  @override
  void initState() {
    super.initState();
    // Filtering follows every keystroke: the list is local, so there is no
    // settling wait before it narrows.
    _search.addListener(_onQuery);
    if (widget.loading()) unawaited(_refresh());
  }

  void _onQuery() {
    if (mounted) setState(() {});
  }

  void _switchTab(_ComposerToolTab tab) {
    if (tab == _tab) return;
    _search.clear();
    setState(() => _tab = tab);
  }

  Future<void> _refresh() async {
    if (_tab == _ComposerToolTab.commands) {
      await widget.onRefresh();
    } else {
      await widget.controller.refreshCatalog();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search
      ..removeListener(_onQuery)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => _buildSheet(context),
  );

  Widget _buildSheet(BuildContext context) {
    final l10n = _chatL10n(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final agentTab = _agentsOffered && _tab == _ComposerToolTab.agents;
    final query = _search.text;
    final Widget list;
    final int resultCount;
    if (agentTab) {
      final agents = _matchingAgents(query);
      resultCount = agents.length;
      list = _AgentPickerList(
        agents: agents,
        query: query,
        loading: widget.controller.catalogLoading,
        error: widget.controller.catalogError,
        onRefresh: _refresh,
        onClearSearch: _search.clear,
        onSelected: widget.onAgentSelected,
      );
    } else {
      final commands = _matchingCommands(query);
      // Typing also searches the rest of the app (settings, Project tools,
      // tabs) through the same index the Settings search uses, so a person
      // in a conversation does not have to leave it to look for something.
      final scope = SearchScope.of(context, widget.controller);
      final elsewhere = searchEntries(l10n, scope, query);
      resultCount = commands.length + elsewhere.length;
      list = _CommandList(
        commands: commands,
        elsewhere: elsewhere,
        query: query,
        onClearSearch: _search.clear,
        onSelected: widget.onSelected,
        onOpenElsewhere: (entry) {
          // The sheet's context dies with the sheet; the result opens from
          // the route below it.
          final navigator = Navigator.of(context);
          final below = navigator.overlay?.context;
          navigator.pop();
          if (below != null) unawaited(entry.open(below, scope));
        },
      );
    }
    final tokens = KitTokens.of(context);
    final height = (MediaQuery.sizeOf(context).height * (largeText ? .96 : .86))
        .floorToDouble();
    final commandsError = agentTab ? null : widget.error();
    return SizedBox(
      key: const Key('command-launcher-sheet'),
      height: height,
      child: KitSheet(
        title: l10n.composerToolCommandsTitle,
        subtitle: agentTab
            ? l10n.chatUiDelegateThisPromptToAServerSubagent
            : l10n.commandLauncherSubtitle,
        fill: true,
        // The modal route draws the one handle (the theme's drag handle).
        handle: false,
        dismissKeyboardOnDrag: true,
        loading: agentTab ? widget.controller.catalogLoading : widget.loading(),
        onClose: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_agentsOffered) ...[
              KitSegmented<_ComposerToolTab>(
                semanticsLabel: l10n.composerToolCommandsTitle,
                selected: agentTab
                    ? _ComposerToolTab.agents
                    : _ComposerToolTab.commands,
                onChanged: _switchTab,
                segments: [
                  KitSegment(
                    key: const Key('composer-tools-commands-tab'),
                    value: _ComposerToolTab.commands,
                    label: l10n.runResultsCommandsTitle,
                    icon: AppIcons.run,
                  ),
                  KitSegment(
                    key: const Key('composer-tools-agents-tab'),
                    value: _ComposerToolTab.agents,
                    label: l10n.chatUiDelegate,
                    icon: AppIconography.agent,
                  ),
                ],
              ),
              SizedBox(height: tokens.space3),
            ],
            KitSearchField(
              label: agentTab
                  ? l10n.chatUiFindASubagent
                  : l10n.chatUiFindACommandOrAction,
              controller: _search,
              onChanged: (_) {},
              resultCount: query.trim().isEmpty ? null : resultCount,
              fieldKey: const Key('command-launcher-search'),
              clearKey: const Key('command-launcher-search-clear'),
            ),
            SizedBox(height: tokens.space3),
            if (commandsError != null) ...[
              KitNotice.error(
                key: const Key('command-launcher-error'),
                message: l10n.chatUiServerCommandsCouldNotBeRefreshed,
                error: commandsError,
                retry: KitAction(
                  key: const Key('command-launcher-retry'),
                  label: l10n.chatUiRetryServerCommands,
                  onPressed: () => unawaited(_refresh()),
                ),
              ),
              SizedBox(height: tokens.space3),
            ],
            // An agent that cannot list its own commands (Codex, Claude
            // Code through Paseo) says so: what follows is the app's own.
            if (!agentTab && !widget.controller.capabilities.serverCatalog) ...[
              KitNotice(
                key: const Key('command-launcher-agent-commands-unavailable'),
                icon: AppIconography.info,
                message: l10n.commandLauncherAgentCommandsUnavailable,
              ),
              SizedBox(height: tokens.space3),
            ],
            list,
          ],
        ),
      ),
    );
  }

  List<_ChatCommand> _matchingCommands(String query) {
    final commands = widget
        .commands()
        .where((command) => command.matchesQuery(query))
        .toList();
    if (query.trim().isNotEmpty) {
      commands.sort((a, b) {
        final score = a.scoreFor(query).compareTo(b.scoreFor(query));
        return score != 0 ? score : a.slash.compareTo(b.slash);
      });
    }
    return commands;
  }

  List<CatalogAgent> _matchingAgents(String query) {
    final normalized = query.trim().toLowerCase().replaceFirst('@', '');
    return widget.agents().where((agent) {
      return normalized.isEmpty ||
          agent.id.toLowerCase().contains(normalized) ||
          (agent.description?.toLowerCase().contains(normalized) ?? false);
    }).toList()..sort((a, b) => a.id.compareTo(b.id));
  }
}

/// The commands, in their groups, then "Go to" places elsewhere in the app;
/// "Nothing matches" with Clear search when a query finds neither.
class _CommandList extends StatelessWidget {
  const _CommandList({
    required this.commands,
    required this.elsewhere,
    required this.query,
    required this.onClearSearch,
    required this.onSelected,
    required this.onOpenElsewhere,
  });

  final List<_ChatCommand> commands;
  final List<SearchEntry> elsewhere;
  final String query;
  final VoidCallback onClearSearch;
  final ValueChanged<_ChatCommand> onSelected;
  final ValueChanged<SearchEntry> onOpenElsewhere;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    if (commands.isEmpty && elsewhere.isEmpty) {
      if (query.trim().isNotEmpty) {
        return KitSearchNoMatch(
          key: const Key('command-launcher-no-match'),
          query: query.trim(),
          onClear: onClearSearch,
        );
      }
      return KitStateView(
        key: const Key('command-launcher-empty'),
        icon: AppIcons.run,
        title: l10n.chatUiNoMatchingCommands,
        size: KitStateSize.inline,
      );
    }
    final groups = <String, List<_ChatCommand>>{};
    for (final command in commands) {
      groups.putIfAbsent(command.group, () => []).add(command);
    }
    return Column(
      key: const Key('command-launcher-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries)
          KitRowGroup(
            label: group.key,
            leadingIcons: false,
            margin: EdgeInsetsDirectional.zero,
            children: [
              for (final command in group.value)
                _CommandRow(command: command, onSelected: onSelected),
            ],
          ),
        if (elsewhere.isNotEmpty)
          KitRowGroup(
            label: l10n.discoverSearchGoTo,
            margin: EdgeInsetsDirectional.zero,
            children: [
              for (final entry in elsewhere)
                KitRow(
                  key: ValueKey('command-launcher-result-${entry.id}'),
                  leading: KitRowIcon(entry.icon),
                  title: entry.title,
                  supporting: entry.parent == null
                      ? null
                      : TextSpan(text: l10n.discoverSearchIn(entry.parent!)),
                  trailing: const KitChevron(),
                  onTap: () => onOpenElsewhere(entry),
                ),
            ],
          ),
      ],
    );
  }
}

/// One command: its name first, what it does under it, and its slash word
/// at the end as the hint for typing it. A server command has no name of
/// its own beyond the slash word, which is then its title.
class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.command, required this.onSelected});

  final _ChatCommand command;
  final ValueChanged<_ChatCommand> onSelected;

  @override
  Widget build(BuildContext context) {
    final server = command.serverCommand != null;
    final slash = '/${command.slash}';
    return KitRow(
      key: Key('command-${server ? 'server' : 'mobile'}-${command.slash}'),
      title: server ? slash : command.title,
      supporting: TextSpan(text: command.description),
      supportingMaxLines: 2,
      trailing: server
          ? null
          : KitText(
              slash,
              role: KitTextRole.mono,
              tone: KitTextTone.secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      enabled: command.enabled,
      onTap: command.enabled ? () => onSelected(command) : null,
    );
  }
}

/// The subagents a prompt can be handed to: "@name", what it is for and the
/// model it runs, one tap to put the mention in the prompt.
class _AgentPickerList extends StatelessWidget {
  const _AgentPickerList({
    required this.agents,
    required this.query,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onClearSearch,
    required this.onSelected,
  });

  final List<CatalogAgent> agents;
  final String query;
  final bool loading;
  final Object? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearSearch;
  final ValueChanged<CatalogAgent> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    if (agents.isEmpty) {
      if (query.trim().isNotEmpty && !loading) {
        return KitSearchNoMatch(
          key: const Key('composer-agent-no-match'),
          query: query.trim(),
          onClear: onClearSearch,
        );
      }
      final refresh = KitAction(
        key: const Key('composer-agent-refresh'),
        label: l10n.globalSessionsRefresh,
        icon: AppIconography.retry,
        onPressed: () => unawaited(onRefresh()),
      );
      if (loading) {
        return KitStateView(
          key: const Key('composer-agent-loading'),
          icon: AppIconography.agent,
          title: l10n.chatUiLoadingSubagents,
          tone: AppStatusTone.progress,
          size: KitStateSize.inline,
        );
      }
      if (error != null) {
        return KitStateView.error(
          key: const Key('composer-agent-error'),
          title: l10n.chatUiSubagentsCouldNotBeLoaded,
          error: error,
          retry: refresh,
          size: KitStateSize.inline,
        );
      }
      return KitStateView(
        key: const Key('composer-agent-empty'),
        icon: AppIconography.agent,
        title: l10n.chatUiNoSubagentsAvailableFromThisServer,
        primary: refresh,
        size: KitStateSize.inline,
      );
    }
    return KitRowGroup(
      key: const Key('composer-agent-list'),
      margin: EdgeInsetsDirectional.zero,
      children: [
        for (final agent in agents)
          KitRow(
            key: Key('composer-agent-${agent.id}'),
            leading: const KitRowIcon(AppIconography.agent),
            title: '@${KitBidi.auto(agent.id)}',
            supporting: TextSpan(
              text: [
                agent.description ?? l10n.chatUiDelegateThisPrompt,
                if (agent.model?.trim() case final model? when model.isNotEmpty)
                  KitBidi.auto(model),
              ].join('\n'),
            ),
            supportingMaxLines: 3,
            onTap: () => onSelected(agent),
          ),
      ],
    );
  }
}
