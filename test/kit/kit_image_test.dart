// Behaviour tests for KitImage, KitAvatar and KitZoom
// (docs/ux-system/kit-api/KitImage.md).
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

/// A valid 1x1 opaque PNG so a source can decode without the network (the
/// same fixture test/provider_logo_test.dart uses).
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00,
  0x90, 0x77, 0x53, 0xDE,
  0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT
  0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00,
  0x18, 0xDD, 0x8D, 0xB0,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

final ImageProvider _placeholderProvider = MemoryImage(
  Uint8List.fromList(const []),
);

/// An [ImageProvider] whose stream always errors, so [KitImage]'s failure
/// state and [KitAvatar]'s "keeps showing the initials" behaviour are
/// deterministic and need no network.
class _FailingProvider extends ImageProvider<_FailingProvider> {
  const _FailingProvider();

  @override
  Future<_FailingProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('kit_image_test: forced failure')),
  );

  @override
  bool operator ==(Object other) => other is _FailingProvider;

  @override
  int get hashCode => runtimeType.hashCode;
}

Future<BuildContext> _pump(
  WidgetTester tester,
  Widget child, {
  double dpr = 1,
  Size physicalSize = const Size(800, 800),
  Locale locale = const Locale('en'),
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: textScaler,
        ),
        child: child!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  return tester.element(find.byType(Scaffold));
}

/// The [Semantics] widget KitImage/KitAvatar/KitZoom builds for itself, or
/// null when it built none (a decorative or unlabeled image excludes
/// itself, so this is the direct, version-stable way to check that).
Semantics? _ownSemantics(WidgetTester tester, Finder of) {
  final found = find.descendant(of: of, matching: find.byType(Semantics));
  final widgets = tester.widgetList<Semantics>(found).toList();
  return widgets.isEmpty ? null : widgets.first;
}

