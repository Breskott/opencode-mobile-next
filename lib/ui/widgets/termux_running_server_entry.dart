import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/profiles.dart';
import '../../state/termux_running_server.dart';
import '../../termux/bridge.dart';
import '../app_iconography.dart';

/// "OpenCode is running on this phone" with a connect action, shown on the
/// Servers and welcome screens only while a read-only Termux check says the
/// app-managed server is ready.
///
/// Renders nothing off Android, while Termux is missing or not ready, and
/// while the first check is running; the generic setup entries cover these. The observation is re-read
/// when the app resumes, when [revision] changes (the caller bumps it after
/// returning from setup), and on the explicit check action; it is never
/// stored. Nothing here connects on its own — every connect is a tap.
class TermuxRunningServerEntry extends StatefulWidget {
  const TermuxRunningServerEntry({
    super.key,
    required this.profiles,
    required this.busy,
    required this.revision,
    required this.onConnect,
    required this.onEnterCredentials,
    this.connectedProfileID,
  });

  /// The saved profiles, used only to find the running server's credential.
  final List<ServerProfile> profiles;

  /// True while the owning screen is connecting or saving; actions disable.
  final bool busy;

  /// Bump to re-read the observation (for example after setup returns).
  final int revision;

  /// The profile that is connected right now, if any. When it is the running
  /// server's own profile there is nothing to connect, so nothing is shown.
  final String? connectedProfileID;

  /// Connect the saved profile that holds the running server's credential.
  final ValueChanged<ServerProfile> onConnect;

  /// Open the existing profile credential editor without entering setup.
  final void Function(TermuxRunningServer, ServerProfile?) onEnterCredentials;

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
    super.dispose();
  }

  Future<void> _check() async {
    if (!platformCapabilities.supportsTermux) {
      if (_server != null && mounted) setState(() => _server = null);
      return;
    }
    if (_checking) {
      // A resume or refresh arriving mid-check still deserves a fresh read.
      _recheckQueued = true;
      return;
    }
    final epoch = ++_epoch;
    setState(() => _checking = true);
    final result = await detectTermuxRunningServer(profiles: widget.profiles);
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
    if (!server.isRunning) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          server.state == TermuxRunningServerState.denied
              ? l10n.termuxRunningPermission
              : l10n.termuxRunningUnavailable,
        ),
        trailing: IconButton(
          tooltip: l10n.managedHealthCheck,
          onPressed: widget.busy || _checking
              ? null
              : () => unawaited(_check()),
          icon: const Icon(AppIconography.retry),
        ),
      );
    }
    final profile = savedProfileForTermuxServer(widget.profiles, server);
    if (profile != null && profile.id == widget.connectedProfileID) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final runtime = _runtimeName(l10n, server.runtime);
    final detail = server.version.isEmpty
        ? runtime
        : '$runtime · ${l10n.e7SetupVersion(server.version)}';
    final observedAt = server.observedAt;
    return Card.filled(
      key: const ValueKey('termux-running-server'),
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.primaryContainer.withValues(alpha: .35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIconography.phone, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _checking
                          ? l10n.managedHealthChecking
                          : l10n.termuxRunningDetected,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('termux-running-server-connect'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.busy || _checking
                      ? null
                      : () async {
                          // A tap revalidates the observation before selecting
                          // a profile; stale discovery must not switch runtime.
                          setState(() => _checking = true);
                          final fresh = await detectTermuxRunningServer(
                            profiles: widget.profiles,
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
                          final saved = savedProfileForTermuxServer(
                            widget.profiles,
                            fresh,
                          );
                          if (saved == null ||
                              fresh.needsCredentials ||
                              saved.requiresPasswordReentry) {
                            widget.onEnterCredentials(fresh, saved);
                          } else {
                            widget.onConnect(saved);
                          }
                        },
                  icon: const Icon(AppIconography.forward),
                  label: Text(l10n.termuxRunningConnect),
                ),
                TextButton.icon(
                  key: const ValueKey('termux-running-server-recheck'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: widget.busy || _checking
                      ? null
                      : () => unawaited(_check()),
                  icon: const Icon(AppIconography.retry),
                  label: Text(l10n.managedHealthCheck),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
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
