import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../api/product_repository.dart';
import '../../api2/models.dart' show Api2FormInfo;
import '../../domain/completion_digest.dart';
import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/platform_capabilities.dart';
import '../../state/connection.dart';
import '../../state/orchestration.dart';
import '../app_iconography.dart';
import '../kit/kit.dart';
import '../kit/kit_scrollbar.dart';
import '../kit/scenes/states_scenes.dart';
import '../permission_presentation.dart';
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
import 'settings_screen.dart';
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
/// 3. **Finished while you were away** — completion digests, on demand.
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
  bool _showDigests = false;
  final Set<(String, int)> _expandedDigests = {};
  final Set<(String, int)> _dismissedDigests = {};
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
    _showDigests = false;
    _expandedDigests.clear();
    _dismissedDigests.clear();
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
    for (final permission in controller.awaitingPermissions) {
      if (permission.sessionID == sessionID) {
        showPermissionSheet(
          context,
          permission: permission,
          controller: controller,
        );
        return;
      }
    }
    for (final question in controller.questions.values) {
      if (question.sessionID == sessionID) {
        showQuestionSheet(
          context,
          controller,
          question,
          onOpenConversation: () => _openChat(question.sessionID),
        );
        return;
      }
    }
    if (controller.capabilities.forms) {
      for (final form in controller.forms.values) {
        if (form.sessionID == sessionID) {
          presentConnectionForm(context, controller, form);
          return;
        }
      }
    }
    // Chat owns the authoritative review/task actions; do not create a second
    // diff cache or a route retaining another profile's content here.
    _openChat(sessionID);
  }

  /// Hides one digest at once and offers Undo (DATA-11: a local act the
  /// app can restore).
  void _dismissDigest(String sessionID, int idle) {
    final key = (sessionID, idle);
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
    );
  }

  Widget _completionDigests() {
    final l10n = _l10n(context);
    final controller = widget.controller;
    final scope = _currentDigestScope;
    final sessions =
        controller.sessionsById.values.where((session) {
          final idle = session.time?.idle;
          return session.parentID == null &&
              session.directory == controller.directory &&
              session.workspaceID == controller.workspace &&
              idle != null &&
              idle > 0 &&
              !controller.busySessions.contains(session.id) &&
              !_dismissedDigests.contains((session.id, idle));
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
    return KitRowGroup(
      key: const ValueKey('activity-digests'),
      children: [
        KitExpandRow(
          headerKey: const ValueKey('activity-digests-header'),
          leading: const KitRowIcon(AppIconography.checklist),
          title: l10n.activityFinishedAway,
          supporting: TextSpan(text: l10n.digestSubtitle),
          supportingMaxLines: 2,
          expanded: _showDigests,
          onExpansionChanged: (open) => setState(() => _showDigests = open),
          children: [
            if (sessions.isEmpty)
              KitRow(
                key: const ValueKey('activity-digests-empty'),
                title: l10n.digestEmpty,
                titleMaxLines: 2,
              ),
            for (final session in sessions)
              KitExpandRow(
                key: ValueKey('activity-digest-${session.id}'),
                title: presentedSessionTitle(
                  session,
                  fallback: l10n.globalSessionsUntitled,
                  l10n: l10n,
                ),
                supporting: TextSpan(text: l10n.digestIdle),
                expanded: _expandedDigests.contains((
                  session.id,
                  session.time!.idle!,
                )),
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
                      changedFiles:
                          session.summary == null || session.summary!.files < 0
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
                                          .where(
                                            (f) => f.sessionID == session.id,
                                          )
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
                    onDismiss: () =>
                        _dismissDigest(session.id, session.time!.idle!),
                  ),
                ],
              ),
          ],
        ),
      ],
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

  void _openBackgroundSettings(BuildContext context) {
    pushKitPage<void>(
      context,
      (_) => NotificationsSettingsScreen(controller: widget.controller),
    );
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
      showQuestionSheet(
        context,
        widget.controller,
        current,
        onOpenConversation: () => _openChat(current.sessionID),
      );
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

  Future<void> _openChat(String sessionID) async {
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
        Navigator.of(context).pushNamed('/chat/$sessionID');
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
              onOpenConversation: () => _openChat(permission.sessionID),
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
            onOpenConversation: () => _openChat(question.sessionID),
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
          onOpen: _opener((
            kind: _PickKind.permission,
            id: permission.id,
          ), () => _openPermissionSheet(context, controller, permission)),
        ),
      for (final question in questions)
        ActivityQuestionTile(
          key: ValueKey('activity-question-${question.id}'),
          question: question,
          controller: controller,
          selected: isPicked(_PickKind.question, question.id),
          onOpen: _opener(
            (kind: _PickKind.question, id: question.id),
            () => showQuestionSheet(
              context,
              controller,
              question,
              onOpenConversation: () => _openChat(question.sessionID),
            ),
          ),
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
          ), () => presentConnectionForm(context, controller, form)),
        ),
      for (final row in team)
        if (row.rank > teamActivityPermissionRank) row.widget,
    ];

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
              onRefresh: _refresh,
            ),
          ProfileMonitorInbox(controller: controller, compact: true),
          // An empty inbox is only reassuring if it would fill while the
          // app is closed; when it would not, offer to turn that on.
          if (platformCapabilities.supportsBackgroundService &&
              !controller.keepLiveInBackground)
            _Section(
              child: KitRowGroup(
                children: [
                  _BackgroundUpdatesHint(
                    onOpen: () => _openBackgroundSettings(context),
                  ),
                ],
              ),
            ),
          _Section(child: _completionDigests()),
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
            // What waits on the person: a request that arrives while the
            // Inbox is open unfolds in, one answered (here or on another
            // device) folds away where it was (design standard §10). The
            // list's first paint shows them at once.
            if (attentionRows.isNotEmpty)
              _Section(
                child: KitRowGroup(
                  key: const ValueKey('activity-attention'),
                  label: l10n.setupSwitchAttention,
                  children: [
                    _DividedRows(
                      key: const ValueKey('activity-attention-rows'),
                      rows: attentionRows,
                    ),
                  ],
                ),
              ),
            if (globalForms.isNotEmpty)
              _Section(
                child: KitRowGroup(
                  label: l10n.e7WorkspaceServerRequests,
                  children: [
                    _DividedRows(
                      key: const ValueKey('activity-global-forms'),
                      rows: [
                        for (final form in globalForms)
                          ActivityFormTile(
                            key: ValueKey('activity-global-form-${form.id}'),
                            form: form,
                            controller: controller,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ProfileMonitorInbox(controller: controller, compact: true),
            // Conversations start and finish while the person looks: their
            // rows come and go gently too.
            if (running.isNotEmpty)
              _Section(
                child: KitRowGroup(
                  key: const ValueKey('activity-running'),
                  label: l10n.workRunning,
                  children: [
                    _DividedRows(
                      key: const ValueKey('activity-running-rows'),
                      rows: [
                        for (final session in running)
                          _SessionRow(
                            key: ValueKey('activity-running-${session.id}'),
                            session: session,
                            live: live,
                            subagents: _subagentCount(session.id),
                            detail:
                                controller.sessionDetailsErrors[session.id] ??
                                _place(session),
                            onTap: () => _openChat(session.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            _Section(child: _completionDigests()),
          ],
        ),
      );
    }

    final body = KitRefresh(onRefresh: _refresh, child: list);
    final topBar = widget.embedded
        ? null
        : KitTopBar(
            title: l10n.shellTabInbox,
            actions: [
              KitAction(
                key: const ValueKey('activity-refresh'),
                label: l10n.globalSessionsRefresh,
                icon: AppIconography.retry,
                working: _refreshing,
                onPressed: _refreshing ? null : _refresh,
              ),
            ],
          );
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
      leading: const KitRowIcon(AppIconography.shield),
      title: title,
      selected: widget.selected,
      supporting: error != null
          ? TextSpan(text: l10n.activityAllowOnceFailed(error))
          : TextSpan(
              text: permission.patterns.isNotEmpty
                  ? permission.patterns.first
                  : _sessionTitle(context, controller, permission.sessionID),
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
      leading: const KitRowIcon(AppIconography.question),
      title: question.prompts.isEmpty
          ? l10n.e7WorkspaceAssistantQuestion
          : question.prompts.first.title,
      supporting: TextSpan(
        text: question.prompts.isEmpty
            ? _sessionTitle(context, controller, question.sessionID)
            : question.prompts.first.question,
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
      leading: const KitRowIcon(AppIconography.editNote),
      title: form.title ?? l10n.e7WorkspaceInputRequested,
      supporting: TextSpan(
        text: form.sessionID == 'global'
            ? l10n.e7WorkspaceMcpAsked
            : l10n.e7WorkspaceQuestionCount(
                count,
                _sessionTitle(context, controller, form.sessionID),
              ),
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
    final (icon, _) = teamGateGlyph(gate.kind);
    final age = gate.createdAt == null
        ? null
        : relativeTimeLabel(
            gate.createdAt!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final subtitle = [
      teamGateKindWord(l10n, gate.kind),
      ?teamGateLink(l10n, team.snapshot, gate),
      ?serverName,
      ?age,
    ].join(' · ');
    final record = teamGateMutation(team, gate);
    void open() => showGateSheet(context, team, gate.id, now: () => now);
    return KitRow(
      leading: KitRowIcon(icon),
      title: gate.title,
      supporting: TextSpan(text: subtitle),
      supportingMaxLines: 2,
      trailing: record == null || record.status == MutationStatus.confirmed
          ? const KitChevron()
          : TeamReceiptChip(
              key: ValueKey('activity-team-gate-${gate.id}-receipt'),
              record: record,
              onOpen: open,
            ),
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
    final (icon, _) = teamAgentGlyph(agent.state);
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
      leading: KitRowIcon(icon),
      title: agent.name,
      supporting: TextSpan(text: subtitle),
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
  try {
    await showKitSheet<void>(
      context,
      title: l10n.e7WorkspaceNeedsInput,
      subtitle: _sessionTitle(context, controller, question.sessionID),
      icon: AppIconography.question,
      routes: routes,
      sheetKey: const ValueKey('question-sheet'),
      body: (sheetContext) => _QuestionForm(
        question: question,
        controller: controller,
        request: request,
        routes: routes,
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
    final state = live ? l10n.workRunning : l10n.activityLastSeenRunning;
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

  const _QuestionForm({
    required this.question,
    required this.controller,
    required this.request,
    required this.routes,
    this.onOpenConversation,
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
  }

  void _changed() {
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final tokens = KitTokens.of(context);
    final prompts = widget.question.prompts;
    final connected = _canAnswer(widget.controller);
    final sendReason = !connected
        ? l10n.activitySendOffline
        : !_complete
        ? l10n.activityAnswerEveryQuestion
        : null;
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
          primary: KitAction(
            key: const ValueKey('question-send'),
            label: l10n.e7WorkspaceSendAnswers,
            working: _busy && !_confirming,
            disabledReason: sendReason,
            onPressed: sendReason == null && !_busy ? _submit : null,
          ),
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

/// Offers to keep the Inbox filling while the app is closed (map
/// `whenMissing: perm.notifications → offers-enable`).
class _BackgroundUpdatesHint extends StatelessWidget {
  final VoidCallback onOpen;

  const _BackgroundUpdatesHint({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return KitRow(
      key: const ValueKey('activity-background-settings'),
      leading: const KitRowIcon(AppIconography.activity),
      title: l10n.activityBackgroundUpdates,
      supporting: TextSpan(text: l10n.activityBackgroundOffDetail),
      supportingKey: const ValueKey('activity-background-hint'),
      supportingMaxLines: 2,
      trailing: const KitChevron(),
      onTap: onOpen,
    );
  }
}

/// A scoped result, rather than an unqualified claim about every project.
class _ActivityStatus extends StatelessWidget {
  const _ActivityStatus({required this.known, required this.onRefresh});
  final bool known;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return KitStateView(
      key: ValueKey(known ? 'activity-all-clear' : 'activity-status-unknown'),
      size: KitStateSize.inline,
      icon: known ? AppIconography.inbox : AppIconography.networkOff,
      // All caught up: the last sheet settles into the tray. Not known yet:
      // the unplugged drawing every load failure uses.
      illustration: known
          ? const StatesTrayScene()
          : const StatesUnpluggedScene(),
      title: known ? l10n.activityClearHere : l10n.activityStatusIncomplete,
      // The all-clear says what would fill this list, so an empty Inbox
      // reads as "watching" rather than "nothing here" (UX plan 5.8, item
      // 3). The unknown state keeps its own copy: teaching there would
      // claim a calm the app has not verified.
      body: known
          ? l10n.emptyTeachInboxMessage
          : l10n.activityUnknownStatusDetail,
      tertiary: [
        if (!known)
          KitAction(
            key: const ValueKey('activity-check-again'),
            label: l10n.activityCheckAgain,
            icon: AppIconography.retry,
            onPressed: onRefresh,
          ),
      ],
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
