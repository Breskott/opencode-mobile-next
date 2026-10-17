// The tasks chip (KitTaskChip) in the line above the field, and the Tasks
// sheet it opens: resting, popped after a task completed, all done, and the
// sheet open. The pop and the all-done state are moments; here they are held
// (a catalog-only long time) so a screenshot can catch them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';

const _tasks = [
  'Find raw colours in the player',
  'Move them into OverlayColors',
  'Fix the two raw text fields',
  'Update the TV focus tests',
  'Remove the legacy cap from the design test',
  'Run the tests',
];

List<KitTaskItem> _items(int done, {bool working = true}) => [
  for (var i = 0; i < _tasks.length; i++)
    KitTaskItem(
      _tasks[i],
      i < done
          ? KitTaskItemState.done
          : i == done && working
          ? KitTaskItemState.inProgress
          : KitTaskItemState.todo,
    ),
];

/// A short conversation with the line above the field at its foot.
class _TaskChipScene extends StatefulWidget {
  const _TaskChipScene({required this.from, this.to, this.openSheet = false});

  /// Tasks done when the scene opens; [to] after a moment (a task completed).
  final int from;
  final int? to;
  final bool openSheet;

  @override
  State<_TaskChipScene> createState() => _TaskChipSceneState();
}

class _TaskChipSceneState extends State<_TaskChipScene> {
  late int _done = widget.from;
  static const _total = 6;
  Timer? _later;

  @override
  void initState() {
    super.initState();
    final to = widget.to;
    if (to != null) {
      _later = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _done = to);
      });
    }
    if (widget.openSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showKitTaskSheet(
            context,
            items: _items(_done),
            done: _done,
            total: _total,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _later?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.roles.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.gutter),
              child: const KitText(
                'UI review and feedback',
                role: KitTextRole.headline,
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.all(tokens.gutter),
              child: const KitText(
                'I removed the legacy cap from the design test. Now running '
                'the tests.',
              ),
            ),
            const Spacer(),
            KitComposerStatusStrip(
              chips: [
                const KitChip.action(
                  label: 'Auto-approve',
                  icon: AppIconography.shield,
                  onPressed: _noop,
                ),
                KitTaskChip(
                  done: _done,
                  total: _total,
                  current: _tasks[(_done).clamp(0, _tasks.length - 1)],
                  // Held for the screenshot.
                  popFor: const Duration(hours: 1),
                  allDoneFor: const Duration(hours: 1),
                  onPressed: () => unawaited(
                    showKitTaskSheet(
                      context,
                      items: _items(_done, working: _done < _total),
                      done: _done,
                      total: _total,
                    ),
                  ),
                ),
              ],
              model: const KitChip.action(
                label: 'gemini-4-argon',
                onPressed: _noop,
              ),
            ),
            SizedBox(height: tokens.space3),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

CatalogComponent kitTaskChip() => catalogComponent(
  area: 'Chats',
  name: 'KitTaskChip',
  useCases: [
    WidgetbookUseCase(
      name: 'Resting',
      builder: (_) => const _TaskChipScene(from: 5),
    ),
    WidgetbookUseCase(
      name: 'Pop: a task completed',
      builder: (_) => const _TaskChipScene(from: 4, to: 5),
    ),
    WidgetbookUseCase(
      name: 'All done',
      builder: (_) => const _TaskChipScene(from: 5, to: 6),
    ),
    WidgetbookUseCase(
      name: 'Sheet open',
      builder: (_) => const _TaskChipScene(from: 5, openSheet: true),
    ),
  ],
);
