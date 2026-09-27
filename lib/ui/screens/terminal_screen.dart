import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../api/product_repository.dart';
import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart' show builtinLinuxProvider;
import '../../builtin/local_terminal.dart';
import '../../feedback/bug_report.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../kit/kit.dart';
import '../kit/scenes/states_scenes.dart';
import '../kit/terminal_key_bar.dart';
import '../widgets/product_states.dart' show productErrorText;
import '../widgets/setup_ui_messages.dart';
import 'local_terminal_screen.dart';

/// Serialises terminal keystrokes into one ordered write per flush.
///
/// Every keystroke used to reach the channel as its own send; under fast
/// typing that let sends interleave and the PTY echo arrive out of order or
/// twice. The queue appends to a single FIFO buffer and flushes it as one
/// write on the next microtask, so bytes leave in exactly the order typed.
class TerminalInputQueue {
  TerminalInputQueue(this._send);

  final void Function(String value) _send;
  final _buffer = StringBuffer();
  bool _flushScheduled = false;
  bool _closed = false;

  bool get hasPending => _buffer.isNotEmpty;

  void write(String value) {
    if (_closed || value.isEmpty) return;
    _buffer.write(value);
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(flush);
  }

  /// Sends everything queued so far as one write, in order.
  void flush() {
    _flushScheduled = false;
    if (_closed || _buffer.isEmpty) return;
    final pending = _buffer.toString();
    _buffer.clear();
    _send(pending);
  }

  /// Drops what has not been sent; used when the channel goes away.
  void discard() {
    _buffer.clear();
  }

  void close() {
    _closed = true;
    _buffer.clear();
  }
}

/// Whether a hardware key event carries a printable character the terminal
/// should receive as text; modifier chords and control keys are left to
/// xterm's own key table.
bool terminalKeyEventText(KeyEvent event) {
  if (event is KeyUpEvent) return false;
  final character = event.character;
  if (character == null || character.isEmpty) return false;
  final code = character.codeUnitAt(0);
  if (code < 0x20 || code == 0x7f) return false;
  final keyboard = HardwareKeyboard.instance;
  return !keyboard.isControlPressed && !keyboard.isMetaPressed;
}

AppLocalizations _l10nOf(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The capability a server's terminals need (docs/ux-system/capabilities.json).
const _terminalCapability = 'flag:fileBrowsing+terminal';

/// [TerminalScreen] as its own pushed route. Every entry point that leaves
/// the shell for the terminal — the More hub, the Workspace header, the
/// desktop shortcut — pushes this one page so they all land identically.
///
/// On Android it offers two sources (docs/design/local-terminal-2026-09-24.md
/// §4): "This phone", a shell in the app's built-in Ubuntu that needs no
/// OpenCode server, and "OpenCode server", the server's own terminals. This
/// phone is the default once its Linux is installed; without it the phone
/// choice stays offered and explains how to set Linux up (P7.4).
class TerminalPage extends ConsumerStatefulWidget {
  final ConnectionController controller;

  /// Where to start; null picks this phone when its Linux is installed.
  final TerminalSource? initialSource;

  /// Tests: whether the local terminal exists here (Android only), and the
  /// fakes behind it.
  final bool? localSupported;
  final BuiltinLinux? linux;
  final LocalTerminalSessions? sessions;

  const TerminalPage({
    super.key,
    required this.controller,
    this.initialSource,
    this.localSupported,
    this.linux,
    this.sessions,
  });

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

/// Where a terminal's shell runs.
enum TerminalSource { phone, server }

class _TerminalPageState extends ConsumerState<TerminalPage> {
  TerminalSource? _source;

  bool get _local => widget.localSupported ?? LocalTerminalSessions.supported;

  @override
  void initState() {
    super.initState();
    _source = _local ? widget.initialSource : TerminalSource.server;
    if (_source == null) unawaited(_pickDefault());
  }

  Future<void> _pickDefault() async {
    var installed = false;
    try {
      final BuiltinLinux linux = widget.linux ?? ref.read(builtinLinuxProvider);
      installed = (await linux.status()).installed;
    } catch (_) {}
    if (!mounted || _source != null) return;
    setState(
      () => _source = installed ? TerminalSource.phone : TerminalSource.server,
    );
  }

  void _choose(TerminalSource source) => setState(() => _source = source);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    if (!_local) {
      return KeyedSubtree(
        key: const ValueKey('terminal-page'),
        child: TerminalScreen(controller: widget.controller, page: true),
      );
    }
    final source = _source;
    final choice = source == null
        ? null
        : _SourceChoice(
            source: source,
            serverName: widget.controller.profile?.name,
            onChanged: _choose,
          );
    return KeyedSubtree(
      key: const ValueKey('terminal-page'),
      child: switch (source) {
        TerminalSource.phone => LocalTerminalView(
          header: choice,
          linux: widget.linux,
          sessions: widget.sessions,
        ),
        TerminalSource.server => TerminalScreen(
          controller: widget.controller,
          page: true,
          // The source choice above is the one way to this phone's
          // terminal: no second "Use this phone's terminal" button.
          header: [?choice],
        ),
        null => KitScreen(
          topBar: KitTopBar(title: l10n.libraryTerminalTitle),
          loading: true,
          loadingLabel: l10n.localTerminalStarting,
          body: const SizedBox.shrink(),
        ),
      },
    );
  }
}

/// Where the shell runs: this phone or the connected server, named
/// ("Laptop"); "OpenCode server" only when the server has no name.
class _SourceChoice extends StatelessWidget {
  const _SourceChoice({
    required this.source,
    required this.onChanged,
    this.serverName,
  });

  final TerminalSource source;
  final ValueChanged<TerminalSource> onChanged;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space1,
        tokens.gutter,
        tokens.space2,
      ),
      child: KitSegmented<TerminalSource>(
        key: const ValueKey('terminal-source'),
        semanticsLabel: l10n.terminalScreenSourceLabel,
        segments: [
          KitSegment(
            key: const ValueKey('terminal-source-phone'),
            value: TerminalSource.phone,
            label: l10n.localTerminalSourcePhone,
          ),
          KitSegment(
            key: const ValueKey('terminal-source-server'),
            value: TerminalSource.server,
            label: switch (serverName?.trim()) {
              final name? when name.isNotEmpty => name,
              _ => l10n.localTerminalSourceServer,
            },
          ),
        ],
        selected: source,
        onChanged: onChanged,
      ),
    );
  }
}

