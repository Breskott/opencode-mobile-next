// The AI Team as a conversation (docs/design/team-conversation-2026-09-26.md)
// on the chat page, with the owner's phone timings of 2026-09-25: the task
// given at 19:49:03, furiosa's session created at 19:51:05, its first output
// about 19:55. Your prompt is the task; the lead's reply is written from the
// team's real events with their times; furiosa is a sub-agent card whose
// state comes from its session (Gas City's /agents said stopped while
// /sessions said running); the Now line says it is starting and that this
// can take minutes on a phone; the composer's words go through the team's
// message control, never into a worker's OpenCode session.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';

import 'support/team_chat_fixture.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

/// A time as the page shows it: the phone's own clock, 24-hour.
String _hhmm(DateTime at) {
  final local = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

/// ma-1 routed to the worker pool at 19:51:05 (its bead says so), not yet
/// claimed: furiosa's session runs but has written nothing yet.
final _routed = WorkItem(
  id: 'ma-1',
  title: 'Add the toggle to Settings',
  state: WorkState.working,
  rawState: 'open',
  runId: 'ma-convoy-1',
  projectId: 'my-app',
  createdAt: DateTime.utc(2026, 9, 25, 19, 49, 3),
  updatedAt: DateTime.utc(2026, 9, 25, 19, 51, 5),
  raw: const {
    'id': 'ma-1',
    'metadata': {'gc.routed_to': 'my-app/gastown.polecat'},
  },
);

final _queued = WorkItem(
  id: 'ma-2',
  title: 'Remember the choice',
  state: WorkState.queued,
  rawState: 'open',
  runId: 'ma-convoy-1',
  projectId: 'my-app',
  createdAt: DateTime.utc(2026, 9, 25, 19, 49, 3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(OrchestrationController, TeamChatGateway, TeamChatApi)> pump(
    WidgetTester tester, {
    List<WorkItem>? work,
    List<OrchestrationGate> gates = const [],
    List<OrchestrationRun>? runs,
    Future<void> Function(BuildContext, OrchestrationAgent)? onOpenAgent,
    String? runId = 'ma-convoy-1',
    TeamPendingTask? pending,
    List<OrchestrationAgent>? agents,
  }) async {
    phoneViewport(tester);
    final (team, gateway) = await bootTeam(
      runs: runs,
      work: work ?? [_routed, _queued],
      gates: gates,
      agents: agents,
    );
    final api = TeamChatApi({
      'ses_furiosa': [
        teamChatMessage('m1', 'assistant', 'Claimed ma-1.', minute: 55),
      ],
    });
    final connection = await teamConnection(
      api: api,
      repository: TeamChatRepository([
        teamSession(
          'ses_furiosa',
          teamPolecatDir,
          updated: DateTime.utc(2026, 9, 25, 19, 54),
        ),
      ]),
    );
    await tester.pumpWidget(
      teamChatApp(
        connection,
        TeamControllerScope(
          team: team,
          child: TeamConversationScreen(
            team: team,
            runId: runId,
            pending: pending,
            now: () => teamClock,
            onOpenAgent: onOpenAgent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (team, gateway, api);
  }

  testWidgets('the task reads as a conversation from the team\'s real data', (
    tester,
  ) async {
    await pump(tester);

    // Your prompt is the task.
    expect(
      find.descendant(
        of: _key('team-conversation-prompt'),
        matching: find.text('Add a dark mode toggle'),
      ),
      findsOneWidget,
    );
    // The lead's lines, each from a real event with its time.
    final lead = _key('team-conversation-lead');
    expect(
      find.descendant(
        of: lead,
        matching: find.textContaining(
          'Planned 2 steps · ${_hhmm(DateTime.utc(2026, 9, 25, 19, 49))}',
          findRichText: true,
        ),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: lead,
        matching: find.textContaining(
          'Sent “Add the toggle to Settings” to the workers · '
          '${_hhmm(DateTime.utc(2026, 9, 25, 19, 51))}',
          findRichText: true,
        ),
      ),
      findsWidgets,
    );
    // furiosa: the session runs, whatever /agents said.
    expect(find.text('furiosa · Worker'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            _key('team-conversation-agent-line-my-app/gastown.furiosa'),
          )
          .data,
      startsWith('Working'),
    );
    // The one Now line: starting, slow on a phone, with the elapsed time.
    expect(
      tester.widget<Text>(_key('team-conversation-now-text')).data,
      'furiosa is starting · can take a few minutes on a phone · 3 min',
    );
    // The family strip: the lead and furiosa.
    expect(_key('team-conversation-family-lead'), findsOneWidget);
    expect(
      _key('team-conversation-family-my-app/gastown.furiosa'),
      findsOneWidget,
    );
    // The steps, with the Overview's marks.
    expect(_key('team-conversation-step-ma-1'), findsOneWidget);
    expect(_key('team-conversation-step-ma-2'), findsOneWidget);
    expect(
      tester.widget<Text>(_key('team-conversation-composer-note')).data,
      'Goes to furiosa · Worker through the AI Team',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Message the team goes through the team\'s control, never into '
      'the worker\'s OpenCode session', (tester) async {
    final (_, gateway, api) = await pump(tester);
    await tester.enterText(
      _key('team-conversation-field'),
      'Put the toggle under Appearance.',
    );
    await tester.pump();
    await tester.tap(_key('team-conversation-send'));
    await tester.pumpAndSettle();

    expect(gateway.messages, [
      ('my-app/gastown.furiosa', 'Put the toggle under Appearance.'),
    ]);
    expect(api.prompts, isEmpty);
    // The person's words stay in the conversation with their receipt.
    expect(
      find.textContaining(
        'Put the toggle under Appearance.',
        findRichText: true,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'team-conversation-sent-',
            ),
      ),
      findsOneWidget,
    );
    // The send's confirmation window runs out (no host event here).
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('the worker card opens its conversation in watching mode', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('furiosa · Worker'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Watching furiosa · Worker · AI Team'), findsOneWidget);
    expect(find.text('Claimed ma-1.'), findsOneWidget);
    expect(find.text('Message the worker'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_key('team-conversation'), findsOneWidget);
  });

  testWidgets('a question from the team is the request card, answered here', (
    tester,
  ) async {
    final (_, gateway, _) = await pump(
      tester,
      gates: [
        OrchestrationGate(
          id: 'ma-gate-1',
          kind: GateKind.choice,
          title: 'Which default?',
          prompt: 'Should the toggle follow the system setting?',
          workId: 'ma-1',
          runId: 'ma-convoy-1',
          choices: const ['Follow the system', 'Always dark'],
          createdAt: DateTime.utc(2026, 9, 25, 19, 54),
        ),
      ],
    );
    expect(
      tester.widget<Text>(_key('team-conversation-now-text')).data,
      'Needs you · Which default?',
    );
    await tester.ensureVisible(find.text('Always dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Always dark'));
    await tester.pumpAndSettle();
    await tester.tap(_key('team-conversation-gate-ma-gate-1-send'));
    await tester.pumpAndSettle();
    expect(gateway.messages, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key ==
            const ValueKey('team-conversation-gate-ma-gate-1-receipt'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('many steps fold under one line', (tester) async {
    await pump(
      tester,
      work: [
        _routed,
        _queued,
        for (var i = 3; i <= 5; i++)
          WorkItem(
            id: 'ma-$i',
            title: 'Step $i',
            state: i == 5 ? WorkState.completed : WorkState.queued,
            runId: 'ma-convoy-1',
          ),
      ],
    );
    expect(find.text('5 steps · 1 done'), findsOneWidget);
    expect(_key('team-conversation-step-ma-4'), findsNothing);
    await tester.tap(_key('team-conversation-steps-fold'));
    await tester.pumpAndSettle();
    expect(_key('team-conversation-step-ma-4'), findsOneWidget);
  });

  testWidgets('a task just given binds to its run once the team lists it', (
    tester,
  ) async {
    final (team, gateway, _) = await pump(
      tester,
      runId: null,
      runs: const [],
      work: const [],
      pending: TeamPendingTask(
        title: 'Add a dark mode toggle',
        sentAt: DateTime.utc(2026, 9, 25, 19, 49, 3),
        workId: 'ma-1',
      ),
    );
    expect(
      tester.widget<Text>(_key('team-conversation-now-text')).data,
      'Waiting for the team to pick it up · 5 min',
    );
    expect(
      find.textContaining(
        'Sent to the team · ${_hhmm(DateTime.utc(2026, 9, 25, 19, 49))}',
        findRichText: true,
      ),
      findsWidgets,
    );

    gateway
      ..runsOverride = [teamTask]
      ..workOverride = [_routed, _queued];
    await team.refresh();
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Planned 2 steps · ${_hhmm(DateTime.utc(2026, 9, 25, 19, 49))}',
        findRichText: true,
      ),
      findsWidgets,
    );
    expect(find.text('furiosa · Worker'), findsOneWidget);
  });

  testWidgets('the task Overview opens the task as a conversation', (
    tester,
  ) async {
    phoneViewport(tester);
    final (team, _) = await bootTeam(work: [_routed, _queued]);
    final connection = await teamConnection(
      api: TeamChatApi(const {}),
      repository: TeamChatRepository(const []),
    );
    await tester.pumpWidget(
      teamChatApp(
        connection,
        RunScreen(controller: team, runId: 'ma-convoy-1', now: () => teamClock),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open conversation'));
    await tester.pumpAndSettle();
    expect(find.byType(TeamConversationScreen), findsOneWidget);
    expect(_key('team-conversation-lead'), findsOneWidget);
  });

  // The chat's rule (the turn model in chat/message_view.dart): lines share
  // the prose's edge, with no frame or fill, and work folds under one line.
  group('drawn the chat\'s one way', () {
    testWidgets('the lead reads as a plain reply: no fill, no bullets', (
      tester,
    ) async {
      await pump(tester);
      final lead = _key('team-conversation-lead');
      final surfaces = find.descendant(
        of: lead,
        matching: find.byKey(const Key('assistant-text-surface')),
      );
      expect(surfaces, findsWidgets);
      for (final element in surfaces.evaluate()) {
        final box = (element.widget as AnimatedContainer).decoration;
        expect(
          (box as BoxDecoration?)?.color ?? Colors.transparent,
          Colors.transparent,
          reason: 'the lead is a finished reply, not one still being written',
        );
      }
      // Three lines: none folded.
      expect(_key('team-conversation-lead-earlier'), findsNothing);
      expect(
        find.descendant(
          of: lead,
          matching: find.textContaining('•', findRichText: true),
        ),
        findsNothing,
      );
    });

    testWidgets('many lead lines fold the earlier ones under one line', (
      tester,
    ) async {
      await pump(
        tester,
        work: [
          _routed,
          _queued,
          WorkItem(
            id: 'ma-3',
            title: 'Drop the old flag',
            state: WorkState.cancelled,
            runId: 'ma-convoy-1',
            updatedAt: DateTime.utc(2026, 9, 25, 19, 53),
          ),
        ],
        gates: [
          OrchestrationGate(
            id: 'ma-gate-1',
            kind: GateKind.choice,
            title: 'Which default?',
            workId: 'ma-1',
            runId: 'ma-convoy-1',
            choices: const ['Follow the system', 'Always dark'],
            createdAt: DateTime.utc(2026, 9, 25, 19, 54),
          ),
        ],
      );
      final planned = find.textContaining(
        'Planned 3 steps',
        findRichText: true,
      );
      expect(_key('team-conversation-lead-earlier'), findsOneWidget);
      expect(find.text('3 earlier updates'), findsOneWidget);
      expect(planned, findsNothing);
      // The newest stay in view.
      expect(
        find.textContaining('Needs you', findRichText: true),
        findsWidgets,
      );
      await tester.tap(_key('team-conversation-lead-earlier'));
      await tester.pumpAndSettle();
      expect(planned, findsWidgets);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a worker is a sub-agent line, not a boxed card', (
      tester,
    ) async {
      OrchestrationAgent? opened;
      await pump(tester, onOpenAgent: (_, agent) async => opened = agent);
      final line = _key('team-conversation-agent-my-app/gastown.furiosa');
      expect(line, findsOneWidget);
      expect(
        find.ancestor(of: line, matching: find.byType(KitPanel)),
        findsNothing,
      );
      expect(
        find.descendant(of: line, matching: find.byType(KitPanel)),
        findsNothing,
      );
      // One line: who, what it works on, its state and time.
      expect(
        find.descendant(of: line, matching: find.text('furiosa · Worker')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: line,
          matching: find.text('Add the toggle to Settings'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(line).height,
        lessThan(64),
        reason: 'one line of the reply',
      );
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(opened?.id, 'my-app/gastown.furiosa');
    });

    testWidgets('the header never says Paused while the worker runs', (
      tester,
    ) async {
      // The agents list says furiosa is suspended; its session runs.
      final base = teamFuriosa();
      await pump(
        tester,
        agents: [
          OrchestrationAgent(
            id: base.id,
            name: base.name,
            state: AgentState.stopped,
            rawState: 'suspended',
            suspended: true,
            sessionId: base.sessionId,
            sessionName: base.sessionName,
            pool: base.pool,
            currentWorkId: base.currentWorkId,
            workDir: base.workDir,
            sessionStartedAt: base.sessionStartedAt,
            sessionState: 'active',
            sessionRunning: true,
          ),
        ],
      );
      expect(find.text('AI Team · On this phone'), findsOneWidget);
      expect(find.textContaining('Paused'), findsNothing);
    });
  });
}
