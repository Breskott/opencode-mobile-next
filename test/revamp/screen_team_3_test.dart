// screen-team-3 (wave 2b): the AI Team's agents list is one list ordered by
// urgency (owner rule 2026-09-27: no state sections), every row names its
// agent ("furiosa · Worker") and says its state in words ("Asleep · wakes
// when there is work"), a paused agent can be woken from its row (map
// team-agents actionsMissing), the top bar says when the list was checked
// (statesMissing freshness), and the Work sheet's missing item is a
// designed state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/team_agents_screen.dart';
import 'package:opencode_mobile/ui/screens/team/work_sheet.dart';

import 'screen_team_3_fixtures.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Finder _key(String name) => find.byKey(ValueKey(name));

final _en = lookupAppLocalizations(const Locale('en'));

Future<OrchestrationController> _pumpAgents(
  WidgetTester tester, {
  List<OrchestrationAgent>? agents,
  OrchestrationCapabilities? caps,
  List<OrchestrationAgent>? opened,
}) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (controller, _) = await team3Controller(agents: agents, caps: caps);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _app(
      TeamAgentsScreen(
        controller: controller,
        now: () => team3Clock,
        onOpenAgent: opened?.add,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('one list, most urgent first; no group by state', (tester) async {
    await _pumpAgents(tester);
    final order = [
      for (final id in ['nux', 'mayor', 'furiosa', 'refinery', 'dog-1', 'slit'])
        tester.getTopLeft(_key('team-home-agent-$id')).dy,
    ];
    expect(order, [...order]..sort());
    // Asleep and paused agents are rows of the same list, not a folded
    // "Suspended on the host" group.
    expect(_key('team-home-suspended-group'), findsNothing);
    expect(find.textContaining('Suspended on the host'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows name the agent and say its state in words', (tester) async {
    await _pumpAgents(tester);
    Finder inRow(String id, String text) => find.descendant(
      of: _key('team-home-agent-$id'),
      matching: find.textContaining(text, findRichText: true),
    );
    expect(inRow('furiosa', 'furiosa · Worker'), findsOneWidget);
    expect(inRow('nux', 'nux · Worker'), findsOneWidget);
    expect(inRow('refinery', 'Reviewer'), findsOneWidget);
    expect(inRow('dog-1', 'Helper'), findsOneWidget);
    expect(inRow('furiosa', 'Working · Add subtract function'), findsOneWidget);
    expect(inRow('nux', 'Waiting for you'), findsOneWidget);
    expect(inRow('dog-1', 'Asleep · wakes when there is work'), findsOneWidget);
    expect(
      inRow('slit', 'Paused · switched off until someone wakes it'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wake slit asks the host to resume that agent, then shows the '
      'receipt', (tester) async {
    final controller = await _pumpAgents(tester);
    // One Wake for the paused agents above the list (owner, build 2055:
    // no button per row); asleep ones wake by themselves.
    expect(_key('team-agents-wake-paused'), findsOneWidget);
    expect(_key('team-agents-wake-slit'), findsNothing);
    expect(find.text(_en.teamAgentsWakePaused(1)), findsOneWidget);

    await tester.tap(_key('team-agents-wake-paused'));
    await tester.pumpAndSettle();
    final record = controller.latestMutation(
      kind: MutationKind.controlAgent,
      targetId: 'slit',
    );
    expect(record, isNotNull);
    expect(record!.request.action, AgentControlAction.resume);
    expect(_key('team-agents-wake-receipt'), findsOneWidget);
    // The fixture never confirms: after the wait the receipt says so, in
    // words, with Check again.
    await tester.pump(controller.mutationTimeout);
    await tester.pumpAndSettle();
    expect(_key('team-agents-wake-receipt'), findsOneWidget);
    expect(find.text(_en.teamAgentsWakeUnconfirmed), findsOneWidget);
    expect(_key('team-agents-wake-check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no Wake when the host keeps agent controls to itself', (
    tester,
  ) async {
    await _pumpAgents(
      tester,
      caps: const OrchestrationCapabilities(runs: true, workGraph: true),
    );
    expect(_key('team-agents-wake-paused'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row opens its agent', (tester) async {
    final opened = <OrchestrationAgent>[];
    await _pumpAgents(tester, opened: opened);
    await tester.tap(_key('team-home-agent-furiosa'));
    await tester.pumpAndSettle();
    expect(opened.single.id, 'furiosa');
  });

  testWidgets('the top bar says when the list was checked', (tester) async {
    await _pumpAgents(tester);
    expect(
      find.textContaining('checked less than a minute ago'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty only when the host lists no agent at all', (tester) async {
    await _pumpAgents(tester, agents: const []);
    expect(_key('team-home-agents-empty'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    // Every agent asleep is still the team: rows, not "No agents".
    await _pumpAgents(
      tester,
      agents: const [
        OrchestrationAgent(
          id: 'dog-1',
          name: 'gastown.dog-1',
          pool: 'gastown.dog',
          state: AgentState.stopped,
        ),
      ],
    );
    expect(_key('team-home-agents-empty'), findsNothing);
    expect(_key('team-home-agent-dog-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a work item the host no longer lists is a designed state', (
    tester,
  ) async {
    final (controller, _) = await team3Controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showWorkSheet(
                  context,
                  controller,
                  'gone',
                  now: () => team3Clock,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Work item gone'), findsOneWidget);
    expect(_key('team-work-sheet-missing'), findsOneWidget);
    expect(
      find.text('This work item is no longer on the host.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Close this sheet to see the task as it is now.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
