// "Open conversation" (2026-09-25, the owner watching his team on the
// phone: "Why isn't these rendered as regular conversations in the already
// built glorious chat page?"). An AI Team worker is an `opencode acp`
// process on the phone's own OpenCode store, so its work is an ordinary
// OpenCode session in its work folder. The agent screen opens that session
// on the chat page in watching mode: a slim banner, no composer (one
// "Message the worker" action through the team's message control), no
// actions that change the session, and the transcript read again while the
// worker writes. With no such session on the connected server, Live output
// opens with a line saying why.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/agent_output_screen.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'support/team_chat_fixture.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The phone's store: furiosa's session for this task, an older one of
  /// the same (reused) worktree from a previous task, the refinery's, and
  /// the person's own conversation in the rig.
  List<GlobalSessionResult> store() => [
    teamSession(
      'ses_furiosa',
      teamPolecatDir,
      updated: DateTime.utc(2026, 9, 25, 19, 54),
      title: 'Polecat startup: claim work and execute',
    ),
    teamSession(
      'ses_furiosa_old',
      teamPolecatDir,
      updated: DateTime.utc(2026, 9, 24, 17, 10),
    ),
    teamSession(
      'ses_refinery',
      teamRefineryDir,
      updated: DateTime.utc(2026, 9, 25, 19, 54, 30),
    ),
    teamSession(
      'ses_mine',
      teamRig,
      updated: DateTime.utc(2026, 9, 25, 19, 54, 40),
      title: 'Add a dark mode toggle',
    ),
  ];

  Map<String, List<MessageWithParts>> transcript() => {
    'ses_furiosa': [
      teamChatMessage('m1', 'user', 'Run gc prime and claim your work.'),
      teamChatMessage(
        'm2',
        'assistant',
        'Claimed ma-1. Adding the toggle to Settings.',
      ),
    ],
  };

  testWidgets(
    'the agent screen opens the worker\'s own conversation in watching mode',
    (tester) async {
      phoneViewport(tester);
      final (team, gateway) = await bootTeam();
      final api = TeamChatApi(transcript());
      final repository = TeamChatRepository(store());
      final connection = await teamConnection(api: api, repository: repository);
      await tester.pumpWidget(
        teamChatApp(
          connection,
          AgentScreen(
            controller: team,
            agentId: 'my-app/gastown.furiosa',
            now: () => teamClock,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Its conversation maps: "Open conversation" is the screen's one
      // primary, and Live output moved to the overflow menu.
      expect(
        tester.widget<KitButton>(_key('team-agent-open-conversation')).role,
        KitButtonRole.primary,
      );
      expect(_key('team-agent-open-output'), findsNothing);
      expect(_key('team-agent-conversation-miss'), findsNothing);
      // Its session runs (the agents list says stopped): Pause, not Resume,
      // beside the "Working" status.
      expect(_key('team-agent-control-pause'), findsOneWidget);
      expect(_key('team-agent-control-resume'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Open conversation'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open conversation'));
      await tester.pumpAndSettle();

      // The chat page, on furiosa's session for this task (not the older
      // one in the same worktree, not the person's own in the rig).
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionID,
        'ses_furiosa',
      );
      expect(find.text('Watching furiosa · Worker · AI Team'), findsOneWidget);
      expect(
        find.text('Claimed ma-1. Adding the toggle to Settings.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Back returns to the team.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AgentScreen), findsOneWidget);
      expect(gateway.messages, isEmpty);
    },
  );

  testWidgets('watching: no composer, no session actions, Message goes to the '
      'team\'s control and nothing into the OpenCode session', (tester) async {
    phoneViewport(tester);
    final (team, gateway) = await bootTeam();
    final api = TeamChatApi(transcript());
    final connection = await teamConnection(
      api: api,
      repository: TeamChatRepository(store()),
    );
    await tester.pumpWidget(
      teamChatApp(
        connection,
        Builder(
          builder: (context) => ChatScreen(
            sessionID: 'ses_furiosa',
            watch: teamAgentWatch(context, teamFuriosa(), team: team),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_key('chat-watching-banner'), findsOneWidget);
    expect(_key('chat-watching-composer'), findsOneWidget);
    // No prompt field, no conversation menu, no running-work switch.
    expect(find.byType(TextField), findsNothing);
    expect(_key('session-actions-button'), findsNothing);
    expect(_key('running-work-indicator'), findsNothing);
    // Copy stays; the message actions (revert, fork) do not.
    expect(_key('message-actions-m2'), findsNothing);

    await tester.tap(find.text('Message the worker'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _key('chat-watching-message-field'),
      'Use the system setting as the default.',
    );
    await tester.pump();
    await tester.tap(_key('chat-watching-message-send'));
    await tester.pumpAndSettle();

    expect(gateway.messages, [
      ('my-app/gastown.furiosa', 'Use the system setting as the default.'),
    ]);
    expect(api.prompts, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('watching reads the transcript again while the worker writes', (
    tester,
  ) async {
    phoneViewport(tester);
    final (team, _) = await bootTeam();
    final messages = transcript();
    final api = TeamChatApi(messages);
    final connection = await teamConnection(
      api: api,
      repository: TeamChatRepository(store()),
    );
    await tester.pumpWidget(
      teamChatApp(
        connection,
        Builder(
          builder: (context) => ChatScreen(
            sessionID: 'ses_furiosa',
            watch: teamAgentWatch(context, teamFuriosa(), team: team),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Toggle added; running the tests.'), findsNothing);

    // The worker's process writes to the shared store; the server's event
    // stream never says so.
    messages['ses_furiosa']!.add(
      teamChatMessage(
        'm3',
        'assistant',
        'Toggle added; running the tests.',
        minute: 54,
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Toggle added; running the tests.'), findsOneWidget);
    expect(api.prompts, isEmpty);
  });

  testWidgets('no conversation on the connected server: Live output, saying '
      'why', (tester) async {
    phoneViewport(tester);
    final (team, _) = await bootTeam();
    // Only the previous task's session in the worktree: furiosa's current
    // one is not on this server (still starting, or the team runs on
    // another computer).
    final repository = TeamChatRepository([
      teamSession(
        'ses_furiosa_old',
        teamPolecatDir,
        updated: DateTime.utc(2026, 9, 24, 17, 10),
      ),
    ]);
    final connection = await teamConnection(
      api: TeamChatApi(const {}),
      repository: repository,
    );
    await tester.pumpWidget(
      teamChatApp(
        connection,
        AgentScreen(
          controller: team,
          agentId: 'my-app/gastown.furiosa',
          now: () => teamClock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The agent screen already knows: its primary is Live output, with the
    // reason beside it, and no "Open conversation" that leads nowhere.
    expect(find.text('Open conversation'), findsNothing);
    expect(
      tester.widget<KitButton>(_key('team-agent-open-output')).role,
      KitButtonRole.primary,
    );
    expect(_key('team-agent-conversation-miss'), findsOneWidget);
    expect(
      find.textContaining("Its conversation isn't on the server"),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      _key('team-agent-open-output'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_key('team-agent-open-output'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(AgentOutputScreen), findsOneWidget);
    expect(_key('team-agent-output-note'), findsOneWidget);
    expect(
      find.textContaining("Its conversation isn't on the server"),
      findsOneWidget,
    );

    // Its session shows up (the worker got going): Refresh looks again and
    // Open conversation becomes the primary.
    await tester.pageBack();
    await tester.pumpAndSettle();
    repository.results.add(
      teamSession(
        'ses_furiosa',
        teamPolecatDir,
        updated: DateTime.utc(2026, 9, 25, 19, 54),
      ),
    );
    await tester.tap(_key('team-agent-refresh'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<KitButton>(_key('team-agent-open-conversation')).role,
      KitButtonRole.primary,
    );
    expect(_key('team-agent-conversation-miss'), findsNothing);
  });

  testWidgets('a watched team session stays out of the person\'s lists', (
    tester,
  ) async {
    phoneViewport(tester);
    final (team, _) = await bootTeam();
    final connection = await teamConnection(
      api: TeamChatApi(transcript()),
      repository: TeamChatRepository(store()),
    );
    connection.directory = teamRig;
    await connection.refreshSessions();
    await tester.pumpWidget(
      teamChatApp(
        connection,
        Builder(
          builder: (context) => ChatScreen(
            sessionID: 'ses_furiosa',
            watch: teamAgentWatch(context, teamFuriosa(), team: team),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    // Read for the page, never listed: the project's list is the person's.
    expect(connection.sessionsById, contains('ses_furiosa'));
    expect(connection.sortedSessions().map((s) => s.id), ['ses_mine']);
    final elsewhere = await connection.conversationsElsewhere();
    expect(elsewhere.map((c) => c.session.id), isNot(contains('ses_furiosa')));
    expect(elsewhere.map((c) => c.session.id), isNot(contains('ses_refinery')));
  });
}
