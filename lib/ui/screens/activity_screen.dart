import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api2/models.dart' show Api2FormInfo;
import '../../domain/completion_digest.dart';
import '../../domain/orchestration_gateway.dart';
import '../../domain/return_brief.dart';
import '../../domain/while_away.dart';
import '../../l10n/app_localizations.dart';
import '../../state/automatic_activity.dart';
import '../../state/connection.dart';
import '../../state/orchestration.dart';
import '../app_iconography.dart';
import '../navigation/chat_route.dart' show ChatRouteArguments;
import '../kit/kit.dart';
import '../kit/scenes/states_scenes.dart';
import '../permission_presentation.dart';
import '../widgets/attention_feed_rows.dart';
import '../widgets/completion_digest.dart';
import '../widgets/product_states.dart' show productErrorText;
import '../widgets/relative_time.dart';
import '../widgets/request_routes.dart';
import '../widgets/session_title.dart';
import '../widgets/team_receipt.dart';
import '../widgets/team_vocabulary.dart';
import 'chat/form_flow.dart';
import 'chat/permission_sheet.dart';
import 'profile_monitor_screen.dart';
import 'run_result_screen.dart';
import 'team/agent_screen.dart';
import 'team/gate_sheet.dart';

/// Inbox: the single cross-session control centre (audit §3, §8; target IA
/// "Dock tab 2").
///
/// It replaces the former Mission Control and Pending requests screens, which
/// showed the same pending count behind two mental models. One destination,
/// one badge, three sections:
///
/// 1. **Needs attention** — permissions, questions, and v2 forms, each row
///    opening the *exact* resolver (the same permission sheet and form flow
///    chat uses), never merely a link to the related chat. A permission can
///    also be allowed once from its row. When the connected server runs the
///    AI Team plugin, its gates join the same list in the BRD §47 order —
///    decision requested, run failed, then the app's own permissions, then
///    review ready, gate beads and blocked agents — each opening the
///    read-only Gate sheet (02-ux §6).
/// 2. **Running** — sessions busy right now, with their subagent counts;
///    while the connection is down they read "Last seen running" instead of
///    a live mark.
/// 3. **While you were away** — what finished (completion digests, on
///    demand) and every automatic act the app did (a reconnect, a request
///    allowed by itself, a queued message sent, a heat pause), newest first
///    in the same list. An act names what it was done to, says what was
///    done and when in one line (with Undo where the act has one) and opens
///    that thing's page. None of it is ever Needs you.
///
/// From an expanded window the Inbox is two panes (KitScreen.twoPane): the
/// list on the start side, and the picked request answered in the detail
/// pane instead of a sheet.
///
/// Every row is server truth the controller already holds; nothing here is
/// estimated. Session history and cross-project discovery live in Work and
/// the all-sessions finder, not here: an empty inbox reads as success.
class ActivityScreen extends StatefulWidget {
  final ConnectionController controller;

  /// A notification tap can name the session whose question should open
  /// immediately, so the alert lands on the answer rather than a list.
  final String? initialQuestionSessionID;

  /// An AI Team notification or link (TEAM-203) names the gate whose sheet
  /// should open as soon as the plugin has data; ids only, and nothing is
  /// sent by opening it.
  final String? initialTeamGateId;

  /// True when Activity is hosted as a primary navigation destination, which
  /// already supplies the top bar. Pushed routes (deep links, notifications)
  /// build their own page frame.
  final bool embedded;

  /// The clock behind the AI Team rows' ages; tests pin it.
  final DateTime Function()? now;

