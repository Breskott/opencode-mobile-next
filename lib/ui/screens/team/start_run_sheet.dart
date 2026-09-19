/// Start a run (TEAM-204; 02-ux-flows-and-screens §7, 06-decisions §A.3):
/// the sheet behind the AI Team home's FAB. **Objective** (multi-line),
/// **Project** (rig picker, "Let the planner choose" by default),
/// **Supervision** (High / Balanced / Autonomous with their descriptions),
/// **Planner** (shown, not chosen: the Mayor), **Boundaries** (read-only
/// host policy from `controller.policy`, TEAM-207; the row is absent when
/// the host reports none rather than invented), then [Send to planner].
///
/// Sending is one `messageAgent` to `gastown.mayor` — the supervisor has
/// no objective endpoint, so the objective and the supervision line go as
/// the message ([composeTeamPlanningMessage]). A planner the host lists as
/// suspended or stopped (the lean profile) turns the form into "The
/// planner (Mayor) is off on this host" with the host guide; nothing is
/// sent — unless the host can create work itself
/// (`controlCreateWork`, the phone's loopback supervisor, TEAM-306), in
/// which case the sheet offers the **direct task** form instead: a
/// project, a title and optional details go as one bead
/// (`createWork`) slung at the project's worker pool
/// (`<rig>/gastown.polecat`, [teamWorkerPoolId]) through
/// [OrchestrationController.giveTask]. A planner with no live session is
/// woken (`controlAgent(start)`)
/// before the message goes. The home then shows [TeamPlanningCard]
/// ("Planning… (Mayor)") until a run carrying the objective appears, or
/// "Still planning — check the planner's output" after 30 minutes.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_planning.dart';
import '../../app_theme.dart';
import '../../widgets/team_host_form.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_output_screen.dart';
import 'policy_block.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Opens the sheet; resolves with the message record once sent (the
/// `createWork` record for a direct task), null when the person backed
/// out or the planner was off with no direct path.
Future<MutationRecord?> showStartRunSheet(
  BuildContext context,
  OrchestrationController controller,
) => showModalBottomSheet<MutationRecord>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => StartRunSheet(controller: controller),
);

/// The supervision level's name and description.
(String, String) teamSupervisionCopy(
  AppLocalizations l10n,
  TeamSupervision level,
) => switch (level) {
  TeamSupervision.high => (
    l10n.teamUiStartRunSupervisionHigh,
    l10n.teamUiStartRunSupervisionHighHint,
  ),
  TeamSupervision.balanced => (
    l10n.teamUiStartRunSupervisionBalanced,
    l10n.teamUiStartRunSupervisionBalancedHint,
  ),
  TeamSupervision.autonomous => (
    l10n.teamUiStartRunSupervisionAutonomous,
    l10n.teamUiStartRunSupervisionAutonomousHint,
  ),
};

class StartRunSheet extends StatefulWidget {
  const StartRunSheet({super.key, required this.controller});

  final OrchestrationController controller;

  @override
  State<StartRunSheet> createState() => _StartRunSheetState();
}

class _StartRunSheetState extends State<StartRunSheet> {
  final _objective = TextEditingController();
  final _task = TextEditingController();
  final _details = TextEditingController();
  String? _projectId;
  String? _directProjectId;
  TeamSupervision _supervision = TeamSupervision.balanced;
  bool _sending = false;
  bool _waking = false;
  bool _showEmpty = false;
  bool _showTaskEmpty = false;
  String? _directError;

  @override
  void initState() {
    super.initState();
    _objective.addListener(_changed);
    _task.addListener(_changed);
  }

