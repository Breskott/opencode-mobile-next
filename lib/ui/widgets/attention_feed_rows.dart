/// The Inbox's rows from the one attention feed (slice-P4.2b): what every
/// saved server waits on, in the Inbox's one list, each row naming its
/// server and saying what the work is doing from its [WorkRowStatus]
/// (slice-P5.5).
///
/// The feed is [ConnectionController.attentionFeed], a read-only projection
/// of the existing monitor and the connected transport: reading it polls
/// nothing. The connected server's own permissions, questions, forms and
/// team gates keep their richer rows in the Inbox; from the connected
/// server this adds only what they do not show (a failed run). Other
/// servers show only while their checks are on, and the list says so
/// plainly, with the way to turn them on, when they are off.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/profile_monitor.dart';
import '../../domain/session_title_text.dart';
import '../../domain/work_row_status.dart';
import '../../l10n/app_localizations.dart';
import '../../state/attention_feed.dart';
import '../../state/connection.dart';
import '../../state/profile_monitor.dart' show ProfileMonitor;
import '../../state/profiles.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../screens/profile_monitor_screen.dart' show openMonitoredRequest;
import '../screens/settings_screen.dart' show NotificationsSettingsScreen;
import '../screens/team_conversation/team_conversation.dart';
import 'phone_server_card.dart' show serverDisplayName;
import 'relative_time.dart';
import 'work_row_presentation.dart';

/// Which feed items the Inbox lists as feed rows: every item of another
/// saved server; from the connected server only failures (its requests and
/// gates already have their own answerable rows, never listed twice).
List<AttentionFeedItem> inboxFeedItems(
  ConnectionController controller,
  AttentionFeed feed,
) {
  if (controller.isIsolated) return const [];
  final active = controller.profile?.id;
  return [
    for (final item in feed.items)
      if (item.profileID != active || item.kind == AttentionKind.failedRun)
        item,
  ];
}

/// One feed item as an Inbox row. A fresh request or gate is the kit's
/// pointing needs-you row; anything else (a failure, or a request only
/// known from an older check) is a row whose line starts with its state
/// words — "Failed · on Home PC", "Needs you · as of 28/09 14:02 · on Home
/// PC" — and rests still.
class AttentionFeedRow extends StatefulWidget {
  const AttentionFeedRow({
    super.key,
    required this.controller,
    required this.item,
    required this.now,
    required this.onOpenConversation,
  });

  final ConnectionController controller;
  final AttentionFeedItem item;
  final DateTime now;

  /// Opens a conversation of the connected server by id, the Inbox's own
  /// route (location first, then `/chat/<id>`).
  final ValueChanged<String> onOpenConversation;

  @override
  State<AttentionFeedRow> createState() => _AttentionFeedRowState();
}

class _AttentionFeedRowState extends State<AttentionFeedRow> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openAttentionItem(
        context,
        widget.controller,
        widget.item.identity,
        onOpenConversation: widget.onOpenConversation,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final item = widget.item;
    final status = item.status;
    final shown = displaySessionTitleText(item.title ?? '');
    final title = shown.isNotEmpty ? shown : _genericTitle(l10n, item.kind);
    final server = _serverName(widget.controller, item, l10n);
    void onOpen() {
      if (!_opening) unawaited(_open());
    }

    final reason = switch (item.kind) {
      AttentionKind.permission => KitNeedsYouReason.consent,
      AttentionKind.question ||
      AttentionKind.form ||
      AttentionKind.teamGate => KitNeedsYouReason.decision,
      AttentionKind.failedRun => null,
    };
    if (reason != null &&
        status.isFresh &&
        status.facts.phase == WorkRowPhase.needsYou) {
      return KitNeedsYou.row(
        title: title,
        titleKey: ValueKey('attention-row-${item.identity}-title'),
        reason: reason,
        server: server,
        ifIgnored: l10n.profileMonitorIfIgnored,
        onOpen: onOpen,
      );
    }
    final facts = [
      if (item.target.taskID != null ||
          item.target.runID != null ||
          item.kind == AttentionKind.teamGate)
        l10n.teamTaskMark,
      l10n.attentionOnServer(KitBidi.auto(server)),
    ];
    return KitRow(
      leading: KitTaskMark(state: workRowTaskState(status)),
      title: title,
      titleMaxLines: 2,
      supporting: TextSpan(
        children: [
          workRowStatusSpan(context, l10n, status, now: widget.now),
          TextSpan(text: facts.map((fact) => ' · $fact').join()),
        ],
      ),
      supportingMaxLines: 2,
      supportingKey: ValueKey('attention-row-${item.identity}-line'),
      trailing: const KitChevron(),
      onTap: onOpen,
    );
  }

  static String _genericTitle(AppLocalizations l10n, AttentionKind kind) =>
      switch (kind) {
        AttentionKind.permission => l10n.e7WorkspacePermissionRequired,
        AttentionKind.question => l10n.e7WorkspaceAssistantQuestion,
        AttentionKind.form => l10n.e7WorkspaceInputRequested,
        AttentionKind.teamGate => l10n.attentionTeamTask,
        AttentionKind.failedRun => l10n.monitorSession,
      };
}

