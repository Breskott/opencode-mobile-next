import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/local_agent_server.dart';
import '../../state/profiles.dart';
import '../../termux/local_agent_runtime.dart';
import 'local_agent_onboarding.dart';
import 'local_server_card.dart';
import 'safety_confirms.dart';

enum _Operation { starting, restarting, stopping }

/// Claude Code on this phone, on the Servers screen and in the server
/// switcher, controlled where it is shown.
///
/// It sits beside the OpenCode server's card and looks the same
/// ([LocalServerCard]), but its state is the daemon's: `claude.sh status`
/// read on mount, on app resume, whenever [revision] changes and after every
/// control. Installing, signing in and choosing a project folder stay in the
/// setup wizard ("Manage setup"); the card appears only once there is
/// something installed to control.
class LocalAgentServerEntry extends StatefulWidget {
  const LocalAgentServerEntry({
    super.key,
    required this.profiles,
    required this.busy,
    required this.revision,
    required this.onConnect,
    this.connectedProfileID,
    this.busyConversations = 0,
    this.onDisconnect,
    this.onForget,
    this.onManage,
    this.runtime,
  });

  final List<ServerProfile> profiles;

  /// True while the host screen runs its own server operation.
  final bool busy;

  /// Bumped by the host when something may have changed the daemon.
  final int revision;

  /// The profile the app is connected through right now, if any.
  final String? connectedProfileID;

  /// Connects through (or reopens) the saved server for the daemon.
  final ValueChanged<ServerProfile> onConnect;

  /// Running conversations a restart or stop would interrupt.
  final int busyConversations;

  final Future<void> Function()? onDisconnect;

  /// Forgets the saved server on this device; the daemon itself is untouched.
  final ValueChanged<ServerProfile>? onForget;

  /// Opens the setup wizard, where install, sign-in and the project folder
  /// live. Also where Connect goes when no server is saved yet.
  final VoidCallback? onManage;

  final LocalAgentRuntime? runtime;

  @override
  State<LocalAgentServerEntry> createState() => _LocalAgentServerEntryState();
}

class _LocalAgentServerEntryState extends State<LocalAgentServerEntry>
    with WidgetsBindingObserver {
  LocalAgentRuntime get _runtime => widget.runtime ?? localAgentRuntime;

  LocalAgentStatus? _status;
  bool _checking = false;
  bool _recheckQueued = false;
  int _epoch = 0;
  _Operation? _operation;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void didUpdateWidget(LocalAgentServerEntry oldWidget) {
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
    super.dispose();
  }

  bool get _locked => widget.busy || _checking || _operation != null;

  Future<LocalAgentStatus?> _read() async {
    try {
      return await _runtime.status();
    } on LocalAgentFailure {
      // No Termux, no permission: there is nothing of ours to show.
      return null;
    }
  }

  Future<void> _check() async {
    if (!platformCapabilities.supportsTermux) return;
    if (_checking) {
      _recheckQueued = true;
      return;
    }
    final epoch = ++_epoch;
    setState(() => _checking = true);
    final status = await _read();
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _status = status;
      _checking = false;
    });
    if (_recheckQueued) {
      _recheckQueued = false;
      unawaited(_check());
    }
  }

  /// Connect acts on a fresh look: Android stops Termux without telling
  /// anyone, and the card may have been on screen for minutes.
  Future<void> _connect() async {
    if (_locked) return;
    setState(() {
      _checking = true;
      _failure = null;
    });
    final status = await _read();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
    if (status == null || !status.isReady) return;
    final saved = savedLocalAgentProfile(widget.profiles);
    if (saved == null || saved.codexDirectory.trim().isEmpty) {
      // No project folder chosen yet: that step lives in the wizard.
      widget.onManage?.call();
      return;
    }
    widget.onConnect(saved);
  }

  Future<void> _run(
    _Operation operation,
    Future<LocalAgentStatus> Function() action,
  ) async {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    setState(() {
      _operation = operation;
      _failure = null;
    });
    try {
      await action();
    } on LocalAgentFailure catch (failure) {
      if (mounted) {
        setState(
          () => _failure = l10n.localAgentCardActionFailed(
            localAgentFailureText(l10n, failure.kind, failure.message),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _operation = null);
        unawaited(_check());
      }
    }
  }

  Future<void> _start() async {
    if (_locked) return;
    await _run(_Operation.starting, _runtime.start);
  }

  Future<void> _restart() async {
    if (_locked) return;
    final confirmed = await confirmRestartLocalAgents(
      context,
      busyConversations: widget.busyConversations,
    );
    if (!confirmed || !mounted || _locked) return;
    await _run(_Operation.restarting, _runtime.restart);
  }

  Future<void> _stop() async {
    if (_locked) return;
    if (!await confirmStopLocalAgents(context)) return;
    if (!mounted || _locked) return;
    await _run(_Operation.stopping, _runtime.stop);
  }

  @override
  Widget build(BuildContext context) {
    if (!platformCapabilities.supportsTermux) return const SizedBox.shrink();
    final status = _status;
    // Nothing installed is the wizard's business, not a server to control.
    if (status == null || !status.installed) return const SizedBox.shrink();
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final profile = savedLocalAgentProfile(widget.profiles);
    final running = status.isReady;
    final connected =
        running && profile != null && profile.id == widget.connectedProfileID;
    final title = switch (_operation) {
      _Operation.starting => l10n.localAgentCardStarting,
      _Operation.restarting => l10n.localAgentCardRestarting,
      _Operation.stopping => l10n.localAgentCardStopping,
      null when _checking => l10n.managedHealthChecking,
      null when connected => l10n.localAgentCardConnected,
      null when running => l10n.localAgentReadyTitle,
      null when status.busy => l10n.localAgentInstalling,
      null => l10n.localAgentCardStopped,
    };
    final failure =
        _failure ??
        (status.phase == LocalAgentPhase.failed
            ? localAgentFailureText(
                l10n,
                status.failureKind ?? LocalAgentFailureKind.other,
                status.message,
              )
            : status.killedByAndroid
            ? l10n.localAgentKilled
            : null);

    return LocalServerCard(
      keyPrefix: 'local-agent-server',
      title: title,
      subtitle: l10n.localAgentCardSubtitle,
      stopped: !running,
      locked: _locked || status.busy,
      inProgress: _operation != null || status.busy,
      connected: connected,
      failure: failure,
      menuTooltip: l10n.localAgentMore,
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
      onStart: () => unawaited(_start()),
      onConnect: () => unawaited(_connect()),
      onRestart: () => unawaited(_restart()),
      onStop: () => unawaited(_stop()),
      detailsTitle: status.claudeVersion.isEmpty
          ? null
          : l10n.termuxRunningDetails,
      details: [
        if (status.claudeVersion.isNotEmpty)
          Text(
            l10n.localAgentVersions(
              status.claudeVersion,
              status.paseoVersion,
              status.nodeVersion,
            ),
            textDirection: TextDirection.ltr,
          ),
      ],
    );
  }
}
