// Gallery (gate G4) for KitAskLine and KitSkeletonTranscript
// (docs/ux-system/kit-api/KitAskLine.md, TEST-9, TEST-20), 30 PNGs:
// - states at 412x915, dark and light: ask_inline (above a composer-height
//   inset), ask_stacked (a long question) and skeleton (6);
// - the default ask_inline and skeleton at every other gallery size
//   (360x800, 915x412, 800x1280, 1280x800, 1600x1000), dark and light (20);
// - ask_inline at 2.0 text and in Arabic at 412x915 and 1280x800, dark (4).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_ask_line_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _question = 'Tell me when the first reply arrives?';
const _longQuestion =
    'Tell me the moment the agent finishes its very first reply in this '
    'conversation?';
const _questionAr = 'أخبرني عند وصول أول رد من الوكيل؟';

KitAskLine _askLine({
  String question = _question,
  bool arabic = false,
}) => KitAskLine(
  icon: AppIconography.inbox,
  question: question,
  decline: KitAction(label: arabic ? 'ليس الآن' : 'Not now', onPressed: () {}),
  accept: KitAction(label: arabic ? 'أعلمني' : 'Notify me', onPressed: () {}),
);

/// A neutral placeholder the height of the composer the ask line sits
/// above in the conversation (never a real composer: KitComposer has not
/// merged yet, R13).
Widget _composerInset() => Builder(
  builder: (context) => SizedBox(
    height: 56,
    child: ColoredBox(color: ThemeRoles.of(context).surface2),
  ),
);

const _states = Size(412, 915);

/// The default shots' sizes: every STANDARDS LAY-4 gallery size except
/// 412x915, whose shots are the states above.
const _defaultSizes = <Size>[
  Size(360, 800),
  Size(915, 412),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

Widget _askAboveComposer({bool arabic = false}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _askLine(arabic: arabic),
    _composerInset(),
  ],
);

void main() {
  setUpAll(loadKitGalleryFonts);

  group('KitAskLine', () {
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';

      testWidgets('stacked (a long question) · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_ask_line_ask_stacked',
            _states,
            light: light,
          ),
          size: _states,
          light: light,
          child: SizedBox(width: 320, child: _askLine(question: _longQuestion)),
        );
      });

      for (final size in [_states, ..._defaultSizes]) {
        testWidgets('inline above the composer · ${kitGallerySize(size)} · '
            '$mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName('kit_ask_line_ask_inline', size, light: light),
            size: size,
            light: light,
            child: _askAboveComposer(),
          );
        });
      }
    }

    for (final size in kitGalleryScaledSizes) {
      testWidgets('inline · 2.0 text · ${kitGallerySize(size)} · dark', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_ask_line_ask_inline',
            size,
            light: false,
            text2: true,
          ),
          size: size,
          light: false,
          textScale: 2,
          child: _askLine(),
        );
      });

      testWidgets('inline · Arabic · ${kitGallerySize(size)} · dark', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_ask_line_ask_inline',
            size,
            light: false,
            ar: true,
          ),
          size: size,
          light: false,
          locale: const Locale('ar'),
          child: _askLine(question: _questionAr, arabic: true),
        );
      });
    }
  });

  group('KitSkeletonTranscript', () {
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';
      for (final size in [_states, ..._defaultSizes]) {
        testWidgets('loading · ${kitGallerySize(size)} · $mode', (
          tester,
        ) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName('kit_ask_line_skeleton', size, light: light),
            size: size,
            light: light,
            child: const SizedBox(height: 360, child: KitSkeletonTranscript()),
          );
        });
      }
    }
  });
}
