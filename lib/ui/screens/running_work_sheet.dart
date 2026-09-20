import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/models.dart';
import '../../domain/server_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/shell_output.dart';
import '../widgets/product_states.dart';
import '../widgets/running_agents_strip.dart';
import '../app_theme.dart';

AppLocalizations _strings(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

// A transport can be replaced while reconnecting to the same location. Pin
// actual scope, not its refresh counter, so that reconnection stays usable.
typedef _WorkScope = (String?, String?, String?, String?);

_WorkScope _scope(ConnectionController conn) =>
    (conn.profile?.id, conn.profile?.baseUrl, conn.directory, conn.workspace);

String _status(AppLocalizations l10n, ManagedShell shell) =>
    switch (shell.status) {
      ManagedShellStatus.running => l10n.workRunning,
      ManagedShellStatus.exited =>
        shell.exitCode == null
            ? l10n.workFinished
            : l10n.workExitCode(shell.exitCode!),
      ManagedShellStatus.timeout => l10n.workTimedOut,
      ManagedShellStatus.killed => l10n.workStopped,
      ManagedShellStatus.unknown => l10n.workUnknown,
    };

/// How a command ended, as the reader cares about it. A shell reports only a
/// status and an exit code; 143 and 130 are "someone stopped it" (SIGTERM,
/// Ctrl-C), not a failure of the command.
enum _Outcome { running, done, failed, stopped, unknown }

_Outcome _outcome(ManagedShell shell) => switch (shell.status) {
  ManagedShellStatus.running => _Outcome.running,
  ManagedShellStatus.killed => _Outcome.stopped,
  ManagedShellStatus.timeout => _Outcome.failed,
  ManagedShellStatus.unknown => _Outcome.unknown,
  ManagedShellStatus.exited => switch (shell.exitCode) {
    null || 0 => _Outcome.done,
    143 || 130 || 137 => _Outcome.stopped,
    _ => _Outcome.failed,
  },
};

String _outcomeLabel(AppLocalizations l10n, ManagedShell shell) =>
    switch (_outcome(shell)) {
      _Outcome.stopped => l10n.workStopped,
      _Outcome.done => l10n.workFinished,
      _ => _status(l10n, shell),
    };

/// A command as a person would say it: the programs it runs, not where they
/// live or what environment they were given. `FOO=1 /tmp/x/bin/flutter test
/// && ./build.sh` reads "flutter test && build.sh". The full text is on the
/// command's own screen.
@visibleForTesting
String shortCommand(String command) {
  final parts = command.trim().split(RegExp(r'\s+(&&|\|\||;|\|)\s+'));
  final joins = RegExp(
    r'\s+(&&|\|\||;|\|)\s+',
  ).allMatches(command.trim()).map((m) => m[1]!).toList();
  final out = StringBuffer();
  for (var i = 0; i < parts.length; i++) {
    final words = parts[i].split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    while (words.length > 1 &&
        RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(words.first)) {
      words.removeAt(0);
    }
    if (words.isNotEmpty && words.first.contains('/')) {
      final name = words.first.split('/').last;
      if (name.isNotEmpty) words[0] = name;
    }
    if (i > 0) out.write(' ${joins[i - 1]} ');
    out.write(words.join(' '));
  }
  final result = out.toString().trim();
  return result.isEmpty ? command : result;
}

String _elapsed(ManagedShell shell) {
  final seconds = (shell.completedAt ?? DateTime.now())
      .difference(shell.startedAt)
      .inSeconds
      .clamp(0, 365 * 86400);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

Future<String?> showRunningWorkSheet(
  BuildContext context, {
  required ConnectionController controller,
  required String sessionID,
  required Set<String> shellIDs,
  Future<BackgroundWorkResult?> Function()? onBackground,
  BackgroundWorkSupport backgroundSupport = BackgroundWorkSupport.unavailable,
  BackgroundWorkSupport Function()? readBackgroundSupport,
  bool Function()? canBackground,
  Listenable? availabilityChanges,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => RunningWorkSheet(
    controller: controller,
    sessionID: sessionID,
    shellIDs: shellIDs,
    onBackground: onBackground,
    backgroundSupport: backgroundSupport,
    readBackgroundSupport: readBackgroundSupport,
    canBackground: canBackground,
    availabilityChanges: availabilityChanges,
  ),
);

class RunningWorkSheet extends StatefulWidget {
  const RunningWorkSheet({
    super.key,
    required this.controller,
    required this.sessionID,
    this.shellIDs = const {},
    this.onBackground,
    this.backgroundSupport = BackgroundWorkSupport.unavailable,
    this.readBackgroundSupport,
    this.canBackground,
    this.availabilityChanges,
  });
  final ConnectionController controller;
  final String sessionID;
  final Set<String> shellIDs;
  final Future<BackgroundWorkResult?> Function()? onBackground;
  final BackgroundWorkSupport backgroundSupport;
  final BackgroundWorkSupport Function()? readBackgroundSupport;
  final bool Function()? canBackground;
  final Listenable? availabilityChanges;
  @override
  State<RunningWorkSheet> createState() => _RunningWorkSheetState();
}

class _RunningWorkSheetState extends State<RunningWorkSheet>
    with WidgetsBindingObserver {
  late final _WorkScope _pinnedScope;
  bool _active = true;
  bool _loading = true;
  bool _refreshing = false;
  bool? _shellSupport;
  Object? _error;
  List<ManagedShell> _shells = [];
  final Map<String, Session> _related = {};
  Object? _agentsError;
  bool _promoting = false;
  BackgroundWorkResult? _promotion;
  Timer? _timer;
  StreamSubscription<EventEnvelope>? _events;
  late int _revision;
  bool get _scopeMatches => _pinnedScope == _scope(widget.controller);
  bool get _visible =>
      mounted && _active && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    _pinnedScope = _scope(widget.controller);
    _revision = widget.controller.dataRefreshRevision;
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
    widget.availabilityChanges?.addListener(_changed);
    _events = widget.controller.events.listen((event) {
      if ((event.type.startsWith('shell.') ||
              event.type == 'session.created' ||
              event.type == 'session.updated' ||
              event.type == 'session.deleted') &&
          _visible) {
        unawaited(_refresh());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_visible && _shellSupport != false) unawaited(_refresh());
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final next = widget.controller.dataRefreshRevision;
    if (next != _revision) {
      _revision = next;
      _shellSupport = null;
      if (_visible) unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && _visible) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing || !_scopeMatches || !_active) return;
    final conn = widget.controller;
    final repo = conn.repository;
    if (repo == null || conn.status != StreamStatus.connected) {
      setState(() => _loading = false);
      return;
    }
    _refreshing = true;
    try {
      // Session lists may omit child sessions. Resolve the family through the
      // existing children endpoint without mutating the global session cache.
      if (conn.capabilities.projectManagement) {
        try {
          final current =
              conn.sessionsById[widget.sessionID] ??
              await repo.getSessionDetails(widget.sessionID);
          final children = <Session>[];
          // Fetch the current session's own children as well as siblings when
          // viewing a child; both may be absent from the global latest page.
          for (final owner in {current.id, ?current.parentID}) {
            children.addAll(await repo.listSessionChildren(owner));
            if (!mounted || !_scopeMatches || repo != conn.repository) return;
          }
          if (!mounted || !_scopeMatches || repo != conn.repository) return;
          _related
            ..clear()
            ..addAll({
              current.id: current,
              for (final child in children) child.id: child,
            });
          _agentsError = null;
        } catch (error) {
          if (!mounted || !_scopeMatches || repo != conn.repository) return;
          _agentsError = error;
        }
      }
      final result = await repo.loadRunningShells();
      final knownIDs = {
        ...widget.shellIDs,
        for (final shell in _shells) shell.id,
      };
      final retained = <ManagedShell>[];
      if (result.supported) {
        for (final id in knownIDs.difference(
          result.shells.map((shell) => shell.id).toSet(),
        )) {
          final shell = await repo.getManagedShell(id);
          if (shell != null) retained.add(shell);
        }
      }
      if (!mounted || !_scopeMatches || repo != conn.repository) return;
      final related = {
        widget.sessionID,
        for (final session in {...conn.sessionsById, ..._related}.values)
          if (session.parentID == widget.sessionID) session.id,
      };
      setState(() {
        _shellSupport = result.supported;
        _shells = result.supported
            ? [...result.shells, ...retained]
                  .where(
                    (shell) =>
                        related.contains(shell.sessionID) ||
                        widget.shellIDs.contains(shell.id),
                  )
                  .toList()
            : [];
        _error = null;
      });
    } catch (error) {
      if (mounted && _scopeMatches && repo == conn.repository) {
        setState(() => _error = error);
      }
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_events?.cancel());
    widget.controller.removeListener(_changed);
    widget.availabilityChanges?.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<Widget> _section(BuildContext context, String title, List<Widget> rows) {
    if (rows.isEmpty) return const [];
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Row(
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              '${rows.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      ...rows,
    ];
  }

  Widget _agentRow(RunningAgentEntry entry, bool busy, {bool unknown = false}) {
    final l10n = _strings(context);
    return _WorkRow(
      key: ValueKey('work-agent-${entry.session.id}'),
      icon: AppIconography.branch,
      title: entry.label,
      status: unknown
          ? l10n.workUnknown
          : busy
          ? l10n.workRunning
          : l10n.workIdle,
      outcome: unknown
          ? _Outcome.unknown
          : busy
          ? _Outcome.running
          : _Outcome.stopped,
      mono: false,
      onTap: () => Navigator.pop(context, entry.session.id),
    );
  }

  Widget _shellRow(ManagedShell shell, bool disconnected) {
    final l10n = _strings(context);
    final conn = widget.controller;
    return _WorkRow(
      key: ValueKey('work-shell-${shell.id}'),
      icon: AppIconography.terminal,
      title: shortCommand(shell.command),
      status: l10n.workStatusElapsed(
        _outcomeLabel(l10n, shell),
        _elapsed(shell),
      ),
      outcome: _outcome(shell),
      mono: true,
      onTap: disconnected
          ? null
          : () async {
              if (!_scopeMatches || conn.status != StreamStatus.connected) {
                return;
              }
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ShellOutputScreen(controller: conn, shell: shell),
                ),
              );
              if (mounted && _visible) await _refresh();
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _strings(context);
    final theme = Theme.of(context);
    final conn = widget.controller;
    final agents = runningAgentEntries(
      sessionID: widget.sessionID,
      sessions: {...conn.sessionsById, ..._related},
      busy: conn.busySessions,
      includeIdle: true,
    ).where((entry) => !entry.current).toList();
    final disconnected = conn.status != StreamStatus.connected;
    final canBackground =
        widget.canBackground?.call() ??
        (widget.onBackground != null && _promotion == null);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          key: const Key('running-work-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.workTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.workRefresh,
                  onPressed: disconnected || !_scopeMatches ? null : _refresh,
                  icon: const Icon(AppIconography.retry),
                ),
                IconButton(
                  tooltip: l10n.workClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(AppIconography.close),
                ),
              ],
            ),
            // No preamble: the title and the list say what this is. The one
            // action appears when it can be taken.
            if (widget.onBackground != null &&
                (canBackground || _promoting || _promotion != null))
              FilledButton.icon(
                onPressed:
                    disconnected ||
                        !_scopeMatches ||
                        _promoting ||
                        !canBackground
                    ? null
                    : () async {
                        setState(() => _promoting = true);
                        try {
                          final result = await widget.onBackground!();
                          if (mounted && _scopeMatches) {
                            setState(() => _promotion = result);
                          }
                          if (mounted && _scopeMatches) await _refresh();
                        } finally {
                          if (mounted) setState(() => _promoting = false);
                        }
                      },
                icon: const Icon(AppIconography.lowPriority),
                label: Text(
                  _promoting
                      ? l10n.workBackgroundPending
                      : l10n.workRunInBackground,
                ),
              ),
            if (_promotion != null) ...[
              const SizedBox(height: 8),
              Text(switch (_promotion!) {
                BackgroundWorkResult.promoted => l10n.backgroundWorkPromoted,
                BackgroundWorkResult.unchanged => l10n.backgroundWorkNoop,
                BackgroundWorkResult.requested => l10n.workBackgroundRequested,
              }),
            ],
            const SizedBox(height: 8),
            if (!_scopeMatches)
              Text(l10n.workContextChanged)
            else ...[
              if (disconnected) _Notice(text: l10n.workDisconnected),
              if (_agentsError != null)
                _Notice(text: productErrorText(_agentsError!)),
              if (_error != null)
                _Notice(
                  text: productErrorText(_error!),
                  action: TextButton(
                    onPressed: _refresh,
                    child: Text(l10n.workRetry),
                  ),
                ),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (agents.isEmpty &&
                  _shells.isEmpty &&
                  _error == null &&
                  _agentsError == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(AppIconography.checkCircle, size: 32),
                      const SizedBox(height: 12),
                      Text(l10n.workEmpty, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        l10n.workEmptyDescription,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              // What is going on now, then what is over. Within each, agents
              // before commands. State is carried by icon and colour, so a
              // glance tells running from done from failed.
              ..._section(context, l10n.workRunning, [
                for (final entry in agents)
                  if (entry.busy && !disconnected) _agentRow(entry, true),
                for (final shell in _shells)
                  if (_outcome(shell) == _Outcome.running)
                    _shellRow(shell, disconnected),
              ]),
              ..._section(context, l10n.workFinished, [
                for (final entry in agents)
                  if (!entry.busy || disconnected)
                    _agentRow(entry, false, unknown: disconnected),
                for (final shell in _shells)
                  if (_outcome(shell) != _Outcome.running)
                    _shellRow(shell, disconnected),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line of the Tasks list. The leading icon says what it is (agent or
/// command), its colour and the trailing mark say how it stands.
class _WorkRow extends StatelessWidget {
  const _WorkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.outcome,
    required this.mono,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final _Outcome outcome;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = outcome == _Outcome.running;
    final tone = switch (outcome) {
      _Outcome.running => scheme.primary,
      _Outcome.failed => scheme.error,
      _Outcome.done => AppTheme.successOf(theme),
      _Outcome.stopped || _Outcome.unknown => scheme.onSurfaceVariant,
    };
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: tone),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      // Live work gets room to be recognised; finished work
                      // is a line.
                      maxLines: live ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: mono ? AppTheme.monoFamily : null,
                        fontSize: mono ? 13 : null,
                        color: live
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: outcome == _Outcome.failed
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // A steady dot, not a spinner: a list of spinners is noise, and
              // the elapsed time already shows that it is alive.
              if (live)
                Container(
                  key: const Key('work-row-live'),
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(
                  switch (outcome) {
                    _Outcome.running => AppIconography.waitingStart,
                    _Outcome.done => AppIconography.checkCircle,
                    _Outcome.failed => AppIconography.error,
                    _Outcome.stopped => AppIconography.blocked,
                    _Outcome.unknown => AppIconography.chevronRight,
                  },
                  size: 16,
                  color: tone,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShellOutputScreen extends StatefulWidget {
  const ShellOutputScreen({
    super.key,
    required this.controller,
    required this.shell,
  });
  final ConnectionController controller;
  final ManagedShell shell;
  @override
  State<ShellOutputScreen> createState() => _ShellOutputScreenState();
}

class _ShellOutputScreenState extends State<ShellOutputScreen>
    with WidgetsBindingObserver {
  late final ShellOutputController _output = ShellOutputController(
    gateway: widget.controller.repository!,
    shell: widget.shell,
  );
  late final _WorkScope _pinnedScope;
  late int _revision;
  final _scroll = ScrollController();
  StreamSubscription<EventEnvelope>? _events;
  Timer? _timer;
  bool _active = true;
  bool _follow = true;
  bool _mutating = false;
  bool _stopped = false;
  bool _reconcilePending = true;
  bool get _sameScope => _pinnedScope == _scope(widget.controller);
  bool get _visible =>
      mounted && _active && (ModalRoute.of(context)?.isCurrent ?? true);
  bool get _connected => widget.controller.status == StreamStatus.connected;
  bool get _canMutate =>
      _sameScope &&
      widget.controller.repository != null &&
      _connected &&
      !_mutating &&
      !_stopped &&
      _output.available &&
      _output.shell.running;

  @override
  void initState() {
    super.initState();
    _pinnedScope = _scope(widget.controller);
    _revision = widget.controller.dataRefreshRevision;
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_connectionChanged);
    _output.addListener(_outputChanged);
    _events = widget.controller.events.listen((event) {
      final info = event.properties['info'];
      final id = event.properties['id'] ?? (info is Map ? info['id'] : null);
      if (event.type.startsWith('shell.') &&
          id == widget.shell.id &&
          _visible) {
        unawaited(_refresh());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refresh(reconcile: true),
    );
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_follow &&
          _visible &&
          _output.available &&
          (_output.shell.running || _output.hasMore)) {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _refresh({bool reconcile = false}) async {
    if (reconcile) _reconcilePending = true;
    if (!_sameScope || !_connected || !_visible || _stopped) return;
    final repo = widget.controller.repository;
    if (repo == null) return;
    final changed = repo != _output.gateway;
    _output.bind(repo);
    if (_output.refreshing) return;
    final needsIdentity = _reconcilePending || changed;
    _reconcilePending = false;
    await _output.refresh(reconcileServer: needsIdentity);
    if (mounted && needsIdentity && _output.error != null) {
      _reconcilePending = true;
    }
  }

  void _connectionChanged() {
    if (!mounted) return;
    setState(() {});
    final revision = widget.controller.dataRefreshRevision;
    if (_revision != revision ||
        widget.controller.repository != _output.gateway) {
      _revision = revision;
      unawaited(_refresh(reconcile: true));
    }
  }

  void _outputChanged() {
    if (!mounted) return;
    setState(() {});
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) unawaited(_refresh(reconcile: true));
  }

  Future<void> _stop() async {
    if (!_canMutate) return;
    final l10n = _strings(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.workStopTitle),
        content: Text(l10n.workStopDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.workCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.workStop),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !_canMutate) return;
    await _change(() async {
      await widget.controller.repository!.stopManagedShell(widget.shell.id);
      if (mounted && _sameScope) setState(() => _stopped = true);
    });
  }

  Future<void> _timeout() async {
    if (!_canMutate) return;
    final l10n = _strings(context);
    final seconds = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                l10n.workTimeoutTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(l10n.workTimeoutDescription),
              for (final option in <int, String>{
                60: l10n.workTimeoutOneMinute,
                300: l10n.workTimeoutFiveMinutes,
                900: l10n.workTimeoutFifteenMinutes,
                3600: l10n.workTimeoutOneHour,
                0: l10n.workTimeoutNone,
              }.entries)
                ListTile(
                  title: Text(option.value),
                  onTap: () => Navigator.pop(context, option.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || seconds == null || !_canMutate) return;
    await _change(() async {
      await widget.controller.repository!.setManagedShellTimeout(
        widget.shell.id,
        seconds == 0 ? null : Duration(seconds: seconds),
      );
      if (mounted && _sameScope) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.workTimeoutSaved)));
      }
    });
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _mutating = true);
    try {
      await action();
      if (mounted && _sameScope) await _refresh();
    } catch (error) {
      if (mounted && _sameScope) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(productErrorText(error))));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_events?.cancel());
    widget.controller.removeListener(_connectionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _output.removeListener(_outputChanged);
    _output.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _strings(context);
    final theme = Theme.of(context);
    final output = _output.displayText;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workOutput),
        actions: [
          IconButton(
            tooltip: l10n.workCopyOutput,
            onPressed: output.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: output));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l10n.workCopied)));
                    }
                  },
            icon: const Icon(AppIconography.copy),
          ),
          IconButton(
            tooltip: l10n.workRefresh,
            onPressed: _sameScope && _connected && !_stopped
                ? () => _refresh(reconcile: true)
                : null,
            icon: const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (event) {
            if (_follow &&
                event.dragDetails != null &&
                event.metrics.pixels < event.metrics.maxScrollExtent - 24) {
              setState(() => _follow = false);
            }
            return false;
          },
          child: ListView(
            key: const Key('shell-output-content'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SelectableText(
                widget.shell.command,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _stopped
                    ? l10n.workStopped
                    : !_sameScope || !_connected || !_output.available
                    ? l10n.workUnknown
                    : l10n.workStatusElapsed(
                        _status(l10n, _output.shell),
                        _elapsed(_output.shell),
                      ),
              ),
              const SizedBox(height: 8),
              if (_output.available && _output.shell.running && !_stopped)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _canMutate ? _timeout : null,
                      icon: const Icon(AppIconography.timer),
                      label: Text(l10n.workTimeout),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: _canMutate ? _stop : null,
                      icon: const Icon(AppIconography.stopCircle),
                      label: Text(l10n.workStop),
                    ),
                  ],
                ),
              if (!_stopped &&
                  _output.available &&
                  (_output.shell.running || _output.hasMore))
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.workFollow),
                  value: _follow,
                  onChanged: _sameScope && _connected
                      ? (value) {
                          setState(() => _follow = value);
                          if (value) unawaited(_refresh());
                        }
                      : null,
                ),
              if (!_sameScope)
                _Notice(text: l10n.workContextChanged)
              else if (!_connected)
                _Notice(text: l10n.workDisconnected)
              else if (!_stopped && !_output.available)
                _Notice(
                  text: _output.serverRestarted
                      ? l10n.workRestarted
                      : l10n.workUnavailable,
                ),
              if (_output.error != null)
                _Notice(
                  text: productErrorText(_output.error!),
                  action: TextButton(
                    onPressed: () => _refresh(reconcile: true),
                    child: Text(l10n.workRetry),
                  ),
                ),
              if (_output.trimmed) _Notice(text: l10n.workTrimmed),
              if (_output.refreshing || _mutating)
                const LinearProgressIndicator(minHeight: 2),
              Container(
                key: const Key('shell-output-text'),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  output.isEmpty
                      ? (_output.shell.running && !_stopped && _output.available
                            ? l10n.workNoOutput
                            : l10n.workNoFinalOutput)
                      : output,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              if (_output.hasMore && !_stopped && _sameScope && _connected)
                TextButton(
                  onPressed: _output.refreshing ? null : _refresh,
                  child: Text(l10n.workMoreOutput),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(text), ?action],
    ),
  );
}