/// Asks for a terminal's new name and renames it on the server. A failure
/// stays in the dialog under the field, with the typed name kept. Returns
/// the new name, or null when nothing changed.
Future<String?> _renameTerminal(
  BuildContext context,
  TerminalProcess process,
  Future<ServerOperationsGateway?> Function() repository,
) {
  final l10n = _l10nOf(context);
  return showKitInputDialog(
    context,
    title: l10n.e7SetupRenameTerminal,
    label: l10n.terminalScreenNameLabel,
    confirmLabel: l10n.terminalScreenRenameConfirm,
    initial: process.title,
    validate: (value) =>
        value.trim().isEmpty ? l10n.terminalScreenNameEmpty : null,
    fieldKey: const ValueKey('terminal-rename-field'),
    confirmKey: const ValueKey('terminal-rename-confirm'),
    onSubmit: (value) async {
      try {
        final gateway = await repository();
        if (gateway == null) return l10n.e7SetupServerDisconnected;
        await gateway.renameTerminal(process.id, value.trim());
        return null;
      } catch (error) {
        return setupUiMessage(l10n, productErrorText(error));
      }
    },
  );
}

/// Asks before stopping (a running terminal) or removing (an ended one) and
/// does it inside the question, so a failure keeps it open with Try again.
/// True once the terminal is gone.
Future<bool> _removeTerminal(
  BuildContext context,
  TerminalProcess process,
  Future<ServerOperationsGateway?> Function() repository,
) {
  final l10n = _l10nOf(context);
  final running = process.running;
  return showKitConfirm(
    context,
    title: running
        ? l10n.terminalScreenStopTitle(process.title)
        : l10n.terminalScreenRemoveTitle(process.title),
    body: running ? l10n.terminalScreenStopBody : l10n.terminalScreenRemoveBody,
    confirmLabel: running
        ? l10n.terminalScreenStopConfirm
        : l10n.terminalScreenRemoveConfirm,
    kind: running ? KitConfirmKind.stop : KitConfirmKind.destructive,
    icon: running ? AppIconography.stop : AppIconography.delete,
    confirmKey: const ValueKey('terminal-remove-confirm'),
    action: () async {
      final gateway = await repository();
      if (gateway == null) {
        throw ProductException(l10n.e7SetupServerDisconnected);
      }
      await gateway.removeTerminal(process.id);
    },
  );
}

/// The server's terminals: one list, running first, each row opening its
/// terminal, with rename and stop or remove in the row's menu.
class TerminalScreen extends StatefulWidget {
  final ConnectionController controller;

  /// Draws its own top bar ("Terminal"). Null decides by where it sits: a
  /// page of its own when nothing above it already frames it.
  final bool? page;

  /// Fixed rows under the top bar (the terminal page's source choice).
  final List<Widget> header;

  /// Offered when this server has no terminals: switch to this phone's.
  final VoidCallback? onUsePhone;

