// The AI Team redesign (docs/design/aiteam-redesign-2026-09-24.md): the
// rules a person sees, checked on the scenes of
// test/support/team_golden_fixture.dart. Each test fails on 51a775cf (the
// commit before the redesign); see
// docs/qa/aiteam-redesign-2026-09-24/README.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import 'support/team_golden_fixture.dart';

/// Gas City's insides: never on a task row, the card or the run's
/// Overview. They stay under Technical details.
final _engineWords = RegExp(
  r'\b(convoys?|formulas?|beads?|rigs?|city|polecats?|refinery|sling|'
  r'wisps?|mayor|gastown)\b|127\.0\.0\.1|\b\d+\.\d+\.\d+\b|\bmol-',
  caseSensitive: false,
);

/// The question the loaded scene's worker asks.
const _question = 'Keep drafts in SQLite or in plain files?';

Finder _key(String name) => find.byKey(ValueKey(name));

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

/// Every piece of text drawn under [within] (Text and Text.rich alike).
List<String> _shown(Finder within) => [
  for (final element
      in find
          .descendant(of: within, matching: find.byType(RichText))
          .evaluate())
    (element.widget as RichText).text.toPlainText(),
];

List<String> _engineWordsIn(Finder within) => [
  for (final text in _shown(within))
    if (_engineWords.hasMatch(text)) text,
];

Future<OrchestrationController> _pump(
  WidgetTester tester,
  Widget Function(OrchestrationController controller) screen, {
  TeamScene scene = TeamScene.loaded,
  bool onPhone = false,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = await teamSceneController(scene, onPhone: onPhone);
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
      home: screen(controller),
    ),
  );
  await tester.pump();
  return controller;
}

Widget _home(OrchestrationController controller) =>
    TeamHomeScreen(controller: controller, now: () => teamSceneClock);

Widget _run(OrchestrationController controller) => RunScreen(
  controller: controller,
  runId: teamSceneRunId,
  now: () => teamSceneClock,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final onPhone in [false, true]) {
    final where = onPhone ? 'on this phone' : 'on a computer';
    testWidgets('no engine words on the home, its rows or the '
        'run\'s Overview and Steps ($where)', (tester) async {
      await _pump(tester, _home, onPhone: onPhone);
      expect(_engineWordsIn(find.byType(TeamHomeScreen)), isEmpty);

      await _pump(tester, _run, onPhone: onPhone);
      expect(_engineWordsIn(find.byType(RunScreen)), isEmpty);
      await tester.tap(_key('team-run-tab-work'));
      await tester.pumpAndSettle();
      expect(_engineWordsIn(find.byType(RunScreen)), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Needs you comes first: the question heads the home, above '
      'every task, without a tap', (tester) async {
    await _pump(tester, _home);
    final question = find.text(_question);
    expect(question, findsOneWidget);
    expect(
      _top(tester, question),
      lessThan(_top(tester, _key('team-home-run-oc-xru'))),
    );
    expect(
      _top(tester, question),
      lessThan(_top(tester, _key('team-home-run-mol-upgrade'))),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('three tasks: no filters, no search, no segments', (
    tester,
  ) async {
    await _pump(tester, _home);
    expect(
      find.byWidgetPredicate(
        (w) => w is ChoiceChip || w is FilterChip || w is SegmentedButton,
      ),
      findsNothing,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Search tasks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more than eight tasks: search waits behind the top bar\'s '
      'search icon', (tester) async {
    await _pump(tester, _home, scene: TeamScene.busy);
    expect(find.byType(TextField), findsNothing);
    final open = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Search tasks'),
    );
    expect(open, findsOneWidget);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'follow-up task 3');
    await tester.pumpAndSettle();
    expect(_key('team-home-run-busy-3'), findsOneWidget);
    expect(_key('team-home-run-busy-4'), findsNothing);
    expect(_key('team-home-run-oc-xru'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the agents list names agents by role, not by engine name', (
    tester,
  ) async {
    await _pump(tester, _home);
    // Under the team's Now line and the tasks.
    await tester.scrollUntilVisible(
      _key('team-home-agents-row'),
      200,
      scrollable: find.descendant(
        of: _key('team-home-runs'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('team-home-agents-row'));
    await tester.pumpAndSettle();
    expect(find.text('Worker'), findsNWidgets(2));
    expect(find.text('Planner'), findsOneWidget);
    expect(_engineWordsIn(find.byType(MaterialApp)), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
