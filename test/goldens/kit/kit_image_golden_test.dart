// Gallery (gate G4) for KitImage, KitAvatar and KitZoom
// (docs/ux-system/kit-api/KitImage.md).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_image_golden_test.dart
// and look at every changed image before committing it.
//
// NOT proven here (STANDARDS.md TEST-15, G6): the overflow matrix without
// images lives in the shared test/text_scale_overflow_test.dart, which (like
// kit.dart's export table) is wired up at integration once the coordinator
// adds this part's row — a kit-part unit does not edit that shared harness
// (docs/ux-system/revamp/STANDARDS.md, "Shared files you never stage").
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// A valid 1x1 opaque PNG, deterministic and network-free (TEST-11); the
/// same fixture test/provider_logo_test.dart and kit_image_test.dart use.
final Uint8List _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00,
  0x90, 0x77, 0x53, 0xDE,
  0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
  0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00,
  0x18, 0xDD, 0x8D, 0xB0,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

/// An [ImageProvider] whose stream always errors, so the failure state
/// renders deterministically and needs no network.
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
    Future<ImageInfo>.error(
      StateError('kit_image_golden_test: forced failure'),
    ),
  );

  @override
  bool operator ==(Object other) => other is _FailingProvider;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Builds [child] (a [KitZoom]) through a [KitZoomController] and, once the
/// first frame is up, drives it with [act] — the gallery's own way to show
/// a part mid-interaction (KitZoom is not a `showKit…` opener, so it has no
/// `then:` step of its own).
class _Driven extends StatefulWidget {
  const _Driven({required this.builder, this.act});

  final Widget Function(KitZoomController) builder;
  final void Function(KitZoomController)? act;

  @override
  State<_Driven> createState() => _DrivenState();
}

class _DrivenState extends State<_Driven> {
  late final KitZoomController controller = KitZoomController();
  bool _acted = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_acted && widget.act != null) {
      _acted = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.act!(controller),
      );
    }
    return widget.builder(controller);
  }
}

/// Entries stack in a plain [Column], generously spaced, so the reading
/// order (top to bottom, then start to end, A11Y-4) is unambiguous. The
/// state each entry shows is named by the golden's own file name (TEST-20:
/// `kit_<part>_<state>`), not by an on-screen caption — a caption's own
/// text would be one more thing this gallery draws, rather than KitImage or
/// KitAvatar content.
Widget _list(List<Widget> entries) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final entry in entries) ...[entry, const SizedBox(height: 32)],
  ],
);

Widget _box(Widget child) => SizedBox(width: 120, height: 90, child: child);

Widget _loadedGallery() => _list([
  _box(
    KitImage(
      source: KitImageSource.memory(_onePixelPng),
      semanticsLabel: 'A photo',
    ),
  ),
  _box(
    KitImage(
      source: KitImageSource.memory(_onePixelPng),
      semanticsLabel: 'A photo',
      fit: KitImageFit.cover,
    ),
  ),
  _box(
    KitImage(
      source: KitImageSource.memory(_onePixelPng),
      semanticsLabel: 'A photo',
      shape: KitShape.panel,
    ),
  ),
  _box(
    KitImage(
      source: KitImageSource.memory(_onePixelPng),
      semanticsLabel: 'A photo',
      shape: KitShape.circle,
    ),
  ),
]);

Widget _loadingGallery() => SizedBox(
  width: 160,
  height: 120,
  child: const KitImage(
    source: KitImageSource.provider(_FailingProvider()),
    semanticsLabel: 'A photo',
  ),
);

Widget _failedGallery({required bool wide}) => SizedBox(
  width: wide ? 200 : 80,
  height: 120,
  child: const KitImage(
    source: KitImageSource.provider(_FailingProvider()),
    semanticsLabel: 'A photo',
  ),
);

Widget _avatarGallery() => _list([
  const KitAvatar(name: 'Open AI'),
  const KitAvatar(name: 'Open AI', size: KitAvatarSize.mark),
  const KitAvatar(name: 'This phone', icon: AppIconography.phone),
  KitAvatar(name: 'A teammate', image: KitImageSource.memory(_onePixelPng)),
]);

