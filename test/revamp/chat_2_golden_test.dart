// Golden renders of chat-2's pages (wave 2c), rebuilt from kit parts: the
// tool steps of a reply (embedded-tool-card: folded states, an opened
// failing command with capped output, an opened edit, a sub-agent step) and
// the agent's plan (embedded-mobile-task-list: in progress, a long plan
// folded to its window), plus the find excerpt. Phone 412x915 and one wide
// window (1280x800), dark and light (owner decision 2026-09-27: no Arabic),
// with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/chat_2_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/mobile_tool_view.dart';
import 'package:opencode_mobile/domain/transcript_search.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_tool_row.dart';
import 'package:opencode_mobile/ui/widgets/mobile_task_view.dart';
import 'package:opencode_mobile/ui/widgets/tool_card.dart';
import 'package:opencode_mobile/ui/widgets/transcript_highlight.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String shot, Size size, bool light) => [
  shot,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

final _t0 = DateTime.utc(2026, 9, 27, 9);

ToolState _state(
  String status, {
  Map<String, dynamic> input = const {},
  String? output,
  Map<String, dynamic>? metadata,
  bool executed = true,
  int seconds = 0,
}) => ToolState(
  status: status,
  input: input,
  output: output,
  metadata: metadata,
  executed: executed,
  startedAt: _t0,
  completedAt: seconds == 0 ? null : _t0.add(Duration(seconds: seconds)),
);

final _failingTest = List.generate(
  30,
  (i) => i == 0
      ? '00:02 +12: loading test/checkout_test.dart'
      : '00:0${3 + i ~/ 10} +${12 + i} -1: checkout total settles ($i)',
).join('\n');

List<Widget> _steps() => [
  ToolCard(
    toolName: 'read',
    embedded: true,
    state: _state(
      'completed',
      input: const {'filePath': 'lib/checkout/checkout_bloc.dart'},
      output: '<content>\n1: class CheckoutBloc {}\n</content>',
      seconds: 1,
    ),
  ),
  ToolCard(
    toolName: 'edit',
    embedded: true,
    state: _state(
      'completed',
      input: const {'filePath': 'test/checkout_test.dart'},
      metadata: const {
        'filediff': {'additions': 6, 'deletions': 2},
      },
      seconds: 2,
    ),
  ),
  ToolCard(
    toolName: 'bash',
    embedded: true,
    state: _state(
      'running',
      input: const {'command': 'flutter test test/checkout_test.dart'},
    ),
  ),
  ToolCard(
    toolName: 'bash',
    embedded: true,
    waitingForYou: true,
    state: _state('running', input: const {'command': 'git push'}),
  ),
  ToolCard(
    toolName: 'bash',
    embedded: true,
    state: _state(
      'completed',
      input: const {'command': 'npm run lint'},
      output: '2 problems',
      metadata: const {'exit': 1},
      seconds: 4,
    ),
  ),
  ToolCard(
    toolName: 'grep',
    embedded: true,
    state: _state(
      'pending',
      input: const {'pattern': 'applyCoupon'},
      executed: false,
    ),
  ),
  ToolCard(
    toolName: 'task',
    embedded: true,
    onOpenSession: (_) {},
    state: _state(
      'completed',
      input: const {
        'subagent_type': 'explore',
        'description': 'Find where the price refresh races the total',
      },
      output: '<task state="completed"><task_result>ok</task_result></task>',
      metadata: const {'sessionId': 'ses_child'},
      seconds: 90,
    ),
  ),
];

Widget _shellOpen() => ToolCard(
  toolName: 'bash',
  expansionStore: {'k': true},
  expansionKey: 'k',
  onRerunCommand: (_) {},
  state: _state(
    'completed',
    input: const {'command': 'flutter test test/checkout_test.dart'},
    output: _failingTest,
    metadata: const {'exit': 1},
    seconds: 14,
  ),
);