  const TerminalScreen({
    super.key,
    required this.controller,
    this.page,
    this.header = const [],
    this.onUsePhone,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

/// A failure about the list that keeps the rows: a refresh or a start that
/// did not work, with the step that tries again.
typedef _ListFailure = ({String title, String message, VoidCallback retry});

class _TerminalScreenState extends State<TerminalScreen> {
  List<TerminalProcess>? _processes;
  String? _error;
  _ListFailure? _failure;
  bool _creating = false;
  bool _removingEnded = false;
  DateTime _loadStartedAt = DateTime.now();
  ServerOperationsGateway? _activeRepository;
  int _locationRevision = -1;
  int _dataRefreshRevision = -1;
  int _ptyRevision = -1;
  int _loadGeneration = 0;

  ServerOperationsGateway? get _repository => widget.controller.repository;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    _captureLocation();
    _load();
  }

  void _captureLocation() {
    _activeRepository = _repository;
    _locationRevision = _revisionOf(_repository);
    _dataRefreshRevision = widget.controller.dataRefreshRevision;
    _ptyRevision = widget.controller.ptyRevision;
  }

  void _controllerChanged() {
    final repository = _repository;
    final revision = _revisionOf(repository);
    final dataRefreshRevision = widget.controller.dataRefreshRevision;
    final ptyRevision = widget.controller.ptyRevision;
    if (identical(repository, _activeRepository) &&
        revision == _locationRevision &&
        dataRefreshRevision == _dataRefreshRevision &&
        ptyRevision == _ptyRevision) {
      return;
    }
    final locationChanged =
        !identical(repository, _activeRepository) ||
        revision != _locationRevision;
    _activeRepository = repository;
    _locationRevision = revision;
    final dataRefreshChanged = dataRefreshRevision != _dataRefreshRevision;
    _dataRefreshRevision = dataRefreshRevision;
    _ptyRevision = ptyRevision;
    _loadGeneration++;
    if (widget.controller.lifecycleSuspended) {
      setState(() {
        _processes ??= const [];
        _error = null;
      });
      return;
    }
    if (widget.controller.connectionLoading && !dataRefreshChanged) {
      return;
    }
    if (locationChanged) {
      setState(() {
        _processes = null;
        _error = null;
        _failure = null;
        _creating = false;
      });
    }
    _load();
  }

  int _revisionOf(ServerOperationsGateway? repository) => Object.hash(
    widget.controller.locationRevision,
    repository is LocationAwareProductRepository
        ? (repository as LocationAwareProductRepository).locationRevision
        : 0,
  );

  bool _isCurrentLocation(ServerOperationsGateway repository, int revision) =>
      mounted &&
      identical(repository, _repository) &&
      revision == _revisionOf(repository);

  /// The repository for an act started at [locationRevision]; null (and the
  /// act fails in words) once the person has moved to another place.
  Future<ServerOperationsGateway?> Function() _actionRepository(
    int locationRevision,
  ) => () async {
    if (locationRevision != widget.controller.locationRevision) return null;
    final repository = await widget.controller.prepareActionRepository();
    if (locationRevision != widget.controller.locationRevision) return null;
    return repository;
  };

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    // A server with no terminals is explained, not asked.
    if (!widget.controller.capabilities.terminal) return;
    if (_processes == null) {
      setState(() {
        _error = null;
        _loadStartedAt = DateTime.now();
      });
    }
    try {
      final repository = await widget.controller.prepareActionRepository();
      if (!mounted || generation != _loadGeneration) return;
      if (repository == null) {
        throw ProductException(_l10nOf(context).e7SetupServerDisconnected);
      }
      final processes = await repository.listTerminals();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _processes = processes;
          _error = null;
          _failure = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        final message = productErrorText(error);
        setState(() {
          _error = message;
          if (_processes != null) {
            _failure = (
              title: _l10nOf(context).refreshFailed,
              message: setupUiMessage(_l10nOf(context), message),
              retry: () => unawaited(_load()),
            );
          }
        });
      }
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _failure = null;
    });
    final l10n = _l10nOf(context);
    final repository = await widget.controller.prepareActionRepository();
    if (!mounted) return;
    if (repository == null) {
      setState(() {
        _creating = false;
        _failure = (
          title: l10n.terminalScreenCreateFailed,
          message: l10n.e7SetupServerDisconnected,
          retry: () => unawaited(_create()),
        );
      });
      return;
    }
    final revision = _revisionOf(repository);
    try {
      final process = await repository.createTerminal(
        title: l10n.e7SetupTerminalNumber((_processes?.length ?? 0) + 1),
      );
      if (!_isCurrentLocation(repository, revision)) return;
      setState(() => _creating = false);
      await _open(process, repository);
    } catch (error) {
      if (_isCurrentLocation(repository, revision)) {
        setState(
          () => _failure = (
            title: l10n.terminalScreenCreateFailed,
            message: setupUiMessage(l10n, productErrorText(error)),
            retry: () => unawaited(_create()),
          ),
        );
      }
    } finally {
      if (_isCurrentLocation(repository, revision) && _creating) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _open(
    TerminalProcess process, [
    ServerOperationsGateway? repository,
  ]) async {
    final gateway = repository ?? _repository;
    if (gateway == null) return;
    await pushKitPage<void>(
      context,
      (_) => TerminalSurface(
        repository: gateway,
        repositoryResolver: () => widget.controller.repository,
        dataRefreshRevisionResolver: () =>
            widget.controller.dataRefreshRevision,
        keepLiveInBackgroundResolver: () =>
            widget.controller.keepLiveInBackground,
        repositoryChanges: widget.controller,
        process: process,
      ),
    );
    // A rename, a stop or a new terminal on the page shows in the list.
    if (mounted) await _load();
  }

  Future<void> _rename(TerminalProcess process) async {
    final renamed = await _renameTerminal(
      context,
      process,
      _actionRepository(widget.controller.locationRevision),
    );
    if (renamed != null && mounted) await _load();
  }

  Future<void> _remove(TerminalProcess process) async {
    final removed = await _removeTerminal(
      context,
      process,
      _actionRepository(widget.controller.locationRevision),
    );
    if (removed && mounted) await _load();
  }

  /// Removes every ended terminal after one question; running ones stay.
  Future<void> _removeEnded(List<TerminalProcess> ended) async {
    if (_removingEnded || ended.isEmpty) return;
    final l10n = _l10nOf(context);
    final repository = _actionRepository(widget.controller.locationRevision);
    setState(() => _removingEnded = true);
    try {
      final removed = await showKitConfirm(
        context,
        title: l10n.terminalScreenRemoveEndedTitle(ended.length),
        body: l10n.terminalScreenRemoveEndedBody,
        confirmLabel: l10n.terminalScreenRemoveEnded(ended.length),
        kind: KitConfirmKind.destructive,
        icon: AppIconography.delete,
        confirmKey: const ValueKey('terminal-remove-ended-confirm'),
        action: () async {
          final gateway = await repository();
          if (gateway == null) {
            throw ProductException(l10n.e7SetupServerDisconnected);
          }
          for (final process in ended) {
            await gateway.removeTerminal(process.id);
          }
        },
      );
      if (removed && mounted) await _load();
    } finally {
      if (mounted) setState(() => _removingEnded = false);
    }
  }

  bool _standalone(BuildContext context) =>
      !KitStatusLineSlot.existsAbove(context) &&
      Scaffold.maybeOf(context) == null;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final processes = _processes;
    final supported = widget.controller.capabilities.terminal;
    final listed = supported && processes != null && processes.isNotEmpty;
    return KitScreen(
      topBar: (widget.page ?? _standalone(context))
          ? KitTopBar(title: l10n.libraryTerminalTitle)
          : null,
      header: widget.header,
      width: KitScreenWidth.list,
      // One new-terminal action per state: the empty state has its own.
      bottom: listed
          ? KitActionBlock(
              primary: KitAction(
                key: const ValueKey('terminal-new'),
                label: l10n.e7SetupNewTerminal,
                icon: AppIconography.add,
                working: _creating,
                onPressed: _create,
              ),
            )
          : null,
      body: supported ? _body(context, l10n) : _unsupported(context, l10n),
    );
  }

