import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/team_conversation.dart';

final t0 = DateTime.utc(2026, 9, 25, 19, 49, 3);
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

OrchestrationRun run({
  RunState state = RunState.working,
  bool merged = false,
  String? lastError,
  DateTime? finishedAt,
}) => OrchestrationRun(
  id: 'ma-1',
  title: 'Add a login page',
  state: state,
  kind: RunKind.batch,
  projectId: 'my-app',
  startedAt: t0,
  merged: merged,
  lastError: lastError,
  finishedAt: finishedAt,
);

WorkItem item(
  String id,
  String title, {
  WorkState state = WorkState.working,
  String? assignee,
  DateTime? createdAt,
  DateTime? updatedAt,
  Map<String, Object?> raw = const {},
}) => WorkItem(
  id: id,
  title: title,
  state: state,
  projectId: 'my-app',
  runId: 'ma-1',
  assignee: assignee,
  createdAt: createdAt,
  updatedAt: updatedAt,
  raw: raw,
);

OrchestrationAgent agent(
  String id, {
  String? name,
  AgentState state = AgentState.working,
  String? workId,
  String? sessionState,
  bool? sessionRunning,
  DateTime? sessionStartedAt,
  String? pool,
}) => OrchestrationAgent(
  id: id,
  name: name ?? id,
  state: state,
  currentWorkId: workId,
  sessionState: sessionState,
  sessionRunning: sessionRunning,
  sessionStartedAt: sessionStartedAt,
  pool: pool,
);

DispatchCycle cycle(
  Map<DispatchStep, DateTime?> reached, {
  bool stalled = false,
  DispatchStall? stallReason,
}) {
  var step = DispatchStep.merged;
  for (final candidate in DispatchStep.values) {
    if (!reached.containsKey(candidate)) {
      step = candidate;
      break;
    }
  }
  return DispatchCycle(
    step: step,
    reachedAt: reached,
    stalled: stalled,
    stallReason: stallReason,
  );
}

