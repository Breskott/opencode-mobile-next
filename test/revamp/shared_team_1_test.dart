// Behaviour of shared-team-1's rebuilt team pieces (wave 2a): the control
// receipt (one KitReceipt since slice-P4.1c), the message field over KitField, the board's
// sheets on the kit sheet frame, and the manual host form's fixes from its
// map record (progress with Cancel test, Save the address anyway, no "kind
// of computer" question, the raw error under Details).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/mutation_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_board.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/widgets/team_board_move_sheet.dart';
import 'package:opencode_mobile/ui/widgets/team_controls.dart';
import 'package:opencode_mobile/ui/widgets/team_host_form.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Finder _key(String key) => find.byKey(ValueKey(key));

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

MutationRecord _record(MutationStatus status, {String? reason}) =>
    MutationRecord(
      key: 'k1',
      request: MutationRequest.controlAgent('fox', AgentControlAction.nudge),
      createdAt: DateTime.utc(2026, 9, 27, 10),
      status: status,
      receipt: reason == null ? null : MutationReceipt.rejected('k1', reason),
    );

String _plain(String text) =>
    text.replaceAll(RegExp(r'[\u2066-\u2069\u200E]', unicode: true), '');

bool _hasText(WidgetTester tester, String wanted) => tester
    .widgetList<Text>(find.byType(Text))
    .any(
      (text) =>
          _plain(text.data ?? text.textSpan?.toPlainText() ?? '') == wanted,
    );

TeamBoardCard _card() => TeamBoardCard(
  item: const WorkItem(
    id: 'oc-1',
    title: 'Fix flaky checkout test',
    state: WorkState.ready,
  ),
  column: TeamBoardColumn.ready,
  priority: WorkPriority.normal,
);