Widget _zoomGallery({required bool zoomed}) => SizedBox(
  width: 280,
  height: 280,
  child: _Driven(
    act: zoomed ? (c) => c.zoomIn() : null,
    builder: (controller) => KitZoom(
      label: 'Screenshot.png',
      controller: controller,
      child: const SizedBox(
        width: 160,
        height: 120,
        child: ColoredBox(color: Color(0xFF3D6BFF)),
      ),
    ),
  ),
);

Widget _defaultGallery() => _list([
  _box(
    KitImage(
      source: KitImageSource.memory(_onePixelPng),
      semanticsLabel: 'A photo',
    ),
  ),
  const KitAvatar(name: 'Open AI'),
]);

void main() {
  setUpAll(loadKitGalleryFonts);

  const size = Size(412, 915);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('states · loaded · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_loaded', size, light: light),
        size: size,
        light: light,
        child: _loadedGallery(),
      );
    });

    testWidgets('states · loading · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_loading', size, light: light),
        size: size,
        light: light,
        child: _loadingGallery(),
      );
    });

    testWidgets('states · failed narrow · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_error_narrow', size, light: light),
        size: size,
        light: light,
        child: _failedGallery(wide: false),
      );
    });

    testWidgets('states · failed wide · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_error_wide', size, light: light),
        size: size,
        light: light,
        child: _failedGallery(wide: true),
      );
    });

    testWidgets('states · avatar · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_avatar', size, light: light),
        size: size,
        light: light,
        child: _avatarGallery(),
      );
    });

    testWidgets('states · zoom rest · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_zoom_rest', size, light: light),
        size: size,
        light: light,
        child: _zoomGallery(zoomed: false),
      );
    });

    testWidgets('states · zoom zoomed · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_zoom_zoomed', size, light: light),
        size: size,
        light: light,
        child: _zoomGallery(zoomed: true),
      );
    });

    for (final s in kitGallerySizes) {
      testWidgets('default (loaded + avatar) · ${kitGallerySize(s)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_image_default', s, light: light),
          size: s,
          light: light,
          child: _defaultGallery(),
        );
      });
    }
  }

  // _text2 and _ar (dark only, per the other galleries' convention of one
  // representative theme for the scaled shots): failed, avatar, zoom_rest
  // at 412x915 and 1280x800.
  for (final s in kitGalleryScaledSizes) {
    testWidgets('failed · text2 · ${kitGallerySize(s)}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_image_error_wide',
          s,
          light: false,
          text2: true,
        ),
        size: s,
        light: false,
        textScale: 2,
        child: _failedGallery(wide: true),
      );
    });

    testWidgets('avatar · text2 · ${kitGallerySize(s)}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_avatar', s, light: false, text2: true),
        size: s,
        light: false,
        textScale: 2,
        child: _avatarGallery(),
      );
    });

    testWidgets('zoom rest · text2 · ${kitGallerySize(s)}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_image_zoom_rest',
          s,
          light: false,
          text2: true,
        ),
        size: s,
        light: false,
        textScale: 2,
        child: _zoomGallery(zoomed: false),
      );
    });

    testWidgets('failed · Arabic · ${kitGallerySize(s)}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_error_wide', s, light: false, ar: true),
        size: s,
        light: false,
        locale: const Locale('ar'),
        child: _failedGallery(wide: true),
      );
    });

    testWidgets('avatar · Arabic · ${kitGallerySize(s)}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_avatar', s, light: false, ar: true),
        size: s,
        light: false,
        locale: const Locale('ar'),
        child: _avatarGallery(),
      );
    });

    testWidgets('zoom rest · Arabic · ${kitGallerySize(s)}', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_image_zoom_rest', s, light: false, ar: true),
        size: s,
        light: false,
        locale: const Locale('ar'),
        child: _zoomGallery(zoomed: false),
      );
    });
  }
}
