// slice-P4.1c: a team gate is the one request card (KitRequestCard.ask)
// wherever it shows, answered in place where the answer is common, with
// the Gate sheet as its Details and one KitReceipt for every answer:
//
// - a decision's option sends on one tap, once, and the card carries
//   "Sending…" on the chosen option;
// - an approval's Approve and Deny send in place (Deny asks nothing more);
//   a destructive one is answered in Details, behind its two steps;
// - a free-text question takes its reply in the card, and the words share
//   the Gate sheet's draft;
// - a refused answer says why above the answers, which stay;
// - a failed task opens Details, which keeps Report this failure (P8.4);
// - a phone that only watches says where to answer and keeps Details;
// - rows point with the one receipt (no chip class is left in lib/ but
//   the one kept for the home until slice-P3.4 merges).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/gate_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_needs_you.dart';
import 'package:opencode_mobile/ui/widgets/team_receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'slice_p4_1c_support.dart';

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OrchestrationStore store;
  final clock = p41cClock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
  });

  Future<(OrchestrationController, P41cGateway)> boot({
    OrchestrationCapabilities capabilities =
        OrchestrationCapabilities.gascityFront,
    List<OrchestrationGate> gates = const [],
  }) async {
    final booted = await p41cBoot(
      store,
      capabilities: capabilities,
      gates: gates,
    );
    addTearDown(booted.$1.dispose);
    expect(booted.$1.phase, OrchestrationPhase.ready);
    return booted;
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets the store's wait window run out so no timer outlives the test.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
  }

  /// The card as the team's conversation shows it, Details opening the
  /// Gate sheet.
  Future<void> pumpCard(
    WidgetTester tester,
    OrchestrationController controller,
    String gateId, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final gate in controller.snapshot.gates)
                  if (gate.id == gateId)
                    TeamNeedsYouCard(
                      keyPrefix: 'gate',
                      controller: controller,
                      gate: gate,
                      title: teamGateWho(_en, controller.snapshot, gate),
                      onOpen: () => unawaited(
                        showGateSheet(
                          context,
                          controller,
                          gate.id,
                          now: () => clock,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<P41cCall> responds(P41cGateway gateway) =>
      gateway.calls.where((c) => c.verb == 'respond').toList();

  testWidgets('a decision is the one request card; one tap sends once', (
    tester,
  ) async {
    final (controller, gateway) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g1',
          kind: GateKind.choice,
          title: 'Which storage should sync use?',
          choices: const ['SQLite', 'Files'],
          agentId: 'bl-5qc',
          createdAt: clock.subtract(const Duration(minutes: 4)),
        ),
      ],
    );
    await pumpCard(tester, controller, 'g1');

    final card = tester.widget<KitRequestCard>(find.byType(KitRequestCard));
    expect(card.kind, KitRequestKind.question);
    expect(card.who, 'fox');
    expect(card.answers, isA<KitRequestChoose<int>>());
    expect(key('gate-more'), findsOneWidget, reason: 'Details');

    await tester.tap(key('gate-option-0'));
    await tester.tap(key('gate-option-0'), warnIfMissed: false);
    await settle(tester);
    final sent = responds(gateway);
    expect(sent, hasLength(1));
    expect((sent.single.arg! as GateResponse).choice, 'SQLite');

    // The chosen option carries the one receipt; the other option goes.
    final after = tester.widget<KitRequestCard>(find.byType(KitRequestCard));
    expect(after.phase, KitRequestPhase.sending);
    expect(after.receipt?.state, KitReceiptState.sending);
    expect(find.text('Files'), findsNothing);
    expect(
      find.textContaining(_en.kitReceiptSending, findRichText: true),
      findsWidgets,
    );
    await drain(tester);
  });

  testWidgets('an approval answers in place; Deny asks nothing more', (
    tester,
  ) async {
    final (controller, gateway) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g2',
          kind: GateKind.confirmation,
          title: 'Run the database migration?',
          agentId: 'bl-5qc',
          createdAt: clock,
        ),
      ],
    );
    await pumpCard(tester, controller, 'g2');
    expect(find.text(_en.teamUiGateAnswerApprove), findsOneWidget);

    await tester.tap(key('gate-deny'));
    await settle(tester);
    expect(key('team-gate-confirm'), findsNothing);
    final sent = responds(gateway);
    expect(sent, hasLength(1));
    expect((sent.single.arg! as GateResponse).confirmed, isFalse);
    // The sending line names the answer beside its receipt.
    expect(find.text('${_en.teamUiGateAnswerDeny} ·'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a destructive approval is answered in Details, in two steps', (
    tester,
  ) async {
    final (controller, gateway) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g3',
          kind: GateKind.confirmation,
          title: 'Delete the staging database?',
          agentId: 'bl-5qc',
          createdAt: clock,
          raw: const {'destructive': true},
        ),
      ],
    );
    await pumpCard(tester, controller, 'g3');
    expect(key('gate-approve'), findsNothing);

    await tester.tap(key('gate-answer'));
    await settle(tester);
    expect(key('team-gate-sheet'), findsOneWidget);
    expect(key('team-gate-destructive'), findsOneWidget);
    await tester.tap(key('team-gate-approve'));
    await settle(tester);
    expect(key('team-gate-confirm'), findsOneWidget);
    expect(responds(gateway), isEmpty);
    await tester.tap(key('team-gate-confirm-yes'));
    await settle(tester);
    expect(responds(gateway), hasLength(1));
    await drain(tester);
  });

  testWidgets('a free-text reply is typed in the card and shares its draft', (
    tester,
  ) async {
    final (controller, gateway) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g4',
          kind: GateKind.freeText,
          title: 'What should the offline banner say?',
          agentId: 'bl-5qc',
          createdAt: clock,
        ),
      ],
    );
    await pumpCard(tester, controller, 'g4');
    final card = tester.widget<KitRequestCard>(find.byType(KitRequestCard));
    expect(card.kind, KitRequestKind.reply);

    await tester.enterText(key('gate-reply'), 'You are offline');
    await settle(tester);
    final prefs = await SharedPreferences.getInstance();
    final draftKey = KitDraft.keyFor(gateSheetDraftTarget('g4'), 'srv-1');
    expect(prefs.getString(draftKey), 'You are offline');

    await tester.tap(key('gate-send'));
    await settle(tester);
    final sent = responds(gateway);
    expect(sent, hasLength(1));
    expect((sent.single.arg! as GateResponse).text, 'You are offline');
    expect(prefs.getString(draftKey), isNull);
    await drain(tester);
  });

  testWidgets('a refused answer says why and offers the answers again', (
    tester,
  ) async {
    final (controller, gateway) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g5',
          kind: GateKind.choice,
          title: 'Which storage should sync use?',
          choices: const ['SQLite', 'Files'],
          agentId: 'bl-5qc',
          createdAt: clock,
        ),
      ],
    );
    gateway.refuse = 'The gate was closed';
    await pumpCard(tester, controller, 'g5');
    await tester.tap(key('gate-option-1'));
    await settle(tester);

    final card = tester.widget<KitRequestCard>(find.byType(KitRequestCard));
    expect(card.phase, KitRequestPhase.waiting);
    expect(card.receipt?.state, KitReceiptState.refused);
    expect(find.textContaining('The gate was closed'), findsOneWidget);
    expect(key('gate-option-0'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a failed task opens Details, which keeps Report this failure', (
    tester,
  ) async {
    final (controller, _) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g6',
          kind: GateKind.runFailed,
          title: 'Run failed',
          prompt: 'exit status 1: go test ./...',
          runId: 'oc-xru',
          workId: 'w2',
          agentId: 'fox',
          createdAt: clock,
        ),
      ],
    );
    await pumpCard(tester, controller, 'g6');
    final card = tester.widget<KitRequestCard>(find.byType(KitRequestCard));
    expect(card.reason, KitNeedsYouReason.blocked);
    expect(card.answers, isA<KitRequestInSheet>());
    expect(find.text(_en.teamGateCardRunFailedOpen), findsOneWidget);
    expect(find.text(_en.teamGateCardIfIgnoredFailed), findsOneWidget);

    await tester.tap(key('gate-answer'));
    await settle(tester);
    expect(key('team-gate-sheet'), findsOneWidget);
    // The sheet is the card's Details: titled after the task that stopped.
    expect(
      find.text(_en.teamUiGateRunStoppedTitle('Offline-first sessions')),
      findsOneWidget,
    );
    expect(key('team-gate-run-fix'), findsOneWidget);
    // Report this failure stays among the failure's ways out (P8.4).
    final block = tester.widget<KitActionBlock>(find.byType(KitActionBlock));
    expect(
      block.tertiary.map((action) => action.key),
      contains(const ValueKey('team-gate-run-report')),
    );
    await drain(tester);
  });

  testWidgets('a phone that only watches says where to answer', (tester) async {
    final (controller, gateway) = await boot(
      capabilities: OrchestrationCapabilities.gascityRead,
      gates: [
        OrchestrationGate(
          id: 'g7',
          kind: GateKind.confirmation,
          title: 'Run the database migration?',
          agentId: 'bl-5qc',
          createdAt: clock,
        ),
      ],
    );
    await pumpCard(tester, controller, 'g7');
    final card = tester.widget<KitRequestCard>(find.byType(KitRequestCard));
    expect(card.answers, isNull);
    expect(
      find.textContaining(_en.teamUiHomeGateAnswerOnComputer),
      findsOneWidget,
    );
    expect(key('gate-more'), findsOneWidget);
    expect(gateway.calls, isEmpty);
  });

  testWidgets('the Gate sheet opens with the ask as its title', (tester) async {
    final (controller, _) = await boot(
      gates: [
        OrchestrationGate(
          id: 'g8',
          kind: GateKind.choice,
          title: 'Which storage should sync use?',
          choices: const ['SQLite', 'Files'],
          agentId: 'bl-5qc',
          createdAt: clock,
        ),
      ],
    );
    await pumpCard(tester, controller, 'g8');
    await tester.tap(key('gate-more'));
    await settle(tester);
    final sheet = find.byKey(const ValueKey('team-gate-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Which storage should sync use?'),
      ),
      findsOneWidget,
      reason: 'the ask is the title, said once',
    );
    await drain(tester);
  });

  group('rows point with the one receipt', () {
    MutationRecord record(MutationStatus status) => MutationRecord(
      key: 'r-1',
      request: MutationRequest.respond(
        'g1',
        const GateResponse.choice('SQLite'),
      ),
      createdAt: clock,
      status: status,
    );

    testWidgets('confirmed has none; others are the receipt word', (
      tester,
    ) async {
      InlineSpan? confirmed;
      final others = <InlineSpan?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                confirmed = teamGateReceiptSpan(
                  context,
                  record(MutationStatus.confirmed),
                );
                others
                  ..clear()
                  ..addAll([
                    for (final status in [
                      MutationStatus.sent,
                      MutationStatus.rejected,
                    ])
                      teamGateReceiptSpan(context, record(status)),
                  ]);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(confirmed, isNull);
      expect(
        others.map((span) => span?.toPlainText().replaceAll('\uFFFC', '')),
        ['Sending…', 'Not accepted'],
      );
    });
  });

  test('Saved prompts no longer claims one server', () {
    expect(_en.promptStashIntro, isNot(contains('server')));
  });
}
