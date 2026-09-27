// Gallery of slice-P5.1, the team's Now line: a task given 31 minutes ago
// with no plan yet (the line, its honest reason and the Why folded open in
// place with its ways out), and the team page where that task is a row of
// the one list (the planning card is gone), at 412x915 and 1280x800, dark and light, with
// the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p5_1_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/team_planning.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart'
    show AgentState, OrchestrationAgent;
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_chat_fixture.dart';
import 'chat_3_support.dart';

final _sentAt = teamClock.subtract(const Duration(minutes: 31));

final _record = MutationRecord(
  key: 'plan-1',
  request: MutationRequest.message(
    teamPlannerAgentId,
    composeTeamPlanningMessage(
      objective: 'Add a dark mode toggle',
      supervision: TeamSupervision.balanced,
    ),
  ),
  createdAt: _sentAt,
  status: MutationStatus.confirmed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(chat3MockSecureStorage);

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    for (final light in [false, true]) {
      final sized = size.width == 412
          ? ''
          : '_${size.width.toInt()}x${size.height.toInt()}';
      final file =
          'p51_team_conversation_planning_why${sized}_'
          '${light ? 'light' : 'dark'}';
      testWidgets(file, (tester) async {
        await withClock(Clock.fixed(teamClock), () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (team, _) = await bootTeam(runs: const [], work: const []);
          final connection = await teamConnection(
            api: TeamChatApi(const {}),
            repository: TeamChatRepository(const []),
          );
          final boundary = GlobalKey();
          try {
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: ProviderScope(
                  overrides: [connProvider.overrideWithValue(connection)],
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: captureTheme(light: light),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: true),
                      child: child!,
                    ),
                    home: TeamControllerScope(
                      team: team,
                      child: TeamConversationScreen(
                        team: team,
                        pending: TeamPendingTask(
                          title: 'Add a dark mode toggle',
                          sentAt: _sentAt,
                          record: _record,
                        ),
                        now: () => teamClock,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('team-conversation-now-why')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(boundary),
              matchesGoldenFile('goldens/$file.png'),
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            debugDefaultTargetPlatformOverride = null;
          }
        });
      });
    }
  }

  // The team page: the task given is a row of the one list, saying where
  // it stands, with no card or drawing of its own.
  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    final sized = size.width == 412
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    final file = 'p51_team_home_planning_row${sized}_dark';
    testWidgets(file, (tester) async {
      await withClock(Clock.fixed(teamClock), () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (team, _) = await bootTeam(
          runs: const [],
          work: const [],
          agents: [
            teamFuriosa(),
            const OrchestrationAgent(
              id: teamPlannerAgentId,
              name: teamPlannerAgentId,
              state: AgentState.idle,
            ),
          ],
        );
        await team.messageAgent(
          teamPlannerAgentId,
          composeTeamPlanningMessage(
            objective: 'Add a dark mode toggle',
            supervision: TeamSupervision.balanced,
          ),
        );
        final connection = await teamConnection(
          api: TeamChatApi(const {}),
          repository: TeamChatRepository(const []),
        );
        final boundary = GlobalKey();
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: ProviderScope(
                overrides: [connProvider.overrideWithValue(connection)],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: captureTheme(light: false),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: child!,
                  ),
                  home: TeamHomeScreen(controller: team, now: () => teamClock),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('goldens/$file.png'),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          // The sent message's receipt window runs out.
          await tester.pump(const Duration(seconds: 61));
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  }
}
