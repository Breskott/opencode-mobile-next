// Golden renders of shared-review-1's pages (wave 2a): Run results' body
// (RunResultView, rebuilt from kit parts) and its "What it did" sheet
// (run-result-output-sheet: one tool record, sized to it and already open).
// Phone 412x915 and one wide window (1280x800), dark and light (owner
// decision 2026-09-27: no Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/shared_review_1_golden_test.dart
// and look at every changed image before committing it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/run_result.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/widgets/run_result_view.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

// A fixed day, far from "today", so the times never read as today's.
final _t0 = DateTime(2026, 3, 14, 9, 30).millisecondsSinceEpoch;

MessageWithParts _msg(
  String id, {
  required String role,
  required int minute,
  int? done,
  String? finish,
  String? error,
  List<Part> parts = const [],
}) => MessageWithParts(
  info: MessageInfo(
    id: id,
    sessionID: 'ses_1',
    role: role,
    agent: role == 'assistant' ? 'build' : null,
    modelID: role == 'assistant' ? 'claude-sonnet-4' : null,
    time: MsgTime(
      created: _t0 + minute * 60000,
      completed: done == null ? null : _t0 + done * 60000,
    ),
    errorText: error,
    finish: finish,
  ),
  parts: parts,
);

Part _tool(
  String id,
  String name, {
  Map<String, dynamic> input = const {},
  Map<String, dynamic>? metadata,
  String output = '',
  bool pruned = false,
}) => Part(
  id: id,
  callID: id,
  type: 'tool',
  toolName: name,
  toolState: ToolState(
    status: 'completed',
    input: input,
    output: output,
    metadata: metadata,
    pruned: pruned,
  ),
);

final _run = [
  _msg('u-prompt', role: 'user', minute: 0),
  _msg(
    'a-edit',
    role: 'assistant',
    minute: 1,
    done: 2,
    finish: 'tool-calls',
    parts: [
      _tool(
        'e1',
        'edit',
        input: {'filePath': 'test/checkout/checkout_flow_test.dart'},
      ),
      _tool('e2', 'write', input: {'filePath': 'README.md'}),
      _tool(
        'c1',
        'bash',
        input: {'command': 'flutter test test/checkout'},
        metadata: {'exit': 1},
        output: '00:04 +7 -1: Some tests failed.',
      ),
    ],
  ),
  _msg(
    'a-final-step',
    role: 'assistant',
    minute: 3,
    done: 5,
    finish: 'stop',
    parts: [
      _tool(
        'c2',
        'bash',
        input: {'command': 'flutter test test/checkout'},
        metadata: {'exit': 0},
        output:
            '00:01 +1: checkout_flow_test.dart: pays with a saved card\n'
            '00:02 +4: checkout_flow_test.dart: retries a declined card\n'
            '00:03 +8: All tests passed!',
      ),
      _tool('c3', 'bash', input: {'command': 'git status --short'}),
    ],
  ),
];

String _name(String shot, Size size, bool light) => [
  'review_$shot',
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Future<void> _shot(
  WidgetTester tester,
  String shot, {
  required bool light,
  required RunResult result,
  Size size = _phone,
  bool observedLive = false,
  Future<void> Function(WidgetTester tester)? open,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SafeArea(
              child: RunResultView(
                result: result,
                observedLive: observedLive,
                sessionTitle: 'Fix flaky checkout test',
                onOpenConversation: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (open != null) await open(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUpAll(loadCaptureFonts);

  final loaded = RunResult.fromMessages('ses_1', _run)!;
  // The start of the run is not in the loaded history, and the only step
  // failed without calling a tool: a partial, evidence-free result.
  final partial = RunResult.fromMessages('ses_1', [
    _msg(
      'a-only',
      role: 'assistant',
      minute: 7,
      done: 8,
      error: 'ProviderError: quota exceeded',
    ),
  ])!;

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    for (final size in [_phone, _wide]) {
      testWidgets('run result, loaded ($theme, $size)', (tester) async {
        await _shot(
          tester,
          'run_result_loaded',
          light: light,
          size: size,
          result: loaded,
          observedLive: true,
        );
      });

      testWidgets('what it did, one record ($theme, $size)', (tester) async {
        await _shot(
          tester,
          'run_result_output_sheet_one_record',
          light: light,
          size: size,
          result: loaded,
          open: (tester) async {
            final row = find.text('Passed · exit 0');
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            await tester.tap(row);
          },
        );
      });
    }

    testWidgets('run result, partial and failed ($theme)', (tester) async {
      await _shot(
        tester,
        'run_result_partial_failed',
        light: light,
        result: partial,
      );
    });
  }
}
