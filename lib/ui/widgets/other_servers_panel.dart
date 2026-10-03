import 'package:flutter/material.dart';

import '../../domain/profile_monitor.dart';
import '../../l10n/app_localizations.dart';
import '../../state/connection.dart';
import '../../state/profile_monitor.dart' show ProfileMonitor;
import '../../state/profiles.dart';
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
///
/// Kit only (shared-servers-1): one [KitRowGroup] of [KitRow]s. A server
/// that needs the person leads with the one needs-you mark and word
/// ([KitNeedsYou], LOOK-24); a working one with the working mark and its
/// count in words (STATE-9), never by colour alone.
///
/// States: hidden (isolated, or nothing going on elsewhere); needs you;
/// working; opening (the row rests while the connection changes).
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
                  key: ValueKey('other-server-${profile.id}'),
                  controller: controller,
                  profile: profile,
                  snapshot: snapshot,
                ),
        ];
        if (rows.isEmpty) return const SizedBox.shrink();
        final l10n = lookupAppLocalizations(Localizations.localeOf(context));
        final tokens = KitTokens.of(context);
        return KitRowGroup(
          key: const ValueKey('other-servers-panel'),
          label: l10n.otherServersTitle,
          margin: EdgeInsetsDirectional.only(
            start: tokens.gutter,
            top: tokens.sectionGap,
            end: tokens.gutter,
          ),
          children: rows,
        );
      },
    );
  }
}

class _OtherServerRow extends StatefulWidget {
  const _OtherServerRow({
    super.key,
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

  /// The needs-you word without its trailing separator, for a line with
  /// nothing after it.
  static TextSpan _needsYouAlone(BuildContext context, int count) {
    final span = KitNeedsYou.span(context, count: count);
    return TextSpan(
      text: span.text?.replaceFirst(RegExp(r'\s*·\s*$'), ''),
      style: span.style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final waiting = widget.snapshot.requests.length;
    final running = widget.snapshot.runningCount ?? 0;
    final working = running > 0
        ? TextSpan(
            text: l10n.otherServerWorking(running),
            style: KitText.styleOf(
              context,
              KitTextRole.label,
              tone: KitTextTone.primary,
            ),
          )
        : null;
    // Needs you outranks working: the first is stuck on the person.
    final InlineSpan supporting = waiting > 0
        ? TextSpan(
            children: [
              if (working == null)
                _needsYouAlone(context, waiting)
              else ...[
                KitNeedsYou.span(context, count: waiting),
                working,
              ],
            ],
          )
        : working!;
    // Opening shows on the screen's loading bar (the connection changes);
    // the row only stops taking taps meanwhile.
    return KitRow(
      leading: waiting > 0
          ? KitNeedsYou.mark()
          : const KitTaskMark(state: KitTaskState.working),
      title: widget.profile.name,
      supporting: supporting,
      supportingKey: ValueKey('other-server-${widget.profile.id}-status'),
      trailing: const KitChevron(),
      onTap: _opening ? null : _open,
    );
  }
}
