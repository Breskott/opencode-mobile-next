/// The AI Team plugin's shared run vocabulary: the order runs appear in,
/// which runs have something waiting on the person, the state words and
/// glyphs (02-ux §11: never colour-only), a run's progress and the honest
/// error copy of 03-onboarding §5. The Workspace card (TEAM-107) and the
/// AI Team home (TEAM-108) both read from here so a run never sorts or
/// reads differently between the two.
library;

import 'package:flutter/material.dart';

import '../../domain/orchestration_gateway.dart';
import '../../l10n/app_localizations.dart';
import '../../state/orchestration.dart';
import '../app_theme.dart';

/// How much of a run is done, working and blocked, from its work items
/// when the snapshot has them and from its step counts otherwise.
class TeamRunProgress {
  const TeamRunProgress({
    required this.done,
    required this.working,
    required this.blocked,
    required this.total,
  });

  final int done;
  final int working;
  final int blocked;
  final int total;

  /// Whole percent done, or null when the host counted nothing.
  int? get percent =>
      total <= 0 ? null : (done * 100 / total).floor().clamp(0, 100);

  static TeamRunProgress of(OrchestrationRun run, List<WorkItem> work) {
    final items = [
      for (final item in work)
        if (item.runId == run.id) item,
    ];
    if (items.isNotEmpty) {
      var done = 0, working = 0, blocked = 0;
      for (final item in items) {
        // Handed to the merge agent (TEAM-117): nobody works it.
        if (workHandedToMerge(item)) continue;
        switch (item.state) {
          case WorkState.completed:
            done += 1;
          case WorkState.working:
          case WorkState.review:
            working += 1;
          case WorkState.blocked:
          case WorkState.needsInput:
          case WorkState.failed:
            blocked += 1;
          case WorkState.queued:
          case WorkState.ready:
          case WorkState.waiting:
          case WorkState.cancelled:
          case WorkState.unknown:
            break;
        }
      }
      return TeamRunProgress(
        done: done,
        working: working,
        blocked: blocked,
        total: items.length,
      );
    }
    final total = run.stepCount ?? 0;
    final done = (run.completedSteps ?? 0).clamp(0, total);
    final open = total - done;
    return TeamRunProgress(
      done: done,
      working: run.state == RunState.working && open > 0 ? 1 : 0,
      blocked: run.state == RunState.blocked && open > 0 ? 1 : 0,
      total: total,
    );
  }
}

// ---------------------------------------------------------------------------
// What the person sees (TEAM-115): the host's upkeep and empty slots hidden
// ---------------------------------------------------------------------------

/// The runs a surface shows by default: the host's own upkeep
/// ([OrchestrationRun.isUpkeep]) left out unless [includeUpkeep].
List<OrchestrationRun> teamVisibleRuns(
  Iterable<OrchestrationRun> runs, {
  bool includeUpkeep = false,
}) => [
  for (final run in runs)
    if (includeUpkeep || !run.isUpkeep) run,
];

/// The host's upkeep runs (patrols, chores), for the "Show team upkeep"
/// reveal.
List<OrchestrationRun> teamUpkeepRuns(Iterable<OrchestrationRun> runs) => [
  for (final run in runs)
    if (run.isUpkeep) run,
];

/// Whether an agent is live: anything but stopped or suspended. Only live
/// agents are dots on the card and counted as the team.
bool teamAgentIsLive(OrchestrationAgent agent) =>
    agent.state != AgentState.stopped && !agent.suspended;

/// The live agents, in the given order.
List<OrchestrationAgent> teamLiveAgents(Iterable<OrchestrationAgent> agents) =>
    [
      for (final agent in agents)
        if (teamAgentIsLive(agent)) agent,
    ];

/// The agents switched off on the host (suspended or stopped): listed
/// under a collapsed group on the home, never on the card.
List<OrchestrationAgent> teamOffAgents(Iterable<OrchestrationAgent> agents) => [
  for (final agent in agents)
    if (!teamAgentIsLive(agent)) agent,
];

