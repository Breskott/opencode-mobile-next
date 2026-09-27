/// The dispatch cycle strip (TEAM-116): six steps — Routed, Agent
/// starting, Claimed, Working, Pushed, Handed to merge — with Merged as
/// the end mark, so a person who just started a task sees which step the
/// team is on and why it waits. Done steps carry a check and their time,
/// the current step the kit's working mark (a still dot under reduced
/// motion), future steps the waiting ring. Under the strip: "usually 1–5
/// min" while an agent starts, or — when the step waited past its window —
/// one notice saying why, with at most two ways out (Refresh, "How the
/// host dispatches", Open agent output, Stop agent, Nudge refinery).
///
/// [TeamCycleStrip.compact] is the Workspace card's form: one row of marks
/// with the current step word and since when, plus the hint or the stall
/// sentence; no buttons (the card's own Refresh is the action).
///
/// Built from kit parts only (shared-team-1): [KitStatusMark] for every
/// step, [KitNotice] for the stall, [KitText] for words, [showKitSheet] for
/// the How sheet; the agent's output is its conversation. The kit's
/// working mark owns its own motion and holds still under reduced motion,
/// so the strip no longer runs a pulse of its own.
///
/// Map (docs/ux-system/map/all.json): `embedded-team-cycle-strip` is a
/// redesign; its new structure (the task's four outcome stages, no buttons)
/// is deferred to slice-P5.1 (the team's Now line). This is the kit-only
/// rebuild of today's layout.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_motion.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_status_mark.dart';
import '../kit/kit_text.dart';
import '../kit/kit_tokens.dart';
import '../screens/team_conversation/team_conversation.dart'
    show openTeamAgentConversationById;
import 'team_controls.dart';
import 'team_now.dart' show teamAgentTitle;
import 'team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The one word for a dispatch step.
String teamCycleStepWord(AppLocalizations l10n, DispatchStep step) =>
    switch (step) {
      DispatchStep.routed => l10n.teamUiCycleStepRouted,
      DispatchStep.agentStarting => l10n.teamUiCycleStepAgentStarting,
      DispatchStep.claimed => l10n.teamUiCycleStepClaimed,
      DispatchStep.working => l10n.teamUiCycleStepWorking,
      DispatchStep.pushed => l10n.teamUiCycleStepPushed,
      DispatchStep.handedToMerge => l10n.teamUiCycleStepHandedToMerge,
      DispatchStep.merged => l10n.teamUiCycleStepMerged,
    };

/// The one sentence for a stall reason (05-beads TEAM-116 table).
String teamCycleStallSentence(AppLocalizations l10n, DispatchStall stall) =>
    switch (stall) {
      DispatchStall.hostNotStarted => l10n.teamUiCycleStallHostNotStarted,
      DispatchStall.agentCannotStart => l10n.teamUiCycleStallAgentCannotStart,
      DispatchStall.providerLimit => l10n.teamUiCycleStallProviderLimit,
      DispatchStall.workingLong => l10n.teamUiCycleStallWorkingLong,
      DispatchStall.mergeWaiting => l10n.teamUiCycleStallMergeWaiting,
    };

/// The step the strip names as current: the pending dot, or the last dot
/// while the merge itself is what is awaited.
DispatchStep teamCycleCurrentStep(DispatchCycle cycle) =>
    cycle.step.isDot ? cycle.step : DispatchStep.handedToMerge;

/// The screen-reader label: "Step 2 of 6, Agent starting, since 22:44".
String teamCycleSemanticsLabel(
  BuildContext context,
  AppLocalizations l10n,
  DispatchCycle cycle,
) {
  final total = DispatchStep.dots.length;
  final since = cycle.since;
  final time = since == null ? null : teamClockLabel(context, since);
  if (cycle.isTerminal) {
    return l10n.teamUiCycleSemanticsMerged(total, time ?? '');
  }
  final step = teamCycleStepWord(l10n, teamCycleCurrentStep(cycle));
  return time == null
      ? l10n.teamUiCycleSemanticsNoTime(cycle.position, total, step)
      : l10n.teamUiCycleSemantics(cycle.position, total, step, time);
}

