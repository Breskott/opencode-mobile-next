import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../builtin/builtin_linux.dart';
import '../../builtin/builtin_server.dart' show builtinLinuxProvider;
import '../../builtin/local_terminal.dart';
import '../../builtin/team/builtin_team.dart' show BuiltinTeam;
import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../kit/scenes/states_scenes.dart';
import '../kit/terminal_key_bar.dart';
import '../widgets/confirm_sheet.dart';
import 'phone_setup/phone_setup_routes.dart';

/// Test seam for leaving to phone setup.
@visibleForTesting
Future<void> Function(BuildContext context)? localTerminalOpenSetupOverride;

/// A shell in this phone's built-in Ubuntu, straight from the app: no
/// OpenCode server is involved, so it works while the server is stopped or
/// not answering (docs/design/local-terminal-2026-09-24.md).
///
/// The whole screen: the top bar (with [header] under it, the source choice
/// of the terminal page), the terminal, and the key bar. Shells outlive the
/// screen ([localTerminalProvider]); the top bar's menu lists them.
class LocalTerminalView extends ConsumerStatefulWidget {
  const LocalTerminalView({super.key, this.header, this.sessions, this.linux});

  /// Shown directly under the top bar, above the one loading bar.
  final Widget? header;

  /// Tests pass fakes; the app uses its providers.
  final LocalTerminalSessions? sessions;
  final BuiltinLinux? linux;

  @override
  ConsumerState<LocalTerminalView> createState() => _LocalTerminalViewState();
}

enum _MenuAction { newShell, paste, stop, close }