/// The host's name from the orchestration URL: `pop-os` for
/// `https://pop-os:7000`, `100.126.15.6` for an address, IPv6 without its
/// brackets. Null when the URL names no host (a fixture path or a
/// `fixture://` URL). Never the connected OpenCode profile's name: the
/// team runs on the host, which is not necessarily the OpenCode server.
String? teamHostName(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri?.scheme == 'fixture') return null;
  var host = uri?.host ?? '';
  if (host.isEmpty) {
    final match = RegExp(
      r'^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]+)',
    ).firstMatch(url.trim());
    host = match?.group(1) ?? '';
    final at = host.lastIndexOf('@');
    if (at >= 0) host = host.substring(at + 1);
    if (!host.startsWith('[')) {
      final colon = host.indexOf(':');
      if (colon >= 0) host = host.substring(0, colon);
    }
  }
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  return host.isEmpty ? null : host;
}

/// The host's name for a controller: the probe's URL, else the config's,
/// else the provider's name (a fixture path names no host).
String teamHostNameOf(OrchestrationController controller) =>
    teamHostName(controller.host?.url) ??
    teamHostName(controller.config.url) ??
    controller.host?.provider ??
    controller.config.provider.name;

/// Runs with something waiting on the person: a gate naming the run, a
/// work item of the run, or an agent working one of its items.
/// Review-ready is informational and never counts.
Set<String> teamGatedRuns(OrchestrationSnapshot snapshot) {
  final runByWork = <String, String>{
    for (final item in snapshot.work)
      if (item.runId != null) item.id: item.runId!,
  };
  final workByAgent = <String, String>{
    for (final agent in snapshot.agents)
      if (agent.currentWorkId case final work?) ...{
        agent.id: work,
        ?agent.sessionId: work,
      },
  };
  String? runOf(OrchestrationGate gate) =>
      gate.runId ??
      runByWork[gate.workId] ??
      runByWork[workByAgent[gate.agentId]];
  return {
    for (final gate in snapshot.gates)
      if (gate.kind != GateKind.reviewReady) ?runOf(gate),
  };
}

/// Order of runs everywhere: what needs the person, then active, then
/// waiting; completed runs come last (and collapse on the card).
int teamRunRank(OrchestrationRun run, Set<String> gated) {
  if (gated.contains(run.id) || run.state == RunState.failed) return 0;
  return switch (run.state) {
    RunState.working => 1,
    RunState.planning => 2,
    RunState.blocked => 3,
    RunState.waiting => 4,
    RunState.unknown => 5,
    RunState.cancelled => 6,
    RunState.failed => 0,
    RunState.completed => 7,
  };
}

/// [teamRunRank] first, then the most recently updated run first.
int teamCompareRuns(OrchestrationRun a, OrchestrationRun b, Set<String> gated) {
  final rank = teamRunRank(a, gated).compareTo(teamRunRank(b, gated));
  if (rank != 0) return rank;
  final at = a.updatedAt ?? a.startedAt;
  final bt = b.updatedAt ?? b.startedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}

/// HH:MM of [at] in the device's zone, for "Showing data from 09:41".
String teamClockLabel(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: true,
    );

/// The one word for a run state.
String teamRunStateWord(AppLocalizations l10n, RunState state) =>
    switch (state) {
      RunState.planning => l10n.teamUiCardRunStatePlanning,
      RunState.working => l10n.teamUiCardRunStateWorking,
      RunState.waiting => l10n.teamUiCardRunStateWaiting,
      RunState.blocked => l10n.teamUiCardRunStateBlocked,
      RunState.failed => l10n.teamUiCardRunStateFailed,
      RunState.completed => l10n.teamUiCardRunStateCompleted,
      RunState.cancelled => l10n.teamUiCardRunStateCancelled,
      RunState.unknown => l10n.teamUiCardRunStateUnknown,
    };

