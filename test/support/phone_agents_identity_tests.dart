part of '../phone_agents_controller_test.dart';

/// What a conversation with an agent on this phone says it is (placeholder,
/// connection line), through the doors that open it: the start path, and a
/// cold open that never went through the Chats list.
void _phoneIdentityTests() {
  Future<void> pumpChat(WidgetTester tester, _World w, String id) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connProvider.overrideWithValue(w.controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: chatLandingPage(sessionID: id),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a chat started with Codex says Codex, never OpenCode', (
    tester,
  ) async {
    final w = await _world(
      tester,
      prefsExtra: {'oc.phoneAgentsUsed.local': true},
    );
    w.state.runtimes = {'claude': _ready('claude'), 'codex': _ready('codex')};
    w.state.providers = [_provider('claude'), _provider('codex')];
    w.state.agents = [];
    final c = w.controller;
    await c.rememberLastUsedProject(_project);
    await c.refreshAgentRows();
    final id = await c.startAgentChatIn(_project, agentId: 'codex');
    expect(c.backendForConversation(id)?.isAgentBackend, isTrue);

    await pumpChat(tester, w, id);

    // Whatever the page says, it says Codex and never OpenCode.
    expect(find.textContaining('Codex'), findsWidgets);
    expect(find.textContaining('OpenCode'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a Codex chat opened cold, without the list, waits for its own '
      'connection and never opens on OpenCode', (tester) async {
    final w = await _world(
      tester,
      prefsExtra: {
        'oc.phoneAgentsUsed.local': true,
        'oc.agentFeed.local': jsonEncode([
          {
            'sourceId': 'paseo:$_project',
            'sessionID': 'saved-codex',
            'title': 'Finance hub',
            'directory': _project,
            'projectName': 'app',
            'isGit': false,
            'at': DateTime(2026, 10, 3).millisecondsSinceEpoch,
            'agentId': 'codex',
            'agentLabel': 'Codex',
            'canReopen': true,
          },
        ]),
      },
    );
    w.state.runtimes = {'claude': _ready('claude'), 'codex': _ready('codex')};
    w.state.providers = [_provider('claude'), _provider('codex')];
    w.state.agents = [];
    final c = w.controller;
    await c.rememberLastUsedProject(_project);
    // The door: a notification, shortcut or last-known row, not the list.
    expect(c.backendForConversation('saved-codex'), isNull);
    expect(c.agentConversationNeedsBackend('saved-codex'), isTrue);
    expect(c.agentConversationNeedsBackend('some-opencode-chat'), isFalse);

    await pumpChat(tester, w, 'saved-codex');

    expect(c.backendForConversation('saved-codex')?.isAgentBackend, isTrue);
    expect(find.textContaining('OpenCode'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a continued conversation shows its link line in the chat', (
    tester,
  ) async {
    final w = await _world(
      tester,
      prefsExtra: {'oc.phoneAgentsUsed.local': true},
    );
    w.state.runtimes = {'claude': _ready('claude')};
    w.state.agents = [_agent('c1', _project)];
    final c = w.controller;
    await c.rememberLastUsedProject(_project);
    await c.refreshAgentRows();
    await c.refreshChatFeed();
    final row = c.chatFeed().items.firstWhere((i) => i.sessionID == 'c1');
    await c.openChatFeedItem(row);
    await AgentHandoffLinks.forPreferences(c.store.prefs).save(
      const HandoffLink(
        id: 'link-1',
        sourceProfileId: 'local',
        sourceSessionId: 'c1',
        sourceOrigin: HandoffOrigin.phoneAgent,
        sourceTitle: 'Finance hub',
        targetProfileId: 'local',
        targetSessionId: 'c2',
        targetOrigin: HandoffOrigin.phoneAgent,
        targetAgent: 'Claude Code',
        projectDirectory: _project,
        handoffPath: '.handoff/x/record.md',
      ),
    );

    await pumpChat(tester, w, 'c1');

    expect(find.byKey(const ValueKey('continued-line')), findsOneWidget);
    expect(
      find.textContaining('Claude Code', findRichText: true),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });
}
