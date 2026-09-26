// Gallery (gate G4) for KitAskLine and KitSkeletonTranscript
// (docs/ux-system/kit-api/KitAskLine.md): the ask line's inline and
// stacked states above a composer-height inset, and the transcript's
// loading skeleton, on the five §8.4 window sizes, light and dark, at 2.0
// text and in Arabic (right to left).
//
// The frozen spec's own size list transposes the second of the five
// standard sizes ("915×412" instead of 412×915, the only entry that
// differs from kitGallerySizes) and its "that is 30 PNGs" total double
// counts the states bucket's ask_inline/skeleton entries against this
// bucket's matching 412×915 shot; both are reported in the QA record. This
// gallery renders the standard kitGallerySizes and gives ask_stacked (not
// produced anywhere else) its own dedicated 412×915 pair, so every name
// stays unique.
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
const _composerInset = SizedBox(
  height: 56,
  child: ColoredBox(color: Color(0x11808080)),
);

Widget _askAboveComposer({bool arabic = false}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _askLine(arabic: arabic),
    _composerInset,
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
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: SizedBox(width: 320, child: _askLine(question: _longQuestion)),
        );
      });

      for (final size in kitGallerySizes) {
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
      for (final size in kitGallerySizes) {
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