/// The run's state word with the merge wait named (TEAM-117): "Waiting
/// for merge" when [teamRunAwaitsMerge], else [teamRunStateWord].
String teamRunStateWordFor(
  AppLocalizations l10n,
  OrchestrationRun run,
  List<WorkItem> work, {
  DispatchCycle? Function(String workId)? cycleOf,
}) => teamRunAwaitsMerge(run, work, cycleOf: cycleOf)
    ? l10n.teamUiCardRunStateWaitingMerge
    : teamRunStateWord(l10n, run.state);

/// True when [item] is open and waits for the merge agent rather than
/// for work (TEAM-117): the mapper saw it handed to the rig's refinery,
/// or its dispatch [cycle] (when the caller has one) is past the hand-off
/// and not merged — a polecat that drained after pushing, before the
/// bead was reassigned.
bool teamWorkAwaitsMerge(WorkItem item, {DispatchCycle? cycle}) {
  if (workHandedToMerge(item)) return true;
  if (cycle == null || cycle.isTerminal) return false;
  if (!cycle.isDone(DispatchStep.handedToMerge)) return false;
  return switch (item.state) {
    WorkState.queued ||
    WorkState.ready ||
    WorkState.working ||
    WorkState.waiting ||
    WorkState.review ||
    WorkState.unknown => true,
    WorkState.blocked ||
    WorkState.needsInput ||
    WorkState.failed ||
    WorkState.completed ||
    WorkState.cancelled => false,
  };
}

/// True when the open [run] tracks work and every open item of it awaits
/// the merge agent ([teamWorkAwaitsMerge]): the batch is waiting for the
/// merge, not for an agent and not working.
bool teamRunAwaitsMerge(
  OrchestrationRun run,
  List<WorkItem> work, {
  DispatchCycle? Function(String workId)? cycleOf,
}) {
  if (run.state != RunState.waiting && run.state != RunState.working) {
    return false;
  }
  var any = false;
  for (final item in work) {
    if (item.runId != run.id || !teamWorkIsOpen(item.state)) continue;
    if (!teamWorkAwaitsMerge(item, cycle: cycleOf?.call(item.id))) {
      return false;
    }
    any = true;
  }
  return any;
}

/// When the [run]'s last hand-off to the merge agent happened, for "20 h
/// since hand-off": the latest hand-off among its items awaiting merge —
/// the cycle's hand-off time, else the bead's `updated_at`, else its
/// `created_at`. Null when no item of the run awaits merge or none
/// carries a time.
DateTime? teamRunHandoffAt(
  OrchestrationRun run,
  List<WorkItem> work, {
  DispatchCycle? Function(String workId)? cycleOf,
}) {
  DateTime? latest;
  for (final item in work) {
    if (item.runId != run.id || !teamWorkIsOpen(item.state)) continue;
    final cycle = cycleOf?.call(item.id);
    if (!teamWorkAwaitsMerge(item, cycle: cycle)) continue;
    final at =
        cycle?.reachedAt[DispatchStep.handedToMerge] ??
        item.updatedAt ??
        item.createdAt;
    if (at != null && (latest == null || at.isAfter(latest))) latest = at;
  }
  return latest;
}

/// Glyph and tone per run state: status is never colour-only (§11).
(IconData, AppStatusTone) teamRunGlyph(RunState state) => switch (state) {
  RunState.planning => (AppIconography.clock, AppStatusTone.neutral),
  RunState.working => (AppIconography.play, AppStatusTone.progress),
  RunState.waiting => (AppIconography.waiting, AppStatusTone.neutral),
  RunState.blocked => (AppIconography.blocked, AppStatusTone.attention),
  RunState.failed => (AppIconography.error, AppStatusTone.failure),
  RunState.completed => (AppIconography.check, AppStatusTone.ok),
  RunState.cancelled => (AppIconography.close, AppStatusTone.neutral),
  RunState.unknown => (AppIconography.question, AppStatusTone.neutral),
};

