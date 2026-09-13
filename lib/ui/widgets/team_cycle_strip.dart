/// The dispatch cycle strip (TEAM-116): six steps — Routed, Agent
/// starting, Claimed, Working, Pushed, Handed to merge — with Merged as
/// the end mark, so a person who just started a task sees which step the
/// team is on and why it waits. Done steps carry a check and their time,
/// the current step a pulsing dot (static under reduced motion), future
/// steps sit dim. Under the strip: "usually 1–5 min" while an agent
/// starts, or — when the step waited past its window — one sentence
/// saying why and one action (Refresh, "How the host dispatches", Open
/// agent output, Stop, Nudge refinery).
///
/// [TeamCycleStrip.compact] is the Workspace card's form: one row of dots
/// with the current step word and since when, plus the hint or the stall
/// sentence; no buttons (the card's own Refresh is the action).
///
/// Motion: one [AnimationController] for the current dot, not created at
/// all under reduced motion (`MediaQuery.disableAnimationsOf`) or once the
/// item merged, so no ticker ever runs there. A host that already runs
/// one pulse (the Workspace card) lends it through [TeamCycleStrip.pulse]
/// with [TeamCycleStrip.ownPulse] off, so the card keeps a single ticker.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';
import '../screens/team/agent_output_screen.dart';
import 'team_controls.dart';
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

/// Opens the small sheet that explains the host's polling chain in three
/// lines.
Future<void> showTeamCycleHowSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final l10n = _copy(sheetContext);
        final theme = Theme.of(sheetContext);
        return SingleChildScrollView(
          key: const ValueKey('team-cycle-how-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.teamUiCycleActionHow,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final line in [
                l10n.teamUiCycleHowLine1,
                l10n.teamUiCycleHowLine2,
                l10n.teamUiCycleHowLine3,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                  key: const ValueKey('team-cycle-how-close'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.teamUiCycleHowClose),
                ),
              ),
            ],
          ),
        );
      },
    );

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

  /// A pulse lent by the host widget, used only when [ownPulse] is false.
  final AnimationController? pulse;

  /// True (default) to create the strip's own pulse controller while a
  /// step is pending and motion is allowed; false to breathe with [pulse]
  /// and never own a ticker.
  final bool ownPulse;

  /// The work item whose cycle is shown (a batch passes its
  /// least-advanced item, [OrchestrationController.cycleWorkForRun]).
  final String workId;

  /// The card's one-row form: dots, the current step word and since when,
  /// the hint or stall sentence; no buttons.
  final bool compact;

  @override
  State<TeamCycleStrip> createState() => TeamCycleStripState();
}