/// The saved server's shown name: the feed's redacted label, or the name
/// the rest of the app gives an unnamed server.
String _serverName(
  ConnectionController controller,
  AttentionFeedItem item,
  AppLocalizations l10n,
) {
  if (item.serverName.trim().isNotEmpty) return item.serverName;
  final profiles = controller.store.profiles;
  return serverDisplayName(
    profiles.where((p) => p.id == item.profileID).firstOrNull,
    l10n,
    among: profiles,
  );
}

/// Opens what the feed row [identity] points at. The row is looked up
/// again first: an old row may have been answered, removed or invalidated
/// by a source edit since it was drawn. Another server's request goes
/// through the monitor's request route (profile, location and the exact
/// request revalidated before the existing resolver shows); a failure or
/// a team item with a conversation opens that conversation there; a team
/// item without one opens its task. Nothing is answered from the row.
///
/// P4.2a hook: the target's `requestID` is the card to land on once the
/// conversation opens; the chat lane owns that focus.
Future<void> openAttentionItem(
  BuildContext context,
  ConnectionController controller,
  String identity, {
  required ValueChanged<String> onOpenConversation,
}) async {
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final item = controller.attentionFeed.items
      .where((candidate) => candidate.identity == identity)
      .firstOrNull;
  final profile = item == null
      ? null
      : controller.store.profiles
            .where((p) => p.id == item.profileID)
            .firstOrNull;
  if (item == null ||
      profile == null ||
      !controller.isProfileReadable(profile.id)) {
    await _changed(context, l10n);
    return;
  }
  final target = item.target;
  if (controller.profile?.id == profile.id) {
    if (target.hasConversation) {
      onOpenConversation(target.sessionID!);
      return;
    }
    final team = controller.orchestration;
    final runID = target.runID ?? _runOfTask(controller, target.taskID);
    if (team != null && runID != null) {
      unawaited(TeamConversation.open(context, team, runId: runID));
      return;
    }
    await _changed(context, l10n);
    return;
  }
  final kind = switch (item.kind) {
    AttentionKind.permission => MonitoredRequestKind.permission,
    AttentionKind.question => MonitoredRequestKind.question,
    AttentionKind.form => MonitoredRequestKind.form,
    // A failure or a gate is not a pending request there: the monitor's
    // conversation route (session revalidated, then the chat) opens it.
    AttentionKind.failedRun || AttentionKind.teamGate =>
      target.hasConversation ? MonitoredRequestKind.checkIn : null,
  };
  final requestID = target.requestID ?? target.sessionID;
  if (kind != null && requestID != null && target.hasConversation) {
    await openMonitoredRequest(
      context,
      controller,
      MonitoredRoute(
        profileID: profile.id,
        requestID: requestID,
        sessionID: target.sessionID!,
        kind: kind,
        createdAt: item.status.observedAt,
        serverUrl: profile.baseUrl,
        sourceIdentity: ProfileMonitor.routeSourceIdentity(profile),
        directory: target.directory,
        workspace: target.workspace,
      ),
    );
    return;
  }
  // A team gate with no worker conversation yet: its task lives on that
  // server's team, so switch there first (asking when a run is going here).
  await _switchTo(context, controller, profile, l10n);
}

String? _runOfTask(ConnectionController controller, String? taskID) {
  if (taskID == null) return null;
  final team = controller.orchestration;
  if (team == null) return null;
  for (final item in team.snapshot.work) {
    if (item.id == taskID) return item.runId;
  }
  return null;
}

Future<void> _switchTo(
  BuildContext context,
  ConnectionController controller,
  ServerProfile profile,
  AppLocalizations l10n,
) async {
  final profiles = controller.store.profiles;
  String nameOf(String? id) => serverDisplayName(
    profiles.where((p) => p.id == id).firstOrNull,
    l10n,
    among: profiles,
  );
  if (controller.busySessions.isNotEmpty) {
    final target = nameOf(profile.id);
    final accepted = await showKitConfirm(
      context,
      title: l10n.monitorSwitchToTitle(target),
      body: l10n.profileMonitorSwitchBody(
        nameOf(controller.profile?.id),
        target,
      ),
      confirmLabel: l10n.monitorSwitchTo(target),
      icon: AppIconography.swap,
    );
    if (!accepted) return;
  }
  try {
    await controller.connect(profile);
  } catch (_) {
    // The connection reports its own failure where connections do.
  }
}