/// The one word for a work state (BRD §14).
String teamWorkStateWord(AppLocalizations l10n, WorkState state) =>
    switch (state) {
      WorkState.queued => l10n.teamUiWorkStateQueued,
      WorkState.ready => l10n.teamUiWorkStateReady,
      WorkState.working => l10n.teamUiWorkStateWorking,
      WorkState.waiting => l10n.teamUiWorkStateWaiting,
      WorkState.blocked => l10n.teamUiWorkStateBlocked,
      WorkState.needsInput => l10n.teamUiWorkStateNeedsInput,
      WorkState.review => l10n.teamUiWorkStateReview,
      WorkState.failed => l10n.teamUiWorkStateFailed,
      WorkState.completed => l10n.teamUiWorkStateCompleted,
      WorkState.cancelled => l10n.teamUiWorkStateCancelled,
      WorkState.unknown => l10n.teamUiWorkStateUnknown,
    };

/// Glyph and tone per work state: status is never colour-only (§11).
(IconData, AppStatusTone) teamWorkGlyph(WorkState state) => switch (state) {
  WorkState.queued => (AppIconography.radioEmpty, AppStatusTone.neutral),
  WorkState.ready => (AppIconography.playCircle, AppStatusTone.neutral),
  WorkState.working => (AppIconography.play, AppStatusTone.progress),
  WorkState.waiting => (AppIconography.waiting, AppStatusTone.neutral),
  WorkState.blocked => (AppIconography.blocked, AppStatusTone.attention),
  WorkState.needsInput => (AppIconography.question, AppStatusTone.attention),
  WorkState.review => (AppIconography.review, AppStatusTone.progress),
  WorkState.failed => (AppIconography.error, AppStatusTone.failure),
  WorkState.completed => (AppIconography.check, AppStatusTone.ok),
  WorkState.cancelled => (AppIconography.close, AppStatusTone.neutral),
  WorkState.unknown => (AppIconography.question, AppStatusTone.neutral),
};

/// The Work tab's group order (02-ux §4.2): what needs the person first,
/// then what is held up, then what moves, then the rest; the two states
/// outside the BRD list (Waiting, Unknown) sit beside their nearest kin.
const teamWorkStateOrder = [
  WorkState.needsInput,
  WorkState.blocked,
  WorkState.waiting,
  WorkState.working,
  WorkState.ready,
  WorkState.queued,
  WorkState.review,
  WorkState.completed,
  WorkState.failed,
  WorkState.cancelled,
  WorkState.unknown,
];

/// Position of [state] in [teamWorkStateOrder].
int teamWorkStateRank(WorkState state) => teamWorkStateOrder.indexOf(state);

/// Whether an item in [state] still holds up what depends on it.
bool teamWorkIsOpen(WorkState state) =>
    state != WorkState.completed && state != WorkState.cancelled;

/// Whether an item in [state] is stuck: blocked, waiting on the person or
/// failed. These start the graph's highlighted blocked chain.
bool teamWorkIsStuck(WorkState state) =>
    state == WorkState.blocked ||
    state == WorkState.needsInput ||
    state == WorkState.failed;

/// Honest one-line copy for a failed probe or read (03-onboarding §5).
String teamErrorCopy(AppLocalizations l10n, OrchestrationErrorKind? kind) =>
    switch (kind) {
      OrchestrationErrorKind.notGasCity => l10n.teamUiCardErrorNotGasCity,
      OrchestrationErrorKind.cityNotRunning =>
        l10n.teamUiCardErrorCityNotRunning,
      OrchestrationErrorKind.plainHttpRefused => l10n.teamUiCardErrorPlainHttp,
      OrchestrationErrorKind.unreachable ||
      OrchestrationErrorKind.readFailed ||
      null => l10n.teamUiCardErrorUnreachable,
    };

/// The BRD §47 order of what needs the person: decision, run failed,
/// review ready, gate bead. Shared by the home's Needs you segment and the
/// run's inline card so the same gate is "most urgent" on both.
int teamGateRank(GateKind kind) => switch (kind) {
  GateKind.choice ||
  GateKind.confirmation ||
  GateKind.freeText ||
  GateKind.unknown => 0,
  GateKind.runFailed => 1,
  GateKind.reviewReady => 2,
  GateKind.gateBead => 3,
};

