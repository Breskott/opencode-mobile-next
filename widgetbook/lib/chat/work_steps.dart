// The work steps of a turn, drawn by the real parts (KitWorkLine over
// ToolCard rows): one line per step on one rail, the running step's spinner,
// an opened command as one box, and an edit's inline diff.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/tool_card.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';

const _findAll = 'find /sdcard -iname "*review*"';
const _findLong =
    'find /root/projects /sdcard/Download /sdcard/Documents -iname "*review*"';
const _findOne = 'find / -xdev -iname "*ui-ux*"';
const _findWrapped =
    r'find / -xdev \( -iname "*ui-ux*" -o -iname "*review*" \) -type f '
    '2>/dev/null | head -20';

ToolState _shell(
  String command, {
  String? output,
  String status = 'completed',
}) => ToolState.fromJson({
  'status': status,
  'input': {'command': command},
  'output': ?output,
  'metadata': status == 'completed' ? const {'exit': 0} : null,
}, toolName: 'bash');

ToolState _read(String path) => ToolState.fromJson({
  'status': 'completed',
  'input': {'filePath': path},
  'output': '<file>\n</file>',
  'metadata': const {
    'display': {'lineStart': 1, 'lineEnd': 80},
  },
}, toolName: 'read');

const _patch =
    '--- a/test/checkout_test.dart\n'
    '+++ b/test/checkout_test.dart\n'
    '@@ -40,6 +40,9 @@\n'
    '   await tester.pumpWidget(const App());\n'
    "   await tester.tap(find.text('Apply'));\n"
    '-  await tester.pump();\n'
    '+  await tester.pumpUntil(\n'
    '+    () => bloc.state is CheckoutSettled,\n'
    '+  );\n'
    "   expect(find.text(r'\$42.00'), findsOneWidget);\n"
    '   expect(bloc.state.total, 42);\n';

ToolState _edit() => ToolState.fromJson({
  'status': 'completed',
  'input': {'filePath': '/root/projects/oc_app/test/checkout_test.dart'},
  'output': 'Edited test/checkout_test.dart',
  'metadata': {
    'filediff': {'patch': _patch, 'additions': 3, 'deletions': 1},
  },
}, toolName: 'edit');

Widget _step(
  String name,
  ToolState state, {
  bool open = false,
  required String key,
}) => ToolCard(
  toolName: name,
  state: state,
  embedded: true,
  expansionKey: key,
  expansionStore: {key: open},
);

Widget _scene({
  required List<Widget> steps,
  required KitWorkCounts counts,
  KitWorkState state = KitWorkState.done,
  bool expanded = true,
}) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StatefulBuilder(
        builder: (context, setState) {
          var open = expanded;
          return StatefulBuilder(
            builder: (context, setOpen) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KitText(
                  'Gemini changed 8 files. Finding the review file itself:',
                  role: KitTextRole.body,
                ),
                const SizedBox(height: 16),
                KitWorkLine(
                  counts: counts,
                  state: state,
                  steps: steps,
                  expanded: open,
                  onExpansionChanged: (value) => setOpen(() => open = value),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ),
);

CatalogComponent kitWorkSteps() => catalogComponent(
  area: 'Chats',
  name: 'Work steps',
  useCases: [
    WidgetbookUseCase(
      name: 'Closed',
      builder: (_) => _scene(
        expanded: false,
        counts: const KitWorkCounts(ran: 2),
        steps: [
          _step('bash', _shell(_findAll, output: '/a'), key: 'a'),
          _step('bash', _shell(_findOne, output: '/b'), key: 'b'),
        ],
      ),
    ),
    WidgetbookUseCase(
      name: 'Open, one step running',
      builder: (_) => _scene(
        state: KitWorkState.running,
        counts: const KitWorkCounts(ran: 2),
        steps: [
          _step('bash', _shell(_findAll, output: '/a'), key: 'a'),
          _step('bash', _shell(_findOne, status: 'running'), key: 'b'),
        ],
      ),
    ),
    WidgetbookUseCase(
      name: 'An open command',
      builder: (_) => _scene(
        counts: const KitWorkCounts(ran: 2),
        steps: [
          _step('bash', _shell(_findLong, output: '/a'), key: 'a'),
          _step(
            'bash',
            _shell(
              _findWrapped,
              output: [
                '/root/projects/oc_app/docs/audits/ui-ux-audit-2026-10-14.md',
                '/sdcard/Download/ui-ux-review.md',
                for (var i = 1; i <= 12; i++)
                  '/root/projects/oc_app/docs/review/notes-$i.md',
              ].join('\n'),
            ),
            open: true,
            key: 'b',
          ),
        ],
      ),
    ),
    WidgetbookUseCase(
      name: 'An open edit, inline diff',
      builder: (_) => _scene(
        counts: const KitWorkCounts(read: 1, edited: 1),
        steps: [
          _step(
            'read',
            _read('/root/projects/oc_app/lib/checkout.dart'),
            key: 'a',
          ),
          _step('edit', _edit(), open: true, key: 'b'),
        ],
      ),
    ),
  ],
);