/// Public so tests can read [debugHasAnimation].
class TeamCycleStripState extends State<TeamCycleStrip>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;
  bool _busy = false;

  /// True while the strip's own pulse controller exists (never under
  /// reduced motion, never once merged, never with a lent pulse).
  bool get debugHasAnimation => _pulse != null;

  AnimationController? get _activePulse =>
      widget.ownPulse ? _pulse : widget.pulse;

  @override
  void initState() {
    super.initState();
    widget.controller.watchCycles();
    widget.controller.addListener(_syncPulse);
  }

  @override
  void didUpdateWidget(TeamCycleStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncPulse);
      oldWidget.controller.unwatchCycles();
      widget.controller.watchCycles();
      widget.controller.addListener(_syncPulse);
    }
    if (oldWidget.workId != widget.workId) _syncPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPulse);
    widget.controller.unwatchCycles();
    _pulse?.dispose();
    super.dispose();
  }

  /// Creates the pulse only while a step is pending and motion is
  /// allowed; drops it (ticker and all) the moment either stops holding.
  void _syncPulse() {
    if (!mounted) return;
    final wanted =
        widget.ownPulse &&
        !MediaQuery.disableAnimationsOf(context) &&
        !widget.controller.cycleFor(widget.workId).isTerminal;
    if (wanted == (_pulse != null)) return;
    if (wanted) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
    setState(() {});
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

  void _openOutput(String agentId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AgentOutputScreen(controller: widget.controller, agentId: agentId),
      ),
    );
  }

  Future<void> _stop(String agentId) async {
    final l10n = _copy(context);
    final name = _agentName(agentId);
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

  String _agentName(String agentId) {
    for (final agent in widget.controller.snapshot.agents) {
      if (agent.id == agentId || agent.sessionId == agentId) {
        return agent.name;
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
    final theme = Theme.of(context);
    final controller = widget.controller;
    final cycle = controller.cycleFor(widget.workId);
    final label = teamCycleSemanticsLabel(context, l10n, cycle);
    final note = _note(l10n, theme, cycle);

    if (widget.compact) {
      return Column(
        key: const ValueKey('team-cycle-strip'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(
              child: _CompactRow(cycle: cycle, pulse: _activePulse),
            ),
          ),
          if (note != null) ...[const SizedBox(height: 2), note],
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
    return Column(
      key: const ValueKey('team-cycle-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: label,
          child: ExcludeSemantics(
            child: _Steps(cycle: cycle, pulse: _activePulse),
          ),
        ),
        if (note != null) ...[const SizedBox(height: 8), note],
        if (cycle.stalled && cycle.stallReason != null) ...[
          const SizedBox(height: 8),
          _Actions(
            stall: cycle.stallReason!,
            agentId: agentId,
            refineryId: refineryId,
            canControl: canControl,
            busy: _busy,
            onRefresh: _refresh,
            onHow: () => showTeamCycleHowSheet(context),
            onOpenOutput: _openOutput,
            onStop: _stop,
            onNudge: _nudge,
          ),
        ],
        if (receipt != null && !receipt.isSettled) ...[
          const SizedBox(height: 8),
          TeamReceiptChip(
            key: const ValueKey('team-cycle-receipt'),
            record: receipt,
            control: teamControlWord(l10n, receipt.request),
          ),
        ],
      ],
    );
  }

  /// The line under the strip: the usual-wait hint while an agent
  /// starts, the stall sentence when stalled, nothing otherwise.
  Widget? _note(AppLocalizations l10n, ThemeData theme, DispatchCycle cycle) {
    final stall = cycle.stallReason;
    if (cycle.stalled && stall != null) {
      final color = AppTheme.statusColor(theme, AppStatusTone.attention);
      return Row(
        key: const ValueKey('team-cycle-stall'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(AppIconography.warning, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              teamCycleStallSentence(l10n, stall),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      );
    }
    if (cycle.hint == DispatchHint.usualWait) {
      return Text(
        l10n.teamUiCycleWaitingForAgent,
        key: const ValueKey('team-cycle-hint'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.mutedOf(theme),
        ),
      );
    }
    return null;
  }
}

/// Whether a dot is done, current or still to come.
enum _Phase { done, current, future }

_Phase _phaseOf(DispatchCycle cycle, DispatchStep step) {
  if (cycle.isDone(step)) return _Phase.done;
  return step == cycle.step ? _Phase.current : _Phase.future;
}

// ---------------------------------------------------------------------------
// Full strip
// ---------------------------------------------------------------------------

/// The six step chips and the end mark, wrapping to as many rows as the
/// width needs (two at 320dp).
class _Steps extends StatelessWidget {
  const _Steps({required this.cycle, required this.pulse});

  final DispatchCycle cycle;
  final AnimationController? pulse;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: [
      for (final step in DispatchStep.dots)
        _StepChip(
          key: ValueKey('team-cycle-step-${step.name}'),
          step: step,
          phase: _phaseOf(cycle, step),
          at: cycle.reachedAt[step],
          pulse: pulse,
        ),
      _StepChip(
        key: const ValueKey('team-cycle-end'),
        step: DispatchStep.merged,
        phase: _phaseOf(cycle, DispatchStep.merged),
        at: cycle.reachedAt[DispatchStep.merged],
        pulse: pulse,
        end: true,
      ),
    ],
  );
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    super.key,
    required this.step,
    required this.phase,
    required this.at,
    required this.pulse,
    this.end = false,
  });

  final DispatchStep step;
  final _Phase phase;
  final DateTime? at;
  final AnimationController? pulse;

  /// The merge end mark: a check in a ring instead of a dot.
  final bool end;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = AppTheme.mutedOf(theme);
    final (color, weight) = switch (phase) {
      _Phase.done => (AppTheme.statusColor(theme, AppStatusTone.ok), null),
      _Phase.current => (colors.primary, FontWeight.w600),
      _Phase.future => (colors.outlineVariant, null),
    };
    final textColor = switch (phase) {
      _Phase.done => muted,
      _Phase.current => colors.onSurface,
      _Phase.future => muted.withValues(alpha: .6),
    };
    final reachedAt = at;
    final sub = phase == _Phase.done && reachedAt != null
        ? teamClockLabel(context, reachedAt)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Glyph(
                phase: phase,
                color: color,
                pulse: phase == _Phase.current ? pulse : null,
                size: 14,
                end: end,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  teamCycleStepWord(l10n, step),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: weight,
                  ),
                ),
              ),
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20),
              child: Text(
                sub,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact strip
// ---------------------------------------------------------------------------

/// One row: the seven glyphs in a line, then "{step} · since {time}".
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.cycle, required this.pulse});

  final DispatchCycle cycle;
  final AnimationController? pulse;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = AppTheme.mutedOf(theme);
    Color colorOf(_Phase phase) => switch (phase) {
      _Phase.done => AppTheme.statusColor(theme, AppStatusTone.ok),
      _Phase.current => colors.primary,
      _Phase.future => colors.outlineVariant,
    };
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in DispatchStep.dots) ...[
          _Glyph(
            key: ValueKey('team-cycle-dot-${step.name}'),
            phase: _phaseOf(cycle, step),
            color: colorOf(_phaseOf(cycle, step)),
            pulse: step == cycle.step ? pulse : null,
            size: 10,
          ),
          const SizedBox(width: 5),
        ],
        _Glyph(
          key: const ValueKey('team-cycle-dot-merged'),
          phase: _phaseOf(cycle, DispatchStep.merged),
          color: colorOf(_phaseOf(cycle, DispatchStep.merged)),
          pulse: cycle.step == DispatchStep.merged && !cycle.isTerminal
              ? pulse
              : null,
          size: 10,
          end: true,
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
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        dots,
        Text(
          line,
          key: const ValueKey('team-cycle-current'),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Glyph
// ---------------------------------------------------------------------------

/// A done step is a check, the current step a filled dot that breathes,
/// a future step a ring; the end mark is a ringed check.
class _Glyph extends StatelessWidget {
  const _Glyph({
    super.key,
    required this.phase,
    required this.color,
    required this.pulse,
    required this.size,
    this.end = false,
  });

  final _Phase phase;
  final Color color;
  final AnimationController? pulse;
  final double size;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final Widget glyph;
    switch (phase) {
      case _Phase.done:
        glyph = end
            ? DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(
                    AppIconography.check,
                    size: size * .7,
                    color: color,
                  ),
                ),
              )
            : Icon(AppIconography.check, size: size, color: color);
      case _Phase.current:
        glyph = DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: SizedBox.square(dimension: size * .8),
        );
      case _Phase.future:
        glyph = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: SizedBox.square(dimension: size * .8),
        );
    }
    final boxed = SizedBox.square(
      dimension: size,
      child: Center(child: glyph),
    );
    final animation = pulse;
    if (animation == null || phase != _Phase.current) return boxed;
    // A very small breath, nothing else moves.
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1,
        end: 1.3,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: boxed,
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// The one action a stall reason calls for (a quieter second one beside
/// it when the table names two).
class _Actions extends StatelessWidget {
  const _Actions({
    required this.stall,
    required this.agentId,
    required this.refineryId,
    required this.canControl,
    required this.busy,
    required this.onRefresh,
    required this.onHow,
    required this.onOpenOutput,
    required this.onStop,
    required this.onNudge,
  });