  const ActivityScreen({
    super.key,
    required this.controller,
    this.initialQuestionSessionID,
    this.initialTeamGateId,
    this.embedded = false,
    this.now,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

/// The request picked for the detail pane (expanded windows only).
enum _PickKind { permission, question, form }

typedef _Pick = ({_PickKind kind, String id});

class _ActivityScreenState extends State<ActivityScreen> {
  /// The embedded tab is built by the shell's IndexedStack at launch and
  /// stays alive; it takes its truth from the controller's own hydration and
  /// live events, and reconciles on pull-to-refresh. Only a pushed Activity —
  /// a deep link or a notification tap — pays for an entry refresh, exactly
  /// as the former Requests screen did.
  late bool _loading = !widget.embedded;
  bool _refreshing = false;
  String? _error;
  bool _initialQuestionScheduled = false;
  bool _initialQuestionHandled = false;
  bool _initialGateScheduled = false;
  bool _initialGateHandled = false;
  Object? _digestScope;
  final Set<(String, int)> _expandedDigests = {};
  final Set<(String, int)> _dismissedDigests = {};

  /// Automatic acts hidden by a Dismiss whose Undo window is still open.
  final Set<String> _dismissedActs = {};

  /// How an Undo of an automatic act ended, until the row goes.
  final Map<String, AutomaticUndoResult> _undoResults = {};
  _Pick? _picked;

  Object get _currentDigestScope => (
    widget.controller,
    widget.controller.profile?.id,
    widget.controller.connectionRevision,
    widget.controller.locationRevision,
    widget.controller.directory,
    widget.controller.workspace,
  );

  void _clearDigestScope() {
    if (_digestScope == _currentDigestScope) return;
    _digestScope = _currentDigestScope;
    _expandedDigests.clear();
    _dismissedDigests.clear();
    _dismissedActs.clear();
    _undoResults.clear();
    _picked = null;
  }

  @override
  void didUpdateWidget(covariant ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _clearDigestScope();
  }

  void _reviewDigest(String sessionID, Object scope) {
    if (_currentDigestScope != scope) return;
    final controller = widget.controller;
    // P4.2a: what waits in the conversation is answered on its card there.
    for (final permission in controller.awaitingPermissions) {
      if (permission.sessionID == sessionID) {
        _openChat(sessionID, landOnRequestID: permission.id);
        return;
      }
    }
    for (final question in controller.questions.values) {
      if (question.sessionID == sessionID) {
        _openChat(sessionID, landOnRequestID: question.id);
        return;
      }
    }
    if (controller.capabilities.forms) {
      for (final form in controller.forms.values) {
        if (form.sessionID == sessionID) {
          _openChat(sessionID, landOnRequestID: form.id);
          return;
        }
      }
    }
    // Chat owns the authoritative review/task actions; do not create a second
    // diff cache or a route retaining another profile's content here.
    _openChat(sessionID);
  }

  /// Hides one digest at once and offers Undo (DATA-11 b: a deferred local
  /// act). When the window closes the dismissal is saved as the same
  /// "reviewed" mark Work's rows use, so it holds after a restart; a save
  /// that fails brings the row back.
  void _dismissDigest(Session session, int idle) {
    final key = (session.id, idle);
    final controller = widget.controller;
    final scope = controller.returnBriefScope;
    setState(() {
      _dismissedDigests.add(key);
      _expandedDigests.remove(key);
    });
    showKitUndo(
      context,
      message: _l10n(context).activityDigestHidden,
      undoKey: const ValueKey('activity-digest-undo'),
      onUndo: () {
        if (mounted) setState(() => _dismissedDigests.remove(key));
      },
      onCommit: () async {
        try {
          await controller.dismissReturnBrief(
            ReturnBrief.single(ReturnBriefRun(session: session, idleAt: idle)),
            expectedScope: scope,
          );
        } catch (_) {
          if (mounted) setState(() => _dismissedDigests.remove(key));
        }
      },
    );
  }

  /// What finished while the person was away, newest first: one ordinary
  /// row each in the Inbox's one list, its done mark and the word
  /// "Finished" carrying the state (owner rule R1: no headed sections). A
  /// row unfolds to its digest card. Only conversations the person has not
  /// looked at since they finished, where the server keeps that record.
  List<({DateTime at, Widget row})> _finishedRows() {
    final l10n = _l10n(context);
    final controller = widget.controller;
    final scope = _currentDigestScope;
    final reviewed = controller.returnBriefAcknowledgement;
    final sessions =
        controller.sessionsById.values.where((session) {
          final idle = session.time?.idle;
          return session.parentID == null &&
              session.directory == controller.directory &&
              session.workspaceID == controller.workspace &&
              idle != null &&
              idle > 0 &&
              !controller.busySessions.contains(session.id) &&
              !_dismissedDigests.contains((session.id, idle)) &&
              !reviewed.coversRun(session.id, idle) &&
              (!controller.supportsSessionReadState ||
                  controller.isSessionUnread(session));
        }).toList()..sort((a, b) {
          final byTime = b.time!.idle!.compareTo(a.time!.idle!);
          return byTime == 0 ? a.id.compareTo(b.id) : byTime;
        });
    final pendingKnown =
        !controller.permissionsLoading &&
        !controller.questionsLoading &&
        controller.permissionsError == null &&
        controller.questionsError == null &&
        (!controller.capabilities.forms ||
            (!controller.formsLoading && controller.formsError == null));
    final now = (widget.now ?? DateTime.now)();
    return [
      for (final session in sessions)
        (
          at: DateTime.fromMillisecondsSinceEpoch(session.time!.idle!),
          row: _finishedRow(session, scope, pendingKnown, now, l10n),
        ),
    ];
  }

  Widget _finishedRow(
    Session session,
    Object scope,
    bool pendingKnown,
    DateTime now,
    AppLocalizations l10n,
  ) {
    final controller = widget.controller;
    return KitExpandRow(
      key: ValueKey('activity-digest-${session.id}'),
      headerKey: ValueKey('activity-digest-${session.id}-header'),
      leading: KitStatusMark(
        state: KitMarkState.done,
        label: l10n.workFinished,
      ),
      title: presentedSessionTitle(
        session,
        fallback: l10n.globalSessionsUntitled,
        l10n: l10n,
      ),
      supporting: TextSpan(
        text: l10n.activityFinishedRow(
          relativeTimeLabel(session.time!.idle!, now: now, l10n: l10n),
        ),
      ),
      expanded: _expandedDigests.contains((session.id, session.time!.idle!)),
      onExpansionChanged: (_) => setState(() {
        final key = (session.id, session.time!.idle!);
        if (!_expandedDigests.remove(key)) _expandedDigests.add(key);
      }),
      children: [
        CompletionDigestCard(
          key: ValueKey((scope, session.id, session.time!.idle)),
          digest: CompletionDigest(
            sessionID: session.id,
            idleAt: session.time!.idle!,
            changedFiles: session.summary == null || session.summary!.files < 0
                ? null
                : session.summary!.files,
            pendingDecisions: !pendingKnown
                ? null
                : controller.awaitingPermissions
                          .where((p) => p.sessionID == session.id)
                          .length +
                      controller.questions.values
                          .where((q) => q.sessionID == session.id)
                          .length +
                      (controller.capabilities.forms
                          ? controller.forms.values
                                .where((f) => f.sessionID == session.id)
                                .length
                          : 0),
          ),
          onOpenConversation: () {
            if (scope == _currentDigestScope) _openChat(session.id);
          },
          onReview: () => _reviewDigest(session.id, scope),
          onRunResults: () {
            if (scope != _currentDigestScope) return;
            pushKitPage<void>(
              context,
              (_) => RunResultScreen(
                controller: controller,
                sessionID: session.id,
              ),
            );
          },
          onDismiss: () => _dismissDigest(session, session.time!.idle!),
        ),
      ],
    );
  }

  /// Every automatic act of this server and project the person has not
  /// dismissed, one row each (P6.2, AUTO-4, AUTO-13): the thing it was done
  /// to as the title, what was done and when as its line. Never Needs you:
  /// the done mark, no count, no badge.
  ///
  /// Routine reconnects are one current row per place (F4): the newest
  /// says when the app last found the server again, and the older ones
  /// fold into it, so a restart or a flaky network never fills the list.
  /// Dismissing that row dismisses what it folded.
  List<({DateTime at, Widget row})> _automaticRows() {
    final controller = widget.controller;
    final history = controller.automaticActivity;
    if (history == null) return const [];
    final l10n = _l10n(context);
    final now = (widget.now ?? DateTime.now)();
    final shown = <AutomaticAct>[];
    final folded = <String, List<String>>{};
    final reconnectRow = <String, String>{};
    for (final act in controller.automaticActsHere) {
      if (_dismissedActs.contains(act.id)) continue;
      if (act.kind == AutomaticActKind.reconnect) {
        // Newest first: the first reconnect of a place is its row.
        final row = reconnectRow[act.locationKey];
        if (row != null) {
          (folded[row] ??= []).add(act.id);
          continue;
        }
        reconnectRow[act.locationKey] = act.id;
      }
      shown.add(act);
    }
    return [
      for (final act in shown)
        (
          at: act.occurredAt,
          row: _AutomaticActRow(
            key: ValueKey('activity-auto-${act.id}'),
            act: act,
            now: now,
            title: _actTarget(act, l10n),
            words: _actWords(act, l10n),
            undoResult: _undoResults[act.id],
            onOpen: act.sessionId == null
                ? null
                : () => _openChat(act.sessionId!),
            onUndo: history.canUndo(act.id)
                ? () => _undoAct(history, act.id)
                : null,
            dismiss: _dismissAct(
              history,
              act,
              l10n,
              also: folded[act.id] ?? const [],
            ),
          ),
        ),
    ];
  }

  /// What the act was done to: the conversation's current title where the
  /// app knows it, else the name saved with the act.
  String _actTarget(AutomaticAct act, AppLocalizations l10n) {
    final session = act.sessionId == null
        ? null
        : widget.controller.sessionsById[act.sessionId];
    if (session != null) {
      return presentedSessionTitle(
        session,
        fallback: l10n.globalSessionsUntitled,
        l10n: l10n,
      );
    }
    return presentedSessionTitleText(
      act.summary,
      fallback: l10n.globalSessionsUntitled,
      l10n: l10n,
    );
  }

  /// What was done, in the person's language (the saved summary is only
  /// the thing's name).
  static String _actWords(AutomaticAct act, AppLocalizations l10n) =>
      switch (act.kind) {
        AutomaticActKind.reconnect => l10n.whileAwayActReconnected,
        AutomaticActKind.restart => l10n.whileAwayActRestarted,
        AutomaticActKind.heatPause => l10n.whileAwayActHeatPaused,
        AutomaticActKind.heatStop => l10n.whileAwayActHeatStopped,
        AutomaticActKind.heatResume => l10n.whileAwayActHeatResumed,
        AutomaticActKind.update => l10n.whileAwayActUpdated,
        AutomaticActKind.permissionApproval => l10n.whileAwayActAllowed,
        AutomaticActKind.queuedSend => l10n.whileAwayActQueuedSent,
        AutomaticActKind.other => l10n.whileAwayActOther,
      };

  Future<void> _undoAct(AutomaticActivityController history, String id) async {
    final result = await history.undo(id);
    if (mounted) setState(() => _undoResults[id] = result);
  }

  /// Dismiss: the row goes at once, with Undo; the history keeps the act
  /// but stops listing it once the window closes (DATA-11 b). A save that
  /// fails brings the row back.
  KitSwipeAction _dismissAct(
    AutomaticActivityController history,
    AutomaticAct act,
    AppLocalizations l10n, {
    List<String> also = const [],
  }) {
    final ids = [act.id, ...also];
    return KitSwipeAction(
      id: ValueKey('activity-auto-dismiss-${act.id}'),
      label: l10n.whileAwayDismiss,
      icon: AppIconography.close,
      undoMessage: l10n.whileAwayDismissed(_actTarget(act, l10n)),
      onAct: () async {
        if (!mounted) return false;
        setState(() => _dismissedActs.addAll(ids));
        return true;
      },
      onUndo: () {
        if (mounted) setState(() => _dismissedActs.removeAll(ids));
      },
      onCommit: () async {
        final saved = await history.acknowledge(ids);
        if (!saved && mounted) setState(() => _dismissedActs.removeAll(ids));
      },
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.embedded) _refreshPending();
      _scheduleInitialQuestion();
      _scheduleInitialGate();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _scheduleInitialQuestion();
    _scheduleInitialGate();
  }

  /// Opens the Gate sheet a notification or link named, once the plugin
  /// controller has its first snapshot (or gave up): the sheet itself says
  /// when the gate is gone. Exactly one open per screen; nothing is sent.
  void _scheduleInitialGate() {
    final gateId = widget.initialTeamGateId;
    final team = widget.controller.orchestration;
    if (!mounted ||
        gateId == null ||
        team == null ||
        _initialGateHandled ||
        _initialGateScheduled) {
      return;
    }
    final settled =
        team.snapshot.hasData ||
        team.phase == OrchestrationPhase.failed ||
        team.phase == OrchestrationPhase.stopped;
    if (!settled) return;
    _initialGateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialGateScheduled = false;
      if (!mounted || _initialGateHandled) return;
      _initialGateHandled = true;
      final now = (widget.now ?? DateTime.now)();
      showGateSheet(context, team, gateId, now: () => now);
    });
  }

  void _scheduleInitialQuestion() {
    final sessionID = widget.initialQuestionSessionID;
    if (!mounted ||
        sessionID == null ||
        _initialQuestionHandled ||
        _initialQuestionScheduled) {
      return;
    }
    PendingQuestion? target;
    for (final question in widget.controller.questions.values) {
      if (question.sessionID == sessionID) {
        target = question;
        break;
      }
    }
    if (target == null) return;
    _initialQuestionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialQuestionScheduled = false;
      if (!mounted || _initialQuestionHandled) return;
      final current = widget.controller.questions[target!.id];
      if (current == null || current.sessionID != sessionID) return;
      _initialQuestionHandled = true;
      // P4.2a: the notification lands on the question's card.
      _openChat(current.sessionID, landOnRequestID: current.id);
    });
  }

  /// Pending work only — the cheap half, run on entry so a notification tap
  /// never shows a stale queue.
  Future<void> _refreshPending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        widget.controller.refreshPendingPermissions(),
        widget.controller.refreshPendingQuestions(),
        widget.controller.refreshPendingForms(),
      ]);
    } catch (error) {
      if (mounted) setState(() => _error = productErrorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Wake-safe manual refresh: reconciliation first, so a retained screen
  /// cannot query through a repository being retired after Android idle.
  /// Refreshes both halves — pending work and the session fleet.
  Future<void> _refresh() async {
    final failureMessage = _l10n(context).e7WorkspaceReconnectingAgain;
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await widget.controller.profileMonitor.refresh();
      final repository = await widget.controller.prepareActionRepository();
      if (repository == null) {
        throw ProductException(failureMessage);
      }
      await widget.controller.refreshSessions();
    } catch (error) {
      if (mounted) setState(() => _error = productErrorText(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    if (!mounted) return;
    await _refreshPending();
  }

  int _subagentCount(String rootID) {
    var count = 0;
    for (final session in widget.controller.sessionsById.values) {
      if (session.parentID == rootID) count += 1;
    }
    return count;
  }

  /// Opens [sessionID]; with [landOnRequestID] the chat lands on that
  /// request's card, with [landOnFailure] on its newest failed turn (P4.2a).
  Future<void> _openChat(
    String sessionID, {
    String? landOnRequestID,
    bool landOnFailure = false,
  }) async {
    final controller = widget.controller;
    final location = controller.locationRevision;
    final profile = controller.profile?.id;
    final l10n = _l10n(context);
    try {
      if (!controller.sessionsById.containsKey(sessionID)) {
        await controller.ensureSession(sessionID);
      }
      if (!mounted ||
          controller.locationRevision != location ||
          controller.profile?.id != profile) {
        return;
      }
      final session = controller.sessionsById[sessionID];
      if (session == null) {
        throw ProductException(
          controller.sessionDetailsErrors[sessionID] ??
              l10n.sessionsDetailsUnavailable,
        );
      }
      if (session.directory != null &&
          (session.directory != controller.directory ||
              session.workspaceID != controller.workspace)) {
        await controller.selectLocationForExistingSession(
          directory: session.directory,
          workspace: session.workspaceID,
        );
      }
      if (mounted && controller.profile?.id == profile) {
        // Speed contract item 2: the chat joins this history read.
        unawaited(controller.prefetchSessionTail(sessionID));
        Navigator.of(context).pushNamed(
          '/chat/$sessionID',
          arguments: ChatRouteArguments(
            landOnRequestID: landOnRequestID,
            landOnFailure: landOnFailure,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        await showKitAlert(
          context,
          title: l10n.activityOpenFailedTitle,
          body: productErrorText(error, l10n: l10n),
          alertKey: const ValueKey('activity-open-failed'),
        );
      }
    }
  }

  /// A request row's tap: the detail pane where it shows (expanded), the
  /// request's own sheet elsewhere.
  VoidCallback _opener(_Pick pick, VoidCallback openSheet) => () {
    if (KitScreen.showsDetail(context)) {
      setState(() => _picked = pick);
    } else {
      openSheet();
    }
  };

  /// The AI Team rows in the §47 order, oldest first within a rank so the
  /// thing blocked longest leads (UX plan 5.7): every gate of the snapshot
  /// plus the blocked agents. A run that completed
  /// since the last view (rank 7) is omitted: the controller keeps no
  /// per-view watermark, and inventing one here would mean guessing.
  List<_TeamRow> _teamRows(OrchestrationController? team) {
    if (team == null) return const [];
    final snapshot = team.snapshot;
    final now = (widget.now ?? DateTime.now)();
    final rows = <_TeamRow>[
      // A gate answered from here leaves once the host confirmed
      // (02-ux §6); until then it stays with its receipt chip.
      for (final gate in snapshot.gates)
        if (!teamGateAnswered(team, gate))
          _TeamRow(
            rank: teamActivityGateRank(gate.kind),
            at: gate.createdAt,
            widget: ActivityGateTile(
              key: ValueKey('activity-team-gate-${gate.id}'),
              gate: gate,
              team: team,
              serverName: widget.controller.profile?.name,
              now: now,
            ),
          ),
      for (final agent in snapshot.agents)
        if (agent.state == AgentState.blocked)
          _TeamRow(
            rank: teamActivityAgentBlockedRank,
            at: agent.lastActivity,
            widget: ActivityAgentBlockedTile(
              key: ValueKey('activity-team-agent-${agent.id}'),
              agent: agent,
              team: team,
              serverName: widget.controller.profile?.name,
              now: now,
            ),
          ),
    ];
    rows.sort((a, b) {
      final rank = a.rank.compareTo(b.rank);
      if (rank != 0) return rank;
      final at = a.at, bt = b.at;
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });
    return rows;
  }

  static String _place(Session session) {
    final directory = session.directory?.trim() ?? '';
    if (directory.isEmpty) return '';
    final parts = directory
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? directory : parts.last;
  }

  /// The picked request's view for the detail pane, or null when nothing is
  /// picked or the pick was answered meanwhile (here or on another device).
  Widget? _detail() {
    final pick = _picked;
    if (pick == null) return null;
    final controller = widget.controller;
    switch (pick.kind) {
      case _PickKind.permission:
        for (final permission in controller.awaitingPermissions) {
          if (permission.id == pick.id) {
            return _PermissionDetail(
              key: ValueKey('activity-detail-permission-${permission.id}'),
              permission: permission,
              controller: controller,
              onOpenConversation: () => _openChat(
                permission.sessionID,
                landOnRequestID: permission.id,
              ),
            );
          }
        }
      case _PickKind.question:
        final question = controller.questions[pick.id];
        if (question != null) {
          return _QuestionDetail(
            key: ValueKey('activity-detail-question-${question.id}'),
            question: question,
            controller: controller,
            onOpenConversation: () =>
                _openChat(question.sessionID, landOnRequestID: question.id),
          );
        }
      case _PickKind.form:
        final form = controller.forms[pick.id];
        if (form != null && controller.capabilities.forms) {
          return _FormDetail(
            key: ValueKey('activity-detail-form-${form.id}'),
            form: form,
            controller: controller,
          );
        }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _clearDigestScope();
    final l10n = _l10n(context);
    final controller = widget.controller;
    // Permissions, questions and forms carry no timestamp; the controller
    // keeps them in arrival order, which is oldest first.
    final permissions = controller.awaitingPermissions.toList();
    final questions = controller.questions.values.toList()
      ..sort((a, b) {
        final selected = widget.initialQuestionSessionID;
        if (selected == null) return 0;
        final aSelected = a.sessionID == selected;
        final bSelected = b.sessionID == selected;
        return aSelected == bSelected ? 0 : (aSelected ? -1 : 1);
      });
    // §7 rule 5: forms are v2-only, so a v1 connection never lists them even
    // if a stale entry survived a server switch.
    final formsAvailable = controller.capabilities.forms;
    final sessionForms = !formsAvailable
        ? const <Api2FormInfo>[]
        : controller.forms.values
              .where((form) => form.sessionID != 'global')
              .toList();
    // Global (MCP elicitation) forms have no session to open, so they keep
    // their own subsection rather than pretending to map to a chat.
    final globalForms = !formsAvailable
        ? const <Api2FormInfo>[]
        : controller.forms.values
              .where((form) => form.sessionID == 'global')
              .toList();

    final running = controller.busySessions
        .map((id) => controller.sessionsById[id] ?? Session(id: id, title: id))
        .where((session) => session.parentID == null)
        .toList();
    // AI Team items of the connected server only: the plugin controller is
    // built for the connected profile and disposed on disconnect, so a gate
    // from another server never reaches this list.
    final team = _teamRows(controller.orchestration);

    final loading =
        _loading ||
        controller.permissionsLoading ||
        controller.questionsLoading ||
        (formsAvailable && controller.formsLoading);
    final error =
        _error ??
        controller.permissionsError ??
        controller.questionsError ??
        (formsAvailable ? controller.formsError : null);
    final attentionCount =
        permissions.length +
        questions.length +
        sessionForms.length +
        globalForms.length +
        team.length;
    final empty =
        attentionCount == 0 &&
        running.isEmpty &&
        controller.unifiedAttentionCount == 0;
    final hasCheckIns =
        !controller.isIsolated &&
        controller.store.profiles.any((profile) {
          if (!controller.isProfileReadable(profile.id)) return false;
          final monitor = controller.profileMonitor;
          final snapshot = monitor.snapshotFor(profile.id);
          return snapshot.isCurrent &&
              snapshot.dueCheckIns(monitor.rulesFor(profile.id)).isNotEmpty;
        });
    // Running work is live only while the connection is: without it the
    // last known rows stay, marked as last seen, never a turning spinner.
    final live = controller.isConnected;
    final picked = _picked;

    bool isPicked(_PickKind kind, String id) =>
        picked != null && picked.kind == kind && picked.id == id;

    final attentionRows = <Widget>[
      for (final row in team)
        if (row.rank < teamActivityPermissionRank) row.widget,
      for (final permission in permissions)
        ActivityPermissionTile(
          key: ValueKey('activity-permission-${permission.id}'),
          permission: permission,
          controller: controller,
          selected: isPicked(_PickKind.permission, permission.id),
          // P4.2a: on a phone the row lands on its card in the
          // conversation, never on a sheet over this list.
          onOpen: _opener(
            (kind: _PickKind.permission, id: permission.id),
            () =>
                _openChat(permission.sessionID, landOnRequestID: permission.id),
          ),
        ),
      for (final question in questions)
        ActivityQuestionTile(
          key: ValueKey('activity-question-${question.id}'),
          question: question,
          controller: controller,
          selected: isPicked(_PickKind.question, question.id),
          onOpen: _opener((
            kind: _PickKind.question,
            id: question.id,
          ), () => _openChat(question.sessionID, landOnRequestID: question.id)),
        ),
      for (final form in sessionForms)
        ActivityFormTile(
          key: ValueKey('activity-form-${form.id}'),
          form: form,
          controller: controller,
          selected: isPicked(_PickKind.form, form.id),
          onOpen: _opener((
            kind: _PickKind.form,
            id: form.id,
          ), () => _openChat(form.sessionID, landOnRequestID: form.id)),
        ),
      for (final row in team)
        if (row.rank > teamActivityPermissionRank) row.widget,
    ];

    // The server's own forms (MCP elicitation) have no conversation to
    // open; they follow the conversations' requests in the same list.
    final globalFormRows = [
      for (final form in globalForms)
        ActivityFormTile(
          key: ValueKey('activity-global-form-${form.id}'),
          form: form,
          controller: controller,
        ),
    ];
    // What every saved server waits on, from the one attention feed
    // (slice-P4.2b): another server's requests, gates and failures, and a
    // failure here, each naming its server. Check-in reminders are not
    // requests; they stay the monitor's own rows.
    final feed = controller.attentionFeed;
    final now = (widget.now ?? DateTime.now)();
    final feedRows = [
      for (final item in inboxFeedItems(controller, feed))
        AttentionFeedRow(
          key: ValueKey(('attention-row', item.identity)),
          controller: controller,
          item: item,
          now: now,
          onOpenConversation: (sessionID, landing) => _openChat(
            sessionID,
            landOnRequestID: landing.landOnRequestID,
            landOnFailure: landing.landOnFailure,
          ),
        ),
    ];
    // Other servers this list cannot speak for, and the way forward.
    final coverageRows = inboxCoverageRows(context, controller, feed, now: now);
    final monitor = ProfileMonitorInbox.rowsFor(controller);
    final runningRows = [
      for (final session in running)
        _SessionRow(
          key: ValueKey('activity-running-${session.id}'),
          session: session,
          live: live,
          subagents: _subagentCount(session.id),
          detail:
              controller.sessionDetailsErrors[session.id] ?? _place(session),
          onTap: () => _openChat(session.id),
        ),
    ];
    // While you were away: what finished and what the app did by itself,
    // newest first, together (P6.2).
    final awayRows = [..._finishedRows(), ..._automaticRows()]
      ..sort((a, b) => b.at.compareTo(a.at));
    final finishedRows = [for (final entry in awayRows) entry.row];
    final history = controller.automaticActivity;
    final historyTrouble = history == null
        ? null
        : history.corruptHistory
        ? l10n.whileAwayHistoryUnreadable
        : history.persistenceFailed
        ? l10n.whileAwayHistoryUnsaved
        : null;
    final historyNotice = historyTrouble == null
        ? null
        : _Section(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: KitTokens.of(context).gutter,
              ),
              child: KitNotice(
                key: const ValueKey('activity-auto-history-notice'),
                message: historyTrouble,
              ),
            ),
          );
    // The one list (owner rule R1, 2026-09-27): no headed state sections.
    // Most urgent first: what waits on the person here, the server's own
    // forms, what every saved server waits on or failed at (the feed),
    // running work (and check-ins due on it), what finished, newest first,
    // then the servers this list cannot speak for. Each row's mark and its
    // word ("Needs you", "Working", "Finished") carry the meaning. A row
    // that arrives while the Inbox is open unfolds in, one answered (here or
    // on another device) folds away where it was (design standard §10).
    final rows = [
      ...attentionRows,
      ...globalFormRows,
      ...feedRows,
      ...runningRows,
      ...monitor.checkIns,
      ...finishedRows,
      ...coverageRows,
    ];
    Widget oneList(List<Widget> rows) => _Section(
      child: KitRowGroup(
        key: const ValueKey('activity-list'),
        children: [
          _DividedRows(key: const ValueKey('activity-rows'), rows: rows),
        ],
      ),
    );

    final Widget list;
    if (loading && empty) {
      list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [KitSkeletonRows()],
      );
    } else if (error != null && empty) {
      list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: KitScreen.padding(context),
        children: [
          KitStateView.error(
            key: const ValueKey('activity-error'),
            size: KitStateSize.inline,
            title: l10n.e7WorkspaceRefreshFailed,
            body: error,
            retry: KitAction(
              label: l10n.isolatedTaskRetryOpen,
              onPressed: _refresh,
            ),
          ),
        ],
      );
    } else if (empty) {
      final quiet = [...monitor.checkIns, ...finishedRows, ...coverageRows];
      list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          if (!hasCheckIns)
            _ActivityStatus(
              known:
                  controller.isConnected &&
                  controller.unknownAttentionProfileCount == 0,
              // In the shell the connection line above says the server is
              // away and holds the one Reconnect (R3); a pushed Inbox has no
              // such line, so it keeps its own.
              offline: !controller.isConnected,
              onRefresh: widget.embedded && !controller.isConnected
                  ? null
                  : _refresh,
            ),
          if (quiet.isNotEmpty) oneList(quiet),
          ?historyNotice,
        ],
      );
    } else {
      list = KitScrollArea(
        builder: (scrollController) => ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            bottom: KitScreen.endPadding(context),
          ),
          children: [
            if (error != null)
              _Section(
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: KitTokens.of(context).gutter,
                  ),
                  child: KitNotice.error(
                    key: const ValueKey('activity-refresh-failed'),
                    title: l10n.e7WorkspaceRefreshFailed,
                    message: error,
                    retry: KitAction(
                      label: l10n.isolatedTaskRetryOpen,
                      onPressed: _refresh,
                    ),
                  ),
                ),
              ),
            if (rows.isNotEmpty) oneList(rows),
            ?historyNotice,
          ],
        ),
      );
    }

    // Pull to refresh is the one refresh (R4): no second one in the bar.
    final body = KitRefresh(onRefresh: _refresh, child: list);
    final topBar = widget.embedded
        ? null
        : KitTopBar(title: l10n.shellTabInbox);
    return KitScreen.twoPane(
      topBar: topBar,
      loading: loading && !empty,
      loadingLabel: l10n.activityLoading,
      listPaneKey: const ValueKey('activity-list-pane'),
      detailPaneKey: const ValueKey('activity-detail-pane'),
      list: body,
      detail: _detail(),
      emptyDetail: KitStateView(
        key: const ValueKey('activity-detail-empty'),
        icon: AppIconography.inbox,
        title: attentionCount > 0
            ? l10n.activityPickRequest
            : l10n.activityClearHere,
        body: attentionCount > 0 ? l10n.activityPickRequestDetail : null,
      ),
    );
  }
}

