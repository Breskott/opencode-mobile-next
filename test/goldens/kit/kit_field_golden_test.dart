// Gallery (gate G4) for KitField, docs/ux-system/kit-api/KitField.md; K2
// §1.4, §8.4.
//
// Owner decision 2026-09-27: Arabic is dropped, and galleries render at the
// phone (412x915) and one wide size (1280x800) only, light and dark. So:
// every declared state at 412x915, the default state at 1280x800, and the
// default state at text 2.0 at both sizes (2 x (11 + 1 + 2) = 28 PNGs).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_field_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_field.dart';

import 'kit_gallery.dart';

const _wide = Size(1280, 800);
const _phone = Size(412, 915);

/// Wraps a scene in the page's side gutter.
Widget _scene(Widget field) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: field);

/// A secret field that is typed into after it mounts (the secret kind is
/// never prefilled, so a masked value has to arrive after the first frame).
class _TypedSecret extends StatefulWidget {
  const _TypedSecret();

  @override
  State<_TypedSecret> createState() => _TypedSecretState();
}

class _TypedSecretState extends State<_TypedSecret> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.text = 'sk-gallery-0123456789';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KitField.secret(
    label: 'API key',
    controller: _controller,
    helper: 'Stored on this phone only.',
  );
}

TextEditingController _typed(String text) {
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  return controller;
}

Widget _default() => const KitField(
  label: 'Project name',
  hint: 'my-app',
  helper: 'Letters, digits and dashes.',
);

final _states = <String, Widget Function()>{
  'default': _default,
  'focused': () => const KitField(
    label: 'Project name',
    hint: 'my-app',
    helper: 'Letters, digits and dashes.',
    autofocus: true,
  ),
  'filled': () => KitField(
    label: 'Server address',
    kind: KitFieldKind.url,
    controller: _typed('https://studio.local:4096'),
    helper: 'The address the server printed when it started.',
  ),
  'error': () => KitField(
    label: 'Port',
    kind: KitFieldKind.number,
    controller: _typed('99999'),
    error: 'Enter a port between 1 and 65535.',
  ),
  'disabled': () => KitField(
    label: 'Branch',
    kind: KitFieldKind.mono,
    controller: _typed('feature/login'),
    enabled: false,
    disabledReason: 'The branch is set when the workspace is created.',
  ),
  'checking': () => KitField(
    label: 'Server address',
    kind: KitFieldKind.url,
    controller: _typed('https://studio.local:4096'),
    checkingSince: DateTime.now(),
  ),
  'checking_slow': () => KitField(
    label: 'Server address',
    kind: KitFieldKind.url,
    controller: _typed('https://studio.local:4096'),
    checkingSince: DateTime.now().subtract(const Duration(seconds: 12)),
    onSlow: [KitAction(label: 'Skip the check', onPressed: () {})],
  ),
  'counter': () => KitField(
    label: 'Conversation title',
    controller: _typed('Fix the login redirect on the tablet sign-in'),
    maxLength: 50,
  ),
  'secret_masked': () => const _TypedSecret(),
  'secret_saved': () => const KitField.secret(label: 'API key', saved: true),
  'multiline': () => KitField(
    label: 'Objective',
    kind: KitFieldKind.multiline,
    controller: _typed(
      'Move the settings screen to the new kit.\n'
      'Keep every setting where it is.\n'
      'Add the missing labels.\n'
      'Check it at text 2.0.\n'
      'Record screenshots.',
    ),
    helper: 'Ctrl+Enter starts the run.',
  ),
};

Future<void> _shot(
  WidgetTester tester, {
  required String state,
  required Widget Function() build,
  required Size size,
  required bool light,
  bool text2 = false,
}) async {
  // A blinking caret never settles; the focused shot shows it steady.
  EditableText.debugDeterministicCursor = true;
  try {
    // Two literal calls, so the G4 manifest reads the text-2.0 shot.
    if (text2) {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_field_$state',
          size,
          light: light,
          text2: true,
        ),
        size: size,
        light: light,
        textScale: 2,
        child: _scene(build()),
      );
    } else {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_field_$state', size, light: light),
        size: size,
        light: light,
        child: _scene(build()),
      );
    }
  } finally {
    EditableText.debugDeterministicCursor = false;
  }
  // Unmount, so a checking field's escalation timer does not outlive it.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: state, value: build) in _states.entries) {
      testWidgets('kit_field $state · $mode', (tester) async {
        await _shot(
          tester,
          state: state,
          build: build,
          size: _phone,
          light: light,
        );
      });
    }
    testWidgets('kit_field default · 1280x800 · $mode', (tester) async {
      await _shot(
        tester,
        state: 'default',
        build: _default,
        size: _wide,
        light: light,
      );
    });
    for (final size in kitGalleryScaledSizes) {
      testWidgets('kit_field default text2 · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _shot(
          tester,
          state: 'default',
          build: _default,
          size: size,
          light: light,
          text2: true,
        );
      });
    }
  }
}