  final DispatchStall stall;
  final String? agentId;
  final String? refineryId;
  final bool canControl;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onHow;
  final ValueChanged<String> onOpenOutput;
  final ValueChanged<String> onStop;
  final ValueChanged<String> onNudge;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final agent = agentId;
    final refinery = refineryId;
    Widget primary(Key key, IconData icon, String label, VoidCallback? tap) =>
        FilledButton.tonalIcon(
          key: key,
          onPressed: tap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
    Widget secondary(Key key, IconData icon, String label, VoidCallback? tap) =>
        TextButton.icon(
          key: key,
          onPressed: tap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
    Widget refresh(Key key, bool lead) => (lead ? primary : secondary)(
      key,
      AppIconography.sync,
      l10n.teamUiCardRefresh,
      busy ? null : onRefresh,
    );
    Widget how(Key key, bool lead) => (lead ? primary : secondary)(
      key,
      AppIconography.info,
      l10n.teamUiCycleActionHow,
      onHow,
    );
    Widget output(Key key) => primary(
      key,
      AppIconography.terminal,
      l10n.teamUiCycleActionOpenOutput,
      agent == null ? null : () => onOpenOutput(agent),
    );
    final buttons = switch (stall) {
      DispatchStall.hostNotStarted => [
        refresh(const ValueKey('team-cycle-action-refresh'), true),
        how(const ValueKey('team-cycle-action-how'), false),
      ],
      DispatchStall.agentCannotStart => [
        how(const ValueKey('team-cycle-action-how'), true),
        refresh(const ValueKey('team-cycle-action-refresh'), false),
      ],
      DispatchStall.providerLimit => [
        output(const ValueKey('team-cycle-action-output')),
        if (canControl && agent != null)
          secondary(
            const ValueKey('team-cycle-action-stop'),
            AppIconography.stop,
            l10n.teamUiControlStop,
            () => onStop(agent),
          ),
      ],
      DispatchStall.workingLong => [
        output(const ValueKey('team-cycle-action-output')),
      ],
      DispatchStall.mergeWaiting => [
        if (canControl && refinery != null)
          primary(
            const ValueKey('team-cycle-action-nudge'),
            AppIconography.forward,
            l10n.teamUiCycleActionNudgeRefinery,
            () => onNudge(refinery),
          )
        else
          refresh(const ValueKey('team-cycle-action-refresh'), true),
      ],
    };
    return Wrap(
      key: const ValueKey('team-cycle-actions'),
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buttons,
    );
  }
}