void main() {
  group('teamLeadLines', () {
    test('a two-step task tells its story in time order', () {
      final work = [
        item('ma-2', 'Login form', state: WorkState.completed),
        item('ma-3', 'Session cookie', assignee: 'my-app/gastown.nux'),
      ];
      final cycles = {
        'ma-2': cycle({
          DispatchStep.routed: at(1),
          DispatchStep.agentStarting: at(2),
          DispatchStep.claimed: at(6),
          DispatchStep.working: at(6),
          DispatchStep.pushed: at(12),
          DispatchStep.handedToMerge: at(13),
          DispatchStep.merged: at(15),
        }),
        'ma-3': cycle({
          DispatchStep.routed: at(1),
          DispatchStep.agentStarting: at(7),
          DispatchStep.claimed: at(9),
          DispatchStep.working: at(9),
        }),
      };
      final agents = [
        agent('gc-58', name: 'my-app/gastown.furiosa', workId: 'ma-2'),
      ];
      final lines = teamLeadLines(
        run: run(),
        work: work,
        cycleOf: (id) => cycles[id] ?? DispatchCycle.none,
        agents: agents,
      );
      expect(
        [for (final l in lines) '${l.event.name}:${l.workId ?? ''}'],
        [
          'planned:',
          'routed:ma-2',
          'routed:ma-3',
          'workerStarting:ma-2',
          'claimed:ma-2',
          'workerStarting:ma-3',
          'claimed:ma-3',
          'pushed:ma-2',
          'handedToReview:ma-2',
          'merged:ma-2',
        ],
      );
      expect(lines.first.count, 2);
      expect(lines.first.at, t0);
      final claims = lines.where((l) => l.event == TeamLeadEvent.claimed);
      expect(claims.map((l) => l.agentName), ['furiosa', 'nux']);
      expect(
        lines.firstWhere((l) => l.event == TeamLeadEvent.pushed).workTitle,
        'Login form',
      );
    });

    test('a worker session made for a routed step says a worker started', () {
      // The phone, 2026-09-25: routed 19:51, the session created 19:51:05,
      // no wake event reached the app.
      final lines = teamLeadLines(
        run: run(),
        work: [item('ma-2', 'Login form')],
        cycleOf: (id) => cycle({DispatchStep.routed: at(2)}),
        agents: [
          agent(
            'gc-58',
            name: 'my-app/gastown.furiosa',
            state: AgentState.stopped,
            workId: 'ma-2',
            sessionRunning: true,
            sessionStartedAt: at(2).add(const Duration(seconds: 2)),
          ),
        ],
      );
      expect(
        [for (final l in lines) l.event],
        [
          TeamLeadEvent.planned,
          TeamLeadEvent.routed,
          TeamLeadEvent.workerStarting,
        ],
      );
      expect(lines.last.at, at(2).add(const Duration(seconds: 2)));
    });

    test('a line the host gave no time keeps its place', () {
      final lines = teamLeadLines(
        run: run(),
        work: [item('ma-2', 'Login form')],
        cycleOf: (_) => cycle({
          DispatchStep.routed: at(1),
          DispatchStep.agentStarting: null,
          DispatchStep.claimed: at(5),
        }),
        agents: const [],
      );
      expect(lines.map((l) => l.event), [
        TeamLeadEvent.planned,
        TeamLeadEvent.routed,
        TeamLeadEvent.workerStarting,
        TeamLeadEvent.claimed,
      ]);
      expect(lines[2].at, isNull);
    });

    test('an open gate says the team needs the person', () {
      final lines = teamLeadLines(
        run: run(),
        work: [item('ma-2', 'Login form')],
        cycleOf: (_) => DispatchCycle.none,
        agents: const [],
        gates: [
          OrchestrationGate(
            id: 'g1',
            kind: GateKind.choice,
            title: 'Which auth library?',
            workId: 'ma-2',
            createdAt: at(3),
          ),
        ],
      );
      final gate = lines.last;
      expect(gate.event, TeamLeadEvent.needsYou);
      expect(gate.detail, 'Which auth library?');
      expect(gate.workTitle, 'Login form');
      expect(gate.at, at(3));
    });

    test('a failed and a cancelled step', () {
      final lines = teamLeadLines(
        run: run(),
        work: [
          item(
            'ma-2',
            'Login form',
            state: WorkState.failed,
            updatedAt: at(4),
            raw: const {
              'metadata': {'last_error': 'tests failed'},
            },
          ),
          item('ma-3', 'Cookie', state: WorkState.cancelled, updatedAt: at(5)),
        ],
        cycleOf: (_) => DispatchCycle.none,
        agents: const [],
      );
      expect(lines[1].event, TeamLeadEvent.stepFailed);
      expect(lines[1].detail, 'tests failed');
      expect(lines[2].event, TeamLeadEvent.stepCancelled);
    });

    test('how the task ended', () {
      TeamLeadLine last(OrchestrationRun r) => teamLeadLines(
        run: r,
        work: const [],
        cycleOf: (_) => DispatchCycle.none,
        agents: const [],
      ).last;
      final merged = last(
        run(state: RunState.completed, merged: true, finishedAt: at(20)),
      );
      expect(merged.event, TeamLeadEvent.taskMerged);
      expect(merged.at, at(20));
      expect(
        last(run(state: RunState.completed)).event,
        TeamLeadEvent.taskFinished,
      );
      final failed = last(run(state: RunState.failed, lastError: ' boom '));
      expect(failed.event, TeamLeadEvent.taskFailed);
      expect(failed.detail, 'boom');
      expect(
        last(run(state: RunState.cancelled)).event,
        TeamLeadEvent.taskCancelled,
      );
      // No work, open: nothing to say yet.
      expect(
        teamLeadLines(
          run: run(),
          work: const [],
          cycleOf: (_) => DispatchCycle.none,
          agents: const [],
        ),
        isEmpty,
      );
    });
  });

  group('teamNow', () {
    TeamNow now(
      List<WorkItem> work,
      Map<String, DispatchCycle> cycles, {
      OrchestrationRun? r,
      List<OrchestrationAgent> agents = const [],
      List<OrchestrationGate> gates = const [],
    }) => teamNow(
      run: r ?? run(),
      work: work,
      cycleOf: (id) => cycles[id] ?? DispatchCycle.none,
      agents: agents,
      gates: gates,
    );

    test('finished', () {
      final result = now(
        const [],
        const {},
        r: run(state: RunState.completed, finishedAt: at(9)),
      );
      expect(result.kind, TeamNowKind.finished);
      expect(result.since, at(9));
    });

    test('a gate comes first', () {
      final result = now(
        [item('ma-2', 'Login form')],
        const {},
        gates: [
          OrchestrationGate(
            id: 'g1',
            kind: GateKind.confirmation,
            title: 'Push to main?',
            createdAt: at(2),
          ),
        ],
      );
      expect(result.kind, TeamNowKind.needsYou);
      expect(result.gateTitle, 'Push to main?');
      expect(result.since, at(2));
    });

    test('no work yet: waiting for a worker since the task started', () {
      final result = now(const [], const {});
      expect(result.kind, TeamNowKind.waitingForWorker);
      expect(result.since, t0);
    });

    test('routed and waiting for the next check', () {
      final result = now(
        [item('ma-2', 'Login form', createdAt: at(0))],
        {
          'ma-2': cycle({DispatchStep.routed: at(1)}),
        },
      );
      expect(result.kind, TeamNowKind.waitingForWorker);
      expect(result.since, at(1));
      expect(result.workTitle, 'Login form');
      // Nothing reached: since the item was made.
      expect(now([item('ma-2', 'x', createdAt: at(0))], const {}).since, at(0));
    });

    test(
      'a running session on the item is starting before the cycle knows',
      () {
        final result = now(
          [item('ma-2', 'Login form')],
          {
            'ma-2': cycle({DispatchStep.routed: at(1)}),
          },
          agents: [
            agent(
              'gc-58',
              name: 'my-app/gastown.furiosa',
              state: AgentState.stopped,
              workId: 'ma-2',
              sessionState: 'active',
              sessionRunning: true,
              sessionStartedAt: at(2),
            ),
          ],
        );
        expect(result.kind, TeamNowKind.starting);
        expect(result.agentName, 'furiosa');
        expect(result.since, at(2));
      },
    );

    test('starting once the agent woke', () {
      final result = now(
        [item('ma-2', 'Login form')],
        {
          'ma-2': cycle({
            DispatchStep.routed: at(1),
            DispatchStep.agentStarting: at(2),
          }),
        },
        agents: [
          agent('gc-58', name: 'my-app/gastown.furiosa', workId: 'ma-2'),
        ],
      );
      expect(result.kind, TeamNowKind.starting);
      expect(result.since, at(2));
      expect(result.agentName, 'furiosa');
    });

    test('working, on the least advanced step', () {
      final result = now(
        [item('ma-2', 'Login form'), item('ma-3', 'Cookie')],
        {
          'ma-2': cycle({
            DispatchStep.routed: at(1),
            DispatchStep.agentStarting: at(2),
            DispatchStep.claimed: at(3),
            DispatchStep.working: at(3),
            DispatchStep.pushed: at(8),
          }),
          'ma-3': cycle({
            DispatchStep.routed: at(1),
            DispatchStep.agentStarting: at(2),
            DispatchStep.claimed: at(4),
          }),
        },
        agents: [agent('gc-59', name: 'my-app/gastown.nux', workId: 'ma-3')],
      );
      expect(result.kind, TeamNowKind.working);
      expect(result.workTitle, 'Cookie');
      expect(result.agentName, 'nux');
      expect(result.since, at(4));
    });

    test('a step queued behind the one in flight does not speak', () {
      // The owner's task: step 1 sent to the workers at 19:51 with furiosa
      // on it, step 2 still queued. The line is about furiosa, not "waiting
      // for a worker" on step 2.
      final result = now(
        [
          item('ma-1', 'Toggle', createdAt: at(0)),
          item(
            'ma-2',
            'Remember it',
            state: WorkState.queued,
            createdAt: at(0),
          ),
        ],
        {
          'ma-1': cycle({DispatchStep.routed: at(2)}),
        },
        agents: [
          agent(
            'gc-58',
            name: 'my-app/gastown.furiosa',
            state: AgentState.stopped,
            workId: 'ma-1',
            sessionState: 'active',
            sessionRunning: true,
            sessionStartedAt: at(2),
          ),
        ],
      );
      expect(result.kind, TeamNowKind.starting);
      expect(result.workTitle, 'Toggle');
      expect(result.agentName, 'furiosa');
    });

    test('a running session overrides "the host has not started an agent"', () {
      final furiosa = agent(
        'gc-58',
        name: 'my-app/gastown.furiosa',
        state: AgentState.stopped,
        workId: 'ma-2',
        sessionState: 'active',
        sessionRunning: true,
        sessionStartedAt: at(2),
      );
      final stalled = {
        'ma-2': cycle(
          {DispatchStep.routed: at(1)},
          stalled: true,
          stallReason: DispatchStall.hostNotStarted,
        ),
      };
      final result = now(
        [item('ma-2', 'Login form')],
        stalled,
        agents: [furiosa],
      );
      expect(result.kind, TeamNowKind.starting);
      expect(result.since, at(2));
      // Without a running session the stall stands.
      expect(
        now([item('ma-2', 'Login form')], stalled).kind,
        TeamNowKind.stalled,
      );
    });

    test('review once handed over', () {
      final result = now(
        [item('ma-2', 'Login form')],
        {
          'ma-2': cycle({
            DispatchStep.routed: at(1),
            DispatchStep.agentStarting: at(2),
            DispatchStep.claimed: at(3),
            DispatchStep.working: at(3),
            DispatchStep.pushed: at(8),
            DispatchStep.handedToMerge: at(9),
          }),
        },
      );
      expect(result.kind, TeamNowKind.review);
      expect(result.since, at(9));
    });

    test('stalled says why and since when', () {
      final result = now(
        [item('ma-2', 'Login form')],
        {
          'ma-2': cycle(
            {DispatchStep.routed: at(1)},
            stalled: true,
            stallReason: DispatchStall.hostNotStarted,
          ),
        },
      );
      expect(result.kind, TeamNowKind.stalled);
      expect(result.stall, DispatchStall.hostNotStarted);
      expect(result.since, at(1));
    });

    test('every step done but the task open: review', () {
      final result = now([
        item(
          'ma-2',
          'Login form',
          state: WorkState.completed,
          updatedAt: at(7),
        ),
      ], const {});
      expect(result.kind, TeamNowKind.review);
      expect(result.since, at(7));
    });
  });

  group('teamSessionState', () {
    test('the session wins over a lagging agents list', () {
      expect(
        teamSessionState(
          agent('a', state: AgentState.stopped, sessionRunning: true),
        ),
        AgentState.working,
      );
      expect(
        teamSessionState(
          agent('a', state: AgentState.stopped, sessionState: 'active'),
        ),
        AgentState.working,
      );
      expect(
        teamSessionState(agent('a', sessionState: 'asleep')),
        AgentState.idle,
      );
      expect(
        teamSessionState(agent('a', sessionState: 'suspended')),
        AgentState.stopped,
      );
      expect(
        teamSessionState(agent('a', sessionState: 'failed')),
        AgentState.crashed,
      );
      expect(
        teamSessionState(agent('a', state: AgentState.idle)),
        AgentState.idle,
      );
    });

    test('waiting and blocked stay (they are the host facts on sessions)', () {
      expect(
        teamSessionState(
          agent('a', state: AgentState.waiting, sessionRunning: true),
        ),
        AgentState.waiting,
      );
      expect(
        teamSessionState(
          agent('a', state: AgentState.blocked, sessionState: 'active'),
        ),
        AgentState.blocked,
      );
    });
  });

  test('teamAgentShortName', () {
    String? name(String n) => teamAgentShortName(agent('x', name: n));
    expect(name('ocproof/gastown.furiosa'), 'furiosa');
    expect(name('my-app/gastown.refinery'), isNull);
    expect(name('gastown.dog-2'), isNull);
    expect(name('gastown.nux'), 'nux');
    expect(name('gastown.mayor'), isNull);
  });

  group('teamConversationAgents', () {
    final work = [item('ma-2', 'Login form'), item('ma-3', 'Cookie')];
    final agents = [
      agent('mayor', name: 'gastown.mayor', workId: null),
      agent(
        'gc-59',
        name: 'my-app/gastown.nux',
        state: AgentState.idle,
        workId: 'ma-3',
      ),
      agent('gc-58', name: 'my-app/gastown.furiosa', workId: 'ma-2'),
      agent('bl-r', name: 'my-app/gastown.refinery', state: AgentState.idle),
      agent('bl-o', name: 'other/gastown.refinery', state: AgentState.idle),
    ];

    test('the workers on the task, working first', () {
      final list = teamConversationAgents(
        agents: agents,
        work: work,
        cycleOf: (_) => DispatchCycle.none,
      );
      expect(list.map((a) => a.id), ['gc-58', 'gc-59']);
    });

    test('the project refinery joins once a step is handed to review', () {
      final list = teamConversationAgents(
        agents: agents,
        work: work,
        cycleOf: (id) => id == 'ma-2'
            ? cycle({
                DispatchStep.routed: at(1),
                DispatchStep.agentStarting: at(2),
                DispatchStep.claimed: at(3),
                DispatchStep.working: at(3),
                DispatchStep.pushed: at(8),
                DispatchStep.handedToMerge: at(9),
              })
            : DispatchCycle.none,
      );
      expect(list.map((a) => a.id), ['gc-58', 'gc-59', 'bl-r']);
    });
  });
}
