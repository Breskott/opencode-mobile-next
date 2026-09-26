// Gallery (gate G4) for KitText v2 (docs/ux-system/kit-api/KitText.md
// "Galleries required"): the ten type roles and the eight tones ("type"),
// the three KitMonoCut values ("mono"), and a word selected with its
// toolbar ("selectable_selected").
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_text_golden_test.dart
// and look at every changed image before committing it.
//
// KitText.md's own size list for the "type" default state gives 915x412
// (a landscape phone) where kit_gallery.dart's shared kitGallerySizes gives
// 412x915 (the census portrait phone) instead; this file follows the frozen
// spec's literal sizes rather than silently swapping in the shared list —
// see the QA record's "contract problems".
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

class _Copy {
  const _Copy({
    required this.phrase,
    required this.tones,
    required this.mono,
    required this.host,
    required this.path,
  });

  final String phrase;

  /// One line per [KitTextTone], in [KitTextTone.values] order.
  final List<String> tones;
  final String mono;
  final String host;
  final String path;
}

const _en = _Copy(
  phrase: 'Fix the flaky checkout test before the release',
  tones: [
    'Primary text, the ambient colour',
    "Secondary text, a row's meta line",
    'Tertiary text, disabled',
    'Accent text, a link',
    'Text on the accent fill',
    'Attention: needs you',
    'Danger: this stops something',
    'Success: it worked',
  ],
  mono: r'git push origin release/2026-09-26 --force-with-lease --no-verify',
  host: 'workstation-office-network-4096.internal.example.com',
  path: '/home/user/projects/very/long/path/to/checkout/main.dart',
);

const _ar = _Copy(
  phrase: 'إصلاح اختبار الدفع غير المستقر قبل الإصدار',
  tones: [
    'نص أساسي، اللون المحيط',
    'نص ثانوي، سطر التفاصيل',
    'نص ثالثي، معطّل',
    'نص التمييز، رابط',
    'نص على تعبئة التمييز',
    'يحتاجك الانتباه',
    'خطر: هذا يوقف شيئاً',
    'نجاح: نجحت العملية',
  ],
  // Technical values are never translated or isolated inline (COPY-26,
  // KitText.md "RTL"): the Arabic gallery still shows the same commands,
  // hosts and paths, only the ambient direction changes.
  mono: r'git push origin release/2026-09-26 --force-with-lease --no-verify',
  host: 'workstation-office-network-4096.internal.example.com',
  path: '/home/user/projects/very/long/path/to/checkout/main.dart',
);

Widget _toneLine(int index, KitTextTone tone, _Copy copy) {
  final text = KitText(copy.tones[index], tone: tone);
  if (tone != KitTextTone.onAccent) return text;
  // onAccent is read on the accent fill (a button, a badge), never on the
  // ground: shown here the same way a caller would.
  return Builder(
    builder: (context) {
      final roles = ThemeRoles.resolve(Theme.of(context));
      return ColoredBox(
        color: roles.accent,
        child: Padding(padding: const EdgeInsets.all(8), child: text),
      );
    },
  );
}

Widget _type(_Copy copy) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final role in KitTextRole.values) ...[
        KitText(
          role == KitTextRole.mono
              ? copy.mono
              : '${role.name} · ${copy.phrase}',
          role: role,
        ),
        const SizedBox(height: 10),
      ],
      for (final (index, tone) in KitTextTone.values.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _toneLine(index, tone, copy),
        ),
    ],
  ),
);

Widget _fixedWidth(Widget child) => Align(
  alignment: AlignmentDirectional.centerStart,
  child: SizedBox(width: 260, child: child),
);

Widget _mono(_Copy copy) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const KitText('wrap', role: KitTextRole.label),
      const SizedBox(height: 4),
      KitText.mono(copy.mono),
      const SizedBox(height: 20),
      const KitText('end', role: KitTextRole.label),
      const SizedBox(height: 4),
      // A fixed width, narrower than either value, so end and middle
      // actually cut in every gallery size and text scale this state is
      // shot at (the reading column alone can be wide enough not to). The
      // Align lets the 260 dp hold inside the stretched column; it sits at
      // the start edge, so the Arabic shot shows it on the right.
      _fixedWidth(KitText.mono(copy.host, cut: KitMonoCut.end)),
      const SizedBox(height: 20),
      const KitText('middle', role: KitTextRole.label),
      const SizedBox(height: 4),
      _fixedWidth(KitText.mono(copy.path, cut: KitMonoCut.middle)),
    ],
  ),
);