/// The one word for a gate kind.
String teamGateKindWord(AppLocalizations l10n, GateKind kind) => switch (kind) {
  GateKind.choice => l10n.teamUiHomeGateKindChoice,
  GateKind.confirmation => l10n.teamUiHomeGateKindConfirmation,
  GateKind.freeText => l10n.teamUiHomeGateKindFreeText,
  GateKind.gateBead => l10n.teamUiHomeGateKindGateBead,
  GateKind.runFailed => l10n.teamUiHomeGateKindRunFailed,
  GateKind.reviewReady => l10n.teamUiHomeGateKindReviewReady,
  GateKind.unknown => l10n.teamUiHomeGateKindUnknown,
};

/// Glyph and tone per gate kind: a failed run is the only red one.
(IconData, AppStatusTone) teamGateGlyph(GateKind kind) => switch (kind) {
  GateKind.choice => (AppIconography.question, AppStatusTone.attention),
  GateKind.confirmation => (
    AppIconography.checkCircle,
    AppStatusTone.attention,
  ),
  GateKind.freeText => (AppIconography.editNote, AppStatusTone.attention),
  GateKind.gateBead => (AppIconography.blocked, AppStatusTone.attention),
  GateKind.runFailed => (AppIconography.error, AppStatusTone.failure),
  GateKind.reviewReady => (AppIconography.review, AppStatusTone.neutral),
  GateKind.unknown => (AppIconography.warning, AppStatusTone.attention),
};

/// The run a gate belongs to: named directly, else through its work item,
/// else through the work item of the agent it names. Null when none.
String? teamGateRunId(OrchestrationSnapshot snapshot, OrchestrationGate gate) {
  if (gate.runId case final id?) return id;
  String? runOfWork(String? workId) {
    if (workId == null) return null;
    for (final item in snapshot.work) {
      if (item.id == workId) return item.runId;
    }
    return null;
  }

  if (runOfWork(gate.workId) case final id?) return id;
  for (final agent in snapshot.agents) {
    if (agent.id == gate.agentId || agent.sessionId == gate.agentId) {
      return runOfWork(agent.currentWorkId);
    }
  }
  return null;
}