// revamp: merge-into:team-conversation (slice-P5.1)
/// Opens the small sheet that explains the host's polling chain in three
/// lines.
Future<void> showTeamCycleHowSheet(BuildContext context) {
  final l10n = _copy(context);
  return showKitSheet<void>(
    context,
    sheetKey: const ValueKey('team-cycle-how-sheet'),
    title: l10n.teamUiCycleActionHow,
    icon: AppIconography.info,
    primary: KitAction(
      key: const ValueKey('team-cycle-how-close'),
      label: l10n.teamUiCycleHowClose,
      onPressed: () => Navigator.of(context).pop(),
    ),
    body: (sheetContext) {
      final tokens = KitTokens.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in [
            l10n.teamUiCycleHowLine1,
            l10n.teamUiCycleHowLine2,
            l10n.teamUiCycleHowLine3,
          ])
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: tokens.space3),
              child: KitText(line),
            ),
        ],
      );
    },
  );
}

class TeamCycleStrip extends StatefulWidget {
  const TeamCycleStrip({
    super.key,
    required this.controller,
    required this.workId,
    this.compact = false,
    this.pulse,
    this.ownPulse = true,
  });

  final OrchestrationController controller;

  /// Retired by shared-team-1: the kit's working mark owns its motion. Kept
  /// so old call sites compile; ignored.
  final AnimationController? pulse;

  /// Retired by shared-team-1 with [pulse]; ignored.
  final bool ownPulse;

  /// The work item whose cycle is shown (a batch passes its
  /// least-advanced item, [OrchestrationController.cycleWorkForRun]).
  final String workId;

  /// The card's one-row form: marks, the current step word and since when,
  /// the hint or stall sentence; no buttons.
  final bool compact;

  @override
  State<TeamCycleStrip> createState() => TeamCycleStripState();
}

/// Public so tests can read [debugHasAnimation].
class TeamCycleStripState extends State<TeamCycleStrip> {
  bool _busy = false;
  bool _moving = false;

  /// True while the current step's mark moves: motion allowed and the item
  /// not merged.
  bool get debugHasAnimation => _moving;

  @override
  void initState() {
    super.initState();
    widget.controller.watchCycles();
  }