  @override
  void dispose() {
    _objective.dispose();
    _task.dispose();
    _details.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  OrchestrationProject? get _project {
    for (final project in widget.controller.snapshot.projects) {
      if (project.id == _projectId) return project;
    }
    return null;
  }

  Future<void> _send(OrchestrationAgent planner) async {
    final objective = _objective.text.trim();
    if (objective.isEmpty) {
      setState(() => _showEmpty = true);
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    final controller = widget.controller;
    try {
      if (planner.sessionId == null || planner.sessionId!.isEmpty) {
        // No live session to message: wake the planner first. The host
        // answers the message route by agent id once it is awake.
        setState(() => _waking = true);
        await controller.controlAgent(planner.id, AgentControlAction.start);
        if (!mounted) return;
        setState(() => _waking = false);
      }
      final record = await controller.messageAgent(
        planner.id,
        composeTeamPlanningMessage(
          objective: objective,
          supervision: _supervision,
          projectName: _project?.name,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(record);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _waking = false;
        });
      }
    }
  }

  /// The direct-task project: the chosen one, else the first listed.
  String? get _directProject {
    final projects = widget.controller.snapshot.projects;
    for (final project in projects) {
      if (project.id == _directProjectId) return project.id;
    }
    return projects.isEmpty ? null : projects.first.id;
  }

  /// The planner is off, but this host creates work: the direct form.
  bool get _direct {
    final controller = widget.controller;
    final planner = teamPlannerAgent(controller.snapshot.agents);
    final off = planner == null || teamPlannerIsOff(planner);
    return off &&
        controller.capabilities.controlCreateWork &&
        controller.snapshot.projects.isNotEmpty;
  }

  Future<void> _sendDirect() async {
    final title = _task.text.trim();
    if (title.isEmpty) {
      setState(() => _showTaskEmpty = true);
      return;
    }
    final projectId = _directProject;
    if (_sending || projectId == null) return;
    setState(() {
      _sending = true;
      _directError = null;
    });
    try {
      final details = _details.text.trim();
      final result = await widget.controller.giveTask(
        title: title,
        description: details.isEmpty ? null : details,
        projectId: projectId,
        agentId: teamWorkerPoolId(projectId),
      );
      if (!mounted) return;
      final created = result.created;
      if (created.status == MutationStatus.rejected) {
        // The bead was not made: stay, say why, let the person edit.
        setState(() => _directError = created.receipt?.message?.trim() ?? '');
        return;
      }
      // The bead exists; a refused sling comes back as its own record so
      // the home says so instead of "sent".
      final assigned = result.assigned;
      Navigator.of(context).pop(
        assigned != null && assigned.status == MutationStatus.rejected
            ? assigned
            : created,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final theme = Theme.of(context);
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      final planner = teamPlannerAgent(widget.controller.snapshot.agents);
      final Widget body;
      if (_direct) {
        body = _directForm(context);
      } else if (planner == null) {
        body = _PlannerOff(
          key: const ValueKey('team-start-run-planner-missing'),
          title: l10n.teamUiStartRunPlannerMissingTitle,
          message: l10n.teamUiStartRunPlannerMissingBody,
        );
      } else if (teamPlannerIsOff(planner)) {
        body = _PlannerOff(
          key: const ValueKey('team-start-run-planner-off'),
          title: l10n.teamUiStartRunPlannerOffTitle,
          message: l10n.teamUiStartRunPlannerOffBody,
        );
      } else {
        body = _form(context, planner);
      }
      return Padding(
        key: const ValueKey('team-start-run-sheet'),
        padding: EdgeInsets.only(bottom: inset),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.teamUiStartRunTitle,
                key: const ValueKey('team-start-run-title'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      );
    },
  );

  Widget _form(BuildContext context, OrchestrationAgent planner) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final projects = widget.controller.snapshot.projects;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(color: muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.teamUiStartRunObjectiveLabel, style: labelStyle),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('team-start-run-objective'),
          controller: _objective,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_sending,
          decoration: InputDecoration(
            hintText: l10n.teamUiStartRunObjectiveHint,
            border: const OutlineInputBorder(),
            errorText: _showEmpty && _objective.text.trim().isEmpty
                ? l10n.teamUiStartRunObjectiveEmpty
                : null,
          ),
        ),
        if (projects.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.teamUiStartRunProjectLabel, style: labelStyle),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            key: const ValueKey('team-start-run-project'),
            initialValue: _projectId,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.teamUiStartRunProjectAny),
              ),
              for (final project in projects)
                DropdownMenuItem<String?>(
                  key: ValueKey('team-start-run-project-${project.id}'),
                  value: project.id,
                  child: Text(
                    project.name,
                    textDirection: TextDirection.ltr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _sending
                ? null
                : (value) => setState(() => _projectId = value),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.teamUiStartRunSupervisionLabel, style: labelStyle),
        const SizedBox(height: 4),
        for (final level in TeamSupervision.values)
          _SupervisionRow(
            key: ValueKey('team-start-run-supervision-${level.name}'),
            level: level,
            selected: _supervision == level,
            onSelected: _sending
                ? null
                : () => setState(() => _supervision = level),
          ),
        const SizedBox(height: 12),
        Text(l10n.teamUiStartRunPlannerLabel, style: labelStyle),
        const SizedBox(height: 4),
        Row(
          key: const ValueKey('team-start-run-planner'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIconography.agent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        l10n.teamUiStartRunPlannerMayor,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        planner.id,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontFamily: AppTheme.monoFamily,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.teamUiStartRunPlannerHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.controller.policy case final policy?) ...[
          const SizedBox(height: 16),
          TeamBoundariesRow(policy: policy),
        ],
        const SizedBox(height: 20),
        if (_waking)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              key: const ValueKey('team-start-run-waking'),
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.teamUiStartRunWaking,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ),
        FilledButton.icon(
          key: const ValueKey('team-start-run-send'),
          onPressed: _sending ? null : () => _send(planner),
          icon: const Icon(AppIconography.send, size: 18),
          label: Text(l10n.teamUiStartRunSend),
        ),
      ],
    );
  }

  /// The direct task (TEAM-306): intro, project, title, details, Send to
  /// an agent, the host's refusal when any, and the host guide below for
  /// the person who would rather wake the planner.
  Widget _directForm(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final projects = widget.controller.snapshot.projects;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(color: muted);
    final error = _directError;
    final failure = AppTheme.statusColor(theme, AppStatusTone.failure);
    return Column(
      key: const ValueKey('team-start-run-direct'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIconography.agent, size: 20, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.teamUiStartRunDirectIntro,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.teamUiStartRunProjectLabel, style: labelStyle),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const ValueKey('team-start-run-direct-project'),
          initialValue: _directProject,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final project in projects)
              DropdownMenuItem<String>(
                key: ValueKey('team-start-run-direct-project-${project.id}'),
                value: project.id,
                child: Text(
                  project.name,
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _sending
              ? null
              : (value) => setState(() => _directProjectId = value),
        ),
        const SizedBox(height: 16),
        Text(l10n.teamUiStartRunDirectTitle, style: labelStyle),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('team-start-run-direct-title'),
          controller: _task,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          enabled: !_sending,
          decoration: InputDecoration(
            hintText: l10n.teamUiStartRunDirectTitleHint,
            border: const OutlineInputBorder(),
            errorText: _showTaskEmpty && _task.text.trim().isEmpty
                ? l10n.teamUiStartRunDirectTitleRequired
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.teamUiStartRunDirectDetails, style: labelStyle),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('team-start-run-direct-details'),
          controller: _details,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_sending,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('team-start-run-direct-error'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIconography.error, size: 18, color: failure),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.isEmpty
                      ? l10n.teamUiGateAnswerRejectedNoMessage
                      : l10n.teamUiStartRunDirectRefused(error),
                  style: theme.textTheme.bodySmall?.copyWith(color: failure),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('team-start-run-direct-send'),
          onPressed: _sending ? null : _sendDirect,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIconography.send, size: 18),
          label: Text(l10n.teamUiStartRunDirectSend),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('team-start-run-host-guide'),
            onPressed: () => showTeamHostGuideSheet(context),
            icon: const Icon(AppIconography.guide, size: 18),
            label: Text(l10n.teamUiStartRunHostGuide),
          ),
        ),
      ],
    );
  }
}