/// What the gate belongs to, as one line: the run, else the work item,
/// else the agent. Server titles are shown verbatim.
String? teamGateLink(
  AppLocalizations l10n,
  OrchestrationSnapshot snapshot,
  OrchestrationGate gate,
) {
  for (final run in snapshot.runs) {
    if (run.id == gate.runId) return l10n.teamUiHomeGateLinkRun(run.title);
  }
  for (final item in snapshot.work) {
    if (item.id == gate.workId) return l10n.teamUiHomeGateLinkWork(item.title);
  }
  for (final agent in snapshot.agents) {
    if (agent.id == gate.agentId || agent.sessionId == gate.agentId) {
      return l10n.teamUiHomeGateLinkAgent(agent.name);
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Activity (02-ux §6, BRD §47)
// ---------------------------------------------------------------------------

/// The Activity inbox's rank of a gate in the BRD §47 order: decision
/// requested (0), run failed (1), then — after the app's own permissions,
/// questions and forms at [teamActivityPermissionRank] — review ready (3)
/// and gate beads (4); blocked agents follow at
/// [teamActivityAgentBlockedRank].
int teamActivityGateRank(GateKind kind) => switch (kind) {
  GateKind.choice ||
  GateKind.confirmation ||
  GateKind.freeText ||
  GateKind.unknown => 0,
  GateKind.runFailed => 1,
  GateKind.reviewReady => 3,
  GateKind.gateBead => 4,
};

/// Where the app's own permissions, questions and forms sit in the §47
/// order.
const teamActivityPermissionRank = 2;

/// Where a blocked agent sits in the §47 order.
const teamActivityAgentBlockedRank = 5;

/// Whether a confirmation would destroy something, from the host's
/// `destructive` flag when it sends one and from the prompt's words
/// otherwise; the sheet marks these in the error tone.
bool teamGateIsDestructive(OrchestrationGate gate) {
  final raw = gate.raw;
  final flagged = raw['destructive'] ?? raw['is_destructive'];
  if (flagged is bool) return flagged;
  if (raw['metadata'] case final Map<Object?, Object?> meta) {
    final flag = meta['destructive'] ?? meta['is_destructive'];
    if (flag is bool) return flag;
  }
  final text = '${gate.title} ${gate.prompt ?? ''}';
  return _destructiveWords.hasMatch(text);
}

final _destructiveWords = RegExp(
  r'\b(delete|remove|drop|discard|overwrite|reset|wipe|destroy|purge|erase|'
  r'force[- ]push|rm -rf|revert|uninstall)\b',
  caseSensitive: false,
);

/// How a failed run failed (02-ux §6), read from the host's error text
/// with [teamClassifyFailure]; [unknown] when the words match nothing.
enum TeamFailureClass {
  agent,
  execution,
  test,
  mergeConflict,
  infrastructure,
  dependency,
  authentication,
  context,
  unknown,
}

/// Classifies a run's `last_error` text by its words. The order matters:
/// the more specific families (merge conflict, authentication, context,
/// dependency) are tried before the generic ones (test, infrastructure,
/// execution, agent) so "tests failed after a merge conflict" is a merge
/// conflict. Null or empty text is [TeamFailureClass.unknown].
TeamFailureClass teamClassifyFailure(String? text) {
  if (text == null || text.trim().isEmpty) return TeamFailureClass.unknown;
  for (final (family, pattern) in _failureFamilies) {
    if (pattern.hasMatch(text)) return family;
  }
  return TeamFailureClass.unknown;
}

final _failureFamilies = <(TeamFailureClass, RegExp)>[
  (
    TeamFailureClass.mergeConflict,
    RegExp(
      r'merge conflict|\bconflict(s|ed|ing)?\b|unmerged|rebase',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.authentication,
    RegExp(
      r'unauthori[sz]ed|unauthenticated|authentication|\bauth\b|'
      r'\b40[13]\b|api[ _-]?key|credential|token (expired|invalid|missing)|'
      r'invalid token|login|forbidden',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.context,
    RegExp(
      r'context (window|length|limit|size)|maximum context|'
      r'too many tokens|token limit|max_tokens|prompt (is )?too long',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.dependency,
    RegExp(
      r'dependenc|module ?not ?found|cannot find (module|package)|'
      r'no such module|unresolved import|import ?error|'
      r'version solving|pub get|npm install|package .* not found|'
      r'missing (package|library|module)|not installed',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.test,
    RegExp(
      r'\btests?\b|assert|expectation|pytest|jest|spec failed|'
      r'\d+ (failed|failing)',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.infrastructure,
    RegExp(
      r'time[d ]?out|connection (refused|reset)|econnrefused|network|'
      r'\bdns\b|unreachable|disk|out of memory|\boom\b|\b50[023]\b|'
      r'\b429\b|rate limit|server error|unavailable|no space left',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.execution,
    RegExp(
      r'exit(ed)? (code|with|status)|non-?zero|command failed|build failed|'
      r'compil|syntax error|exception|traceback|panic|segfault|'
      r'permission denied|no such file',
      caseSensitive: false,
    ),
  ),
  (
    TeamFailureClass.agent,
    RegExp(
      r'\bagent\b|crash|session (died|ended|lost)|harness|polecat|'
      r'no response|stalled|stuck|nudge|gave up|abandoned',
      caseSensitive: false,
    ),
  ),
];

/// The one word for a failure class.
String teamFailureClassWord(
  AppLocalizations l10n,
  TeamFailureClass cls,
) => switch (cls) {
  TeamFailureClass.agent => l10n.teamUiGateFailureClassAgent,
  TeamFailureClass.execution => l10n.teamUiGateFailureClassExecution,
  TeamFailureClass.test => l10n.teamUiGateFailureClassTest,
  TeamFailureClass.mergeConflict => l10n.teamUiGateFailureClassMergeConflict,
  TeamFailureClass.infrastructure => l10n.teamUiGateFailureClassInfrastructure,
  TeamFailureClass.dependency => l10n.teamUiGateFailureClassDependency,
  TeamFailureClass.authentication => l10n.teamUiGateFailureClassAuthentication,
  TeamFailureClass.context => l10n.teamUiGateFailureClassContext,
  TeamFailureClass.unknown => l10n.teamUiGateFailureClassUnknown,
};

/// Whether a retry from the host can recover a failure of this class
/// without a person changing something first; null when the class is
/// unknown, so the sheet says so rather than guessing.
bool? teamFailureRecoverable(TeamFailureClass cls) => switch (cls) {
  TeamFailureClass.agent ||
  TeamFailureClass.execution ||
  TeamFailureClass.infrastructure ||
  TeamFailureClass.context => true,
  TeamFailureClass.test ||
  TeamFailureClass.mergeConflict ||
  TeamFailureClass.dependency ||
  TeamFailureClass.authentication => false,
  TeamFailureClass.unknown => null,
};

/// The recommended action for a failure class, as text: the buttons that
/// perform it are Sprint B.
String teamFailureAction(
  AppLocalizations l10n,
  TeamFailureClass cls,
) => switch (cls) {
  TeamFailureClass.agent => l10n.teamUiGateFailureActionAgent,
  TeamFailureClass.execution => l10n.teamUiGateFailureActionExecution,
  TeamFailureClass.test => l10n.teamUiGateFailureActionTest,
  TeamFailureClass.mergeConflict => l10n.teamUiGateFailureActionMergeConflict,
  TeamFailureClass.infrastructure => l10n.teamUiGateFailureActionInfrastructure,
  TeamFailureClass.dependency => l10n.teamUiGateFailureActionDependency,
  TeamFailureClass.authentication => l10n.teamUiGateFailureActionAuthentication,
  TeamFailureClass.context => l10n.teamUiGateFailureActionContext,
  TeamFailureClass.unknown => l10n.teamUiGateFailureActionUnknown,
};

// ---------------------------------------------------------------------------
// Agents (02-ux §5.1)
// ---------------------------------------------------------------------------

/// Context use from which the number takes the attention tone.
const teamContextAttentionPercent = 75;

/// Context use from which the number takes the failure tone and the agent
/// detail says "Recycling soon" (the host's recycle policy threshold).
const teamContextRecyclePercent = 90;

/// Tone of a context-use number: neutral, attention from
/// [teamContextAttentionPercent], failure from [teamContextRecyclePercent].
AppStatusTone teamContextTone(int percent) =>
    percent >= teamContextRecyclePercent
    ? AppStatusTone.failure
    : percent >= teamContextAttentionPercent
    ? AppStatusTone.attention
    : AppStatusTone.neutral;

/// Sort of §5.1: needs-you first, then working, idle, stopped; a crashed
/// agent sits with the exceptions, right after the ones waiting.
int teamAgentRank(AgentState state) => switch (state) {
  AgentState.waiting || AgentState.blocked => 0,
  AgentState.crashed => 1,
  AgentState.working => 2,
  AgentState.idle => 3,
  AgentState.stopped => 4,
  AgentState.unknown => 5,
};

/// [teamAgentRank] first, then by name so the order is stable.
int teamCompareAgents(OrchestrationAgent a, OrchestrationAgent b) {
  final rank = teamAgentRank(a.state).compareTo(teamAgentRank(b.state));
  return rank != 0 ? rank : a.name.compareTo(b.name);
}

/// The one word for an agent state.
String teamAgentStateWord(AppLocalizations l10n, AgentState state) =>
    switch (state) {
      AgentState.working => l10n.teamUiHomeAgentStateWorking,
      AgentState.idle => l10n.teamUiHomeAgentStateIdle,
      AgentState.waiting => l10n.teamUiHomeAgentStateWaiting,
      AgentState.blocked => l10n.teamUiHomeAgentStateBlocked,
      AgentState.stopped => l10n.teamUiHomeAgentStateStopped,
      AgentState.crashed => l10n.teamUiHomeAgentStateCrashed,
      AgentState.unknown => l10n.teamUiHomeAgentStateUnknown,
    };

/// Glyph and tone per agent state: status is never colour-only (§11).
(IconData, AppStatusTone) teamAgentGlyph(AgentState state) => switch (state) {
  AgentState.working => (AppIconography.play, AppStatusTone.progress),
  AgentState.idle => (AppIconography.statusDot, AppStatusTone.neutral),
  AgentState.waiting => (AppIconography.question, AppStatusTone.attention),
  AgentState.blocked => (AppIconography.blocked, AppStatusTone.attention),
  AgentState.stopped => (AppIconography.stopCircle, AppStatusTone.neutral),
  AgentState.crashed => (AppIconography.error, AppStatusTone.failure),
  AgentState.unknown => (AppIconography.question, AppStatusTone.neutral),
};

/// "12m", "3h 14m", "2d": an elapsed span in the run's short form.
String teamElapsedLabel(AppLocalizations l10n, Duration elapsed) {
  if (elapsed.inHours < 1) {
    return l10n.teamUiRunElapsedMinutes(elapsed.inMinutes);
  }
  if (elapsed.inDays < 1) {
    return l10n.teamUiRunElapsedHours(
      elapsed.inHours,
      elapsed.inMinutes - elapsed.inHours * 60,
    );
  }
  return l10n.teamUiRunElapsedDays(elapsed.inDays);
}

/// The agents working on a run: those whose current work item belongs to
/// it, in the fleet order.
List<OrchestrationAgent> teamAgentsOnRun(
  OrchestrationSnapshot snapshot,
  String runId,
) {
  final workIds = {
    for (final item in snapshot.work)
      if (item.runId == runId) item.id,
  };
  return [
    for (final agent in snapshot.agents)
      if (workIds.contains(agent.currentWorkId)) agent,
  ]..sort(teamCompareAgents);
}

// ---------------------------------------------------------------------------
// Usage (05-beads TEAM-113)
// ---------------------------------------------------------------------------

/// Parts joined on one line ("$0.42 est. · 12.4k tokens"); no letters, so
/// it needs no translation.
const teamUsageSeparator = ' · ';

/// "980", "12.4k", "1.2M": a token count in the chat's compact form.
String teamCompactCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

/// "$0.42": the app's session-row currency form (cents; three decimals
/// only when the amount would otherwise round to nothing).
String teamCurrencyLabel(double usd) => usd > 0 && usd < 0.01
    ? '\$${usd.toStringAsFixed(3)}'
    : '\$${usd.toStringAsFixed(2)}';

/// Input plus output tokens as far as the host reported either, or null.
int? teamUsageTokens(OrchestrationUsage? usage) {
  if (usage == null) return null;
  final input = usage.inputTokens, output = usage.outputTokens;
  if (input == null && output == null) return null;
  return (input ?? 0) + (output ?? 0);
}

/// "12.4k tokens", or null when the host reported no token count.
String? teamUsageTokensLabel(AppLocalizations l10n, OrchestrationUsage? usage) {
  final tokens = teamUsageTokens(usage);
  return tokens == null
      ? null
      : l10n.teamUiUsageTokens(teamCompactCount(tokens));
}

/// "$0.42 est.": the cost with the estimate suffix — always, since every
/// figure Gas City's `/usage` reports is its local estimate — or null when
/// the host reported no cost.
String? teamUsageCostLabel(AppLocalizations l10n, OrchestrationUsage? usage) {
  final cost = usage?.costUsd;
  return cost == null
      ? null
      : l10n.teamUiUsageCostEstimated(teamCurrencyLabel(cost));
}

/// "$0.42 est. · 12.4k tokens", whichever of the two the host reported,
/// or null when it reported neither: the surfaces that show it then stay
/// absent rather than show a placeholder.
String? teamUsageLabel(AppLocalizations l10n, OrchestrationUsage? usage) {
  final parts = [
    ?teamUsageCostLabel(l10n, usage),
    ?teamUsageTokensLabel(l10n, usage),
  ];
  return parts.isEmpty ? null : parts.join(teamUsageSeparator);
}