const _selectableWord = 'select';
const _selectableSentence =
    'Long-press a word to $_selectableWord it, then Copy or Select all.';

Widget _selectableSelected() => const Padding(
  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  child: KitText.selectable(_selectableSentence),
);

/// The global centre of [word] in the sole on-screen [EditableText] (the
/// selectable text's own render object, not the paragraph's): the widget's
/// own geometric centre ([WidgetController.getCenter]) can fall between two
/// wrapped lines and hit no glyph at all, landing the gesture below on a
/// collapsed caret instead of a word.
Offset _wordCenter(WidgetTester tester, String sentence, String word) {
  final editable = tester
      .state<EditableTextState>(find.byType(EditableText))
      .renderEditable;
  final start = sentence.indexOf(word);
  final boxes = editable.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + word.length),
  );
  return editable.localToGlobal(boxes.first.toRect().center);
}

/// Like [kitGalleryPart] (same DPR-3 sizing, G5 checks and golden compare),
/// but runs [select] once the content has settled, so the golden itself
/// shows an active selection (handles and toolbar) rather than the idle
/// state a plain pump leaves KitText.selectable in.
Future<void> _selectedShot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required Widget child,
  required Future<void> Function(WidgetTester tester) select,
}) async {
  final own = light ? 'light' : 'dark';
  if (!name.endsWith('_$own')) {
    throw ArgumentError.value(name, 'name', 'must end in _$own ($light)');
  }
  final stem = name.substring(0, name.length - own.length - 1);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    for (final pass in [!light, light]) {
      late BuildContext context;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(light: pass),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (inner) {
                  context = inner;
                  return Center(child: child);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await select(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(context),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

/// KitText.md's literal "Default state (type)" sizes (915x412, not the
/// shared kitGallerySizes' 412x915 landscape entry — see the file header).
const _typeDefaultSizes = <Size>[
  Size(360, 800),
  Size(915, 412),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('type · 412x915 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_text_type',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _type(_en),
      );
    });

    for (final size in _typeDefaultSizes) {
      testWidgets('type · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_text_type', size, light: light),
          size: size,
          light: light,
          child: _type(_en),
        );
      });
    }

    testWidgets('mono · 412x915 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_text_mono',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _mono(_en),
      );
    });

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);

      testWidgets('type · text 2.0 · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_text_type',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _type(_en),
        );
      });

      testWidgets('type · Arabic · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_text_type', size, light: light, ar: true),
          size: size,
          light: light,
          locale: const Locale('ar'),
          child: _type(_ar),
        );
      });

      testWidgets('mono · text 2.0 · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_text_mono',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _mono(_en),
        );
      });

      testWidgets('mono · Arabic · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_text_mono', size, light: light, ar: true),
          size: size,
          light: light,
          locale: const Locale('ar'),
          child: _mono(_ar),
        );
      });
    }

    testWidgets('selectable_selected · $mode', (tester) async {
      await _selectedShot(
        tester,
        name: kitGalleryName(
          'kit_text_selectable_selected',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _selectableSelected(),
        select: (tester) async {
          // A long-press selects the word as soon as the press starts
          // (RenderEditable.selectWord); the popup toolbar only opens once
          // the gesture *ends* (onSingleLongTapEnd). Cancelling instead of
          // lifting leaves the selection and its handles shown — the
          // "selected" state this shot is named for — without the
          // platform's own toolbar, whose 44 dp buttons are native Android
          // chrome the kit does not draw and G5 has no ceiling entry for.
          final gesture = await tester.startGesture(
            _wordCenter(tester, _selectableSentence, _selectableWord),
          );
          await tester.pump(kLongPressTimeout + kPressTimeout);
          await gesture.cancel();
        },
      );
    });
  }
}
