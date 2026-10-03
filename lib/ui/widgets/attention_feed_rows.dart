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
import '../../state/orchestration.dart'
    show OrchestrationController, OrchestrationPhase;
import '../navigation/chat_route.dart';
import '../screens/team/gate_sheet.dart' show showGateSheet;
import '../screens/team_conversation/team_conversation.dart';
import 'phone_server_card.dart' show serverDisplayName;
import 'relative_time.dart';
import 'session_title.dart';
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
  /// route (location first, then `/chat/<id>`), landing where [landing]
  /// says (P4.2a).
  final AttentionConversationOpener onOpenConversation;

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
    // The server's untitled placeholder reads as Work shows it (F3).
    final title = presentedSessionTitleText(
      item.title,
      fallback: _genericTitle(l10n, item.kind),
      l10n: l10n,
    );
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
/// P4.2a: a request lands on its card in the conversation, a failed run on
/// its newest failed turn, and a team gate on its card in the task's
/// conversation (or its Gate sheet when the task has none) — on another
/// server after the switch too.
Future<void> openAttentionItem(
  BuildContext context,
  ConnectionController controller,
  String identity, {
  required AttentionConversationOpener onOpenConversation,
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
    // A gate's card lives in its task's conversation, not the worker's.
    if (item.kind == AttentionKind.teamGate &&
        _openTeamTarget(context, controller, target)) {
      return;
    }
    if (target.hasConversation) {
      onOpenConversation(target.sessionID!, _landing(item));
      return;
    }
    if (_openTeamTarget(context, controller, target)) return;
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
      landOnFailure: item.kind == AttentionKind.failedRun,
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
  // server's team, so switch there first (asking when a run is going here),
  // then open the gate itself once that team has listed it.
  final navigator = Navigator.of(context);
  // The switch rebuilds the list this row was in; the navigator stays.
  BuildContext here() => context.mounted
      ? context
      : navigator.overlay?.context ?? navigator.context;
  if (!await _switchTo(context, controller, profile, l10n)) return;
  if (controller.profile?.id != profile.id) return;
  final listed = await _teamListed(controller);
  if (!navigator.mounted) return;
  if (!listed || !_openTeamTarget(here(), controller, target)) {
    await _changed(here(), l10n);
  }
}

/// Where a connected-server row lands in its chat (P4.2a).
ChatRouteArguments _landing(AttentionFeedItem item) => ChatRouteArguments(
  landOnRequestID: switch (item.kind) {
    AttentionKind.permission ||
    AttentionKind.question ||
    AttentionKind.form => item.target.requestID,
    AttentionKind.teamGate || AttentionKind.failedRun => null,
  },
  landOnFailure: item.kind == AttentionKind.failedRun,
);

/// Opens a team gate or task of the connected server exactly: the task's
/// conversation (on the gate's card for a gate), or a gate's own sheet when
/// its task has no run yet. False when this team does not list it: a run is
/// never taken for a task and nothing is guessed.
bool _openTeamTarget(
  BuildContext context,
  ConnectionController controller,
  AttentionTarget target,
) {
  final team = controller.orchestration;
  if (team == null || team.profileId != target.profileID) return false;
  final gateID = target.kind == AttentionKind.teamGate
      ? target.requestID
      : null;
  final runID = target.runID ?? _runOfTask(controller, target.taskID);
  if (runID != null) {
    unawaited(
      Navigator.of(
        context,
      ).push(TeamConversation.route(team, runId: runID, landOnGateId: gateID)),
    );
    return true;
  }
  if (gateID != null && team.snapshot.gates.any((gate) => gate.id == gateID)) {
    unawaited(showGateSheet(context, team, gateID));
    return true;
  }
  return false;
}

/// Waits (bounded) until the connected server's team has its first
/// snapshot, or says it cannot: a switch starts the team controller, which
/// loads after the connection.
Future<bool> _teamListed(ConnectionController controller) async {
  bool settled() {
    final team = controller.orchestration;
    return team != null &&
        (team.snapshot.hasData ||
            team.phase == OrchestrationPhase.failed ||
            team.phase == OrchestrationPhase.stopped);
  }

  if (settled()) return controller.orchestration!.snapshot.hasData;
  final done = Completer<void>();
  OrchestrationController? watched;
  void check() {
    final team = controller.orchestration;
    if (team != watched) {
      watched?.removeListener(check);
      watched = team;
      team?.addListener(check);
    }
    if (settled() && !done.isCompleted) done.complete();
  }

  controller.addListener(check);
  check();
  try {
    await done.future.timeout(const Duration(seconds: 15));
  } on TimeoutException {
    return false;
  } finally {
    controller.removeListener(check);
    watched?.removeListener(check);
  }
  return controller.orchestration?.snapshot.hasData ?? false;
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

/// Switches to [profile], asking first while a run is going here. False
/// when the person declined.
Future<bool> _switchTo(
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
    if (!accepted) return false;
  }
  try {
    await controller.connect(profile);
  } catch (_) {
    // The connection reports its own failure where connections do.
  }
  return true;
}

/// Opens a connected-server conversation, landing where the chat is told
/// (P4.2a): the Inbox passes its own route (location first, then
/// `/chat/<id>` with [ChatRouteArguments]).
typedef AttentionConversationOpener =
    void Function(String sessionID, ChatRouteArguments landing);

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
    // Lands on the section where each saved server's checks are turned on.
    (_) => NotificationsSettingsScreen(
      controller: controller,
      initialSection: 'servers',
    ),
  ),
);
