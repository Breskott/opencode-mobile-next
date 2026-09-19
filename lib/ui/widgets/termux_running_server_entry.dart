import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/local_server_controls.dart';
import '../../state/profiles.dart';
import '../../state/termux_running_server.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import 'safety_confirms.dart';

/// What the card can do to the phone's server, injected so the card stays a
/// widget and tests can stand in for Termux.
class LocalServerCardActions {
  const LocalServerCardActions({required this.restart, required this.stop});

  /// Starts a stopped server or restarts a running one; completes when ready.
  final Future<void> Function() restart;
  final Future<void> Function() stop;
}

enum _Operation { starting, restarting, stopping }

/// The server on this phone, first on the Servers screen and controlled in
/// place.
///
/// A server the app itself set up is the closest thing to "your server" a
/// phone-first person has, so it leads the list and everything a person does
/// to it lives on the card: connect or open, disconnect, start, restart,
/// stop, and forget the saved sign-in. Installation and runtime switching
/// stay in the setup wizard ("Manage").
///
/// The observation is read on mount, on app resume, whenever [revision]
/// changes, and after every control.
class TermuxRunningServerEntry extends StatefulWidget {
  const TermuxRunningServerEntry({
    super.key,
    required this.profiles,
    required this.busy,
    required this.revision,
    required this.onConnect,
    required this.onEnterCredentials,
    this.connectedProfileID,
    this.actions,
    this.busyConversations = 0,
    this.onDisconnect,
    this.onForget,
    this.onManage,
  });

  final List<ServerProfile> profiles;

  /// True while the host screen runs its own server operation.
  final bool busy;

  /// Bumped by the host when something may have changed the phone's server.
  final int revision;

  /// The profile the app is connected through right now, if any.
  final String? connectedProfileID;

  final ValueChanged<ServerProfile> onConnect;

  final void Function(TermuxRunningServer, ServerProfile?) onEnterCredentials;

  /// Null hides Start, Restart and Stop (a host that cannot control Termux).
  final LocalServerCardActions? actions;

  /// Running conversations a restart or stop would interrupt.
  final int busyConversations;

  /// Leaves the connection and keeps the server running.
  final Future<void> Function()? onDisconnect;

  /// Forgets the saved server on this device; the server itself is untouched.
  final ValueChanged<ServerProfile>? onForget;

  /// Opens the setup wizard.
  final VoidCallback? onManage;

  @override
  State<TermuxRunningServerEntry> createState() =>
      _TermuxRunningServerEntryState();
}

