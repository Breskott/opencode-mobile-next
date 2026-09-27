// Gallery of slice-P3.5 and the owner's team conversation reports (build
// 2055): a task with no progress for 45 h (the Now line, the notice and its
// next steps, the task said once), a moving task under the header strip
// and above the solid composer band, and Task details (the sheet that
// replaced the run page), at 412x915 and 1280x800, dark and light, with the
// app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p3_5_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_board_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_chat_fixture.dart';
import 'chat_3_support.dart';

final _stalledAt = teamClock.subtract(const Duration(hours: 45));

final _stalledTask = OrchestrationRun(
  id: 'ma-convoy-1',
  title: 'Add a dark mode toggle',
  state: RunState.working,
  rawState: 'open',
  kind: RunKind.batch,
  projectId: 'my-app',
  stepCount: 1,
  completedSteps: 0,
  startedAt: _stalledAt.subtract(const Duration(minutes: 5)),
  updatedAt: _stalledAt,
  raw: const {'id': 'ma-convoy-1', 'issue_type': 'convoy'},
);

final _soleStep = WorkItem(
  id: 'ma-1',
  title: 'Add a dark mode toggle',
  state: WorkState.working,
  rawState: 'in_progress',
  runId: 'ma-convoy-1',
  projectId: 'my-app',
  assignee: 'my-app/gastown.furiosa',
  createdAt: _stalledAt.subtract(const Duration(minutes: 5)),
  updatedAt: _stalledAt,
  raw: const {
    'id': 'ma-1',
    'metadata': {'gc.routed_to': 'my-app/gastown.polecat'},
  },
);

final _quietFuriosa = OrchestrationAgent(
  id: 'my-app/gastown.furiosa',
  name: 'my-app/gastown.furiosa',
  state: AgentState.working,
  rawState: 'active',
  sessionId: 'ma-wisp-7',
  sessionName: 'my-app--gastown__polecat-ma-wisp-7',
  pool: 'my-app/gastown.polecat',
  provider: 'opencode',
  harness: 'OpenCode',
  currentWorkId: 'ma-1',
  workDir: teamPolecatDir,
  sessionStartedAt: _stalledAt,
  lastActivity: _stalledAt,
  sessionState: 'active',
  sessionRunning: true,
);

typedef _Then = Future<void> Function(WidgetTester tester);

class _Scene {
  const _Scene({this.stalled = false, this.then});

  final bool stalled;
  final _Then? then;
}

Future<void> _details(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('team-conversation-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('team-conversation-details')));
  await tester.pumpAndSettle();
}

Future<void> _toEnd(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('team-conversation-list')),
    const Offset(0, -2000),
  );
  await tester.pumpAndSettle();
}

final _scenes = <String, _Scene>{
  'p35_team_conversation_no_progress': const _Scene(
    stalled: true,
    then: _toEnd,
  ),
  'p35_team_conversation_working': const _Scene(),
  'p35_team_task_details': const _Scene(then: _details),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(chat3MockSecureStorage);

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    for (final light in [false, true]) {
      final sized = size.width == 412
          ? ''
          : '_${size.width.toInt()}x${size.height.toInt()}';
      final theme = light ? 'light' : 'dark';
      for (final MapEntry(key: name, value: scene) in _scenes.entries) {
        final file = '$name${sized}_$theme';
        testWidgets(file, (tester) async {
          await withClock(Clock.fixed(teamClock), () async {
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final (team, _) = scene.stalled
                ? await bootTeam(
                    runs: [_stalledTask],
                    work: [_soleStep],
                    agents: [_quietFuriosa],
                  )
                : await bootTeam();
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
                          runId: 'ma-convoy-1',
                          now: () => teamClock,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await scene.then?.call(tester);
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
  }

  // The board's + is the one "Give the team a task" sheet (P3.5), with
  // Keep in backlog beside Send.
  for (final (size, light) in const [
    (Size(412, 915), false),
    (Size(1280, 800), true),
  ]) {
    final sized = size.width == 412
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    final file = 'p35_board_give_task${sized}_${light ? 'light' : 'dark'}';
    testWidgets(file, (tester) async {
      await withClock(Clock.fixed(teamClock), () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (team, _) = await bootTeam(
          agents: [
            teamFuriosa(),
            const OrchestrationAgent(
              id: 'gastown.mayor',
              name: 'gastown.mayor',
              state: AgentState.stopped,
              suspended: true,
            ),
          ],
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
                    child: TeamBoardScreen(
                      controller: team,
                      projectId: 'my-app',
                      now: () => teamClock,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final add = find.byWidgetPredicate(
            (w) =>
                w.key == const ValueKey('team-board-add') ||
                w.key == const ValueKey('team-board-empty-add'),
          );
          await tester.tap(add.first);
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