void main() {
  group('KitImage decode size (KitImage.md "Decode size")', () {
    testWidgets('a 100dp box at DPR 3 requests a decode width of 300', (
      tester,
    ) async {
      await _pump(
        tester,
        KitImage(
          source: KitImageSource.provider(_placeholderProvider),
          semanticsLabel: 'photo',
          width: 100,
          height: 100,
        ),
        dpr: 3,
      );
      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.width, 300);
      expect(resized.height, isNull);
    });

    testWidgets('at DPR 2.625 it requests 263', (tester) async {
      await _pump(
        tester,
        KitImage(
          source: KitImageSource.provider(_placeholderProvider),
          semanticsLabel: 'photo',
          width: 100,
          height: 100,
        ),
        dpr: 2.625,
      );
      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.width, 263);
    });

    testWidgets('filterQuality is high for memory, asset and provider', (
      tester,
    ) async {
      for (final source in [
        KitImageSource.memory(_onePixelPng),
        const KitImageSource.asset('assets/does_not_matter.png'),
        KitImageSource.provider(_placeholderProvider),
      ]) {
        await _pump(
          tester,
          KitImage(source: source, semanticsLabel: 'photo', width: 40),
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.filterQuality, FilterQuality.high);
      }
    });
  });

  group('KitImage states', () {
    testWidgets('loading shows a surface2 fill with no spinner', (
      tester,
    ) async {
      final context = await _pump(
        tester,
        const KitImage(
          source: KitImageSource.provider(_FailingProvider()),
          semanticsLabel: 'photo',
          width: 100,
          height: 100,
        ),
      );
      // Before the (async) error lands, the frame is null: no spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final tokens = KitTokens.of(context);
      final decoration =
          tester
                  .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                  .first
                  .decoration
              as ShapeDecoration;
      expect(decoration.color, tokens.roles.surface2);
    });

    testWidgets(
      'a failing provider shows the broken-image glyph; at 120dp+ the words too',
      (tester) async {
        await _pump(
          tester,
          const KitImage(
            source: KitImageSource.provider(_FailingProvider()),
            semanticsLabel: 'photo',
            width: 200,
            height: 200,
          ),
        );
        await tester.pump();
        expect(find.byIcon(AppIconography.imageBroken), findsOneWidget);
        expect(find.text("Can't show this image"), findsOneWidget);
      },
    );

    testWidgets('a narrow failure (<120dp) shows the glyph only', (
      tester,
    ) async {
      await _pump(
        tester,
        const KitImage(
          source: KitImageSource.provider(_FailingProvider()),
          semanticsLabel: 'photo',
          width: 80,
          height: 80,
        ),
      );
      await tester.pump();
      expect(find.byIcon(AppIconography.imageBroken), findsOneWidget);
      expect(find.text("Can't show this image"), findsNothing);
    });

    testWidgets('fallback replaces the failure notice when given', (
      tester,
    ) async {
      await _pump(
        tester,
        const KitImage(
          source: KitImageSource.provider(_FailingProvider()),
          semanticsLabel: 'photo',
          width: 200,
          height: 200,
          fallback: Text('fallback shown'),
        ),
      );
      await tester.pump();
      expect(find.text('fallback shown'), findsOneWidget);
      expect(find.byIcon(AppIconography.imageBroken), findsNothing);
    });

    testWidgets('a source change from a good image to a failing one shows the '
        'failure state, never the old image', (tester) async {
      await _pump(
        tester,
        KitImage(
          source: KitImageSource.memory(_onePixelPng),
          semanticsLabel: 'photo',
          width: 100,
          height: 100,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIconography.imageBroken), findsNothing);

      await _pump(
        tester,
        const KitImage(
          source: KitImageSource.provider(_FailingProvider()),
          semanticsLabel: 'photo',
          width: 100,
          height: 100,
        ),
      );
      await tester.pump();
      expect(find.byIcon(AppIconography.imageBroken), findsOneWidget);
    });
  });

  group('KitImage semantics (A11Y)', () {
    testWidgets('semanticsLabel null gives no semantics node', (tester) async {
      await _pump(
        tester,
        KitImage(
          source: KitImageSource.memory(_onePixelPng),
          semanticsLabel: null,
          width: 40,
          height: 40,
        ),
      );
      await tester.pumpAndSettle();
      expect(_ownSemantics(tester, find.byType(KitImage)), isNull);
    });

    testWidgets('a label gives one image node', (tester) async {
      await _pump(
        tester,
        KitImage(
          source: KitImageSource.memory(_onePixelPng),
          semanticsLabel: 'A cat',
          width: 40,
          height: 40,
        ),
      );
      await tester.pumpAndSettle();
      final semantics = _ownSemantics(tester, find.byType(KitImage))!;
      expect(semantics.properties.label, 'A cat');
      expect(semantics.properties.image, isTrue);
    });
  });

  group('KitAvatar', () {
    testWidgets('shows initials and the semantic label', (tester) async {
      await _pump(tester, const KitAvatar(name: 'Open AI'));
      expect(find.text('OA'), findsOneWidget);
      final semantics = _ownSemantics(tester, find.byType(KitAvatar))!;
      expect(semantics.properties.label, 'Open AI');
      expect(semantics.properties.image, isTrue);
    });

    testWidgets('an Arabic name shows its first graphemes, no case change', (
      tester,
    ) async {
      await _pump(tester, const KitAvatar(name: 'محمد علي'));
      expect(find.text('مع'), findsOneWidget);
    });

    testWidgets('decorative gives no semantics node', (tester) async {
      await _pump(tester, const KitAvatar(name: 'Open AI', decorative: true));
      expect(_ownSemantics(tester, find.byType(KitAvatar)), isNull);
    });

    testWidgets('a failing image keeps showing the initials', (tester) async {
      await _pump(
        tester,
        const KitAvatar(
          name: 'Open AI',
          image: KitImageSource.provider(_FailingProvider()),
        ),
      );
      await tester.pump();
      expect(find.text('OA'), findsOneWidget);
    });

    testWidgets('at 2.0 text the initials stay clamped', (tester) async {
      await _pump(
        tester,
        const KitAvatar(name: 'Open AI'),
        textScaler: const TextScaler.linear(2),
      );
      final rendered = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(KitAvatar),
          matching: find.byType(RichText),
        ),
      );
      // MediaQuery.withClampedTextScaling caps the scaler the KitText below
      // it reads, so the paragraph's applied scale is under 2.0.
      expect(
        rendered.textScaler.scale(10),
        lessThan(const TextScaler.linear(2).scale(10)),
      );
    });
  });

  group('KitZoom', () {
    setUp(() {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    });
    tearDown(() => debugPlatformCapabilities = null);

    Widget zoom({
      KitZoomMode mode = KitZoomMode.fit,
      KitZoomController? controller,
      Object? resetKey,
      Key? resetControlKey,
    }) => SizedBox(
      width: 300,
      height: 300,
      child: KitZoom(
        label: 'Screenshot.png',
        mode: mode,
        controller: controller,
        resetKey: resetKey,
        resetControlKey: resetControlKey,
        child: const SizedBox(
          width: 100,
          height: 100,
          child: ColoredBox(color: Colors.blue),
        ),
      ),
    );

    String? zoomValue(WidgetTester tester) {
      final matches = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(KitZoom),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => s.properties.value != null);
      return matches.isEmpty ? null : matches.first.properties.value;
    }

    Map<CustomSemanticsAction, VoidCallback> zoomActions(WidgetTester tester) {
      final matches = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(KitZoom),
              matching: find.byType(Semantics),
            ),
          )
          .where((s) => s.properties.customSemanticsActions != null);
      return matches.isEmpty
          ? const {}
          : matches.first.properties.customSemanticsActions!;
    }

    Future<void> doubleTapAt(WidgetTester tester, Offset point) async {
      await tester.tapAt(point);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(point);
      await tester.pump();
    }

    // KitIconButton never shows its label as a mounted Text (only as a
    // tooltip and a semantic name), so it is found by its field, not by
    // find.widgetWithText.
    Finder byLabel(String label) =>
        find.byWidgetPredicate((w) => w is KitIconButton && w.label == label);

    testWidgets('double-tap goes to 2x and back to 1x', (tester) async {
      await _pump(tester, zoom());
      final center = tester.getCenter(find.byType(KitZoom));
      await doubleTapAt(tester, center);
      await tester.pumpAndSettle();
      expect(zoomValue(tester), isNot('100 %'));

      await doubleTapAt(tester, center);
      await tester.pumpAndSettle();
      expect(zoomValue(tester), '100 %');
    });

    testWidgets('Ctrl+= then Ctrl+0 returns to 1x (desktop capabilities)', (
      tester,
    ) async {
      await _pump(tester, zoom());
      await tester.tap(find.byType(KitZoom));
      // A tap only resolves once the double-tap disambiguation window
      // passes with no second tap (the same GestureDetector also handles
      // double-tap-to-zoom).
      await tester.pump(kDoubleTapTimeout);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(zoomValue(tester), isNot('100 %'));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(zoomValue(tester), '100 %');
    });

    testWidgets('the custom actions zoom in, zoom out and reset', (
      tester,
    ) async {
      await _pump(tester, zoom());
      final zoomIn = zoomActions(
        tester,
      ).entries.firstWhere((e) => e.key.label == 'Zoom in').value;
      zoomIn();
      await tester.pumpAndSettle();
      expect(zoomValue(tester), isNot('100 %'));

      final reset = zoomActions(
        tester,
      ).entries.firstWhere((e) => e.key.label == 'Reset zoom').value;
      reset();
      await tester.pumpAndSettle();
      expect(zoomValue(tester), '100 %');
    });

    testWidgets(
      'at 1x reset is disabled with its reason, at max zoom in is disabled',
      (tester) async {
        await _pump(tester, zoom());
        final reset = tester.widget<KitIconButton>(
          byLabel('Already at full view'),
        );
        expect(reset.onPressed, isNull);

        for (var i = 0; i < 20; i++) {
          final zoomInFinder = find.widgetWithIcon(
            KitIconButton,
            AppIconography.expand,
          );
          final button = tester.widget<KitIconButton>(zoomInFinder);
          if (button.onPressed == null) break;
          button.onPressed!();
          await tester.pumpAndSettle();
        }
        final atMax = tester.widget<KitIconButton>(byLabel('Largest zoom'));
        expect(atMax.onPressed, isNull);
      },
    );

    testWidgets('a new resetKey resets', (tester) async {
      await _pump(tester, zoom(resetKey: 1));
      final center = tester.getCenter(find.byType(KitZoom));
      await doubleTapAt(tester, center);
      await tester.pumpAndSettle();
      expect(zoomValue(tester), isNot('100 %'));

      await _pump(tester, zoom(resetKey: 2));
      await tester.pumpAndSettle();
      expect(zoomValue(tester), '100 %');
    });

    testWidgets(
      'canvas mode fits a 2000x2000 child on open and reset() returns to it',
      (tester) async {
        final controller = KitZoomController();
        addTearDown(controller.dispose);
        await _pump(
          tester,
          SizedBox(
            width: 300,
            height: 300,
            child: KitZoom(
              label: 'Work graph',
              mode: KitZoomMode.canvas,
              controller: controller,
              resetControlKey: const ValueKey('fit'),
              child: const SizedBox(
                width: 2000,
                height: 2000,
                child: ColoredBox(color: Colors.green),
              ),
            ),
          ),
        );
        await tester.pump();
        final fitted = controller.value.getMaxScaleOnAxis();
        expect(fitted, lessThanOrEqualTo(1.0));
        expect(fitted, greaterThanOrEqualTo(KitZoom.minScale));

        // Pans within the (very large) boundary without throwing.
        await tester.drag(find.byType(KitZoom), const Offset(-40, -40));
        await tester.pumpAndSettle();

        controller.reset();
        await tester.pumpAndSettle();
        expect(controller.value.getMaxScaleOnAxis(), closeTo(fitted, 0.01));
        expect(find.byKey(const ValueKey('fit')), findsOneWidget);
      },
    );

    testWidgets('under reduced motion the reset settles after one pump', (
      tester,
    ) async {
      await _pump(tester, zoom(), disableAnimations: true);
      final center = tester.getCenter(find.byType(KitZoom));
      await doubleTapAt(tester, center);
      // _animateTo jumps straight to the target under reduced motion
      // (KitMotion.reduced) instead of starting the shared
      // AnimationController, so the value is exact after doubleTapAt's own
      // single pump, never mid-tween.
      expect(zoomValue(tester), isNot('100 %'));

      tester.widget<KitIconButton>(byLabel('Reset zoom')).onPressed!();
      await tester.pump();
      expect(zoomValue(tester), '100 %');
      // What is left running past this one pump is Material's own
      // IconButton enabled/disabled chrome transition (kThemeChangeDuration
      // — the button changed from "Reset zoom" to the disabled "Already at
      // full view"), not KitZoom's motion: the v1 KitIconButton this unit
      // depends on (KitImage.md "Depends on") owns that timing, and it is
      // bounded and unrelated to KitMotion.reduced.
      final flushed = await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
      );
      expect(flushed, lessThan(30));
    });

    testWidgets('no HapticFeedback call', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.startsWith('HapticFeedback')) calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, zoom());
      final center = tester.getCenter(find.byType(KitZoom));
      await doubleTapAt(tester, center);
      await tester.pumpAndSettle();
      await tester.tap(byLabel('Reset zoom'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });
  });
}
