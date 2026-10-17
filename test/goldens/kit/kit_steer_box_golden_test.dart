// Gallery (gate G4) for KitSteerBox: at 412x915 and 1280x800, dark and light, and
// at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_steer_box_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _box({
  KitSteerBoxPhase phase = KitSteerBoxPhase.ready,
  String text = '',
  String? blockedReason,
  String? message,
}) => Padding(
  padding: const EdgeInsets.all(16),
  child: KitSteerBox(
    title: 'Add to this turn',
    controller: TextEditingController(text: text),
    hint: 'Write a message',
    sendLabel: 'Send',
    phase: phase,
    blockedReason: blockedReason,
    message: message,
    onSend: (_) {},
    onDictate: () {},
    onClose: () {},
  ),
);

final _states = <String, Widget Function()>{
  'default': () => _box(text: 'Also add a test for the empty case'),
  'working': () =>
      _box(text: 'Also add a test', phase: KitSteerBoxPhase.sending),
  'disabled': () => _box(
    text: 'A draft that stays',
    blockedReason: 'Waiting for conversation details…',
  ),
  'answered': () => _box(text: 'Done', phase: KitSteerBoxPhase.sent),
  'note': () => _box(
    text: 'Keep me',
    message: 'The conversation changed. Your message is still here.',
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('default · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_steer_box_default', size, light: light),
          size: size,
          light: light,
          child: _states['default']!(),
        );
      });
    }
  }
  for (final size in kitGalleryScaledSizes) {
    testWidgets('default · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_steer_box_default',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _states['default']!(),
      );
    });
  }

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('working · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_steer_box_working', size, light: light),
          size: size,
          light: light,
          child: _states['working']!(),
        );
      });
    }
  }
  for (final size in kitGalleryScaledSizes) {
    testWidgets('working · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_steer_box_working',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _states['working']!(),
      );
    });
  }

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('disabled · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_steer_box_disabled', size, light: light),
          size: size,
          light: light,
          child: _states['disabled']!(),
        );
      });
    }
  }
  for (final size in kitGalleryScaledSizes) {
    testWidgets('disabled · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_steer_box_disabled',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _states['disabled']!(),
      );
    });
  }

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('answered · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_steer_box_answered', size, light: light),
          size: size,
          light: light,
          child: _states['answered']!(),
        );
      });
    }
  }
  for (final size in kitGalleryScaledSizes) {
    testWidgets('answered · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_steer_box_answered',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _states['answered']!(),
      );
    });
  }

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('note · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_steer_box_note', size, light: light),
          size: size,
          light: light,
          child: _states['note']!(),
        );
      });
    }
  }
  for (final size in kitGalleryScaledSizes) {
    testWidgets('note · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_steer_box_note',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _states['note']!(),
      );
    });
  }
}
