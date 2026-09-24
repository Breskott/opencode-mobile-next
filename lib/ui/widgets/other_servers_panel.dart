import 'package:flutter/material.dart';

import '../../domain/profile_monitor.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profile_monitor.dart' show ProfileMonitor;
import '../../state/profiles.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import '../screens/profile_monitor_screen.dart' show openMonitoredRequest;

/// The other agent running on this phone (or any other watched server), on
/// the Work tab.
///
/// The app talks to one server at a time, but OpenCode and Claude Code can
/// both be working here at once. The one you are not looking at kept going
/// out of sight, and an approval it stopped on waited unseen. This names each
/// other server with something going on, what it is ("Needs you", "2
/// working"), and takes you there in one tap: straight to the request when it
/// is waiting on you.
class OtherServersPanel extends StatelessWidget {
  const OtherServersPanel({super.key, required this.controller});

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isIsolated) return const SizedBox.shrink();
    final monitor = controller.profileMonitor;
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final rows = [
          for (final profile in controller.store.profiles)
            if (profile.id != controller.profile?.id &&
                controller.isProfileReadable(profile.id))
              if (monitor.snapshotFor(profile.id) case final snapshot
                  when snapshot.isCurrent &&
                      (snapshot.requests.isNotEmpty ||
                          (snapshot.runningCount ?? 0) > 0))
                _OtherServerRow(
                  controller: controller,
                  profile: profile,
                  snapshot: snapshot,
                ),
        ];
        if (rows.isEmpty) return const SizedBox.shrink();
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        return Column(
          key: const ValueKey('other-servers-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SectionLabel(l10n.otherServersTitle), ...rows],
        );
      },
    );
  }
}

class _OtherServerRow extends StatefulWidget {
  const _OtherServerRow({
    required this.controller,
    required this.profile,
    required this.snapshot,
  });

  final ConnectionController controller;
  final ServerProfile profile;
  final ProfileAttentionSnapshot snapshot;

  @override
  State<_OtherServerRow> createState() => _OtherServerRowState();
}

class _OtherServerRowState extends State<_OtherServerRow> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final request = widget.snapshot.requests.firstOrNull;
      if (request != null) {
        await openMonitoredRequest(
          context,
          widget.controller,
          MonitoredRoute(
            profileID: widget.profile.id,
            requestID: request.id,
            sessionID: request.sessionID,
            kind: request.kind,
            createdAt: widget.snapshot.checkedAt ?? DateTime.now(),
            serverUrl: widget.profile.baseUrl,
            sourceIdentity: ProfileMonitor.routeSourceIdentity(widget.profile),
            directory: request.directory,
            workspace: request.workspace,
          ),
        );
      } else {
        await widget.controller.connect(widget.profile);
      }
    } catch (_) {
      // The connection reports its own failure where connections do.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final waiting = widget.snapshot.requests.length;
    final running = widget.snapshot.runningCount ?? 0;
    final status = [
      if (waiting > 0) l10n.otherServerNeedsYou,
      if (running > 0) l10n.otherServerWorking(running),
    ].join(' · ');
    // The same state colours as Other projects: needs you, else running.
    final color = waiting > 0
        ? AppTheme.statusColor(theme, AppStatusTone.attention)
        : theme.colorScheme.primary;
    // Opening shows on the screen's loading bar (the connection changes);
    // the row only stops taking taps meanwhile.
    return KitRow(
      key: ValueKey('other-server-${widget.profile.id}'),
      leading: SizedBox.square(
        dimension: 32,
        child: Icon(AppIconography.statusDot, size: 12, color: color),
      ),
      title: widget.profile.name,
      supporting: TextSpan(
        text: status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: const SizedBox.square(
        dimension: 48,
        child: Icon(AppIconography.chevronRight, size: 20),
      ),
      onTap: _opening ? null : _open,
    );
  }
}
