// KitQr (lib/ui/kit/kit_qr.dart), frozen spec docs/ux-system/kit-api/KitQr.md
// "Tests required" 1-8.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_qr.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';
import 'package:qr/qr.dart';

import 'kit_motion_still.dart';

/// A fixture link: never a real server address or token (SEC-5, TEST-11).
const _link = 'https://example.invalid/s/abc';

/// A secret-shaped fixture, to prove [KitQr] never renders [_link]-like
/// data as text or semantics (SEC-2). Still short enough to fit a code.
const _secretLink = 'https://example.invalid/s/super-secret-token-abc123';

/// Longer than a version-40 code holds at error correction M (2,331 bytes
/// in byte mode): the "too long" fixture (TEST item 4).
final _tooLongData = 'x' * 4000;

/// An app around [child], its own size set by [tester.view.physicalSize]
/// (a bare [Center] gives its child loose constraints, so the child's own
/// requested size is never forced wider, unlike a fixed-width [SizedBox]).
Widget _host(
  Widget child, {
  bool light = false,
  ThemeData? theme,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: theme ?? (light ? AppTheme.light() : AppTheme.dark()),
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: Directionality(textDirection: direction, child: widget!),
  ),
  home: Scaffold(body: Center(child: child)),
);

Finder _qrCustomPaint() =>
    find.descendant(of: find.byType(KitQr), matching: find.byType(CustomPaint));