  /// This server keeps no terminals: say so, about the terminal only and
  /// naming the server ("Laptop doesn't share a terminal"), instead of an
  /// empty list, and offer this phone's terminal where there is one and no
  /// source choice already offers it.
  Widget _unsupported(BuildContext context, AppLocalizations l10n) {
    final onUsePhone = widget.onUsePhone;
    final name = widget.controller.profile?.name.trim();
    return KitStateView.missing(
      key: const ValueKey('terminal-unavailable'),
      // The registry entry is shared with Files (no terminal-only id yet);
      // the words here are the terminal's own.
      capability: _terminalCapability,
      title: name == null || name.isEmpty
          ? l10n.terminalScreenNoTerminalThisServer
          : l10n.terminalScreenNoTerminalNamed(name),
      why: l10n.terminalScreenNoTerminalWhy,
      size: KitStateSize.page,
      icon: AppIconography.terminal,
      enableKey: const ValueKey('terminal-use-phone'),
      enable: onUsePhone == null
          ? null
          : KitAction(
              label: l10n.terminalScreenUsePhone,
              onPressed: onUsePhone,
            ),
    );
  }

  /// One terminal's row: open on tap; rename and stop or remove from its
  /// menu (long-press or right click).
  Widget _processRow(BuildContext context, TerminalProcess process) {
    final l10n = _l10nOf(context);
    final roles = KitTokens.of(context).roles;
    final running = process.running;
    final code = process.exitCode;
    final state = running
        ? l10n.terminalScreenRowRunning(process.command)
        : code == null
        ? l10n.terminalScreenRowEndedNoCode(process.command)
        : l10n.terminalScreenRowEnded('$code', process.command);
    return KitRow(
      key: ValueKey('terminal-session-${process.id}'),
      leading: KitRow.icon(
        context,
        AppIconography.terminal,
        color: running ? roles.success : null,
      ),
      title: process.title,
      supporting: TextSpan(text: state),
      trailing: const KitChevron(),
      onTap: () => unawaited(_open(process)),
      menuLabel: l10n.terminalScreenMenuLabel(process.title),
      menu: [
        KitMenuItem(
          key: const ValueKey('terminal-menu-open'),
          label: l10n.terminalScreenOpen(process.title),
          icon: AppIconography.terminal,
          onSelected: () => unawaited(_open(process)),
        ),
        KitMenuItem(
          key: const ValueKey('terminal-menu-rename'),
          label: l10n.terminalScreenRename(process.title),
          icon: AppIconography.edit,
          onSelected: () => unawaited(_rename(process)),
        ),
        KitMenuItem(
          key: const ValueKey('terminal-menu-remove'),
          label: running
              ? l10n.terminalScreenStop(process.title)
              : l10n.terminalScreenRemove(process.title),
          icon: running ? AppIconography.stopCircle : AppIconography.delete,
          destructive: true,
          onSelected: () => unawaited(_remove(process)),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final processes = _processes;
    final error = _error;
    if (processes == null && error == null) {
      // A wait that runs past 8 s says so and offers Try again (STATE-5).
      return KitStateView(
        key: const ValueKey('terminal-loading'),
        icon: AppIconography.terminal,
        title: l10n.terminalScreenLoading,
        progress: const KitProgress.waiting(),
        since: _loadStartedAt,
        onSlow: [
          KitAction(
            label: l10n.commonRetry,
            onPressed: () => unawaited(_load()),
          ),
        ],
      );
    }
    if (processes == null) {
      // Every load failure draws the unplugged cable (design standard §10).
      return KitStateView(
        key: const ValueKey('terminal-list-failed'),
        icon: AppIconography.error,
        tone: AppStatusTone.failure,
        illustration: const StatesUnpluggedScene(),
        title: l10n.terminalListFailedTitle,
        body: setupUiMessage(l10n, error!),
        primary: KitAction(
          label: l10n.commonRetry,
          onPressed: () => unawaited(_load()),
        ),
        tertiary: [
          KitAction(
            key: const ValueKey('product-error-report-bug'),
            label: l10n.e7LibraryReportABug,
            onPressed: () => unawaited(openBugReport(context)),
          ),
        ],
      );
    }
    // Running first (they are what the person is using), then the ended
    // ones, each group in the server's order.
    final running = [
      for (final process in processes)
        if (process.running) process,
    ];
    final ended = [
      for (final process in processes)
        if (!process.running) process,
    ];
    final failure = _failure;
    final tokens = KitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A failed refresh or start unfolds over the kept rows and folds
        // away once it works (design standard §10).
        KitReveal(
          child: failure == null
              ? null
              : Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: tokens.gutter,
                    vertical: tokens.space2,
                  ),
                  child: KitNotice(
                    key: const ValueKey('terminal-list-notice'),
                    tone: AppStatusTone.failure,
                    title: failure.title,
                    message: failure.message,
                    actions: [
                      KitAction(
                        label: l10n.refreshRetry,
                        onPressed: failure.retry,
                      ),
                    ],
                  ),
                ),
        ),
        Expanded(
          key: const ValueKey('refresh-content'),
          child: KitRefresh(
            onRefresh: _load,
            child: processes.isEmpty
                ? KitStateView(
                    // The terminal window with its prompt: the same drawing
                    // as This phone's terminal before it is set up.
                    key: const ValueKey('terminal-none'),
                    icon: AppIconography.terminal,
                    illustration: const StatesTerminalScene(),
                    title: l10n.e7SetupNoTerminals,
                    body: l10n.e7SetupNewTerminalDetail,
                    primary: KitAction(
                      key: const ValueKey('terminal-new'),
                      label: l10n.e7SetupNewTerminal,
                      icon: AppIconography.add,
                      working: _creating,
                      onPressed: _create,
                    ),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsetsDirectional.only(
                      top: tokens.space2,
                      bottom: KitScreen.endPadding(context),
                    ),
                    children: [
                      KitRowGroup(
                        key: const ValueKey('terminal-session-rows'),
                        children: [
                          for (final process in [...running, ...ended])
                            _processRow(context, process),
                        ],
                      ),
                      if (ended.isNotEmpty)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: tokens.gutter,
                            top: tokens.space3,
                            end: tokens.gutter,
                          ),
                          child: KitActionBlock(
                            tertiary: [
                              KitAction(
                                key: const ValueKey('terminal-remove-ended'),
                                label: l10n.terminalScreenRemoveEnded(
                                  ended.length,
                                ),
                                icon: AppIconography.clearAll,
                                working: _removingEnded,
                                onPressed: () => unawaited(_removeEnded(ended)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    widget.controller.removeListener(_controllerChanged);
    super.dispose();
  }
}

/// One server terminal, live: the shell with the kit's key bar, one status
/// line only while it is not connected, Copy in the bar and the rest
/// (readable text, paste, reconnect, rename, details, stop) in its menu.
class TerminalSurface extends StatefulWidget {
  final ServerOperationsGateway repository;
  final ServerOperationsGateway? Function()? repositoryResolver;
  final int Function()? dataRefreshRevisionResolver;
  final bool Function()? keepLiveInBackgroundResolver;
  final Listenable? repositoryChanges;
  final TerminalProcess process;

  const TerminalSurface({
    super.key,
    required this.repository,
    this.repositoryResolver,
    this.dataRefreshRevisionResolver,
    this.keepLiveInBackgroundResolver,
    this.repositoryChanges,
    required this.process,
  });

  @override
  State<TerminalSurface> createState() => _TerminalSurfaceState();
}

class _TerminalSurfaceState extends State<TerminalSurface>
    with WidgetsBindingObserver {
  late final xterm.Terminal _terminal;
  final _terminalController = xterm.TerminalController();
  final _scrollController = ScrollController();
  final _focus = FocusNode();
  final _keys = TerminalKeyBarController();
  final _accessibleInput = TextEditingController();
  TerminalChannel? _channel;
  late final TerminalInputQueue _input = TerminalInputQueue(_sendNow);
  StreamSubscription<String>? _subscription;
  String? _error;
  bool _connecting = true;
  DateTime _connectingSince = DateTime.now();

  /// The connection has taken longer than [KitMotion.escalateAfter]: the
  /// loading bar alone would hide a stuck wait (STATE-5), so the line says
  /// so and offers Reconnect.
  bool _slowConnect = false;
  Timer? _slowTimer;
  bool _closed = false;
  int _connectionGeneration = 0;
  Timer? _resizeTimer;
  bool _accessibleMode = false;
  bool _lifecycleSuspended = false;
  String _transcript = '';
  final _transcriptSanitizer = _TerminalTranscriptSanitizer();
  int? _terminalCursor;
  ServerOperationsGateway? _activeRepository;
  int _activeDataRefreshRevision = -1;

  /// The name shown; a rename here changes it at once.
  String? _renamed;

  String get _title => _renamed ?? widget.process.title;

  ServerOperationsGateway? get _repository => widget.repositoryResolver == null
      ? widget.repository
      : widget.repositoryResolver!();

  bool get _canWrite =>
      !_lifecycleSuspended &&
      !_connecting &&
      !_closed &&
      _error == null &&
      _channel != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repositoryChanges?.addListener(_repositoryChanged);
    _activeRepository = _repository;
    _activeDataRefreshRevision =
        widget.dataRefreshRevisionResolver?.call() ?? -1;
    _terminal = xterm.Terminal(
      maxLines: 5000,
      onOutput: _write,
      onResize: _resize,
    );
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _lifecycleSuspended =
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached;
    if (!_lifecycleSuspended) _connect();
  }

  @override
  void didUpdateWidget(covariant TerminalSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repositoryChanges, widget.repositoryChanges)) {
      oldWidget.repositoryChanges?.removeListener(_repositoryChanged);
      widget.repositoryChanges?.addListener(_repositoryChanged);
    }
    if (oldWidget.process.id != widget.process.id) _renamed = null;
    _repositoryChanged(
      forceReconnect: oldWidget.process.id != widget.process.id,
    );
  }

  void _repositoryChanged({bool forceReconnect = false}) {
    final repository = _repository;
    final dataRefreshRevision =
        widget.dataRefreshRevisionResolver?.call() ?? -1;
    final dataRefreshChanged =
        dataRefreshRevision != _activeDataRefreshRevision;
    if (!forceReconnect &&
        !dataRefreshChanged &&
        identical(repository, _activeRepository)) {
      return;
    }
    _activeRepository = repository;
    _activeDataRefreshRevision = dataRefreshRevision;
    if (repository == null) {
      _connectionGeneration++;
      _resizeTimer?.cancel();
      _resizeTimer = null;
      final subscription = _subscription;
      final channel = _channel;
      _rememberCursor(channel);
      _subscription = null;
      _channel = null;
      _input.discard();
      if (mounted && !_lifecycleSuspended) {
        setState(() {
          _connecting = false;
          _closed = true;
          _error = _l10nOf(context).e7SetupTransportReconnecting;
        });
      }
      unawaited(_closeConnection(subscription, channel).catchError((_) {}));
      return;
    }
    if (!_lifecycleSuspended && mounted) unawaited(_connect());
  }

  Future<void> _connect() async {
    if (_lifecycleSuspended) return;
    final generation = ++_connectionGeneration;
    final repository = _repository;
    setState(() {
      _connecting = true;
      _connectingSince = DateTime.now();
      _slowConnect = false;
      _error = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(KitMotion.escalateAfter, () {
      if (mounted && _connecting && generation == _connectionGeneration) {
        setState(() => _slowConnect = true);
      }
    });
    final previousSubscription = _subscription;
    final previousChannel = _channel;
    _rememberCursor(previousChannel);
    _subscription = null;
    _channel = null;
    _input.discard();
    try {
      await _closeConnectionBestEffort(previousSubscription, previousChannel);
      if (!mounted ||
          _lifecycleSuspended ||
          generation != _connectionGeneration) {
        return;
      }
      if (repository == null) {
        throw ProductException(_l10nOf(context).e7SetupTransportReconnecting);
      }
      _activeRepository = repository;
      _transcriptSanitizer.reset();
      final channel = await repository.connectTerminal(
        widget.process.id,
        cursor: _terminalCursor,
      );
      if (!mounted ||
          _lifecycleSuspended ||
          generation != _connectionGeneration) {
        await channel.close();
        return;
      }
      _channel = channel;
      _subscription = channel.output.listen(
        (chunk) {
          if (generation == _connectionGeneration) {
            _terminal.write(chunk);
            _appendTranscript(chunk);
            _rememberCursor(channel);
          }
        },
        onError: (Object error) {
          if (mounted && generation == _connectionGeneration) {
            setState(() {
              _error = productErrorText(error);
              _closed = true;
            });
          }
        },
        onDone: () {
          if (mounted && generation == _connectionGeneration) {
            setState(() => _closed = true);
          }
        },
      );
      setState(() {
        _connecting = false;
        _closed = false;
      });
      _focus.requestFocus();
    } catch (error) {
      if (mounted && generation == _connectionGeneration) {
        setState(() {
          _connecting = false;
          _closed = true;
          _error = productErrorText(error);
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _suspendForLifecycle();
      case AppLifecycleState.resumed:
        _resumeFromLifecycle();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _suspendForLifecycle() {
    if (widget.keepLiveInBackgroundResolver?.call() == true) return;
    if (_lifecycleSuspended) return;
    _lifecycleSuspended = true;
    _connectionGeneration++;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    final subscription = _subscription;
    final channel = _channel;
    _rememberCursor(channel);
    _subscription = null;
    _channel = null;
    _input.discard();
    if (mounted) {
      setState(() {
        _connecting = false;
        _closed = true;
        _error = null;
      });
    }
    unawaited(_closeConnection(subscription, channel).catchError((_) {}));
  }

  void _resumeFromLifecycle() {
    if (!_lifecycleSuspended || !mounted) return;
    _lifecycleSuspended = false;
    unawaited(_connect());
  }

  Future<void> _closeConnection(
    StreamSubscription<String>? subscription,
    TerminalChannel? channel,
  ) async {
    // Retired transports are generation-guarded, so their potentially slow
    // cleanup must never hold up the replacement connection.
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((_) {}));
    }
    if (channel != null) {
      unawaited(channel.close().catchError((_) {}));
    }
  }

  Future<void> _closeConnectionBestEffort(
    StreamSubscription<String>? subscription,
    TerminalChannel? channel,
  ) async {
    try {
      await _closeConnection(
        subscription,
        channel,
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // A retired transport must not prevent its replacement from connecting.
    }
  }

  /// Everything the terminal sends (typing, the key bar, a paste). Text from
  /// the phone's keyboard takes the key bar's latched Ctrl or Alt.
  void _write(String value) {
    if (!_canWrite) return;
    _input.write(_keys.apply(value));
  }

  void _sendNow(String value) {
    if (!_canWrite) return;
    _channel!.write(value);
  }

  /// Desktop keyboards deliver each key once as a hardware event; routing
  /// printable characters from there (instead of the IME text path) keeps
  /// fast typing from being re-delivered as accumulated deltas.
  KeyEventResult _onTerminalKey(FocusNode node, KeyEvent event) {
    if (!terminalKeyEventText(event)) return KeyEventResult.ignored;
    _write(event.character!);
    return KeyEventResult.handled;
  }

  void _rememberCursor(TerminalChannel? channel) {
    final cursor = channel?.cursor;
    if (cursor != null && cursor >= 0) _terminalCursor = cursor;
  }

  void _appendTranscript(String chunk) {
    final plain = _transcriptSanitizer.add(chunk);
    if (plain.isEmpty) return;
    _transcript = '$_transcript$plain';
    if (_transcript.length > 100000) {
      _transcript = _transcript.substring(_transcript.length - 100000);
    }
    if (_accessibleMode && mounted) setState(() {});
  }

  void _sendAccessibleInput() {
    final value = _accessibleInput.text;
    if (value.isEmpty || !_canWrite) return;
    _write('$value\r');
    _accessibleInput.clear();
  }

  void _resize(int cols, int rows, int pixelWidth, int pixelHeight) {
    if (cols <= 0 || rows <= 0) return;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_canWrite) return;
      final repository = _repository;
      if (repository == null) return;
      unawaited(
        repository
            .resizeTerminal(widget.process.id, rows: rows, cols: cols)
            .catchError((_) {}),
      );
    });
  }

  /// The selection, or the whole readable output when nothing is selected.
  String _copyText() {
    final selection = KitTerminalView.selectedText(
      _terminal,
      _terminalController,
    );
    return selection.isNotEmpty ? selection : _transcript;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    _terminal.paste(text);
    _focus.requestFocus();
  }

  Future<void> _rename() async {
    final renamed = await _renameTerminal(
      context,
      widget.process,
      () async => _repository,
    );
    if (renamed != null && mounted) setState(() => _renamed = renamed.trim());
  }

  Future<void> _remove() async {
    final process = widget.process;
    final removed = await _removeTerminal(
      context,
      TerminalProcess(
        id: process.id,
        title: _title,
        command: process.command,
        arguments: process.arguments,
        directory: process.directory,
        running: process.running && !_closed,
        pid: process.pid,
        exitCode: process.exitCode,
      ),
      () async => _repository,
    );
    if (removed && mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _details() {
    final l10n = _l10nOf(context);
    final process = widget.process;
    final command = [process.command, ...process.arguments].join(' ');
    return showKitTechnicalDetails(
      context,
      title: l10n.terminalScreenDetailsTitle(_title),
      text: '',
      values: [
        KitTechnicalValue(l10n.terminalScreenDetailCommand, command),
        if (process.directory.isNotEmpty)
          KitTechnicalValue(l10n.terminalScreenDetailFolder, process.directory),
        KitTechnicalValue(l10n.terminalScreenDetailPid, '${process.pid}'),
        if (process.exitCode != null)
          KitTechnicalValue(
            l10n.terminalScreenDetailExit,
            '${process.exitCode}',
          ),
      ],
    );
  }

  /// The one line, shown only while the terminal is not connected.
  KitStatus? _status(AppLocalizations l10n) {
    final reconnect = KitAction(
      key: const ValueKey('terminal-status-reconnect'),
      label: l10n.e7SetupReconnect,
      onPressed: () => unawaited(_connect()),
    );
    if (_lifecycleSuspended) {
      return KitStatus(
        kind: KitStatusKind.connection,
        id: 'terminal-connection',
        icon: AppIconography.pause,
        message: l10n.terminalScreenPaused,
      );
    }
    if (_connecting) {
      if (!_slowConnect) return null;
      return KitStatus(
        kind: KitStatusKind.connection,
        id: 'terminal-connection',
        icon: AppIconography.sync,
        tone: AppStatusTone.progress,
        message: l10n.terminalScreenConnecting,
        since: _connectingSince,
        onSlow: [reconnect],
      );
    }
    final error = _error;
    if (error != null) {
      return KitStatus(
        kind: KitStatusKind.connection,
        id: 'terminal-connection',
        icon: AppIconography.error,
        tone: AppStatusTone.failure,
        message: setupUiMessage(l10n, error),
        action: reconnect,
      );
    }
    if (_closed) {
      return KitStatus(
        kind: KitStatusKind.connection,
        id: 'terminal-connection',
        icon: AppIconography.cloudOff,
        message: l10n.e7SetupConnectionClosed,
        action: reconnect,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final canWrite = _canWrite;
    final running = widget.process.running && !_closed;
    return KitScreen(
      status: _status(l10n),
      loading: _connecting,
      loadingLabel: l10n.terminalScreenConnecting,
      topBar: KitTopBar(
        title: _title,
        menuKey: const ValueKey('terminal-surface-menu'),
        actions: [
          KitAction.copy(
            key: const ValueKey('terminal-copy'),
            label: l10n.terminalScreenCopy,
            text: _copyText,
          ),
        ],
        menu: [
          KitMenuItem(
            key: const Key('terminal-accessible-mode'),
            label: _accessibleMode
                ? l10n.terminalScreenLiveMode
                : l10n.terminalScreenReadableMode,
            icon: _accessibleMode
                ? AppIconography.terminal
                : AppIconography.article,
            onSelected: () =>
                setState(() => _accessibleMode = !_accessibleMode),
          ),
          KitMenuItem(
            key: const ValueKey('terminal-paste'),
            label: l10n.terminalScreenPaste(_title),
            icon: AppIconography.paste,
            enabled: canWrite,
            disabledReason: l10n.e7SetupInputDisconnected,
            onSelected: () => unawaited(_paste()),
          ),
          KitMenuItem(
            key: const Key('terminal-reconnect'),
            label: l10n.e7SetupReconnect,
            icon: AppIconography.retry,
            enabled: !_connecting && !_lifecycleSuspended,
            disabledReason: l10n.terminalScreenConnecting,
            onSelected: () => unawaited(_connect()),
          ),
          KitMenuItem(
            key: const ValueKey('terminal-rename'),
            label: l10n.terminalScreenRename(_title),
            icon: AppIconography.edit,
            onSelected: () => unawaited(_rename()),
          ),
          KitMenuItem(
            key: const ValueKey('terminal-details'),
            label: l10n.terminalScreenDetails,
            icon: AppIconography.info,
            onSelected: () => unawaited(_details()),
          ),
          KitMenuItem(
            key: const ValueKey('terminal-remove'),
            label: running
                ? l10n.terminalScreenStop(_title)
                : l10n.terminalScreenRemove(_title),
            icon: running ? AppIconography.stopCircle : AppIconography.delete,
            destructive: true,
            onSelected: () => unawaited(_remove()),
          ),
        ],
      ),
      body: _accessibleMode
          ? _AccessibleTerminal(
              transcript: _transcript,
              input: _accessibleInput,
              enabled: canWrite,
              onSend: _sendAccessibleInput,
            )
          : KitTerminalView.live(
              terminal: _terminal,
              semanticsLabel: l10n.e7SetupTerminalSemantics,
              controller: _terminalController,
              scrollController: _scrollController,
              focusNode: _focus,
              readOnly: !canWrite,
              keys: _keys,
              interruptKeys: true,
              // Desktop: hardware keys only, so a keystroke is never
              // delivered twice (key event + IME delta).
              onKeyEvent: desktopInteractions ? _onTerminalKey : null,
              keysKey: const ValueKey('terminal-keys'),
            ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.repositoryChanges?.removeListener(_repositoryChanged);
    _connectionGeneration++;
    _resizeTimer?.cancel();
    _slowTimer?.cancel();
    unawaited(_subscription?.cancel().catchError((_) {}));
    unawaited(_channel?.close().catchError((_) {}));
    _terminalController.dispose();
    _scrollController.dispose();
    _input.close();
    _focus.dispose();
    _keys.dispose();
    _accessibleInput.dispose();
    super.dispose();
  }
}

/// The terminal for a screen reader: the readable output (control codes
/// stripped) and one labelled command field that sends a line.
class _AccessibleTerminal extends StatelessWidget {
  final String transcript;
  final TextEditingController input;
  final bool enabled;
  final VoidCallback onSend;

  const _AccessibleTerminal({
    required this.transcript,
    required this.input,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = _l10nOf(context);
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space2,
        tokens.gutter,
        tokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Semantics(
              label: l10n.e7SetupTranscript,
              textField: true,
              readOnly: true,
              child: KitSurface(
                level: KitSurfaceLevel.surface1,
                child: ListView(
                  reverse: true,
                  children: [
                    if (transcript.isEmpty)
                      KitText(l10n.e7SetupNoOutput, tone: KitTextTone.secondary)
                    else
                      KitText.mono(transcript, selectable: true),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.space2),
          KitField(
            label: l10n.e7SetupCommandInput,
            hint: l10n.e7SetupCommandHint,
            kind: KitFieldKind.mono,
            controller: input,
            enabled: enabled,
            disabledReason: enabled ? null : l10n.e7SetupInputDisconnected,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            fieldKey: const Key('terminal-accessible-input'),
            action: KitAction(
              key: const ValueKey('terminal-accessible-send'),
              label: enabled
                  ? l10n.e7SetupSendCommand
                  : l10n.e7SetupInputUnavailable,
              icon: AppIconography.returnKey,
              onPressed: enabled ? onSend : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Converts a stream of terminal bytes decoded as text into a readable,
/// append-only transcript. Terminal rendering commands are intentionally not
/// exposed to assistive technology.
class _TerminalTranscriptSanitizer {
  static const _normal = 0;
  static const _escape = 1;
  static const _escapeIntermediate = 2;
  static const _csi = 3;
  static const _osc = 4;
  static const _oscEscape = 5;
  static const _controlString = 6;
  static const _controlStringEscape = 7;

  int _state = _normal;
  bool _pendingCarriageReturn = false;

  void reset() {
    _state = _normal;
    _pendingCarriageReturn = false;
  }

  String add(String chunk) {
    // Keep a defensive guard for older/custom transports that expose OpenCode's
    // NUL-prefixed metadata as text instead of consuming it at the channel.
    if (chunk.isEmpty || (_state == _normal && chunk.startsWith('\x00'))) {
      return '';
    }
    final output = StringBuffer();

    for (final rune in chunk.runes) {
      if (_state == _normal && _pendingCarriageReturn) {
        if (rune == 0x0a) {
          output.write('\n');
          _pendingCarriageReturn = false;
          continue;
        }
        output.write('\n');
        _pendingCarriageReturn = false;
      }

      switch (_state) {
        case _normal:
          if (rune == 0x1b) {
            _state = _escape;
          } else if (rune == 0x9b) {
            _state = _csi;
          } else if (rune == 0x9d) {
            _state = _osc;
          } else if (rune == 0x90 ||
              rune == 0x98 ||
              rune == 0x9e ||
              rune == 0x9f) {
            _state = _controlString;
          } else if (rune == 0x0d) {
            _pendingCarriageReturn = true;
          } else if (rune == 0x0a || rune == 0x09) {
            output.writeCharCode(rune);
          } else if ((rune >= 0x20 && rune != 0x7f) &&
              !(rune >= 0x80 && rune <= 0x9f)) {
            output.writeCharCode(rune);
          }
        case _escape:
          if (rune == 0x5b) {
            _state = _csi;
          } else if (rune == 0x5d) {
            _state = _osc;
          } else if (rune == 0x50 ||
              rune == 0x58 ||
              rune == 0x5e ||
              rune == 0x5f) {
            _state = _controlString;
          } else if (rune >= 0x20 && rune <= 0x2f) {
            _state = _escapeIntermediate;
          } else if (rune != 0x1b) {
            _state = _normal;
          }
        case _escapeIntermediate:
          if (rune == 0x1b) {
            _state = _escape;
          } else if (rune >= 0x30 && rune <= 0x7e) {
            _state = _normal;
          } else if (rune < 0x20 || rune > 0x2f) {
            _state = _normal;
          }
        case _csi:
          if (rune == 0x1b) {
            _state = _escape;
          } else if (rune >= 0x40 && rune <= 0x7e) {
            _state = _normal;
          }
        case _osc:
          if (rune == 0x07 || rune == 0x9c) {
            _state = _normal;
          } else if (rune == 0x1b) {
            _state = _oscEscape;
          }
        case _oscEscape:
          if (rune == 0x5c) {
            _state = _normal;
          } else if (rune != 0x1b) {
            _state = _osc;
          }
        case _controlString:
          if (rune == 0x9c) {
            _state = _normal;
          } else if (rune == 0x1b) {
            _state = _controlStringEscape;
          }
        case _controlStringEscape:
          if (rune == 0x5c) {
            _state = _normal;
          } else if (rune != 0x1b) {
            _state = _controlString;
          }
      }
    }
    return output.toString();
  }
}
