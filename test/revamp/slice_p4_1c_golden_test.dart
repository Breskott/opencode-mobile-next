// Gallery of slice-P4.1c (team gates on the one request card): a gate as
// the conversation and a task's Overview show it — a decision, an
// approval, a free-text question and a failed task waiting, a decision
// sending — and its Details (the Gate sheet), at 412x915 and 1280x800,
// dark and light, with the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p4_1c_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/gate_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_needs_you.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'slice_p4_1c_support.dart';

/// Four minutes before the real time the kit's age words read, so the card
/// says "waiting 4 min" and the sheet "4m ago".
final _asked = DateTime.now().subtract(const Duration(minutes: 4));

final _gates = <String, OrchestrationGate>{
  'choice': OrchestrationGate(
    id: 'g-choice',
    kind: GateKind.choice,
    title: 'Which storage should sync use?',
    prompt: 'Both work offline; SQLite is faster to query.',
    choices: const ['SQLite', 'Files'],
    agentId: 'bl-5qc',
    createdAt: _asked,
  ),
  'approval': OrchestrationGate(
    id: 'g-approval',
    kind: GateKind.confirmation,
    title: 'Run the database migration?',
    agentId: 'bl-5qc',
    createdAt: _asked,
  ),
  'free_text': OrchestrationGate(
    id: 'g-text',
    kind: GateKind.freeText,
    title: 'What should the offline banner say?',
    agentId: 'bl-5qc',
    createdAt: _asked,
  ),
  'run_failed': OrchestrationGate(
    id: 'g-failed',
    kind: GateKind.runFailed,
    title: 'Run failed',
    prompt: 'exit status 1: go test ./sync/...',
    runId: 'oc-xru',
    workId: 'w2',
    agentId: 'fox',
    createdAt: _asked,
  ),
};

/// name → (gate, what to do once the card shows).
final _scenes = <String, (String, Future<void> Function(WidgetTester tester)?)>{
  'p4_1c_card_choice': ('choice', null),
  'p4_1c_card_approval': ('approval', null),
  'p4_1c_card_free_text': ('free_text', null),
  'p4_1c_card_run_failed': ('run_failed', null),
  'p4_1c_card_choice_sending': (
    'choice',
    (tester) async {
      await tester.tap(find.byKey(const ValueKey('gate-option-0')));
      await _settle(tester);
    },
  ),
  'p4_1c_details_choice': (
    'choice',
    (tester) async {
      await tester.tap(find.byKey(const ValueKey('gate-more')));
      await _settle(tester);
    },
  ),
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    for (final light in [false, true]) {
      final sized = size.width == 412
          ? ''
          : '_${size.width.toInt()}x${size.height.toInt()}';
      final theme = light ? 'light' : 'dark';
      for (final MapEntry(key: name, value: (gateName, act))
          in _scenes.entries) {
        final file = '$name${sized}_$theme';
        testWidgets(file, (tester) async {
          SharedPreferences.setMockInitialValues({});
          final store = OrchestrationStore(
            await SharedPreferences.getInstance(),
          );
          final gate = _gates[gateName]!;
          late OrchestrationController controller;
          await tester.runAsync(() async {
            (controller, _) = await p41cBoot(store, gates: [gate]);
          });
          addTearDown(controller.dispose);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: light ? AppTheme.light() : AppTheme.dark(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: Builder(
                      builder: (context) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: TeamNeedsYouCard(
                                keyPrefix: 'gate',
                                controller: controller,
                                gate: gate,
                                title: 'fox',
                                onOpen: () => unawaited(
                                  showGateSheet(
                                    context,
                                    controller,
                                    gate.id,
                                    now: DateTime.now,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await _settle(tester);
          await act?.call(tester);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('goldens/$file.png'),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 61));
        });
      }
    }
  }
}