  @override
  void didUpdateWidget(TeamCycleStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.unwatchCycles();
      widget.controller.watchCycles();
    }
  }

  @override
  void dispose() {
    widget.controller.unwatchCycles();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() => _run(widget.controller.refresh);

  /// The agent's conversation (watching), or its live output.
  void _openOutput(String agentId) => unawaited(
    openTeamAgentConversationById(context, widget.controller, agentId),
  );

  // revamp: merge-into:team-agent-stop-confirm-sheet (screen-team-1)
  Future<void> _stop(String agentId) async {
    final l10n = _copy(context);
    final name = _agentName(l10n, agentId);
    final ok = await confirmTeamControl(
      context,
      title: l10n.teamUiControlStopConfirmTitle(name),
      message: l10n.teamUiControlStopConfirmBody,
      confirmLabel: l10n.teamUiControlStopConfirmAction,
      sheetKey: const ValueKey('team-cycle-stop-confirm'),
      confirmKey: const ValueKey('team-cycle-stop-confirm-action'),
    );
    if (!ok || !mounted) return;
    await _run(
      () => widget.controller.controlAgent(agentId, AgentControlAction.stop),
    );
  }

  Future<void> _nudge(String agentId) => _run(
    () => widget.controller.controlAgent(agentId, AgentControlAction.nudge),
  );

  /// The agent in the person's words ("Worker · furiosa"), never the
  /// engine's address; the id only when the agent is not in the list.
  String _agentName(AppLocalizations l10n, String agentId) {
    for (final agent in widget.controller.snapshot.agents) {
      if (agent.id == agentId || agent.sessionId == agentId) {
        return teamAgentTitle(l10n, agent);
      }
    }
    return agentId;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    final cycle = controller.cycleFor(widget.workId);
    final label = teamCycleSemanticsLabel(context, l10n, cycle);
    _moving = !KitMotion.reduced(context) && !cycle.isTerminal;

    if (widget.compact) {
      final note = _note(l10n, cycle, const []);
      return Column(
        key: const ValueKey('team-cycle-strip'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(child: _CompactRow(cycle: cycle)),
          ),
          if (note != null) ...[SizedBox(height: tokens.space1), note],
        ],
      );
    }

    final agentId = controller.cycleAgentFor(widget.workId);
    final canControl = controller.capabilities.controlAgent && !_busy;
    final refineryId = controller.cycleRefineryFor(widget.workId);
    final receipt = agentId == null
        ? null
        : controller.latestMutation(
            kind: MutationKind.controlAgent,
            targetId: agentId,
          );
    final stall = cycle.stalled ? cycle.stallReason : null;
    final note = _note(
      l10n,
      cycle,
      stall == null
          ? const []
          : _stallActions(
              l10n,
              stall,
              agentId: agentId,
              refineryId: refineryId,
              canControl: canControl,
            ),
    );
    return Column(
      key: const ValueKey('team-cycle-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: label,
          child: ExcludeSemantics(child: _Steps(cycle: cycle)),
        ),
        if (note != null) ...[SizedBox(height: tokens.space2), note],
        if (receipt != null && !receipt.isSettled) ...[
          SizedBox(height: tokens.space2),
          teamControlReceipt(
            context,
            receipt,
            key: const ValueKey('team-cycle-receipt'),
          ),
        ],
      ],
    );
  }

  /// The ways out a stall reason calls for, most helpful first; the notice
  /// shows at most two (05-beads TEAM-116 table).
  List<KitAction> _stallActions(
    AppLocalizations l10n,
    DispatchStall stall, {
    required String? agentId,
    required String? refineryId,
    required bool canControl,
  }) {
    final refresh = KitAction(
      key: const ValueKey('team-cycle-action-refresh'),
      label: l10n.teamUiCardRefresh,
      icon: AppIconography.sync,
      working: _busy,
      onPressed: _busy ? null : _refresh,
    );
    final how = KitAction(
      key: const ValueKey('team-cycle-action-how'),
      label: l10n.teamUiCycleActionHow,
      icon: AppIconography.info,
      onPressed: () => showTeamCycleHowSheet(context),
    );
    final agent = agentId;
    final output = KitAction(
      key: const ValueKey('team-cycle-action-output'),
      label: l10n.teamUiCycleActionOpenOutput,
      icon: AppIconography.terminal,
      onPressed: agent == null ? null : () => _openOutput(agent),
      disabledReason: agent == null ? l10n.teamCycleStripNoAgentYet : null,
    );
    final refinery = refineryId;
    return switch (stall) {
      DispatchStall.hostNotStarted => [refresh, how],
      DispatchStall.agentCannotStart => [how, refresh],
      DispatchStall.providerLimit => [
        output,
        if (canControl && agent != null)
          KitAction(
            key: const ValueKey('team-cycle-action-stop'),
            label: l10n.teamUiControlStopConfirmAction,
            icon: AppIconography.stop,
            destructive: true,
            onPressed: () => _stop(agent),
          ),
      ],
      DispatchStall.workingLong => [output],
      DispatchStall.mergeWaiting => [
        if (canControl && refinery != null)
          KitAction(
            key: const ValueKey('team-cycle-action-nudge'),
            label: l10n.teamUiCycleActionNudgeRefinery,
            icon: AppIconography.forward,
            onPressed: () => _nudge(refinery),
          )
        else
          refresh,
      ],
    };
  }

  /// The line under the strip: the usual-wait hint while an agent
  /// starts, the stall notice (with its ways out) when stalled, nothing
  /// otherwise. A stall is a condition, not "needs you": the neutral tone
  /// with the warning glyph (LOOK-4).
  Widget? _note(
    AppLocalizations l10n,
    DispatchCycle cycle,
    List<KitAction> actions,
  ) {
    final stall = cycle.stallReason;
    if (cycle.stalled && stall != null) {
      return KitNotice(
        key: const ValueKey('team-cycle-stall'),
        icon: AppIconography.warning,
        message: teamCycleStallSentence(l10n, stall),
        actions: actions,
      );
    }
    if (cycle.hint == DispatchHint.usualWait) {
      return KitText(
        l10n.teamUiCycleWaitingForAgent,
        key: const ValueKey('team-cycle-hint'),
        role: KitTextRole.secondary,
        tone: KitTextTone.secondary,
      );
    }
    return null;
  }
}

