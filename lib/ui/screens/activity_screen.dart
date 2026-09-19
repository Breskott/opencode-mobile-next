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
import '../app_theme.dart';
import '../desktop/desktop_interaction.dart';
import '../permission_presentation.dart';
import '../widgets/product_states.dart';
import '../widgets/completion_digest.dart';
import '../widgets/question_options.dart';
import '../widgets/relative_time.dart';
import '../widgets/request_routes.dart';
import '../widgets/team_receipt.dart';
import '../widgets/team_vocabulary.dart';
import 'chat/form_flow.dart';
import 'chat/permission_sheet.dart';
import 'settings_screen.dart';
import 'profile_monitor_screen.dart';
import 'run_result_screen.dart';
import 'team/agent_screen.dart';
import 'team/gate_sheet.dart';

/// Activity: the single cross-session control centre (audit §3, §8).
///
/// It replaces the former Mission Control and Pending requests screens, which
/// showed the same pending count behind two mental models. One destination,
/// one badge, two sections — a pure inbox:
///
/// 1. **Needs attention** — permissions, questions, and v2 forms, each row
///    opening the *exact* resolver (the same permission sheet and form flow
///    chat uses), never merely a link to the related chat. When the
///    connected server runs the AI Team plugin, its gates join the same
///    list in the BRD §47 order — decision requested, run failed, then the
///    app's own permissions, then review ready, gate beads and blocked
///    agents — each opening the read-only Gate sheet (02-ux §6).
/// 2. **Running** — sessions busy right now, with their subagent counts.
///
/// Every row is server truth the controller already holds; nothing here is
/// estimated. Session history and cross-project discovery live in Workspace
/// and the all-sessions finder, not here: an empty inbox reads as success.
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
  /// already supplies the app bar. Pushed routes (deep links, notifications)
  /// keep their own Scaffold.
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
        showQuestionSheet(context, controller, question);
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

  Widget _completionDigests() {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(AppIconography.checklist),
          title: Text(l10n.digestTitle),
          subtitle: _showDigests ? Text(l10n.digestSubtitle) : null,
          trailing: Icon(
            _showDigests
                ? AppIconography.chevronUp
                : AppIconography.chevronDown,
          ),
          onTap: () => setState(() => _showDigests = !_showDigests),
        ),
        if (_showDigests && sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.digestEmpty),
          ),
        if (_showDigests)
          for (final session in sessions) ...[
            ListTile(
              title: Text(
                session.title?.trim().isNotEmpty == true
                    ? session.title!
                    : _l10n(context).globalSessionsUntitled,
              ),
              subtitle: Text(l10n.digestIdle),
              trailing: Icon(
                _expandedDigests.contains((session.id, session.time!.idle!))
                    ? AppIconography.chevronUp
                    : AppIconography.chevronDown,
              ),
              onTap: () => setState(() {
                final key = (session.id, session.time!.idle!);
                if (!_expandedDigests.remove(key)) _expandedDigests.add(key);
              }),
            ),
            if (_expandedDigests.contains((session.id, session.time!.idle!)))
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
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RunResultScreen(
                        controller: controller,
                        sessionID: session.id,
                      ),
                    ),
                  );
                },
                onDismiss: () => setState(() {
                  final key = (session.id, session.time!.idle!);
                  _dismissedDigests.add(key);
                  _expandedDigests.remove(key);
                }),
              ),
          ],
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsSettingsScreen(controller: widget.controller),
      ),
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
      showQuestionSheet(context, widget.controller, current);
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
    final missing = lookupAppLocalizations(
      Localizations.localeOf(context),
    ).sessionsDetailsUnavailable;
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
          controller.sessionDetailsErrors[sessionID] ?? missing,
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
      if (mounted) showProductError(context, error);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    _clearDigestScope();
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

    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: loading && empty
          ? const LoadingList()
          : error != null && empty
          ? ProductErrorState(message: error, onRetry: _refresh)
          : empty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!hasCheckIns) ...[
                  _ActivityStatus(
                    known:
                        controller.isConnected &&
                        controller.unknownAttentionProfileCount == 0,
                    onRefresh: _refresh,
                  ),
                ],
                ProfileMonitorInbox(controller: controller, compact: true),
                // An empty inbox is only reassuring if it would fill while
                // the app is closed; when it would not, say what to turn on.
                if (platformCapabilities.supportsBackgroundService &&
                    !controller.keepLiveInBackground)
                  _BackgroundUpdatesHint(
                    onOpen: () => _openBackgroundSettings(context),
                  ),
                _completionDigests(),
              ],
            )
          : DesktopScrollbarArea(
              builder: (scrollController) => ListView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (loading) const LinearProgressIndicator(minHeight: 2),
                  if (error != null)
                    ProductInlineEmpty(
                      icon: Icons.sync_problem_rounded,
                      title: _l10n(context).e7WorkspaceRefreshFailed,
                      message: error,
                      actionLabel: _l10n(context).isolatedTaskRetryOpen,
                      onAction: _refresh,
                    ),
                  if (attentionCount > 0)
                    SectionLabel(_l10n(context).setupSwitchAttention),
                  for (final row in team)
                    if (row.rank < teamActivityPermissionRank) row.widget,
                  for (final permission in permissions)
                    ActivityPermissionTile(
                      key: ValueKey('activity-permission-${permission.id}'),
                      permission: permission,
                      controller: controller,
                    ),
                  for (final question in questions)
                    ActivityQuestionTile(
                      key: ValueKey('activity-question-${question.id}'),
                      question: question,
                      controller: controller,
                    ),
                  for (final form in sessionForms)
                    ActivityFormTile(form: form, controller: controller),
                  for (final row in team)
                    if (row.rank > teamActivityPermissionRank) row.widget,
                  if (globalForms.isNotEmpty) ...[
                    SectionLabel(_l10n(context).e7WorkspaceServerRequests),
                    for (final form in globalForms)
                      ActivityFormTile(form: form, controller: controller),
                  ],
                  ProfileMonitorInbox(controller: controller, compact: true),
                  if (running.isNotEmpty)
                    SectionLabel(_l10n(context).workRunning),
                  if (running.isNotEmpty)
                    for (final session in running)
                      _SessionRow(
                        key: ValueKey('activity-running-${session.id}'),
                        session: session,
                        running: true,
                        subagents: _subagentCount(session.id),
                        detail:
                            controller.sessionDetailsErrors[session.id] ??
                            _place(session),
                        onTap: () => _openChat(session.id),
                      ),
                  _completionDigests(),
                ],
              ),
            ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(_l10n(context).shellTabInbox),
        actions: [
          IconButton(
            tooltip: _l10n(context).globalSessionsRefresh,
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIconography.retry),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// One permission component, three entry points: this row opens the same
/// sheet the chat auto-presents, so resolving here is resolving there.
class ActivityPermissionTile extends StatelessWidget {
  final PermissionRequest permission;
  final ConnectionController controller;

  const ActivityPermissionTile({
    super.key,
    required this.permission,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = permission.permission.isEmpty
        ? _l10n(context).e7WorkspacePermissionRequired
        : permissionRequestTitle(permission.permission);
    return ListTile(
      minTileHeight: 66,
      leading: Icon(AppIconography.shield, color: theme.colorScheme.tertiary),
      title: Text(title),
      subtitle: Text(
        permission.patterns.isNotEmpty
            ? permission.patterns.first
            : _sessionTitle(context, controller, permission.sessionID),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: permission.patterns.isNotEmpty
            ? const TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: AppTheme.codeFontSize,
              )
            : null,
      ),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: () => showPermissionSheet(
        context,
        permission: permission,
        controller: controller,
        contextLabel: _l10n(context).e7WorkspaceRequestFor(
          _sessionTitle(context, controller, permission.sessionID),
        ),
      ),
    );
  }
}

class ActivityQuestionTile extends StatelessWidget {
  final PendingQuestion question;
  final ConnectionController controller;

  const ActivityQuestionTile({
    super.key,
    required this.question,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 66,
      leading: Icon(
        AppIconography.supportQuestion,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        question.prompts.isEmpty
            ? _l10n(context).e7WorkspaceAssistantQuestion
            : question.prompts.first.title,
      ),
      subtitle: Text(
        question.prompts.isEmpty
            ? _sessionTitle(context, controller, question.sessionID)
            : question.prompts.first.question,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: () => showQuestionSheet(context, controller, question),
    );
  }
}

class ActivityFormTile extends StatelessWidget {
  final Api2FormInfo form;
  final ConnectionController controller;

  const ActivityFormTile({
    super.key,
    required this.form,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final count = form.fields.length;
    return ListTile(
      key: ValueKey('form-request-tile-${form.id}'),
      minTileHeight: 66,
      leading: Icon(
        AppIconography.checklist,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(form.title ?? _l10n(context).e7WorkspaceInputRequested),
      subtitle: Text(
        form.sessionID == 'global'
            ? _l10n(context).e7WorkspaceMcpAsked
            : _l10n(context).e7WorkspaceQuestionCount(
                count,
                _sessionTitle(context, controller, form.sessionID),
              ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: () => presentConnectionForm(context, controller, form),
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
    final theme = Theme.of(context);
    final (icon, tone) = teamGateGlyph(gate.kind);
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
    return ListTile(
      minTileHeight: 66,
      leading: Icon(icon, color: AppTheme.statusColor(theme, tone)),
      title: Text(gate.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: record == null || record.status == MutationStatus.confirmed
          ? const Icon(AppIconography.chevronRight)
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
    final theme = Theme.of(context);
    final (icon, tone) = teamAgentGlyph(agent.state);
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
    return ListTile(
      minTileHeight: 66,
      leading: Icon(icon, color: AppTheme.statusColor(theme, tone)),
      title: Text(agent.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(AppIconography.chevronRight),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AgentScreen(controller: team, agentId: agent.id, now: () => now),
        ),
      ),
    );
  }
}

/// The exact answer surface, shared by Activity rows and notification taps.
Future<void> showQuestionSheet(
  BuildContext context,
  ConnectionController controller,
  PendingQuestion question,
) async {
  final request = controller.questionIdentity(question);
  if (!controller.isRequestPending(request)) return;
  final routes = RequestRoutes(
    changes: controller,
    isPending: () => controller.isRequestPending(request),
  );
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        routes.own(ModalRoute.of(context));
        return _QuestionSheet(
          question: question,
          controller: controller,
          request: request,
          routes: routes,
        );
      },
    );
  } finally {
    routes.close();
  }
}

class _SessionRow extends StatelessWidget {
  final Session session;
  final bool running;
  final int subagents;
  final String detail;
  final VoidCallback onTap;

  const _SessionRow({
    super.key,
    required this.session,
    required this.running,
    required this.subagents,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = session.title?.trim().isNotEmpty == true
        ? session.title!.trim()
        : _l10n(context).globalSessionsUntitled;
    return ListTile(
      leading: running
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              AppIconography.chat,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: detail.isEmpty
          ? null
          : Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subagents > 0)
            Tooltip(
              message: _l10n(context).e7WorkspaceSubagentCount(subagents),
              child: Badge(
                label: Text('$subagents'),
                child: const Icon(AppIconography.branch, size: 19),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(AppIconography.chevronRight),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _QuestionSheet extends StatefulWidget {
  final PendingQuestion question;
  final ConnectionController controller;
  final PendingRequestIdentity request;
  final RequestRoutes routes;

  const _QuestionSheet({
    required this.question,
    required this.controller,
    required this.request,
    required this.routes,
  });

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
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
  /// tap replaces the choice and clears custom text; a multi-select tap
  /// toggles the choice and keeps custom text.
  void _toggle(int index, QuestionPrompt prompt, QuestionChoice choice) {
    setState(() {
      if (prompt.multiple) {
        if (!_answers[index].remove(choice.label)) {
          _answers[index].add(choice.label);
        }
      } else {
        _custom[index].clear();
        _answers[index]
          ..clear()
          ..add(choice.label);
      }
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          widget.routes.own(ModalRoute.of(context));
          return AlertDialog(
            title: Text(_l10n(context).e7WorkspaceDismissRequest),
            content: Text(_l10n(context).e7WorkspaceDismissDetail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_l10n(context).projectFolderCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_l10n(context).workspaceDismissNotice),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted || !widget.routes.isPending) return;
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
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final availableHeight = (media.size.height - media.viewInsets.bottom - 8)
        .clamp(96.0, media.size.height * .9);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SizedBox(
            height: availableHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(
                        _l10n(context).e7WorkspaceNeedsInput,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sessionTitle(
                          context,
                          widget.controller,
                          widget.question.sessionID,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedOf(theme),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (
                        var index = 0;
                        index < widget.question.prompts.length;
                        index++
                      )
                        Builder(
                          builder: (context) {
                            final prompt = widget.question.prompts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prompt.title,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(prompt.question),
                                  const SizedBox(height: 10),
                                  for (final choice in prompt.choices)
                                    QuestionOptionRow(
                                      choice: choice,
                                      multiple: prompt.multiple,
                                      selected: _answers[index].contains(
                                        choice.label,
                                      ),
                                      enabled: !_busy,
                                      onTap: () =>
                                          _toggle(index, prompt, choice),
                                    ),
                                  if (prompt.custom)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: QuestionCustomAnswerField(
                                        controller: _custom[index],
                                        enabled: !_busy,
                                        onChanged: (value) {
                                          setState(() {
                                            if (!prompt.multiple &&
                                                value.trim().isNotEmpty) {
                                              _answers[index].clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _reject,
                      child: Text(_l10n(context).workspaceDismissNotice),
                    ),
                    FilledButton(
                      onPressed: _complete && !_busy ? _submit : null,
                      child: _busy && !_confirming
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_l10n(context).e7WorkspaceSendAnswers),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _custom) {
      controller.dispose();
    }
    super.dispose();
  }
}

String _sessionTitle(
  BuildContext context,
  ConnectionController controller,
  String id,
) {
  final session = controller.sessionsById[id];
  return session?.title?.isNotEmpty == true
      ? session!.title!
      : _l10n(context).e7WorkspaceSessionId(id);
}

class _BackgroundUpdatesHint extends StatelessWidget {
  final VoidCallback onOpen;

  const _BackgroundUpdatesHint({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return ListTile(
      key: const ValueKey('activity-background-settings'),
      leading: const Icon(AppIconography.activity),
      title: Text(l10n.activityBackgroundUpdates),
      subtitle: Text(
        l10n.activityBackgroundOffDetail,
        key: const ValueKey('activity-background-hint'),
      ),
      trailing: const Icon(AppIconography.chevronRight),
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
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return Padding(
      key: ValueKey(known ? 'activity-all-clear' : 'activity-status-unknown'),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            known ? AppIconography.checkCircle : Icons.sync_problem_rounded,
            size: 32,
            color: known
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            known ? l10n.activityClearHere : l10n.activityStatusIncomplete,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            known
                ? l10n.activityCheckedLocationsClear
                : l10n.activityUnknownStatusDetail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!known)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(AppIconography.retry),
                label: Text(l10n.activityCheckAgain),
              ),
            ),
        ],
      ),
    );
  }
}

AppLocalizations _l10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(Localizations.localeOf(context));
