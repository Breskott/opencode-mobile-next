import 'package:flutter/material.dart';

import '../../domain/profile_monitor.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profile_monitor.dart' show ProfileMonitor;
import '../../state/profiles.dart';
import '../app_theme.dart';
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
        final theme = Theme.of(context);
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        return Column(
          key: const ValueKey('other-servers-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 2),
              child: Text(
                l10n.otherServersTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            ...rows,
          ],
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
    final tone = waiting > 0 ? AppStatusTone.attention : AppStatusTone.progress;
    return ListTile(
      key: ValueKey('other-server-${widget.profile.id}'),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
      leading: _opening
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              AppIconography.statusDot,
              size: 12,
              color: AppTheme.statusColor(theme, tone),
            ),
      minLeadingWidth: 16,
      title: Text(
        widget.profile.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: _opening ? null : _open,
    );
  }
}