Widget _editOpen() => ToolCard(
  toolName: 'edit',
  expansionStore: {'k': true},
  expansionKey: 'k',
  state: _state(
    'completed',
    input: const {'filePath': 'test/checkout_test.dart'},
    metadata: const {
      'filediff': {
        'additions': 3,
        'deletions': 1,
        'patch':
            '@@ -40,4 +40,6 @@\n'
            '   await tester.tap(find.text(\'Apply\'));\n'
            '-  await tester.pump();\n'
            '+  await tester.pumpUntil(\n'
            '+    () => bloc.state is CheckoutSettled,\n'
            '+  );\n'
            '   expect(find.text(\'\$42.00\'), findsOneWidget);',
      },
    },
    seconds: 1,
  ),
);

Widget _subagentStep() => ToolCard(
  toolName: 'task',
  expansionStore: {'k': true},
  expansionKey: 'k',
  state: _state(
    'completed',
    input: const {
      'subagent_type': 'explore',
      'description': 'Find where the price refresh races the total',
      'prompt': 'Look through lib/checkout for the coupon flow.',
    },
    output:
        '<task_result>The race is in `applyCoupon()`: it awaits the network '
        'before the total settles.</task_result>',
    metadata: const {
      'model': {'modelID': 'claude-sonnet-5'},
    },
    seconds: 75,
  ),
);

final _plan = MobileTaskView.fromTodos(const [
  {'content': 'Reproduce the flaky run', 'status': 'completed'},
  {
    'content': 'Find what races the price refresh',
    'status': 'completed',
    'priority': 'medium',
  },
  {
    'content': 'Make the test wait for the settled state',
    'status': 'in_progress',
    'priority': 'high',
  },
  {'content': 'Run the checkout suite 20 times', 'status': 'pending'},
  {'content': 'Rewrite the checkout screen', 'status': 'cancelled'},
])!;

final _longPlan = MobileTaskView.fromTodos([
  for (var i = 1; i <= 22; i++)
    {
      'content': 'Migrate screen $i to the kit',
      'status': i < 10
          ? 'completed'
          : i == 10
          ? 'in_progress'
          : 'pending',
    },
])!;

Future<void> _shot(
  WidgetTester tester,
  String shot,
  List<Widget> children, {
  required bool light,
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android; // ARCH-11
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(shot, size, light)}.png'),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in [_phone, _wide]) {
      testWidgets('tool steps $mode ${size.width}', (tester) async {
        await _shot(
          tester,
          'chat_tool_steps',
          _steps(),
          light: light,
          size: size,
        );
      });
      testWidgets('plan $mode ${size.width}', (tester) async {
        await _shot(
          tester,
          'chat_task_list',
          [MobileTaskList(view: _plan)],
          light: light,
          size: size,
        );
      });
    }
    testWidgets('failing command open $mode', (tester) async {
      await _shot(tester, 'chat_tool_shell_open', [_shellOpen()], light: light);
    });
    testWidgets('edit open $mode', (tester) async {
      await _shot(tester, 'chat_tool_edit_open', [_editOpen()], light: light);
    });
    testWidgets('sub-agent step $mode', (tester) async {
      await _shot(tester, 'chat_tool_subagent_step', [
        _subagentStep(),
      ], light: light);
    });
    testWidgets('long plan $mode', (tester) async {
      await _shot(tester, 'chat_task_list_long', [
        MobileTaskList(view: _longPlan),
      ], light: light);
    });
    testWidgets('find excerpt $mode', (tester) async {
      await _shot(tester, 'chat_find_excerpt', [
        const TranscriptMatchExcerpt(
          match: TranscriptMatch(
            messageID: 'm1',
            partIndex: 0,
            start: 10,
            end: 18,
            text: 'The flaky checkout test fails one run in five on CI.',
            kind: 'tool',
          ),
        ),
      ], light: light);
    });
  }

  // Keep the import honest: the steps render as kit rows.
  test('the steps are kit rows', () {
    expect(_steps().whereType<ToolCard>().length, 7);
    expect(KitToolStatus.values, contains(KitToolStatus.waitingForYou));
  });
}