void main() {
  group('teamControlReceipt is the one KitReceipt (slice-P4.1c)', () {
    Widget receipt(MutationRecord record, {Future<void> Function()? onRetry}) =>
        _app(
          Builder(
            builder: (context) =>
                teamControlReceipt(context, record, onRetry: onRetry),
          ),
        );

    testWidgets('names the control while it moves and once confirmed', (
      tester,
    ) async {
      await tester.pumpWidget(receipt(_record(MutationStatus.sent)));
      final kit = tester.widget<KitReceipt>(find.byType(KitReceipt));
      expect(kit.state, KitReceiptState.sending);
      expect(kit.automatic, isFalse);
      expect(_hasText(tester, 'Nudge · Sending…'), isTrue);

      await tester.pumpWidget(receipt(_record(MutationStatus.confirmed)));
      expect(_hasText(tester, 'Nudge · Confirmed'), isTrue);
    });

    testWidgets('unconfirmed offers Try again, which retries', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        receipt(
          _record(MutationStatus.unconfirmed),
          onRetry: () async => retried++,
        ),
      );
      expect(_hasText(tester, _en.kitReceiptNotConfirmed), isTrue);
      await tester.tap(_key('team-receipt-retry'));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('a refusal carries the host reason', (tester) async {
      await tester.pumpWidget(
        receipt(_record(MutationStatus.rejected, reason: 'session gone')),
      );
      expect(find.textContaining('session gone'), findsOneWidget);
    });
  });

  group('confirmTeamControl', () {
    testWidgets('true only on the confirming button', (tester) async {
      final results = await _open<bool>(
        tester,
        (context) => confirmTeamControl(
          context,
          title: 'Stop Worker · furiosa?',
          message: 'Its session ends now.',
          confirmLabel: 'Stop agent',
          sheetKey: const ValueKey('sheet'),
          confirmKey: const ValueKey('confirm'),
        ),
      );
      expect(_key('sheet'), findsOneWidget);
      expect(find.text(_en.teamUiControlKeep), findsOneWidget);
      await tester.tap(_key('confirm'));
      await tester.pumpAndSettle();
      expect(results, [true]);
    });
  });

  group('board sheets', () {
    testWidgets('move sheet: the task title, moves, Cancel task last', (
      tester,
    ) async {
      final results = await _open<TeamBoardSheetChoice>(
        tester,
        (context) => showTeamBoardMoveSheet(
          context,
          card: _card(),
          moves: const [
            TeamBoardMove.cancel,
            TeamBoardMove.backToBacklog,
            TeamBoardMove.priority,
          ],
          readOnly: false,
          hasConversation: true,
        ),
      );
      expect(_key('team-board-move-sheet'), findsOneWidget);
      expect(find.text('Fix flaky checkout test'), findsOneWidget);
      final open = tester.getTopLeft(_key('team-board-move-open')).dy;
      final cancel = tester.getTopLeft(_key('team-board-move-cancel')).dy;
      expect(cancel, greaterThan(open));
      await tester.tap(_key('team-board-move-backToBacklog'));
      await tester.pumpAndSettle();
      expect(results.single, isA<TeamBoardChoseMove>());
      expect(
        (results.single! as TeamBoardChoseMove).move,
        TeamBoardMove.backToBacklog,
      );
    });

    testWidgets('priority: a new level returns it, the same one null', (
      tester,
    ) async {
      var results = await _open<WorkPriority>(
        tester,
        (context) =>
            showTeamBoardPrioritySheet(context, current: WorkPriority.normal),
      );
      await tester.tap(_key('team-board-priority-urgent'));
      await tester.pumpAndSettle();
      expect(results, [WorkPriority.urgent]);

      results = await _open<WorkPriority>(
        tester,
        (context) =>
            showTeamBoardPrioritySheet(context, current: WorkPriority.normal),
      );
      await tester.tap(_key('team-board-priority-normal'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('cancel asks, with Keep it as the way back', (tester) async {
      final results = await _open<bool>(
        tester,
        (context) => confirmTeamBoardCancel(context, 'Fix flaky test'),
      );
      expect(_key('team-board-cancel-sheet'), findsOneWidget);
      await tester.tap(find.text(_en.teamBoardCancelKeep));
      await tester.pumpAndSettle();
      expect(results, [false]);
    });
  });

  group('host form (map team-host-sheet: fix)', () {
    Future<void> pumpForm(
      WidgetTester tester,
      TeamHostProbe probe,
      List<OrchestrationConfig> found,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: TeamHostForm(probe: probe, onFound: found.add),
          ),
        ),
      );
    }

    testWidgets('no kind of computer; the city is the team name', (
      tester,
    ) async {
      await pumpForm(
        tester,
        (url, {city}) async => const ProbeUnreachable(error: 'x'),
        [],
      );
      for (final kind in teamHostKindChoices) {
        expect(_key('team-host-kind-${kind.name}'), findsNothing);
      }
      expect(find.text(_en.teamUiHostKindLabel), findsNothing);
      expect(find.text(_en.teamHostFormTeamLabel), findsOneWidget);
    });

    testWidgets('testing is progress with Cancel test; a late answer is '
        'dropped', (tester) async {
      final answer = Completer<ProbeVerdict>();
      final found = <OrchestrationConfig>[];
      await pumpForm(tester, (url, {city}) => answer.future, found);
      await tester.enterText(_key('team-host-url'), 'http://100.64.0.3:8372');
      await tester.tap(_key('team-host-submit'));
      await tester.pump();
      // Progress is the working primary, with Cancel test beside it.
      expect(_key('team-host-cancel-test'), findsOneWidget);
      await tester.tap(_key('team-host-cancel-test'));
      await tester.pump();
      expect(_key('team-host-cancel-test'), findsNothing);
      answer.complete(
        const ProbeFound(
          host: OrchestrationHostIdentity(
            provider: 'gascity',
            url: 'http://100.64.0.3:8372',
            hostMode: OrchestrationHostMode.computer,
          ),
          city: 'demo',
        ),
      );
      await tester.pump();
      expect(found, isEmpty);
    });

    testWidgets('no answer: the reason, the raw error under Details, and '
        'Save the address anyway', (tester) async {
      final found = <OrchestrationConfig>[];
      await pumpForm(
        tester,
        (url, {city}) async => const ProbeUnreachable(
          error: 'SocketException: Connection refused (OS Error: 111)',
        ),
        found,
      );
      await tester.enterText(_key('team-host-url'), 'http://100.64.0.3:8372');
      await tester.tap(_key('team-host-submit'));
      await tester.pumpAndSettle();
      expect(find.text(_en.teamUiVerdictUnreachable), findsOneWidget);
      // The raw error is folded, not on the page.
      expect(find.textContaining('Connection refused'), findsNothing);
      expect(find.byKey(const ValueKey('kit-details-toggle')), findsOneWidget);
      await tester.tap(_key('team-host-save-anyway'));
      await tester.pump();
      expect(found.single.url, 'http://100.64.0.3:8372');
      expect(found.single.provider, OrchestrationProvider.gascity);
      expect(found.single.front, isFalse);
    });

    testWidgets('not a team host: the guide is one named action away', (
      tester,
    ) async {
      await pumpForm(
        tester,
        (url, {city}) async => const ProbeNotGasCity(statusCode: 200),
        [],
      );
      await tester.enterText(_key('team-host-url'), 'http://100.64.0.3:8372');
      await tester.tap(_key('team-host-submit'));
      await tester.pumpAndSettle();
      expect(find.text(_en.teamHostFormHowAction), findsOneWidget);
      expect(_key('team-host-save-anyway'), findsNothing);
    });
  });
}
