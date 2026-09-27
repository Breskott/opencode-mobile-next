// slice-R12: the AI Team host form's actions are pinned by its sheet and
// say what they do; the turn-off question's confirm names what it turns
// off; a moving board card is a sending receipt in the move's own words;
// the setup output's failure-report copy lives inside the log panel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_log_panel.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/widgets/setup_terminal.dart';
import 'package:opencode_mobile/ui/widgets/team_board_card.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Finder _key(String key) => find.byKey(ValueKey(key));

/// [key] inside the sheet's pinned action block.
Finder _pinned(String key) =>
    find.descendant(of: _key('kit-sheet-actions'), matching: _key(key));

Widget _app(Widget body) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: body),
);

/// Pumps a button that runs [open] and keeps its result.
Future<List<T?>> _open<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext context) open,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final results = <T?>[];
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Center(
          child: GestureDetector(
            key: const ValueKey('open'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(open(context).then(results.add)),
            child: const SizedBox.square(dimension: 48),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  return results;
}

const _found = ProbeFound(
  host: OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://100.64.0.3:8372',
    hostMode: OrchestrationHostMode.computer,
  ),
  city: 'demo',
);

void main() {
  group('host sheet: the changing actions are pinned', () {
    testWidgets('Test and turn on, then Cancel test while it runs', (
      tester,
    ) async {
      final answer = Completer<ProbeVerdict>();
      final results = await _open<OrchestrationConfig>(
        tester,
        (context) =>
            showTeamHostSheet(context, probe: (url, {city}) => answer.future),
      );
      final submit = _pinned('team-host-submit');
      expect(submit, findsOneWidget);
      expect(
        find.descendant(of: submit, matching: find.text(_en.teamUiAddSubmit)),
        findsOneWidget,
      );
      // Nothing to cancel or save yet.
      expect(_key('team-host-cancel-test'), findsNothing);
      expect(_key('team-host-save-anyway'), findsNothing);

      await tester.enterText(_key('team-host-url'), 'http://100.64.0.3:8372');
      await tester.tap(submit);
      await tester.pump();
      expect(_pinned('team-host-cancel-test'), findsOneWidget);
      expect(find.text(_en.teamUiAddTesting), findsOneWidget);

      await tester.tap(_pinned('team-host-cancel-test'));
      await tester.pump();
      expect(_key('team-host-cancel-test'), findsNothing);
      expect(find.text(_en.teamUiAddSubmit), findsOneWidget);

      // The answer for the cancelled test is dropped: the sheet stays.
      answer.complete(_found);
      await tester.pumpAndSettle();
      expect(_key('team-host-form'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('no answer: Save the address anyway, its note, and the raw '
        'error under Connection details', (tester) async {
      final results = await _open<OrchestrationConfig>(
        tester,
        (context) => showTeamHostSheet(
          context,
          probe: (url, {city}) async => const ProbeUnreachable(
            error: 'SocketException: Connection refused (OS Error: 111)',
          ),
        ),
      );
      await tester.enterText(_key('team-host-url'), 'http://100.64.0.3:8372');
      await tester.tap(_pinned('team-host-submit'));
      await tester.pumpAndSettle();

      expect(find.text(_en.teamUiVerdictUnreachable), findsOneWidget);
      expect(find.text(_en.teamHostFormSaveAnywayNote), findsOneWidget);
      expect(find.text(_en.teamHostFormConnectionDetails), findsOneWidget);
      expect(find.text('Details'), findsNothing);
      expect(find.textContaining('Connection refused'), findsNothing);
      // The retired wording is gone.
      expect(find.text('Save without an answer'), findsNothing);

      final save = _pinned('team-host-save-anyway');
      expect(
        find.descendant(
          of: save,
          matching: find.text(_en.teamHostFormSaveAnyway),
        ),
        findsOneWidget,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(results.single?.url, 'http://100.64.0.3:8372');
      expect(results.single?.front, isFalse);
    });

    testWidgets('a found host closes the sheet with its config', (
      tester,
    ) async {
      final results = await _open<OrchestrationConfig>(
        tester,
        (context) =>
            showTeamHostSheet(context, probe: (url, {city}) async => _found),
      );
      await tester.enterText(_key('team-host-url'), 'http://100.64.0.3:8372');
      await tester.tap(_pinned('team-host-submit'));
      await tester.pumpAndSettle();
      expect(_key('team-host-form'), findsNothing);
      expect(results.single?.city, 'demo');
    });
  });

  testWidgets('the turn-off confirm names what it turns off', (tester) async {
    final results = await _open<bool>(
      tester,
      (context) => showTeamTurnOffSheet(context, 'Workstation'),
    );
    expect(find.text(_en.teamUiTurnOffTitle('Workstation')), findsOneWidget);
    final confirm = _key('team-turn-off-confirm');
    expect(
      find.descendant(of: confirm, matching: find.text('Turn off AI Team')),
      findsOneWidget,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('a moving card is a sending receipt in the move\'s words', (
    tester,
  ) async {
    final card = TeamBoardCard(
      item: const WorkItem(
        id: 'oc-1',
        title: 'Fix flaky checkout test',
        state: WorkState.review,
      ),
      column: TeamBoardColumn.review,
      priority: WorkPriority.normal,
      moving: true,
    );
    await tester.pumpWidget(
      _app(
        TeamBoardCardView(
          card: card,
          now: DateTime.utc(2026, 9, 27, 12),
          onOpen: () {},
        ),
      ),
    );
    final receipt = tester.widget<KitReceipt>(find.byType(KitReceipt));
    expect(receipt.state, KitReceiptState.sending);
    expect(receipt.automatic, isFalse);
    expect(receipt.sendingLabel, 'Moving to Review…');
    expect(
      find.textContaining('Moving to Review', findRichText: true),
      findsOneWidget,
    );
  });

  group('setup output: the failure report is in the panel', () {
    Future<void> mount(WidgetTester tester, {String? copyTooltip}) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _app(
          SetupTerminal(
            output: 'error: failed',
            running: false,
            controller: scroll,
            onCopy: () {},
            copyTooltip: copyTooltip,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('named, inside the log panel, no loose button', (tester) async {
      await mount(tester, copyTooltip: _en.e7SetupCopyFailureReport);
      final panel = tester.widget<KitLogPanel>(find.byType(KitLogPanel));
      expect(panel.headerAction?.label, _en.e7SetupCopyFailureReport);
      final report = _key('setup-copy-report');
      expect(
        find.descendant(of: find.byType(KitLogPanel), matching: report),
        findsOneWidget,
      );
      // The report is a named button; Copy all stays the panel's own.
      expect(tester.widget(report), isA<KitButton>());
      expect(_key('kit-log-copy-all'), findsOneWidget);
    });

    testWidgets('without its words, no extra action', (tester) async {
      await mount(tester);
      final panel = tester.widget<KitLogPanel>(find.byType(KitLogPanel));
      expect(panel.headerAction, isNull);
      expect(_key('setup-copy-report'), findsNothing);
    });
  });
}
