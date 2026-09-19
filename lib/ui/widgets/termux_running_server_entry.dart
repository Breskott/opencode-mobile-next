import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/local_server_controls.dart';
import '../../state/profiles.dart';
import '../../state/termux_running_server.dart';
import '../../termux/bridge.dart';
import '../app_theme.dart';
import 'local_server_card.dart';
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

    // The look is shared with the Claude Code daemon's card; what this entry
    // owns is the OpenCode server's state and what its controls do.
    return LocalServerCard(
      keyPrefix: 'termux-running-server',
      title: title,
      subtitle: runtime,
      stopped: server.isStopped,
      locked: _locked,
      inProgress: _operation != null,
      connected: connected,
      failure: _failure,
      menuTooltip: l10n.phoneServerMore,
      menuItems: [
        if (connected && widget.onDisconnect != null)
          LocalServerCardMenuItem(
            keySuffix: 'disconnect',
            label: l10n.e7WorkspaceDisconnect,
            onSelected: () => unawaited(widget.onDisconnect!()),
          ),
        LocalServerCardMenuItem(
          keySuffix: 'recheck',
          label: l10n.workRefresh,
          onSelected: () => unawaited(_check()),
        ),
        if (widget.onManage != null)
          LocalServerCardMenuItem(
            keySuffix: 'manage',
            label: l10n.phoneServerManage,
            onSelected: widget.onManage!,
          ),
        if (profile != null && widget.onForget != null)
          LocalServerCardMenuItem(
            keySuffix: 'forget',
            label: l10n.phoneServerForget,
            onSelected: () => widget.onForget!(profile),
          ),
      ],
      startLabel: l10n.phoneServerStart,
      connectLabel: l10n.phoneServerConnect,
      openLabel: l10n.phoneServerOpen,
      restartLabel: l10n.termuxRestartConfirm,
      stopLabel: l10n.phoneServerStop,
      onStart: actions == null ? null : () => unawaited(_start(l10n)),
      onConnect: () => unawaited(_connect()),
      onRestart: actions == null ? null : () => unawaited(_restart(l10n)),
      onStop: actions == null ? null : () => unawaited(_stop(l10n)),
      detailsTitle: server.isRunning ? l10n.termuxRunningDetails : null,
      details: [
        Text(detail),
        if (observedAt != null)
          Text(
            l10n.managedHealthObserved(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(observedAt)),
            ),
          ),
      ],
    );
  }
}
