/// A team task in the Work tab's own lists (docs/design/team-conversation-
/// 2026-09-26.md: a team task is a conversation): its task mark, the
/// title, and "Team · Working · 2 of 5 steps done" or "Team · Waiting for
/// a worker · the team checks every minute". It opens
/// the task's team conversation. It replaces the separate AI Team card on
/// the Work tab.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../domain/work_row_status.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../../state/team_conversation.dart' show TeamNowKind, teamNow;
import '../kit/kit_row.dart';
import '../kit/kit_task_mark.dart';
import '../kit/kit_text.dart';
import '../kit/kit_time.dart';
import 'team_now.dart';
import 'team_vocabulary.dart';
import 'work_row_presentation.dart';

/// The team's open tasks (not finished, not cancelled), what needs the
/// person first; the host's upkeep left out.
List<OrchestrationRun> teamOpenTasks(OrchestrationController team) {
  final snapshot = team.snapshot;
  if (!snapshot.hasData) return const [];
  final gated = teamGatedRuns(snapshot);
  return [
    for (final run in teamVisibleRuns(snapshot.runs))
      if (run.state != RunState.completed && run.state != RunState.cancelled)
        run,
  ]..sort((a, b) => teamCompareRuns(a, b, gated));
}

class TeamTaskRow extends StatelessWidget {
  const TeamTaskRow({
    super.key,
    required this.team,
    required this.run,
    required this.onOpen,
    this.connected = true,
  });

  final OrchestrationController team;
  final OrchestrationRun run;
  final VoidCallback onOpen;

  /// The server's connection is live. Without it (or with a stale team
  /// read) the row is the last seen state: still mark, "as of" time
  /// (slice-P5.5).
  final bool connected;

  /// The row's one status (slice-P5.5), from the same vocabulary as the
  /// Work and Inbox rows: needs you and a finished outcome outrank a stall,
  /// and a stall is the task's own P3.5 evidence ([teamNow]), never the
  /// row's age.
  static WorkRowStatus statusOf(
    OrchestrationController team,
    OrchestrationRun run, {
    required bool needsYou,
    required bool connected,
    required DateTime now,
  }) {
    final snapshot = team.snapshot;
    final stalled =
        !needsYou &&
        teamNow(
              run: run,
              work: snapshot.work,
              cycleOf: team.cycleFor,
              agents: snapshot.agents,
              gates: snapshot.gates,
              now: now,
            ).kind ==
            TeamNowKind.stalled;
    return WorkRowStatus(
      facts: WorkRowFacts(
        phase: needsYou
            ? WorkRowPhase.needsYou
            : switch (run.state) {
                RunState.failed => WorkRowPhase.failed,
                RunState.completed => WorkRowPhase.done,
                RunState.cancelled => WorkRowPhase.stopped,
                _ when stalled => WorkRowPhase.stalled,
                RunState.working || RunState.planning => WorkRowPhase.working,
                RunState.waiting ||
                RunState.blocked ||
                RunState.unknown => WorkRowPhase.waiting,
              },
        finishedAt: run.finishedAt,
      ),
      observedAt: snapshot.refreshedAt ?? now,
      isFresh: connected && !team.isStale && snapshot.hasData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final snapshot = team.snapshot;
    final needsYou = teamGatedRuns(snapshot).contains(run.id);
    // The stall is judged on the team's own clock, as its pages judge it.
    final now = team.now();
    final status = statusOf(
      team,
      run,
      needsYou: needsYou,
      connected: connected,
      now: now,
    );
    final stall = status.facts.phase == WorkRowPhase.stalled
        ? teamNow(
            run: run,
            work: snapshot.work,
            cycleOf: team.cycleFor,
            agents: snapshot.agents,
            gates: snapshot.gates,
            now: now,
          )
        : null;
    final stalledSince = stall?.quietSince ?? stall?.since;
    final fullLine = teamTaskLine(
      l10n,
      run,
      snapshot.work,
      needsYou: needsYou,
      now: DateTime.now(),
      cycleOf: team.cycleFor,
      explainWait: true,
      checkEvery: teamCheckInterval(team),
      paused: teamRest(snapshot.agents, config: team.config) == TeamRest.paused,
      // The list has no clock of the team's to draw an age from; the
      // task's own page says how long.
      showWaitAge: false,
    );
    // A stalled task says since when; a row that is not fresh says the
    // last seen state and as of when, with a still mark.
    final line = !status.isFresh
        ? status.line(
            l10n,
            now: now,
            moment: (at) => KitTime.moment(context, at, now: now),
          )
        : stall != null
        ? (stalledSince == null
              ? l10n.workStalled
              : l10n.workStalledSince(_clock(context, stalledSince, now)))
        : fullLine;
    // The Work list's own row: the task's mark leads, and the "Team" word
    // in `text1` opens the line, so the row reads as the team's, not one
    // agent's. The list's scaffold is the ink surface.
    return Semantics(
      button: true,
      child: KitRow(
        key: ValueKey('team-work-task-${run.id}'),
        leading: KeyedSubtree(
          key: ValueKey('team-work-task-mark-${run.id}'),
          child: KitTaskMark(
            state: status.isFresh && stall == null
                ? teamRunMark(run, needsYou: needsYou)
                : workRowTaskState(status),
          ),
        ),
        title: run.title,
        titleMaxLines: 2,
        supporting: TextSpan(
          children: [
            TextSpan(
              text: l10n.teamTaskMark,
              style: KitText.styleOf(
                context,
                KitTextRole.secondary,
                tone: KitTextTone.primary,
              ),
            ),
            TextSpan(text: '$teamUsageSeparator$line'),
          ],
        ),
        supportingMaxLines: 2,
        supportingKey: ValueKey('team-work-task-line-${run.id}'),
        onTap: onOpen,
      ),
    );
  }
}

/// The clock today, else the day with it (KitTime, F15).
String _clock(BuildContext context, DateTime at, DateTime now) =>
    KitTime.moment(context, at, now: now);