/// Opens the permission sheet with the conversation named, the one resolver
/// every door shares.
void _openPermissionSheet(
  BuildContext context,
  ConnectionController controller,
  PermissionRequest permission,
) => unawaited(
  showPermissionSheet(
    context,
    permission: permission,
    controller: controller,
    contextLabel: _l10n(context).e7WorkspaceRequestFor(
      _sessionTitle(context, controller, permission.sessionID),
    ),
  ),
);

/// One automatic act in While you were away, a row like a finished one:
/// the done mark, the thing it was done to as the title, and the
/// KitAutoLine's words as the supporting line ("Reconnected by itself ·
/// 12m ago"). Undo only where the act has a real inverse. A tap opens that
/// thing's page; Dismiss is a swipe and its menu twin.
class _AutomaticActRow extends StatelessWidget {
  const _AutomaticActRow({
    super.key,
    required this.act,
    required this.title,
    required this.words,
    required this.dismiss,
    required this.now,
    this.undoResult,
    this.onOpen,
    this.onUndo,
  });

  final AutomaticAct act;
  final String title;
  final String words;
  final KitSwipeAction dismiss;
  final DateTime now;
  final AutomaticUndoResult? undoResult;
  final VoidCallback? onOpen;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final undone = act.undone || undoResult == AutomaticUndoResult.undone;
    // An Undo that went out and was never confirmed is never retried and
    // never reads as done (STATE-10).
    final line = undone
        ? l10n.whileAwayActUndone(words)
        : switch (undoResult) {
            AutomaticUndoResult.failed => l10n.whileAwayUndoFailed(words),
            AutomaticUndoResult.unconfirmed => l10n.whileAwayUndoUnconfirmed(
              words,
            ),
            _ when act.undoAttempted => l10n.whileAwayUndoUnconfirmed(words),
            _ => words,
          };
    final undo = undone ? null : onUndo;
    return KitRow(
      leading: KitStatusMark(
        state: KitMarkState.done,
        label: l10n.whileAwayMark,
      ),
      title: title,
      supporting: TextSpan(
        children: [
          KitReceipt.span(context, KitReceiptState.confirmed, label: line),
          TextSpan(
            text: relativeTimeLabel(
              act.occurredAt.millisecondsSinceEpoch,
              now: now,
              l10n: l10n,
            ),
          ),
        ],
      ),
      supportingMaxLines: 2,
      onTap: onOpen,
      swipe: dismiss,
      trailing: undo == null
          ? null
          : KitButton.tertiary(
              key: ValueKey('activity-auto-undo-${act.id}'),
              label: l10n.kitUndoAction,
              onPressed: undo,
            ),
    );
  }
}