/// The [Rect]s the part's painter drew, read back with a recording canvas
/// (TestRecordingCanvas/TestRecordingPaintingContext) rather than pixels.
List<Rect> _paintedRects(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderCustomPaint>(_qrCustomPaint());
  final canvas = TestRecordingCanvas();
  final context = TestRecordingPaintingContext(canvas);
  renderObject.paint(context, Offset.zero);
  return [
    for (final invocation in canvas.invocations)
      if (invocation.invocation.memberName == #drawRect)
        invocation.invocation.positionalArguments[0] as Rect,
  ];
}

/// The [Paint.color] of the first module the part painted.
Color _paintedInk(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderCustomPaint>(_qrCustomPaint());
  final canvas = TestRecordingCanvas();
  final context = TestRecordingPaintingContext(canvas);
  renderObject.paint(context, Offset.zero);
  final paint =
      canvas.invocations
              .firstWhere((i) => i.invocation.memberName == #drawRect)
              .invocation
              .positionalArguments[1]
          as Paint;
  return paint.color;
}

/// Every dark module's (row, col), from the painted [Rect]s at a card of
/// [side] logical pixels holding [total] modules per side.
Set<(int, int)> _paintedCells(WidgetTester tester, double side, int total) {
  final moduleLogical = side / total;
  final quiet = moduleLogical * KitTokens.qrQuietModules;
  return {
    for (final rect in _paintedRects(tester))
      (
        ((rect.top - quiet) / moduleLogical).round(),
        ((rect.left - quiet) / moduleLogical).round(),
      ),
  };
}

Set<(int, int)> _darkCellsOf(String data) {
  final image = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  return {
    for (var r = 0; r < image.moduleCount; r++)
      for (var c = 0; c < image.moduleCount; c++)
        if (image.isDark(r, c)) (r, c),
  };
}

void main() {
  kitMotionStillTests(
    'KitQr',
    builds: {
      'default': () => const KitQr(data: _link, semanticsLabel: 'code'),
      'too long': () => KitQr(data: _tooLongData, semanticsLabel: 'code'),
    },
  );

  testWidgets(
    '1. module snapping: side <= 240 and every module is a whole physical '
    'pixel at DPR 3 with 272 dp available',
    (tester) async {
      tester.view.physicalSize = const Size(272 * 3, 400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(const KitQr(data: _link, semanticsLabel: 'code')),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(KitQr));
      expect(size.width, lessThanOrEqualTo(240));
      expect(size.height, size.width);

      final image = QrImage(
        QrCode.fromData(data: _link, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
      final total = image.moduleCount + KitTokens.qrQuietModules * 2;
      final physicalSide = size.width * 3;
      expect(physicalSide.roundToDouble(), closeTo(physicalSide, 1e-6));
      expect(physicalSide.round() % total, 0);

      final rects = _paintedRects(tester);
      expect(rects, isNotEmpty);
      for (final rect in rects) {
        for (final v in [rect.left, rect.top, rect.width, rect.height]) {
          final physical = v * 3;
          expect(physical.roundToDouble(), closeTo(physical, 1e-6));
        }
      }
    },
  );

  testWidgets('2. pattern: the painted modules equal the encoder\'s cells', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const KitQr(data: _link, semanticsLabel: 'code')),
    );
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(KitQr));
    final image = QrImage(
      QrCode.fromData(data: _link, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    final total = image.moduleCount + KitTokens.qrQuietModules * 2;
    expect(_paintedCells(tester, size.width, total), _darkCellsOf(_link));
  });

  testWidgets('3. theme-proof: paper is graphiteLight.surface1 and ink is '
      'graphiteLight.text1 in dark, light and a high-contrast pack', (
    tester,
  ) async {
    final themes = <String, ThemeData>{
      'dark': AppTheme.dark(),
      'light': AppTheme.light(),
      // No accessibility high-contrast mode exists yet (2026-09-26); a
      // pack with a very different, high-saturation palette stands in.
      'high-contrast pack (gruvbox dark)': AppTheme.dark(
        themePack(ThemePackId.gruvbox),
      ),
    };
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      await tester.pumpWidget(
        _host(
          const KitQr(data: _link, semanticsLabel: 'code'),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(KitQr),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.color!.toARGB32(),
        graphiteLight.surface1.toARGB32(),
        reason: name,
      );
      expect(
        _paintedInk(tester).toARGB32(),
        graphiteLight.text1.toARGB32(),
        reason: name,
      );
    }
  });

  testWidgets(
    '4. too long: shows kitQrTooLong and no paper; KitQr.fits agrees',
    (tester) async {
      expect(KitQr.fits(_tooLongData), isFalse);
      expect(KitQr.fits(_link), isTrue);

      await tester.pumpWidget(
        _host(KitQr(data: _tooLongData, semanticsLabel: 'code')),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.kitQrTooLong), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KitQr),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    '5. semantics: one image node with semanticsLabel; data appears nowhere',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        const label = 'QR code to open this conversation on your phone';
        await tester.pumpWidget(
          _host(const KitQr(data: _secretLink, semanticsLabel: label)),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(find.textContaining('super-secret-token'), findsNothing);

        final leaked = [
          for (final node in tester.semantics.simulatedAccessibilityTraversal())
            for (final part in [
              node.getSemanticsData().label,
              node.getSemanticsData().value,
              node.getSemanticsData().tooltip,
              node.getSemanticsData().hint,
            ])
              if (part.contains('super-secret-token')) part,
        ];
        expect(leaked, isEmpty);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('6. direction: the painted pattern under RTL equals LTR', (
    tester,
  ) async {
    Future<Set<(int, int)>> cellsFor(TextDirection direction) async {
      await tester.pumpWidget(
        _host(
          const KitQr(data: _link, semanticsLabel: 'code'),
          direction: direction,
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(KitQr));
      final image = QrImage(
        QrCode.fromData(data: _link, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
      final total = image.moduleCount + KitTokens.qrQuietModules * 2;
      return _paintedCells(tester, size.width, total);
    }

    final ltr = await cellsFor(TextDirection.ltr);
    final rtl = await cellsFor(TextDirection.rtl);
    expect(rtl, ltr);
  });

  test('7. empty: KitQr(data: \'\') asserts', () {
    expect(
      () => KitQr(data: '', semanticsLabel: 'code'),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets(
    '8. overflow: no overflow at 320/412 dp, text 1.0/1.3/2.0, LTR/RTL, '
    'both states',
    (tester) async {
      for (final width in [320.0, 412.0]) {
        tester.view.physicalSize = Size(width, 800) * 3;
        tester.view.devicePixelRatio = 3;
        for (final textScale in [1.0, 1.3, 2.0]) {
          for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
            for (final data in [_link, _tooLongData]) {
              await tester.pumpWidget(
                _host(
                  KitQr(data: data, semanticsLabel: 'code'),
                  textScale: textScale,
                  direction: direction,
                ),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'width=$width scale=$textScale dir=$direction '
                    'data.length=${data.length}',
              );
            }
          }
        }
      }
      addTearDown(tester.view.reset);
    },
  );
}
