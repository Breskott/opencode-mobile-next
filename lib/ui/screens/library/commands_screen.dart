part of '../library_screen.dart';

/// "Server commands" (map `commands`, proposal fix), built from kit parts
/// (screen-library-4): the server's slash commands as one panel of
/// [KitRow]s on the rails, one run metaphor (the lightning tile; a tap asks
/// where to run it), the agent each command runs with, a search once the
/// list is long, and the missing states: the loading skeleton, an empty
/// page that says where commands come from, no match, and a failed first
/// load that explains itself with Try again and Report a problem.
///
/// Running a command inside the conversation you came from belongs to the
/// conversation's own command launcher, not here: this page has no
/// conversation (see docs/qa/revamp-screen-library-4/README.md).
class CommandsScreen extends StatefulWidget {
  final ConnectionController controller;

  /// Embedded mode renders the body only, for the Commands & tools tabs.
  final bool embedded;
  const CommandsScreen({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  @override
  State<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends State<CommandsScreen> {
  List<CommandInfo>? _commands;
  String? _error;
  String _query = '';
  bool _openingCommand = false;
  int _loadGeneration = 0;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (_commands == null) setState(() => _error = null);
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (!mounted || generation != _loadGeneration) return;
      if (repository == null) {
        throw ProductException(
          _libraryCopy(context).e7LibraryOpenCodeIsReconnecting,
        );
      }
      final commands = await repository.listCommands();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _commands = commands;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = productErrorText(error));
      }
    }
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  List<CommandInfo> _matching() {
    final query = _query.trim().toLowerCase();
    return (_commands ?? const <CommandInfo>[])
        .where(
          (command) =>
              query.isEmpty ||
              command.name.toLowerCase().contains(query) ||
              (command.description ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _libraryCopy(context);
    final commands = _commands;
    final matching = _matching();
    final showSearch =
        commands != null &&
        (KitSearchField.worthShowing(commands.length) || _query.isNotEmpty);
    return KitScreen(
      width: KitScreenWidth.list,
      topBar: widget.embedded
          ? null
          : KitTopBar(title: l10n.e7LibraryServerCommands),
      loading: commands == null && _error == null,
      loadingLabel: l10n.commandsScreenLoading,
      search: showSearch
          ? KitSearchField(
              label: l10n.e7LibrarySearchServerCommands,
              controller: _search,
              fieldKey: const ValueKey('commands-search'),
              resultCount: _query.trim().isEmpty ? null : matching.length,
              onChanged: (value) => setState(() => _query = value),
            )
          : null,
      body: KitRefresh(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            bottom: KitScreen.endPadding(context),
          ),
          children: _content(context, commands, matching),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    List<CommandInfo>? commands,
    List<CommandInfo> matching,
  ) {
    final l10n = _libraryCopy(context);
    final tokens = KitTokens.of(context);
    Widget railed(Widget child) => Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: tokens.space3,
      ),
      child: child,
    );
    final error = _error;
    if (commands == null) {
      if (error == null) {
        return const [KitSkeletonRows(key: ValueKey('commands-loading'))];
      }
      return [
        railed(
          KitStateView.error(
            key: const ValueKey('commands-load-failed'),
            title: l10n.commandsScreenLoadFailed,
            body: error,
            reportSource: 'commands',
            size: KitStateSize.inline,
            retry: KitAction(label: l10n.commonRetry, onPressed: _load),
          ),
        ),
      ];
    }
    return [
      if (error != null)
        railed(
          KitNotice.error(
            key: const ValueKey('product-refresh-failed'),
            title: l10n.refreshFailed,
            message: error,
            retry: KitAction(label: l10n.refreshRetry, onPressed: _load),
          ),
        ),
      if (commands.isEmpty)
        railed(
          KitStateView(
            key: const ValueKey('commands-empty'),
            size: KitStateSize.inline,
            icon: AppIcons.run,
            title: l10n.e7LibraryNoServerCommandsFound,
            body: l10n.e7LibraryCommandsFromYourProjectAndSkillsAppear,
          ),
        )
      else if (matching.isEmpty)
        railed(
          KitSearchNoMatch(
            key: const ValueKey('commands-no-match'),
            query: _query.trim(),
            what: l10n.commandsScreenWhat,
            onClear: _clearSearch,
          ),
        )
      else
        KitRowGroup(
          children: [
            for (final command in matching) _commandRow(context, command),
          ],
        ),
    ];
  }

  Widget _commandRow(BuildContext context, CommandInfo command) {
    final l10n = _libraryCopy(context);
    final slash = KitBidi.ltr('/${command.name}');
    final description = command.description?.trim();
    final agent = command.agent?.trim();
    final supporting = [
      description?.isNotEmpty == true
          ? description!
          : l10n.e7LibraryNoDescription,
      if (agent?.isNotEmpty == true)
        l10n.commandsScreenRunsWith(KitBidi.auto(agent!)),
    ].join(' · ');
    return KitRow(
      key: ValueKey('command-${command.name}'),
      leading: const KitRowIcon(AppIcons.run),
      // Plain: the app is left to right only (owner 2026-09-27), and the
      // conversation's launcher and tests find a command by '/name'.
      title: '/${command.name}',
      supporting: TextSpan(text: supporting),
      supportingMaxLines: 2,
      onTap: () => _run(command),
      menuLabel: l10n.commandsScreenMenuLabel,
      menu: [
        KitMenuItem(
          label: l10n.commandsScreenRun(slash),
          icon: AppIcons.run,
          onSelected: () => _run(command),
        ),
        KitMenuItem.copy(
          label: l10n.commandsScreenCopy(slash),
          text: () => '/${command.name}',
        ),
      ],
    );
  }

  Future<void> _run(CommandInfo command) async {
    if (_openingCommand) return;
    _openingCommand = true;
    try {
      final sessionID = await showRunCommandDialog(
        context,
        controller: widget.controller,
        command: command,
      );
      if (mounted && sessionID != null) {
        Navigator.of(context).pushNamed('/chat/$sessionID');
      }
    } finally {
      _openingCommand = false;
    }
  }
}
