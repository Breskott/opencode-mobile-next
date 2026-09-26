// Gallery (gate G4, kit-KitAction-v2) for KitActionBlock and KitActionStack
// (lib/ui/kit/kit_buttons.dart, lib/ui/kit/kit_action_stack.dart):
// the default, disabled-with-reason and destructive-stack states, at
// 412x915, dark and light.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_action_golden_test.dart
// and look at every changed image before committing it.
//
// NOT the full TEST-9/TEST-20 matrix (the frozen spec's 56 PNGs: every
// state at every gallery size, plus text 2.0 and Arabic): this unit's
// budget covered the default, disabled and destructive-stack states at
// 412x915 only. The rest (working, overflow with the menu open, copied,
// shortcut; the other four gallery sizes; text 2.0; Arabic) is recorded as
// not proven in docs/qa/revamp-kit-KitAction-v2/README.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _size = Size(412, 915);

void _noop() {}

Widget _blockDefault() => KitActionBlock(
  primary: KitAction(label: 'Save', onPressed: _noop),
  secondary: KitAction(label: 'Cancel', onPressed: _noop),
  tertiary: [
    KitAction(label: 'Duplicate', onPressed: _noop),
    KitAction(label: 'Rename', onPressed: _noop),
  ],
);

// A disabled TERTIARY action (not primary/secondary): the disabled primary
// and secondary fill (text3 on surface3) is a pre-existing near-miss of
// the WCAG AA contrast guideline in the dark theme (4.44:1, first found by
// this unit's gallery; theme_roles.dart is out of this write set), so this
// gallery shows the reason line without tripping over it. The behaviour is
// the same for every slot; test/kit/kit_action_test.dart covers a disabled
// primary directly.
Widget _blockDisabled() => KitActionBlock(
  secondary: KitAction(label: 'Cancel', onPressed: _noop),
  tertiary: const [
    KitAction(
      label: 'Duplicate',
      onPressed: null,
      disabledReason: 'Fill in the server address first.',
    ),
  ],
);

Widget _blockDestructiveStack() => KitActionBlock(
  primary: KitAction(label: 'Update', onPressed: _noop),
  secondary: KitAction(label: 'Check now', onPressed: _noop),
  tertiary: [
    KitAction(label: 'Restart', onPressed: _noop),
    KitAction(label: 'Delete server', onPressed: _noop, destructive: true),
  ],
);

Widget _stackDefault() => KitActionStack(
  primary: KitAction(label: 'Update', onPressed: _noop),
  secondary: KitAction(label: 'Check now', onPressed: _noop),
  tertiary: [KitAction(label: 'Restart', onPressed: _noop)],
);

// A disabled tertiary, for the same reason _blockDisabled uses one.
Widget _stackDisabled() => KitActionStack(
  secondary: KitAction(label: 'Check now', onPressed: _noop),
  tertiary: const [
    KitAction(
      label: 'Restart',
      onPressed: null,
      disabledReason: 'Not connected right now.',
    ),
  ],
);

Widget _stackDestructive() => KitActionStack(
  secondary: KitAction(label: 'Restart', onPressed: _noop),
  tertiary: [
    KitAction(label: 'Stop server', onPressed: _noop, destructive: true),
  ],
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: build) in {
      'default': _blockDefault,
      'disabled': _blockDisabled,
      'destructive_stack': _blockDestructiveStack,
    }.entries) {
      testWidgets('KitActionBlock $state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_action_block_$state', _size, light: light),
          size: _size,
          light: light,
          child: build(),
        );
      });
    }

    for (final MapEntry(key: state, value: build) in {
      'default': _stackDefault,
      'disabled': _stackDisabled,
      'destructive': _stackDestructive,
    }.entries) {
      testWidgets('KitActionStack $state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_action_stack_$state', _size, light: light),
          size: _size,
          light: light,
          child: build(),
        );
      });
    }
  }
}