/// One supervision level: radio, name, description; the whole row taps.
class _SupervisionRow extends StatelessWidget {
  const _SupervisionRow({
    super.key,
    required this.level,
    required this.selected,
    required this.onSelected,
  });

  final TeamSupervision level;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final (name, hint) = teamSupervisionCopy(l10n, level);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? AppIconography.radioSelected
                    : AppIconography.radioEmpty,
                size: 22,
                color: selected
                    ? theme.colorScheme.primary
                    : AppTheme.mutedOf(theme),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedOf(theme),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The planner is missing or off: the reason and the host guide; no form.
class _PlannerOff extends StatelessWidget {
  const _PlannerOff({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final color = AppTheme.statusColor(theme, AppStatusTone.attention);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIconography.warning, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(message, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('team-start-run-host-guide'),
            onPressed: () => showTeamHostGuideSheet(context),
            icon: const Icon(AppIconography.guide, size: 18),
            label: Text(l10n.teamUiStartRunHostGuide),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The pending card on the home
// ---------------------------------------------------------------------------

/// "Planning… (Mayor)" for one Start-a-run request: the objective, the
/// state line, "Planner output" (the Mayor's live output page) and
/// Dismiss. Resolved requests (a run appeared) are not shown at all — the
/// run is in the list.
class TeamPlanningCard extends StatelessWidget {
  const TeamPlanningCard({
    super.key,
    required this.controller,
    required this.request,
    this.now,
  });

  final OrchestrationController controller;
  final TeamPlanningRequest request;
  final DateTime Function()? now;

  void _openPlannerOutput(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentOutputScreen(
          controller: controller,
          agentId: request.plannerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone, title) = switch (request.status) {
      TeamPlanningStatus.planning => (
        AppIconography.waiting,
        AppStatusTone.progress,
        l10n.teamUiStartRunPlanning,
      ),
      TeamPlanningStatus.stillPlanning => (
        AppIconography.timer,
        AppStatusTone.attention,
        l10n.teamUiStartRunStillPlanning,
      ),
      TeamPlanningStatus.unconfirmed => (
        AppIconography.warning,
        AppStatusTone.attention,
        l10n.teamUiStartRunUnconfirmed,
      ),
      TeamPlanningStatus.refused => (
        AppIconography.error,
        AppStatusTone.failure,
        l10n.teamUiStartRunRefused(request.record.receipt?.message ?? ''),
      ),
      TeamPlanningStatus.started => (
        AppIconography.checkCircle,
        AppStatusTone.ok,
        request.run?.title ?? request.objective,
      ),
    };
    final color = AppTheme.statusColor(theme, tone);
    return Container(
      key: ValueKey('team-planning-${request.key}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('team-planning-title'),
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.objective,
            key: const ValueKey('team-planning-objective'),
            style: theme.textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (request.status == TeamPlanningStatus.planning) ...[
            const SizedBox(height: 4),
            Text(
              l10n.teamUiStartRunPlanningHint,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.teamUiStartRunSentAt(teamClockLabel(context, request.sentAt)),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: const ValueKey('team-planning-output'),
                onPressed: () => _openPlannerOutput(context),
                icon: const Icon(AppIconography.terminal, size: 18),
                label: Text(l10n.teamUiStartRunPlannerOutput),
              ),
              TextButton(
                key: const ValueKey('team-planning-dismiss'),
                onPressed: () => controller.dismissPlanning(request.key),
                child: Text(l10n.teamUiStartRunDismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The pending cards for [controller] at [now]: every Start-a-run request
/// still waiting on a run, newest first; resolved and dismissed ones drop.
List<TeamPlanningRequest> teamPendingPlanning(
  OrchestrationController controller,
  DateTime now,
) => [
  for (final request in teamPlanningRequests(
    mutations: controller.mutations,
    runs: controller.snapshot.runs,
    dismissed: {
      for (final record in controller.mutations)
        if (controller.isPlanningDismissed(record.key)) record.key,
    },
    now: now,
  ))
    if (request.status != TeamPlanningStatus.started) request,
];