class _TermuxRunningServerEntryState extends State<TermuxRunningServerEntry>
    with WidgetsBindingObserver {
  TermuxRunningServer? _server;
  bool _checking = false;
  bool _recheckQueued = false;
  int _epoch = 0;
  TermuxDiscoveryCancellation? _observation;
  _Operation? _operation;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void didUpdateWidget(TermuxRunningServerEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _epoch++;
    _observation?.cancel();
    super.dispose();
  }

  bool get _locked => widget.busy || _checking || _operation != null;

  Future<void> _check() async {
    if (!platformCapabilities.supportsTermux) {
      if (_server != null && mounted) setState(() => _server = null);
      return;
    }
    if (_checking) {
      _recheckQueued = true;
      return;
    }
    final epoch = ++_epoch;
    setState(() => _checking = true);
    final observation = TermuxDiscoveryCancellation();
    _observation = observation;
    final result = await detectTermuxRunningServer(
      profiles: widget.profiles,
      cancellation: observation,
    );
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _server = result;
      _checking = false;
    });
    if (_recheckQueued) {
      _recheckQueued = false;
      unawaited(_check());
    }
  }

  /// Connect always acts on a fresh look: the card may have been on screen
  /// for minutes, and Android stops Termux without telling anyone.
  Future<void> _connect() async {
    if (_locked) return;
    setState(() {
      _checking = true;
      _failure = null;
    });
    final observation = TermuxDiscoveryCancellation();
    _observation = observation;
    final fresh = await detectTermuxRunningServer(
      profiles: widget.profiles,
      cancellation: observation,
    );
    if (!mounted) return;
    setState(() {
      _server = fresh;
      _checking = false;
    });
    if (_recheckQueued) {
      _recheckQueued = false;
      unawaited(_check());
      return;
    }
    if (!fresh.isRunning) return;
    final saved = savedProfileForTermuxServer(widget.profiles, fresh);
    if (saved == null ||
        fresh.needsCredentials ||
        saved.requiresPasswordReentry) {
      widget.onEnterCredentials(fresh, saved);
    } else {
      widget.onConnect(saved);
    }
  }

  Future<void> _run(
    _Operation operation,
    Future<void> Function() action,
    String fallbackFailure,
  ) async {
    setState(() {
      _operation = operation;
      _failure = null;
    });
    try {
      await action();
    } on LocalServerControlFailure catch (error) {
      if (mounted) {
        setState(
          () => _failure = error.message.trim().isEmpty
              ? fallbackFailure
              : error.message.trim(),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _failure = fallbackFailure);
    } finally {
      if (mounted) {
        setState(() => _operation = null);
        unawaited(_check());
      }
    }
  }

  Future<void> _start(AppLocalizations l10n) async {
    final actions = widget.actions;
    if (_locked || actions == null) return;
    await _run(
      _Operation.starting,
      actions.restart,
      l10n.phoneServerStartFailed,
    );
  }

  Future<void> _restart(AppLocalizations l10n) async {
    final actions = widget.actions;
    if (_locked || actions == null) return;
    final confirmed = await confirmRestartLocalServer(
      context,
      busyConversations: widget.busyConversations,
    );
    if (!confirmed || !mounted || _locked) return;
    await _run(
      _Operation.restarting,
      actions.restart,
      l10n.phoneServerRestartFailed,
    );
  }

  Future<void> _stop(AppLocalizations l10n) async {
    final actions = widget.actions;
    if (_locked || actions == null) return;
    if (!await confirmStopLocalServer(context)) return;
    if (!mounted || _locked) return;
    await _run(_Operation.stopping, actions.stop, l10n.phoneServerStopFailed);
  }

  String _runtimeName(AppLocalizations l10n, TermuxRuntime? runtime) =>
      runtime == TermuxRuntime.openCode2
      ? l10n.setupRuntimeTwo
      : l10n.setupRuntimeOne;

  @override
  Widget build(BuildContext context) {
    if (!platformCapabilities.supportsTermux) return const SizedBox.shrink();
    final server = _server;
    if (server == null ||
        server.state == TermuxRunningServerState.unsupported ||
        server.state == TermuxRunningServerState.absent) {
      return const SizedBox.shrink();
    }
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    if (!server.isRunning && !server.isStopped) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          server.state == TermuxRunningServerState.denied
              ? l10n.termuxRunningPermission
              : l10n.termuxRunningUnavailable,
        ),
        trailing: IconButton(
          tooltip: l10n.commonRetry,
          onPressed: _locked ? null : () => unawaited(_check()),
          icon: const Icon(AppIconography.retry),
        ),
      );
    }

    final theme = Theme.of(context);
    final profile = savedProfileForTermuxServer(widget.profiles, server);
    final connected =
        server.isRunning &&
        profile != null &&
        profile.id == widget.connectedProfileID;
    final runtime = _runtimeName(l10n, server.runtime);
    final detail = server.version.isEmpty
        ? runtime
        : '$runtime · ${l10n.e7SetupVersion(server.version)}';
    final observedAt = server.observedAt;
    final title = switch (_operation) {
      _Operation.starting => l10n.phoneServerStarting,
      _Operation.restarting => l10n.phoneServerRestarting,
      _Operation.stopping => l10n.phoneServerStopping,
      null when _checking => l10n.managedHealthChecking,
      null when connected => l10n.phoneServerConnected,
      null when server.isStopped => l10n.phoneServerStopped,
      null => l10n.termuxRunningDetected,
    };
    final actions = widget.actions;
    const touch = Size(48, 48);

    return Card.filled(
      key: const ValueKey('termux-running-server'),
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.primaryContainer.withValues(
        alpha: server.isStopped ? .18 : .35,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    AppIconography.phone,
                    color: server.isStopped
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          runtime,
                          key: const ValueKey('termux-running-server-runtime'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<VoidCallback>(
                  key: const ValueKey('termux-running-server-menu'),
                  tooltip: l10n.phoneServerMore,
                  enabled: !_locked,
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    if (connected && widget.onDisconnect != null)
                      PopupMenuItem(
                        key: const ValueKey('termux-running-server-disconnect'),
                        value: () => unawaited(widget.onDisconnect!()),
                        child: Text(l10n.e7WorkspaceDisconnect),
                      ),
                    PopupMenuItem(
                      key: const ValueKey('termux-running-server-recheck'),
                      value: () => unawaited(_check()),
                      child: Text(l10n.workRefresh),
                    ),
                    if (widget.onManage != null)
                      PopupMenuItem(
                        key: const ValueKey('termux-running-server-manage'),
                        value: widget.onManage!,
                        child: Text(l10n.phoneServerManage),
                      ),
                    if (profile != null && widget.onForget != null)
                      PopupMenuItem(
                        key: const ValueKey('termux-running-server-forget'),
                        value: () => widget.onForget!(profile),
                        child: Text(l10n.phoneServerForget),
                      ),
                  ],
                ),
              ],
            ),
            if (_operation != null)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 8, end: 8),
                child: LinearProgressIndicator(
                  key: ValueKey('termux-running-server-progress'),
                ),
              ),
            if (_failure != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!,
                    key: const ValueKey('termux-running-server-failure'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (server.isStopped)
                    FilledButton.icon(
                      key: const ValueKey('termux-running-server-start'),
                      style: FilledButton.styleFrom(minimumSize: touch),
                      onPressed: _locked || actions == null
                          ? null
                          : () => unawaited(_start(l10n)),
                      icon: const Icon(AppIconography.forward),
                      label: Text(l10n.phoneServerStart),
                    )
                  else ...[
                    FilledButton.icon(
                      key: const ValueKey('termux-running-server-connect'),
                      style: FilledButton.styleFrom(minimumSize: touch),
                      onPressed: _locked ? null : () => unawaited(_connect()),
                      icon: const Icon(AppIconography.forward),
                      label: Text(
                        connected
                            ? l10n.phoneServerOpen
                            : l10n.phoneServerConnect,
                      ),
                    ),
                    if (actions != null) ...[
                      OutlinedButton.icon(
                        key: const ValueKey('termux-running-server-restart'),
                        style: OutlinedButton.styleFrom(minimumSize: touch),
                        onPressed: _locked
                            ? null
                            : () => unawaited(_restart(l10n)),
                        icon: const Icon(AppIconography.restart),
                        label: Text(l10n.termuxRestartConfirm),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('termux-running-server-stop'),
                        style: OutlinedButton.styleFrom(minimumSize: touch),
                        onPressed: _locked
                            ? null
                            : () => unawaited(_stop(l10n)),
                        icon: const Icon(AppIcons.stop),
                        label: Text(l10n.phoneServerStop),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            // Version and check time are for diagnosis, not for deciding what
            // to do next, so they stay folded away.
            if (server.isRunning)
              ExpansionTile(
                tilePadding: const EdgeInsetsDirectional.only(end: 8),
                title: Text(l10n.termuxRunningDetails),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(detail),
                  ),
                  if (observedAt != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.managedHealthObserved(
                          MaterialLocalizations.of(
                            context,
                          ).formatTimeOfDay(TimeOfDay.fromDateTime(observedAt)),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
