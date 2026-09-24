// The AI Team on the design standard (docs/design/design-standard.md,
// migration step 4): the rules a person sees, checked on the scenes of
// test/support/team_golden_fixture.dart. Each test fails on dca366f1 (the
// commit before the migration); see
// docs/qa/design-standard-aiteam-2026-09-24/README.md.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import 'support/team_golden_fixture.dart';

Finder _key(String name) => find.byKey(ValueKey(name));

Future<OrchestrationController> _pump(
  WidgetTester tester,
  TeamScene scene, {
  bool run = false,
  double width = 412,
}) async {
  tester.view.physicalSize = Size(width, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = await teamSceneController(scene);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: run
          ? RunScreen(
              controller: controller,
              runId: teamSceneRunId,
              now: () => teamSceneClock,
            )
          : TeamHomeScreen(controller: controller, now: () => teamSceneClock),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('§4: connecting says so, and after 8 s says the host is not '
      'answering with a way out; one 2 dp bar, no spinner', (tester) async {
    await _pump(tester, TeamScene.connecting);
    expect(_key('team-home-loading'), findsOneWidget);
    expect(find.text('Connecting to the team host…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 2);

    await tester.pump(const Duration(seconds: 7));
    expect(_key('team-home-not-answering'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(_key('team-home-loading'), findsNothing);
    expect(_key('team-home-not-answering'), findsOneWidget);
    expect(find.text('The team host isn’t answering'), findsOneWidget);
    expect(_key('team-home-retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('§3: a failed host is one state: title, body, Try again, and '
      'the technical error only under Details, below the action', (
    tester,
  ) async {
    await _pump(tester, TeamScene.failed);
    expect(_key('team-home-error'), findsOneWidget);
    expect(find.text('Can’t reach the team host'), findsOneWidget);
    final retry = _key('team-home-retry');
    expect(retry, findsOneWidget);
    // The raw error is not on screen until Details opens, and sits below
    // the action when it does.
    expect(find.textContaining('Connection refused'), findsNothing);
    await tester.tap(_key('kit-state-details'));
    await tester.pump();
    final raw = find.textContaining('Connection refused');
    expect(raw, findsOneWidget);
    expect(
      tester.getTopLeft(raw).dy,
      greaterThan(tester.getBottomLeft(retry).dy),
    );
  });

  testWidgets('§1/§2: Start a run is the one primary, pinned below the list '
      'rather than floating over it', (tester) async {
    await _pump(tester, TeamScene.loaded);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FloatingActionButton), findsNothing);
    final start = _key('team-home-start-run');
    expect(start, findsOneWidget);
    expect(
      find.ancestor(of: start, matching: _key('kit-screen-bottom')),
      findsOneWidget,
    );
    // The list ends above the button: nothing of it is drawn under it.
    final list = find.byKey(const ValueKey('team-home-runs'));
    expect(
      tester.getBottomLeft(list).dy,
      lessThanOrEqualTo(tester.getTopLeft(start).dy),
    );
  });

  testWidgets('§6: a finished task keeps its whole "Done · merged 5h ago" '
      'line', (tester) async {
    await _pump(tester, TeamScene.loaded, width: 600);
    await tester.pump(const Duration(milliseconds: 300));
    final line = find.descendant(
      of: _key('team-home-run-state-ma-lqw'),
      matching: find.byType(RichText),
    );
    expect(line, findsOneWidget);
    expect(
      tester.widget<RichText>(line).text.toPlainText(),
      'Done · merged 5h ago',
    );
    expect(
      tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('§1: the run keeps one icon action; Technical details and '
      'Stop run are in the overflow', (tester) async {
    await _pump(tester, TeamScene.loaded, run: true);
    await tester.pump(const Duration(milliseconds: 300));
    final bar = find.byType(AppBar);
    expect(
      find.descendant(of: bar, matching: find.byType(IconButton)),
      findsNWidgets(2), // Refresh, and the overflow's own button
    );
    expect(_key('team-run-details'), findsNothing);
    await tester.tap(_key('team-run-more'));
    await tester.pumpAndSettle();
    expect(_key('team-run-details'), findsOneWidget);
    expect(_key('team-run-cancel'), findsOneWidget);
  });

  testWidgets('the run\'s four stages are drawn, not zero-sized', (
    tester,
  ) async {
    // The old progress bar was once laid out 0 dp tall and never seen;
    // its replacement, the stage line, must take real space.
    await _pump(tester, TeamScene.loaded, run: true);
    await tester.pump(const Duration(milliseconds: 300));
    final stages = _key('team-run-stage-line');
    expect(stages, findsOneWidget);
    final size = tester.getSize(stages);
    expect(size.height, greaterThan(16));
    expect(size.width, greaterThan(100));
  });
}