Future<void> _changed(BuildContext context, AppLocalizations l10n) async {
  if (!context.mounted) return;
  await showKitAlert(
    context,
    title: l10n.profileMonitorOpenFailedTitle,
    body: l10n.monitorOpenFailed,
    icon: AppIconography.info,
    alertKey: const ValueKey('attention-open-changed'),
  );
}

/// Rows saying which other saved servers the list cannot speak for, with
/// the way forward: servers whose checks are off (one row, opening
/// Notifications, where checks are turned on; showing the Inbox never opts
/// in), and each server the last check could not reach or is old for (Check
/// again). Waiting and checking are passing states and show nothing; a
/// server this app cannot check at all is not listed.
List<Widget> inboxCoverageRows(
  BuildContext context,
  ConnectionController controller,
  AttentionFeed feed, {
  required DateTime now,
}) {
  if (controller.isIsolated) return const [];
  final l10n = lookupAppLocalizations(Localizations.localeOf(context));
  final monitor = controller.profileMonitor;
  final profiles = {for (final p in controller.store.profiles) p.id: p};
  final off = <String>[];
  final rows = <Widget>[];
  for (final check in feed.servers) {
    final profile = profiles[check.profileID];
    if (profile == null ||
        profile.id == controller.profile?.id ||
        !controller.isProfileReadable(profile.id) ||
        !monitor.supportsProfile(profile)) {
      continue;
    }
    final name = check.serverName.trim().isNotEmpty
        ? check.serverName
        : serverDisplayName(profile, l10n, among: controller.store.profiles);
    switch (check.state) {
      case AttentionCheckState.disabled:
        off.add(KitBidi.auto(name));
      case AttentionCheckState.unavailable || AttentionCheckState.stale:
        final checkedAt = check.checkedAt;
        rows.add(
          KitRow(
            key: ValueKey('attention-unchecked-${profile.id}'),
            leading: KitRow.icon(context, AppIconography.cloudOff),
            title: l10n.attentionUnchecked(KitBidi.auto(name)),
            titleMaxLines: 2,
            supporting: TextSpan(
              text: checkedAt == null
                  ? l10n.attentionUncheckedDetail
                  : l10n.attentionUncheckedSince(
                      relativeTimeLabel(
                        checkedAt.millisecondsSinceEpoch,
                        now: now,
                        l10n: l10n,
                      ),
                    ),
            ),
            supportingMaxLines: 3,
            trailing: KitButton.tertiary(
              key: ValueKey('attention-check-again-${profile.id}'),
              label: l10n.activityCheckAgain,
              onPressed: () => unawaited(monitor.refresh()),
            ),
          ),
        );
      case AttentionCheckState.wifiRequired || AttentionCheckState.paused:
        rows.add(
          KitRow(
            key: ValueKey('attention-unchecked-${profile.id}'),
            leading: KitRow.icon(
              context,
              check.state == AttentionCheckState.paused
                  ? AppIconography.pause
                  : AppIconography.network,
            ),
            title: check.state == AttentionCheckState.paused
                ? l10n.attentionChecksPaused(KitBidi.auto(name))
                : l10n.attentionWaitsForWifi(KitBidi.auto(name)),
            titleMaxLines: 2,
            supporting: TextSpan(text: l10n.attentionUncheckedDetail),
            supportingMaxLines: 2,
            trailing: const KitChevron(),
            onTap: () => _openNotifications(context, controller),
          ),
        );
      case AttentionCheckState.waiting ||
          AttentionCheckState.checking ||
          AttentionCheckState.current ||
          AttentionCheckState.partial:
        break;
    }
  }
  if (off.isNotEmpty) {
    rows.insert(
      0,
      KitRow(
        key: const ValueKey('attention-checks-off'),
        leading: KitRow.icon(context, AppIconography.notificationImportant),
        title: l10n.attentionChecksOff(off.join(', ')),
        titleMaxLines: 2,
        supporting: TextSpan(text: l10n.attentionChecksOffDetail),
        supportingMaxLines: 3,
        trailing: const KitChevron(),
        onTap: () => _openNotifications(context, controller),
      ),
    );
  }
  return rows;
}

void _openNotifications(
  BuildContext context,
  ConnectionController controller,
) => unawaited(
  pushKitPage<void>(
    context,
    (_) => NotificationsSettingsScreen(controller: controller),
  ),
);