/// A section of the list: the VL gap above each group (LAY-7).
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(top: KitTokens.of(context).sectionGap),
    child: child,
  );
}

/// Keyed rows that come and go gently ([KitAnimatedRows]) with the panel's
/// hairline between them, inset to where the words start.
class _DividedRows extends StatelessWidget {
  const _DividedRows({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => KitAnimatedRows(
    children: [
      for (var i = 0; i < rows.length; i++)
        KeyedSubtree(
          key: ValueKey(('activity-row', rows[i].key)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (i > 0) const KitDivider(inset: KitDividerInset.text),
              rows[i],
            ],
          ),
        ),
    ],
  );
}

/// One permission component, three entry points: this row opens the same
/// sheet the chat auto-presents, so resolving here is resolving there. Its
/// trailing action allows it once without the sheet (the common case), and
/// says so if the answer did not go through.
class ActivityPermissionTile extends StatefulWidget {
  final PermissionRequest permission;
  final ConnectionController controller;

  /// What a tap does; null opens the permission sheet.
  final VoidCallback? onOpen;

  /// The row shown in the detail pane (expanded windows).
  final bool selected;

  const ActivityPermissionTile({
    super.key,
    required this.permission,
    required this.controller,
    this.onOpen,
    this.selected = false,
  });

