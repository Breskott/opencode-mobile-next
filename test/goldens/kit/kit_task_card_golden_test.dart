// Gallery (gate G4) for KitTaskCard, docs/ux-system/kit-api/KitTaskCard.md.
//
// Owner decision 2026-09-27 (dated later than KitTaskCard.md, R15): Arabic
// is dropped and the sizes narrow to the phone (412x915) and one wide size
// (1280x800), light and dark. This replaces the spec's own grid (360x800,
// 915x412, 800x1280, 1600x1000, text 2.0 and Arabic); recorded in
// docs/qa/revamp-kit-KitTaskCard/README.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_task_card_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_receipt.dart';
import 'package:opencode_mobile/ui/kit/kit_task_card.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';

import 'kit_gallery.dart';

const _meta = [
  KitTaskMeta('High', priority: KitPriority.high, strong: true),
  KitTaskMeta('Bug', icon: AppIconography.bug),
  KitTaskMeta('fox'),
  KitTaskMeta('12 min ago'),
];

KitAction _move({String? reason}) => KitAction(
  label: 'Move or change',
  icon: AppIconography.swap,
  onPressed: () {},
  disabledReason: reason,
);

/// One card per scene, in a lane-width column on the ground.
Widget _lane(KitTaskCard card) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: 320, child: card),
  ),
);

final Map<String, KitTaskCard Function()> _states = {
  'default': () => KitTaskCard(
    title: 'Fix the sync engine dropping queued messages',
    mark: KitTaskState.working,
    onOpen: () {},
    meta: _meta,
    action: _move(),
  ),
  'needs_you': () => KitTaskCard(
    title: 'Merge the onboarding branch',
    mark: KitTaskState.needsYou,
    onOpen: () {},
    meta: const [KitTaskMeta('fox'), KitTaskMeta('3 min ago')],
    flag: const KitTaskFlag(
      kind: KitTaskFlagKind.needsYou,
      label: 'Approve the merge',
    ),
    action: _move(),
  ),
  'blocked': () => KitTaskCard(
    title: 'Ship the settings redesign',
    mark: KitTaskState.waiting,
    onOpen: () {},
    meta: const [
      KitTaskMeta('Urgent', priority: KitPriority.urgent, strong: true),
      KitTaskMeta('2 h ago'),
    ],
    flag: const KitTaskFlag(
      kind: KitTaskFlagKind.blocked,
      label: 'Blocked by Sync engine',
    ),
    action: _move(),
  ),
  'failed': () => KitTaskCard(
    title: 'Upgrade the build tools',
    mark: KitTaskState.failed,
    onOpen: () {},
    meta: const [KitTaskMeta('owl'), KitTaskMeta('1 h ago')],
    flag: const KitTaskFlag(
      kind: KitTaskFlagKind.failed,
      label: 'Stopped with an error',
    ),
    action: _move(),
  ),
  'stopped': () => KitTaskCard(
    title: 'Try the old cache layout',
    mark: KitTaskState.stopped,
    onOpen: () {},
    meta: const [
      KitTaskMeta('Someday', priority: KitPriority.someday),
      KitTaskMeta('2 d ago'),
    ],
    flag: const KitTaskFlag(kind: KitTaskFlagKind.stopped, label: 'Cancelled'),
    action: _move(),
  ),
  'done': () => KitTaskCard(
    title: 'Write the release notes',
    mark: KitTaskState.done,
    onOpen: () {},
    meta: const [
      KitTaskMeta('Low', priority: KitPriority.low),
      KitTaskMeta('Feature', icon: AppIconography.sparkle),
      KitTaskMeta('1 d ago'),
    ],
    flag: const KitTaskFlag(
      kind: KitTaskFlagKind.info,
      label: 'In Onboarding',
      icon: AppIconography.layers,
    ),
    action: _move(),
  ),
  'moving': () => KitTaskCard(
    title: 'Fix the sync engine dropping queued messages',
    mark: KitTaskState.working,
    onOpen: () {},
    meta: _meta,
    receipt: const KitReceipt(
      state: KitReceiptState.sending,
      label: 'Moving to Review…',
      automatic: true,
    ),
    action: _move(reason: 'Moving to Review…'),
  ),
  'not_confirmed': () => KitTaskCard(
    title: 'Fix the sync engine dropping queued messages',
    mark: KitTaskState.working,
    onOpen: () {},
    meta: _meta,
    receipt: KitReceipt(state: KitReceiptState.notConfirmed, onRetry: () {}),
    action: _move(),
  ),
  'read_only': () => KitTaskCard(
    title: 'Fix the sync engine dropping queued messages',
    mark: KitTaskState.working,
    onOpen: () {},
    meta: _meta,
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: state, value: build) in _states.entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_task_card_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: _lane(build()),
        );
      });
    }
    testWidgets('default · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_task_card_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _lane(_states['default']!()),
      );
    });
  }
}