/// Whether a step is done, current or still to come, as the kit's mark.
/// The current step is the kit's working mark, which holds still under
/// reduced motion on its own.
KitMarkState _markOf(DispatchCycle cycle, DispatchStep step) {
  if (cycle.isDone(step)) return KitMarkState.done;
  if (step == cycle.step && !cycle.isTerminal) return KitMarkState.working;
  return KitMarkState.waiting;
}

// ---------------------------------------------------------------------------
// Full strip
// ---------------------------------------------------------------------------

/// The six steps and the end mark, wrapping to as many rows as the width
/// needs (two at 320dp).
class _Steps extends StatelessWidget {
  const _Steps({required this.cycle});

  final DispatchCycle cycle;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Wrap(
      spacing: tokens.space3,
      runSpacing: tokens.space2,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        for (final step in DispatchStep.dots)
          _StepChip(
            key: ValueKey('team-cycle-step-${step.name}'),
            step: step,
            mark: _markOf(cycle, step),
            at: cycle.reachedAt[step],
          ),
        _StepChip(
          key: const ValueKey('team-cycle-end'),
          step: DispatchStep.merged,
          mark: _markOf(cycle, DispatchStep.merged),
          at: cycle.reachedAt[DispatchStep.merged],
        ),
      ],
    );
  }
}

/// One step: the kit's mark with the step's word beside it, and under it
/// the time a done step was reached.
class _StepChip extends StatelessWidget {
  const _StepChip({
    super.key,
    required this.step,
    required this.mark,
    required this.at,
  });

  final DispatchStep step;
  final KitMarkState mark;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final reachedAt = at;
    final sub = mark == KitMarkState.done && reachedAt != null
        ? teamClockLabel(context, reachedAt)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitStatusMark(
          state: mark,
          label: teamCycleStepWord(l10n, step),
          showLabel: true,
        ),
        if (sub != null)
          Padding(
            padding: EdgeInsetsDirectional.only(start: KitTokens.markSlotSize),
            child: KitText(
              sub,
              role: KitTextRole.caption,
              tone: KitTextTone.tertiary,
              tabular: true,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact strip
// ---------------------------------------------------------------------------

/// One row: the seven marks in a line, then "{step} · since {time}".
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.cycle});

  final DispatchCycle cycle;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final marks = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in DispatchStep.dots)
          KitStatusMark(
            key: ValueKey('team-cycle-dot-${step.name}'),
            state: _markOf(cycle, step),
            label: teamCycleStepWord(l10n, step),
          ),
        KitStatusMark(
          key: const ValueKey('team-cycle-dot-merged'),
          state: _markOf(cycle, DispatchStep.merged),
          label: teamCycleStepWord(l10n, DispatchStep.merged),
        ),
      ],
    );
    final since = cycle.since;
    final time = since == null ? null : teamClockLabel(context, since);
    final word = teamCycleStepWord(
      l10n,
      cycle.isTerminal ? DispatchStep.merged : teamCycleCurrentStep(cycle),
    );
    final line = time == null ? word : l10n.teamUiCycleCurrent(word, time);
    return Wrap(
      spacing: tokens.space2,
      runSpacing: tokens.space1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        marks,
        KitText(
          line,
          key: const ValueKey('team-cycle-current'),
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
      ],
    );
  }
}