  @override
  State<ActivityPermissionTile> createState() => _ActivityPermissionTileState();
}

class _ActivityPermissionTileState extends State<ActivityPermissionTile> {
  bool _sending = false;
  String? _error;

  Future<void> _allowOnce() async {
    if (_sending) return;
    final controller = widget.controller;
    final request = controller.permissionIdentity(widget.permission);
    if (!controller.isRequestPending(request)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await controller.answerPermission(
        widget.permission.id,
        'once',
        expectedRequest: request,
      );
    } catch (error) {
      if (mounted) setState(() => _error = productErrorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final permission = widget.permission;
    final controller = widget.controller;
    final title = permission.permission.isEmpty
        ? l10n.e7WorkspacePermissionRequired
        : permissionRequestTitle(permission.permission);
    final error = _error;
    final connected = _canAnswer(controller);
    return KitRow(
      leading: KitNeedsYou.mark(),
      title: title,
      selected: widget.selected,
      supporting: error != null
          ? TextSpan(text: l10n.activityAllowOnceFailed(error))
          : TextSpan(
              children: [
                KitNeedsYou.span(context),
                TextSpan(
                  text: permission.patterns.isNotEmpty
                      ? permission.patterns.first
                      : _sessionTitle(
                          context,
                          controller,
                          permission.sessionID,
                        ),
                ),
              ],
            ),
      supportingMaxLines: error != null ? 2 : 1,
      trailing: KitIconButton(
        key: ValueKey('activity-permission-allow-${permission.id}'),
        icon: AppIconography.check,
        tooltip: l10n.chatUiAllowOnce,
        working: _sending,
        disabledReason: connected ? null : l10n.activitySendOffline,
        onPressed: connected ? _allowOnce : null,
      ),
      onTap:
          widget.onOpen ??
          () => _openPermissionSheet(context, controller, permission),
    );
  }
}

class ActivityQuestionTile extends StatelessWidget {
  final PendingQuestion question;
  final ConnectionController controller;

  /// What a tap does; null opens the question sheet.
  final VoidCallback? onOpen;

  /// The row shown in the detail pane (expanded windows).
  final bool selected;

  const ActivityQuestionTile({
    super.key,
    required this.question,
    required this.controller,
    this.onOpen,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return KitRow(
      leading: KitNeedsYou.mark(),
      title: question.prompts.isEmpty
          ? l10n.e7WorkspaceAssistantQuestion
          : question.prompts.first.title,
      supporting: TextSpan(
        children: [
          KitNeedsYou.span(context),
          TextSpan(
            text: question.prompts.isEmpty
                ? _sessionTitle(context, controller, question.sessionID)
                : question.prompts.first.question,
          ),
        ],
      ),
      supportingMaxLines: 2,
      selected: selected,
      trailing: const KitChevron(),
      onTap: onOpen ?? () => showQuestionSheet(context, controller, question),
    );
  }
}

class ActivityFormTile extends StatelessWidget {
  final Api2FormInfo form;
  final ConnectionController controller;

  /// What a tap does; null opens the form.
  final VoidCallback? onOpen;

  /// The row shown in the detail pane (expanded windows).
  final bool selected;

  const ActivityFormTile({
    super.key,
    required this.form,
    required this.controller,
    this.onOpen,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final count = form.fields.length;
    return KitRow(
      key: ValueKey('form-request-tile-${form.id}'),
      leading: KitNeedsYou.mark(),
      title: form.title ?? l10n.e7WorkspaceInputRequested,
      supporting: TextSpan(
        children: [
          KitNeedsYou.span(context),
          TextSpan(
            text: form.sessionID == 'global'
                ? l10n.e7WorkspaceMcpAsked
                : l10n.e7WorkspaceQuestionCount(
                    count,
                    _sessionTitle(context, controller, form.sessionID),
                  ),
          ),
        ],
      ),
      supportingMaxLines: 2,
      selected: selected,
      trailing: const KitChevron(),
      onTap: onOpen ?? () => presentConnectionForm(context, controller, form),
    );
  }
}

/// One AI Team row of the inbox with its §47 rank and time, for the merge
/// with the app's own rows.
class _TeamRow {
  const _TeamRow({required this.rank, required this.at, required this.widget});

  final int rank;
  final DateTime? at;
  final Widget widget;
}

/// A gate of the connected server's AI Team: kind glyph, one-line title,
/// the kind, what it belongs to, the server and its age, and — once
/// answered from here — the receipt chip ("Sent", "Unconfirmed", "Not
/// accepted"). Opens the Gate sheet (02-ux §6), where the answer and the
/// retry live.
class ActivityGateTile extends StatelessWidget {
  const ActivityGateTile({
    super.key,
    required this.gate,
    required this.team,
    required this.serverName,
    required this.now,
  });

  final OrchestrationGate gate;
  final OrchestrationController team;
  final String? serverName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final age = gate.createdAt == null
        ? null
        : relativeTimeLabel(
            gate.createdAt!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final record = teamGateMutation(team, gate);
    void open() => showGateSheet(context, team, gate.id, now: () => now);
    return KitRow(
      leading: KitNeedsYou.mark(),
      title: gate.title,
      // "Needs you · Question · Not confirmed yet · …": the answer's
      // receipt as a word while the host has not confirmed it; the row
      // opens the Gate sheet, where Try again lives.
      supporting: TextSpan(
        children: [
          KitNeedsYou.span(context),
          teamGateRowLine(context, [
            teamGateKindWord(l10n, gate.kind),
            ?teamGateLink(l10n, team.snapshot, gate),
            ?serverName,
            ?age,
          ], record: record),
        ],
      ),
      supportingMaxLines: 2,
      supportingKey: ValueKey('activity-team-gate-${gate.id}-line'),
      trailing: const KitChevron(),
      onTap: open,
    );
  }
}

/// A blocked agent of the connected server's AI Team (BRD §47 rank 5):
/// its name, what it works on, the server and its age. Opens the agent.
class ActivityAgentBlockedTile extends StatelessWidget {
  const ActivityAgentBlockedTile({
    super.key,
    required this.agent,
    required this.team,
    required this.serverName,
    required this.now,
  });

  final OrchestrationAgent agent;
  final OrchestrationController team;
  final String? serverName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    String? work;
    for (final item in team.snapshot.work) {
      if (item.id == agent.currentWorkId) {
        work = l10n.teamUiHomeGateLinkWork(item.title);
        break;
      }
    }
    final age = agent.lastActivity == null
        ? null
        : relativeTimeLabel(
            agent.lastActivity!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final subtitle = [
      l10n.teamUiGateKindAgentBlocked,
      ?work,
      ?serverName,
      ?age,
    ].join(' · ');
    return KitRow(
      leading: KitNeedsYou.mark(),
      title: agent.name,
      supporting: TextSpan(
        children: [
          KitNeedsYou.span(context),
          TextSpan(text: subtitle),
        ],
      ),
      supportingMaxLines: 2,
      trailing: const KitChevron(),
      onTap: () => pushKitPage<void>(
        context,
        (_) => AgentScreen(controller: team, agentId: agent.id, now: () => now),
      ),
    );
  }
}

/// The exact answer surface, shared by Inbox rows, the conversation and
/// notification taps: the kit sheet with each prompt's choices, an own
/// answer where the prompt takes one, Send with its reason while it cannot
/// send, and Dismiss (confirmed first: nobody can restore a dismissed
/// question, DATA-11). [onOpenConversation], when given, adds "Open
/// conversation" for context before answering.
Future<void> showQuestionSheet(
  BuildContext context,
  ConnectionController controller,
  PendingQuestion question, {
  VoidCallback? onOpenConversation,
}) async {
  final request = controller.questionIdentity(question);
  if (!controller.isRequestPending(request)) return;
  final routes = RequestRoutes(
    changes: controller,
    isPending: () => controller.isRequestPending(request),
  );
  final l10n = _l10n(context);
  // Send is pinned to the sheet's foot, above the keyboard, and enables as
  // the person answers: the form publishes it here (slice-P3.11a).
  final send = ValueNotifier<KitAction?>(
    _QuestionFormState.sendAction(
      l10n,
      reason: _canAnswer(controller)
          ? (question.prompts.isEmpty ? null : l10n.activityAnswerEveryQuestion)
          : l10n.activitySendOffline,
      working: false,
      onSend: null,
    ),
  );
  try {
    await showKitSheet<void>(
      context,
      title: l10n.e7WorkspaceNeedsInput,
      subtitle: _sessionTitle(context, controller, question.sessionID),
      icon: AppIconography.question,
      routes: routes,
      sheetKey: const ValueKey('question-sheet'),
      primaryListenable: send,
      body: (sheetContext) => _QuestionForm(
        question: question,
        controller: controller,
        request: request,
        routes: routes,
        pinnedSend: send,
        onOpenConversation: onOpenConversation == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onOpenConversation();
              },
      ),
    );
  } finally {
    routes.close();
    // Not disposed: the form may still publish while the sheet animates
    // out, and a notifier with no listeners holds nothing.
  }
}

class _SessionRow extends StatelessWidget {
  final Session session;

  /// The connection is up: the row is live. Otherwise it is the last known
  /// state, said in words, with a still mark.
  final bool live;
  final int subagents;
  final String detail;
  final VoidCallback onTap;

  const _SessionRow({
    super.key,
    required this.session,
    required this.live,
    required this.subagents,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final title = presentedSessionTitle(
      session,
      fallback: l10n.globalSessionsUntitled,
      l10n: l10n,
    );
    final state = live
        ? l10n.globalSessionsWorking
        : l10n.activityLastSeenRunning;
    final line = [
      state,
      if (detail.isNotEmpty) detail,
      if (subagents > 0) l10n.e7WorkspaceSubagentCount(subagents),
    ].join(' · ');
    return KitRow(
      leading: KitStatusMark(
        state: live ? KitMarkState.working : KitMarkState.waiting,
        label: state,
      ),
      title: title,
      supporting: TextSpan(text: line),
      supportingKey: ValueKey('activity-running-${session.id}-line'),
      trailing: const KitChevron(),
      onTap: onTap,
    );
  }
}

/// A permission picked into the detail pane: the one answer card, with
/// Allow once and Reject in place and Details opening the full sheet
/// (the reject message, the diff, the persistent grant).
class _PermissionDetail extends StatefulWidget {
  const _PermissionDetail({
    super.key,
    required this.permission,
    required this.controller,
    required this.onOpenConversation,
  });

  final PermissionRequest permission;
  final ConnectionController controller;
  final VoidCallback onOpenConversation;

  @override
  State<_PermissionDetail> createState() => _PermissionDetailState();
}

class _PermissionDetailState extends State<_PermissionDetail> {
  DateTime? _since;
  String? _answer;
  String? _refused;

  Future<void> _reply(String reply, String words) async {
    if (_since != null) return;
    final controller = widget.controller;
    final request = controller.permissionIdentity(widget.permission);
    if (!controller.isRequestPending(request)) return;
    setState(() {
      _since = DateTime.now();
      _answer = words;
      _refused = null;
    });
    try {
      await controller.answerPermission(
        widget.permission.id,
        reply,
        expectedRequest: request,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _since = null;
          _refused = productErrorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final permission = widget.permission;
    final controller = widget.controller;
    final title = permission.permission.isEmpty
        ? l10n.e7WorkspacePermissionRequired
        : permissionRequestTitle(permission.permission);
    final since = _since;
    final refused = _refused;
    final connected = _canAnswer(controller);
    return ListView(
      padding: KitScreen.padding(context),
      children: [
        SizedBox(height: KitTokens.of(context).space4),
        KitRequestCard.ask(
          kind: KitRequestKind.permission,
          title: title,
          who: _sessionTitle(context, controller, permission.sessionID),
          reason: KitNeedsYouReason.decision,
          ifIgnored: l10n.activityIfIgnored,
          announcement: l10n.activityPermissionAnnouncement(title),
          summary: permission.patterns.isEmpty
              ? null
              : permission.patterns.join('\n'),
          phase: since == null
              ? KitRequestPhase.waiting
              : KitRequestPhase.sending,
          answer: _answer,
          receipt: since != null
              ? KitReceipt(state: KitReceiptState.sending, since: since)
              : refused != null
              ? KitReceipt(state: KitReceiptState.refused, reason: refused)
              : null,
          answers: KitRequestDecide(
            allowKey: const ValueKey('activity-detail-allow'),
            rejectKey: const ValueKey('activity-detail-reject'),
            disabledReason: connected ? null : l10n.activitySendOffline,
            onAllow: connected
                ? () => _reply('once', l10n.chatUiAllowOnce)
                : null,
            onReject: connected
                ? () => _reply('reject', l10n.chatUiReject)
                : null,
          ),
          onDetails: () =>
              _openPermissionSheet(context, controller, permission),
          tertiary: [
            KitAction(
              key: const ValueKey('activity-detail-open-conversation'),
              label: l10n.digestOpenConversation,
              onPressed: widget.onOpenConversation,
            ),
          ],
        ),
      ],
    );
  }
}

/// A form picked into the detail pane: the answer card; Answer opens the
/// form flow, the one resolver for OpenCode 2 forms.
class _FormDetail extends StatelessWidget {
  const _FormDetail({super.key, required this.form, required this.controller});

  final Api2FormInfo form;
  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final title = form.title ?? l10n.e7WorkspaceInputRequested;
    return ListView(
      padding: KitScreen.padding(context),
      children: [
        SizedBox(height: KitTokens.of(context).space4),
        KitRequestCard.ask(
          kind: KitRequestKind.form,
          title: title,
          who: form.sessionID == 'global'
              ? l10n.e7WorkspaceMcpAsked
              : _sessionTitle(context, controller, form.sessionID),
          reason: KitNeedsYouReason.decision,
          ifIgnored: l10n.activityIfIgnored,
          announcement: l10n.activityFormAnnouncement(title),
          detail: l10n.e7WorkspaceQuestionCount(
            form.fields.length,
            _sessionTitle(context, controller, form.sessionID),
          ),
          answers: const KitRequestInSheet(
            key: ValueKey('activity-detail-form-answer'),
          ),
          onDetails: () => presentConnectionForm(context, controller, form),
        ),
      ],
    );
  }
}

/// A question picked into the detail pane: the same form the sheet holds,
/// under the sheet's header words.
class _QuestionDetail extends StatefulWidget {
  const _QuestionDetail({
    super.key,
    required this.question,
    required this.controller,
    required this.onOpenConversation,
  });

  final PendingQuestion question;
  final ConnectionController controller;
  final VoidCallback onOpenConversation;

  @override
  State<_QuestionDetail> createState() => _QuestionDetailState();
}

class _QuestionDetailState extends State<_QuestionDetail> {
  late final PendingRequestIdentity _request = widget.controller
      .questionIdentity(widget.question);

  /// Owns no route: the pane closes by the question leaving the list.
  late final RequestRoutes _routes = RequestRoutes(
    changes: widget.controller,
    isPending: () => widget.controller.isRequestPending(_request),
  );

  @override
  void dispose() {
    _routes.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final tokens = KitTokens.of(context);
    return ListView(
      padding: KitScreen.padding(context),
      children: [
        SizedBox(height: tokens.space4),
        KitText(l10n.e7WorkspaceNeedsInput, role: KitTextRole.title),
        SizedBox(height: tokens.space1),
        KitText(
          _sessionTitle(context, widget.controller, widget.question.sessionID),
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        SizedBox(height: tokens.space5),
        _QuestionForm(
          question: widget.question,
          controller: widget.controller,
          request: _request,
          routes: _routes,
          onOpenConversation: widget.onOpenConversation,
        ),
      ],
    );
  }
}

/// Every prompt of one question: its choices (one or several), its own
/// answer where it takes one, and the actions. Send says why it cannot send
/// yet (STATE-8); a failed send stays here with the reason and Try again.
class _QuestionForm extends StatefulWidget {
  final PendingQuestion question;
  final ConnectionController controller;
  final PendingRequestIdentity request;
  final RequestRoutes routes;
  final VoidCallback? onOpenConversation;

  /// In a sheet, where Send is pinned: the form publishes its Send here
  /// instead of drawing it. Null in the wide detail pane, which draws it.
  final ValueNotifier<KitAction?>? pinnedSend;

  const _QuestionForm({
    required this.question,
    required this.controller,
    required this.request,
    required this.routes,
    this.onOpenConversation,
    this.pinnedSend,
  });

  @override
  State<_QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<_QuestionForm> {
  late final List<Set<String>> _answers = List.generate(
    widget.question.prompts.length,
    (_) => <String>{},
  );
  late final List<TextEditingController> _custom = List.generate(
    widget.question.prompts.length,
    (_) => TextEditingController(),
  );
  bool _busy = false;
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    // The sheet opened with a first Send; say the form's own at once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Every change of the form's state also updates the pinned Send, from
  /// the event that changed it (never from build).
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _publish();
  }

  void _publish() {
    final pinned = widget.pinnedSend;
    if (pinned == null || !mounted) return;
    pinned.value = _send(_l10n(context));
  }

  /// The one Send: pinned in the sheet, inline in the detail pane.
  KitAction _send(AppLocalizations l10n) {
    final reason = !_canAnswer(widget.controller)
        ? l10n.activitySendOffline
        : !_complete
        ? l10n.activityAnswerEveryQuestion
        : null;
    return sendAction(
      l10n,
      reason: reason,
      working: _busy && !_confirming,
      onSend: _busy ? null : _submit,
    );
  }

  bool get _complete {
    for (var i = 0; i < widget.question.prompts.length; i++) {
      if (_answers[i].isEmpty && _custom[i].text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_complete || _busy || !widget.routes.isPending) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final answers = <List<String>>[];
    for (var i = 0; i < _answers.length; i++) {
      final prompt = widget.question.prompts[i];
      final customAnswer = _custom[i].text.trim();
      if (prompt.multiple) {
        answers.add([
          ..._answers[i],
          if (customAnswer.isNotEmpty) customAnswer,
        ]);
      } else {
        answers.add([
          if (customAnswer.isNotEmpty)
            customAnswer
          else if (_answers[i].isNotEmpty)
            _answers[i].first,
        ]);
      }
    }
    try {
      await widget.controller.answerQuestion(
        widget.question.id,
        answers,
        expectedRequest: widget.request,
      );
      widget.routes.close();
    } catch (error) {
      if (mounted && widget.routes.isPending) {
        setState(() => _error = productErrorText(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The same selection rules the inline chat card applies: a single-select
  /// choice replaces the choice and clears custom text; a multi-select
  /// change keeps custom text.
  void _choose(int index, String label) {
    setState(() {
      _custom[index].clear();
      _answers[index]
        ..clear()
        ..add(label);
    });
  }

  Future<void> _reject() async {
    if (_busy || !widget.routes.isPending) return;
    setState(() {
      _busy = true;
      _confirming = true;
      _error = null;
    });
    try {
      final confirmed = await showKitConfirm(
        context,
        title: _l10n(context).e7WorkspaceDismissRequest,
        body: _l10n(context).e7WorkspaceDismissDetail,
        confirmLabel: _l10n(context).workspaceDismissNotice,
        kind: KitConfirmKind.destructive,
        icon: AppIconography.blocked,
        routes: widget.routes,
      );
      if (!confirmed || !mounted || !widget.routes.isPending) return;
      setState(() => _confirming = false);
      await widget.controller.rejectQuestion(
        widget.question.id,
        expectedRequest: widget.request,
      );
      widget.routes.close();
    } catch (error) {
      if (mounted && widget.routes.isPending) {
        setState(() => _error = productErrorText(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  /// A Send for [reason]: disabled with it, else sending with [onSend].
  static KitAction sendAction(
    AppLocalizations l10n, {
    required String? reason,
    required bool working,
    required VoidCallback? onSend,
  }) => KitAction(
    key: const ValueKey('question-send'),
    label: l10n.e7WorkspaceSendAnswers,
    working: working,
    disabledReason: reason,
    onPressed: reason == null ? onSend : null,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final tokens = KitTokens.of(context);
    final prompts = widget.question.prompts;
    final pinned = widget.pinnedSend;
    final error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < prompts.length; index++) ...[
          if (index > 0) SizedBox(height: tokens.sectionGap),
          if (prompts.length > 1)
            KitText(
              l10n.activityQuestionProgress(index + 1, prompts.length),
              role: KitTextRole.caption,
              tone: KitTextTone.secondary,
            ),
          KitText(prompts[index].title, role: KitTextRole.headline),
          SizedBox(height: tokens.space1),
          KitText(prompts[index].question),
          if (prompts[index].choices.isNotEmpty) ...[
            SizedBox(height: tokens.space3),
            _choices(index, prompts[index]),
          ],
          if (prompts[index].custom) ...[
            SizedBox(height: tokens.space3),
            KitField(
              key: ValueKey('question-own-answer-$index'),
              label: l10n.activityOwnAnswer,
              controller: _custom[index],
              enabled: !_busy,
              disabledReason: _busy ? l10n.activitySending : null,
              textInputAction: TextInputAction.done,
              onChanged: (value) => setState(() {
                if (!prompts[index].multiple && value.trim().isNotEmpty) {
                  _answers[index].clear();
                }
              }),
            ),
          ],
        ],
        if (error != null) ...[
          SizedBox(height: tokens.space4),
          KitNotice.error(
            key: const ValueKey('question-send-failed'),
            message: error,
            retry: KitAction(
              label: l10n.isolatedTaskRetryOpen,
              onPressed: _complete && !_busy ? _submit : null,
            ),
          ),
        ],
        SizedBox(height: tokens.space5),
        KitActionBlock(
          primary: pinned == null ? _send(l10n) : null,
          tertiary: [
            if (widget.onOpenConversation case final open?)
              KitAction(
                key: const ValueKey('question-open-conversation'),
                label: l10n.digestOpenConversation,
                onPressed: _busy ? null : open,
              ),
            KitAction(
              key: const ValueKey('question-dismiss'),
              label: l10n.workspaceDismissNotice,
              destructive: true,
              onPressed: _busy ? null : _reject,
            ),
          ],
        ),
      ],
    );
  }

  Widget _choices(int index, QuestionPrompt prompt) {
    final choices = [
      for (final choice in prompt.choices)
        KitChoice<String>(
          value: choice.label,
          title: choice.label,
          supporting: choice.description.isEmpty ? null : choice.description,
          enabled: !_busy,
          disabledReason: _busy ? _l10n(context).activitySending : null,
        ),
    ];
    if (prompt.multiple) {
      return KitChoiceList<String>.multi(
        key: ValueKey('question-choices-$index'),
        choices: choices,
        selected: _answers[index],
        semanticsLabel: prompt.title,
        onChanged: (values) => setState(
          () => _answers[index]
            ..clear()
            ..addAll(values),
        ),
      );
    }
    return KitChoiceList<String>.single(
      key: ValueKey('question-choices-$index'),
      choices: choices,
      selected: _answers[index].isEmpty ? null : _answers[index].first,
      actsOnTap: false,
      semanticsLabel: prompt.title,
      onSelected: (value) => _choose(index, value),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    for (final controller in _custom) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Whether an answer can leave the phone: a server gateway is there (it
/// stays through a stream reconnect). Without one, answering is disabled
/// with its reason rather than failing after the tap.
bool _canAnswer(ConnectionController controller) =>
    controller.repository != null;

String _sessionTitle(
  BuildContext context,
  ConnectionController controller,
  String id,
) {
  final session = controller.sessionsById[id];
  return presentedSessionTitle(
    session,
    fallback: _l10n(context).e7WorkspaceSessionId(id),
    l10n: _l10n(context),
  );
}

/// A scoped result, rather than an unqualified claim about every project.
/// Offline it says only what that means here; the fix is the connection
/// line's Reconnect, so [onRefresh] is null there and no second button
/// repeats it (R3).
class _ActivityStatus extends StatelessWidget {
  const _ActivityStatus({
    required this.known,
    required this.offline,
    required this.onRefresh,
  });
  final bool known;
  final bool offline;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final retry = onRefresh;
    return KitStateView(
      key: ValueKey(known ? 'activity-all-clear' : 'activity-status-unknown'),
      size: KitStateSize.inline,
      icon: known ? AppIconography.inbox : AppIconography.networkOff,
      // All caught up: the last sheet settles into the tray. Not known yet:
      // the unplugged drawing every load failure uses.
      illustration: known
          ? const StatesTrayScene()
          : const StatesUnpluggedScene(),
      title: known
          ? l10n.activityClearHere
          : offline
          ? l10n.activityOfflineRequests
          : l10n.activityStatusIncomplete,
      // The all-clear says what would fill this list, so an empty Inbox
      // reads as "watching" rather than "nothing here" (UX plan 5.8, item
      // 3). The unknown state keeps its own copy: teaching there would
      // claim a calm the app has not verified.
      body: known
          ? l10n.emptyTeachInboxMessage
          : offline
          ? null
          : l10n.activityUnknownStatusDetail,
      tertiary: [
        if (!known && retry != null)
          KitAction(
            key: const ValueKey('activity-check-again'),
            label: l10n.activityCheckAgain,
            icon: AppIconography.retry,
            onPressed: retry,
          ),
      ],
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