class _LocalTerminalViewState extends ConsumerState<LocalTerminalView> {
  late final LocalTerminalSessions _sessions =
      widget.sessions ?? ref.read(localTerminalProvider);
  late final BuiltinLinux _linux =
      widget.linux ?? ref.read(builtinLinuxProvider);
  final _keys = TerminalKeyBarController();
  final _selection = xterm.TerminalController();
  final _focus = FocusNode();
  BuiltinLinuxStatus? _status;
  String? _statusFailure;
  LocalShell? _shell;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _sessions.addListener(_sessionsChanged);
    _selection.addListener(_selectionChanged);
    unawaited(_open());
  }

  @override
  void dispose() {
    _sessions.removeListener(_sessionsChanged);
    _selection.removeListener(_selectionChanged);
    _shell?.inputFilter = null;
    _selection.dispose();
    _keys.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _status = null;
      _statusFailure = null;
    });
    BuiltinLinuxStatus status;
    try {
      status = await _linux.status();
    } catch (error) {
      if (mounted) setState(() => _statusFailure = '$error');
      return;
    }
    if (!mounted) return;
    setState(() => _status = status);
    if (!status.installed) return;
    await _sessions.load();
    if (!mounted) return;
    final shells = _sessions.shells;
    final remembered = _sessions.current;
    _show(
      remembered != null && shells.contains(remembered)
          ? remembered
          : shells.isNotEmpty
          ? shells.last
          : _sessions.startShell(),
    );
    if (status.serviceRunning(BuiltinTeam.serviceName)) {
      unawaited(_sessions.refreshProcesses());
    }
  }

  void _show(LocalShell shell) {
    if (!identical(_shell, shell)) _shell?.inputFilter = null;
    shell.inputFilter = _keys.apply;
    _sessions.current = shell;
    _selection.clearSelection();
    setState(() => _shell = shell);
  }

  void _sessionsChanged() {
    if (!mounted) return;
    final shell = _shell;
    if (shell != null && !_sessions.shells.contains(shell)) {
      final shells = _sessions.shells;
      if (shells.isNotEmpty) {
        _show(shells.last);
        return;
      }
      _shell = null;
    }
    setState(() {});
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  void _newShell() => _show(_sessions.startShell());

  void _restart(LocalShell shell) => _show(_sessions.restart(shell));

  Future<void> _paste(LocalShell shell) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    shell.terminal.paste(text);
    _focus.requestFocus();
  }

  Future<void> _copy(LocalShell shell) async {
    final range = _selection.selection;
    if (range == null) return;
    final text = shell.terminal.buffer.getText(range);
    _selection.clearSelection();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _stop(LocalShell shell) async {
    final l10n = _l10n;
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.localTerminalStopTitle,
      message: l10n.localTerminalStopBody,
      confirmLabel: l10n.localTerminalStop,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      icon: AppIcons.stop,
      destructive: true,
      confirmKey: const ValueKey('local-terminal-stop-confirm'),
    );
    if (!confirmed) return;
    await _sessions.stop(shell);
  }

  void _menu(Object value) {
    final shell = _shell;
    if (value is LocalShell) {
      _show(value);
      return;
    }
    switch (value) {
      case _MenuAction.newShell:
        _newShell();
      case _MenuAction.paste when shell != null:
        unawaited(_paste(shell));
      case _MenuAction.stop when shell != null:
        unawaited(_stop(shell));
      case _MenuAction.close when shell != null:
        unawaited(_sessions.remove(shell));
      default:
        break;
    }
  }

  String _shellName(LocalShell shell) =>
      _l10n.localTerminalShellName(shell.number);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final shell = _shell;
    final installed = _status?.installed == true;
    final starting =
        (_status == null && _statusFailure == null) ||
        (installed &&
            (shell == null || shell.state == LocalShellState.starting));
    // Landscape with the keyboard up leaves a strip: the source choice goes
    // and the key bar folds into one row, so the shell keeps some lines.
    final compact = _compact(context);
    final header = compact ? null : widget.header;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(l10n.libraryTerminalTitle),
        actions: [
          if (shell != null && _selection.selection != null)
            IconButton(
              key: const ValueKey('local-terminal-copy'),
              tooltip: l10n.localTerminalCopy,
              onPressed: () => unawaited(_copy(shell)),
              icon: const Icon(AppIcons.copy),
            ),
          if (installed)
            PopupMenuButton<Object>(
              key: const ValueKey('local-terminal-menu'),
              tooltip: l10n.localTerminalMenu,
              icon: const Icon(AppIconography.more),
              onSelected: _menu,
              itemBuilder: (context) => [
                for (final each in _sessions.shells)
                  CheckedPopupMenuItem<Object>(
                    key: ValueKey('local-terminal-shell-${each.number}'),
                    value: each,
                    checked: identical(each, shell),
                    child: Text(
                      each.running || each.state == LocalShellState.starting
                          ? _shellName(each)
                          : l10n.localTerminalShellEnded(_shellName(each)),
                    ),
                  ),
                if (_sessions.shells.isNotEmpty) const PopupMenuDivider(),
                PopupMenuItem<Object>(
                  key: const ValueKey('local-terminal-new'),
                  value: _MenuAction.newShell,
                  child: Text(l10n.localTerminalNewShell),
                ),
                if (shell != null && shell.running) ...[
                  PopupMenuItem<Object>(
                    key: const ValueKey('local-terminal-paste'),
                    value: _MenuAction.paste,
                    child: Text(l10n.localTerminalPaste),
                  ),
                  PopupMenuItem<Object>(
                    key: const ValueKey('local-terminal-stop'),
                    value: _MenuAction.stop,
                    child: Text(
                      l10n.localTerminalStopShell,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ] else if (shell != null)
                  PopupMenuItem<Object>(
                    key: const ValueKey('local-terminal-close'),
                    value: _MenuAction.close,
                    child: Text(l10n.localTerminalCloseShell),
                  ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            (header == null ? 0 : _headerHeight) + 2,
          ),
          child: Column(
            children: [
              ?header,
              KitLoadingBar(
                loading: starting,
                label: l10n.localTerminalStarting,
              ),
            ],
          ),
        ),
      ),
      body: _body(context),
    );
  }

  static const _headerHeight = 56.0;

  /// Less than this much height above the keyboard makes the screen compact.
  static const compactHeight = 420.0;

  static bool _compact(BuildContext context) =>
      MediaQuery.sizeOf(context).height -
          MediaQuery.viewInsetsOf(context).bottom <
      compactHeight;

  Widget _body(BuildContext context) {
    final l10n = _l10n;
    final status = _status;
    if (_statusFailure != null) {
      return KitStateView(
        key: const ValueKey('local-terminal-failed'),
        icon: AppIconography.error,
        tone: AppStatusTone.failure,
        title: l10n.localTerminalFailedTitle,
        body: l10n.localTerminalFailedBody,
        primary: KitAction(
          key: const ValueKey('local-terminal-try-again'),
          label: l10n.localTerminalTryAgain,
          onPressed: () => unawaited(_open()),
        ),
        details: _statusFailure,
      );
    }
    if (status == null) return const SizedBox.shrink();
    if (!status.installed) {
      return KitStateView(
        key: const ValueKey('local-terminal-not-set-up'),
        icon: AppIconography.terminal,
        illustration: const StatesTerminalScene(),
        title: l10n.localTerminalNotSetUpTitle,
        body: l10n.localTerminalNotSetUpBody,
        primary: KitAction(
          key: const ValueKey('local-terminal-set-up'),
          label: l10n.localTerminalSetUp,
          onPressed: () async {
            await (localTerminalOpenSetupOverride ?? openPhoneSetupStart)(
              context,
            );
            if (mounted) unawaited(_open());
          },
        ),
      );
    }
    final shell = _shell;
    if (shell == null) return const SizedBox.shrink();
    if (shell.state == LocalShellState.failed) {
      return KitStateView(
        key: const ValueKey('local-terminal-failed'),
        icon: AppIconography.error,
        tone: AppStatusTone.failure,
        title: l10n.localTerminalFailedTitle,
        body: l10n.localTerminalFailedBody,
        primary: KitAction(
          key: const ValueKey('local-terminal-try-again'),
          label: l10n.localTerminalTryAgain,
          onPressed: () => _restart(shell),
        ),
        details: shell.failure,
      );
    }
    final teamOn = status.serviceRunning(BuiltinTeam.serviceName);
    final processes = _sessions.processes;
    return ListenableBuilder(
      listenable: shell,
      builder: (context, _) {
        final exited = shell.state == LocalShellState.exited;
        return Column(
          children: [
            if (teamOn)
              KitStatusLine(
                key: const ValueKey('local-terminal-cost'),
                icon: AppIconography.info,
                tone: AppStatusTone.attention,
                message: processes == null
                    ? l10n.localTerminalCost(
                        LocalTerminalSessions.processesPerShell,
                        LocalTerminalSessions.androidProcessLimit,
                      )
                    : l10n.localTerminalCostNow(
                        LocalTerminalSessions.processesPerShell,
                        // The app itself is not one of the extra processes.
                        (processes - 1).clamp(0, 9999),
                        LocalTerminalSessions.androidProcessLimit,
                      ),
              ),
            Expanded(
              child: ColoredBox(
                color: xterm.TerminalThemes.defaultTheme.background,
                child: Semantics(
                  label: l10n.localTerminalSemantics,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: xterm.TerminalView(
                      shell.terminal,
                      key: ValueKey('local-terminal-view-${shell.number}'),
                      controller: _selection,
                      focusNode: _focus,
                      autofocus: true,
                      autoResize: true,
                      keyboardType: TextInputType.text,
                      keyboardAppearance: Brightness.dark,
                      deleteDetection: true,
                      readOnly: !shell.running,
                      padding: const EdgeInsets.all(6),
                      textStyle: const xterm.TerminalStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: AppTheme.codeFontSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (exited)
              SafeArea(
                top: false,
                child: KitStateView(
                  key: const ValueKey('local-terminal-ended'),
                  size: KitStateSize.inline,
                  icon: AppIconography.terminal,
                  illustration: const StatesTerminalScene(ended: true),
                  title: l10n.localTerminalEndedTitle,
                  body: l10n.localTerminalEndedBody(shell.exitCode ?? -1),
                  primary: KitAction(
                    key: const ValueKey('local-terminal-restart'),
                    label: l10n.localTerminalRestart,
                    onPressed: () => _restart(shell),
                  ),
                ),
              )
            else
              SafeArea(
                top: false,
                child: TerminalKeyBar(
                  key: const ValueKey('local-terminal-keys'),
                  compact: _compact(context),
                  controller: _keys,
                  enabled: shell.running,
                  onKey: (key, {required ctrl, required alt}) =>
                      sendTerminalBarKey(
                        shell.terminal,
                        key,
                        ctrl: ctrl,
                        alt: alt,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}
