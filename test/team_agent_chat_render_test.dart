// Renders for docs/qa/team-agent-chat-2026-09-25 at 412 × 915, dark: the
// agent screen's "Open conversation", the worker's conversation in watching
// mode, its live output as the fallback, and the task as a conversation (also
// in Arabic). Writes PNGs only when TEAM_CHAT_CAPTURE_DIR is set; otherwise
// it checks each screen builds without an exception.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';

import '../tool/capture/fixtures.dart'
    show capturePng, captureTheme, loadCaptureFonts, writePng;
import 'support/team_chat_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['TEAM_CHAT_CAPTURE_DIR'];

  setUpAll(() async {
    if (dir != null) await loadCaptureFonts();
  });

  Future<void> shoot(
    WidgetTester tester,
    ConnectionController connection,
    Widget home,
    String name, {
    Locale locale = const Locale('en'),
    Future<void> Function()? before,
  }) async {
    phoneViewport(tester);
    // TEAM_CHAT_CAPTURE_WIDE: the same pages in a 1280 x 800 window.
    if (Platform.environment['TEAM_CHAT_CAPTURE_WIDE'] != null) {
      tester.view.physicalSize = const Size(1280, 800);
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [connProvider.overrideWithValue(connection)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await before?.call();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (dir != null) {
      await writePng('$dir/$name.png', await capturePng(tester, boundary));
    }
  }

  final work = [
    WorkItem(
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
    ),
    WorkItem(
      id: 'ma-2',
      title: 'Remember the choice',
      state: WorkState.queued,
      rawState: 'open',
      runId: 'ma-convoy-1',
      projectId: 'my-app',
      createdAt: DateTime.utc(2026, 9, 25, 19, 49, 3),
    ),
  ];

  final transcript = {
    'ses_furiosa': [
      teamChatMessage(
        'm1',
        'user',
        'Run `gc prime`, claim your work and carry it out.',
        minute: 55,
      ),
      teamChatMessage(
        'm2',
        'assistant',
        'Claimed **ma-1** (Add the toggle to Settings). The settings screen '
            'lives in `lib/settings/appearance.dart`; I will add a '
            '`SwitchListTile` bound to the theme mode and a test for it.',
        minute: 56,
      ),
    ],
  };

  Future<ConnectionController> connection() => teamConnection(
    api: TeamChatApi(transcript),
    repository: TeamChatRepository([
      teamSession(
        'ses_furiosa',
        teamPolecatDir,
        updated: DateTime.utc(2026, 9, 25, 19, 56),
        title: 'Polecat startup: claim work and execute',
      ),
    ]),
  );

  testWidgets('agent screen with Open conversation', (tester) async {
    final (team, _) = await bootTeam(work: work);
    await shoot(
      tester,
      await connection(),
      AgentScreen(
        controller: team,
        agentId: 'my-app/gastown.furiosa',
        now: () => teamClock,
      ),
      'agent-screen-open-conversation',
      before: () => tester.scrollUntilVisible(
        find.text('Open conversation'),
        300,
        scrollable: find.byType(Scrollable).first,
      ),
    );
  });

  testWidgets('watching chat', (tester) async {
    final (team, _) = await bootTeam(work: work);
    final conn = await connection();
    await shoot(
      tester,
      conn,
      Builder(
        builder: (context) => ChatScreen(
          sessionID: 'ses_furiosa',
          watch: teamAgentWatch(context, teamFuriosa(), team: team),
        ),
      ),
      'watching-chat',
    );
  });

  testWidgets('live output fallback', (tester) async {
    final (team, _) = await bootTeam(work: work);
    await shoot(
      tester,
      await connection(),
      Builder(
        builder: (context) => TeamWatchLiveScreen(
          team: team,
          agentId: 'my-app/gastown.furiosa',
          note: lookupAppLocalizations(
            const Locale('en'),
          ).teamWatchFallbackNotFound,
        ),
      ),
      'live-output-fallback',
    );
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('team conversation ${locale.languageCode}', (tester) async {
      final (team, _) = await bootTeam(work: work);
      await shoot(
        tester,
        await connection(),
        TeamControllerScope(
          team: team,
          child: TeamConversationScreen(
            team: team,
            runId: 'ma-convoy-1',
            now: () => teamClock,
          ),
        ),
        'team-conversation-${locale.languageCode}',
        locale: locale,
      );
    });
  }

  testWidgets('team conversation needs you', (tester) async {
    final (team, _) = await bootTeam(
      work: work,
      gates: [
        OrchestrationGate(
          id: 'ma-gate-1',
          kind: GateKind.choice,
          title: 'Which default should the toggle start with?',
          workId: 'ma-1',
          runId: 'ma-convoy-1',
          choices: const ['Follow the system', 'Always dark'],
          createdAt: DateTime.utc(2026, 9, 25, 19, 54),
        ),
      ],
    );
    await shoot(
      tester,
      await connection(),
      TeamControllerScope(
        team: team,
        child: TeamConversationScreen(
          team: team,
          runId: 'ma-convoy-1',
          now: () => teamClock,
        ),
      ),
      'team-conversation-needs-you',
      before: () => tester.drag(
        find.byKey(const ValueKey('team-conversation-list')),
        const Offset(0, -600),
      ),
    );
  });
}
