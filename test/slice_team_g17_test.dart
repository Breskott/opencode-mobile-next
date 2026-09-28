// slice-team-g17: on the team page amber means "needs you" and nothing else
// (docs/design/visual-language-2026-09-26.md §1, LOOK-4, LOOK-24). A state
// that waits on the person leads its row with the kit's one needs-you mark;
// a held-up, stale or degraded state (blocked, not answering, refused plain
// http, a high context) is neutral; a failure keeps the failure tone.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/team_states.dart';
import 'package:opencode_mobile/ui/widgets/team_agent_row.dart';
import 'package:opencode_mobile/ui/widgets/team_vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  group('the marks: needs you, or not amber at all', () {
    test('only the states that wait on the person take the needs-you mark', () {
      expect(
        [
          for (final s in WorkState.values)
            if (teamWorkMark(s).needsYou) s,
        ],
        [WorkState.needsInput],
      );
      expect(
        [
          for (final s in AgentState.values)
            if (teamAgentMark(s).needsYou) s,
        ],
        [AgentState.waiting],
      );
      expect(
        [
          for (final k in GateKind.values)
            if (teamGateMark(k).needsYou) k,
        ],
        [
          GateKind.choice,
          GateKind.confirmation,
          GateKind.freeText,
          GateKind.gateBead,
          GateKind.unknown,
        ],
      );
    });

    test('no team state is drawn in the attention tone', () {
      final tones = <AppStatusTone?>[
        for (final s in WorkState.values) teamWorkMark(s).tone,
        for (final s in AgentState.values) teamAgentMark(s).tone,
        for (final k in GateKind.values) teamGateMark(k).tone,
        for (final s in RunState.values) teamRunGlyph(s).$2,
        for (final kind in [null, ...OrchestrationErrorKind.values])
          teamErrorState(_en, kind).$2,
      ];
      expect(tones, isNot(contains(AppStatusTone.attention)));
    });

    test('held up and degraded states are neutral; a failure keeps its '
        'tone', () {
      expect(teamWorkMark(WorkState.blocked).tone, AppStatusTone.neutral);
      expect(teamAgentMark(AgentState.blocked).tone, AppStatusTone.neutral);
      expect(teamRunGlyph(RunState.blocked).$2, AppStatusTone.neutral);
      expect(
        teamErrorState(_en, OrchestrationErrorKind.unreachable).$2,
        AppStatusTone.neutral,
      );
      expect(
        teamErrorState(_en, OrchestrationErrorKind.plainHttpRefused).$2,
        AppStatusTone.neutral,
      );
      expect(teamGateMark(GateKind.runFailed).tone, AppStatusTone.failure);
      expect(teamWorkMark(WorkState.failed).tone, AppStatusTone.failure);
      // A request card still names the kind with its own glyph.
      expect(teamGateMark(GateKind.freeText).icon, AppIconography.editNote);
    });

    test('a high context reads in primary text, never amber or red', () {
      expect(teamContextTone(40), KitTextTone.secondary);
      expect(teamContextTone(teamContextHighPercent), KitTextTone.primary);
      expect(teamContextTone(95), KitTextTone.primary);
    });
  });

  group('rows', () {
    Future<void> pumpAgents(
      WidgetTester tester,
      List<OrchestrationAgent> agents,
    ) => tester.pumpWidget(
      _app(
        ListView(
          children: [
            for (final agent in agents)
              TeamAgentRow(
                agent: agent,
                work: null,
                now: DateTime.utc(2026, 9, 28),
                onTap: null,
              ),
          ],
        ),
      ),
    );

    Finder markIn(String id) => find.descendant(
      of: find.byKey(ValueKey('team-agent-$id')),
      matching: find.byType(KitTaskMark),
    );

    testWidgets('an agent waiting on the person leads with the needs-you '
        'mark; a blocked one does not', (tester) async {
      await pumpAgents(tester, const [
        OrchestrationAgent(id: 'fox', name: 'fox', state: AgentState.waiting),
        OrchestrationAgent(id: 'owl', name: 'owl', state: AgentState.blocked),
      ]);
      expect(markIn('fox'), findsOneWidget);
      expect(
        tester.widget<KitTaskMark>(markIn('fox')).state,
        KitTaskState.needsYou,
      );
      expect(markIn('owl'), findsNothing);
    });

    testWidgets('a question row leads with the same needs-you mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => KitRow(
              key: const ValueKey('gate'),
              leading: teamGateMark(GateKind.freeText).leading(context),
              title: 'What should the toggle say?',
            ),
          ),
        ),
      );
      final mark = tester.widget<KitTaskMark>(find.byType(KitTaskMark));
      expect(mark.state, KitTaskState.needsYou);
    });
  });

  testWidgets('a team that does not answer is a neutral state page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          ),
    );
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.gascity,
      url: 'http://100.100.1.2:8373',
      city: 'bright-lights',
      enabledAt: DateTime.utc(2026, 9, 10),
    );
    final team = OrchestrationController(
      profile: ServerProfile(
        id: 'pc',
        name: 'Laptop',
        baseUrl: 'http://100.100.1.2:4096',
        orchestration: config,
      ),
      config: config,
      store: OrchestrationStore(prefs),
      probe: (_) async => const ProbeUnreachable(error: 'no answer'),
    );
    addTearDown(team.dispose);
    await team.start();
    expect(teamScreenFailed(team), isTrue);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => teamScreenState(
            context,
            controller: team,
            keyPrefix: 'g17',
            onRetry: () {},
          )!,
        ),
      ),
    );
    final view = tester.widget<KitStateView>(find.byType(KitStateView));
    expect(view.tone, AppStatusTone.neutral);
    expect(find.text(_en.teamUiStateUnreachableTitle), findsOneWidget);
  });
}
