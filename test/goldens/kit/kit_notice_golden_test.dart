// Gallery (gate G4) for KitNotice v2, docs/ux-system/kit-api/KitNotice.md:
// the plain notice in its tones, the error in its network and other forms,
// the cost line before its primary and the one-sentence offer, each on a
// surface1 section on the host's rails.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_notice_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_notice.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// A surface1 section on the screen's rails, as a form or a list holds a
/// notice.
class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.roles.surface1,
          borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

void _noop() {}

String _t(bool ar, String en, String arabic) => ar ? arabic : en;

/// The whole anatomy: title, message, notes, an action and the close.
Widget _default({bool ar = false}) => _Section(
  children: [
    KitNotice(
      title: _t(ar, 'The key was not accepted', 'لم يُقبل المفتاح'),
      message: _t(
        ar,
        'The provider said the key has expired. Paste a new one.',
        'قال المزوّد إن المفتاح منتهٍ. الصق مفتاحًا جديدًا.',
      ),
      notes: [
        _t(ar, 'Nothing was saved', 'لم يُحفظ شيء'),
        _t(
          ar,
          'The old key stays on the server until you replace it',
          'يبقى المفتاح القديم على الخادم حتى تستبدله',
        ),
      ],
      actions: [
        KitAction(label: _t(ar, 'Paste a key', 'لصق مفتاح'), onPressed: _noop),
      ],
      onDismiss: _noop,
    ),
  ],
);

Widget _tone(AppStatusTone tone, String message) => _Section(
  children: [KitNotice(message: message, tone: tone)],
);

Widget _errorNetwork() => _Section(
  children: [
    KitNotice.error(
      message: 'Couldn’t reach the laptop',
      error: TimeoutException('no answer in 10 s'),
      details: 'GET /session timed out after 10 s',
      retry: const KitAction(label: 'Try again', onPressed: _noop),
      switchServer: const KitAction(label: 'Switch server', onPressed: _noop),
    ),
  ],
);

/// Shown with a report handler registered (see [_withHandler]).
Widget _errorOther({bool ar = false}) => _Section(
  children: [
    KitNotice.error(
      title: _t(ar, 'Couldn’t load files', 'تعذّر تحميل الملفات'),
      message: _t(
        ar,
        'The server sent something the app can’t read.',
        'أرسل الخادم شيئًا لا يستطيع التطبيق قراءته.',
      ),
      error: const FormatException('unexpected character'),
      details: 'FormatException: unexpected character at 12',
      reportSource: 'files-viewer',
      retry: KitAction(
        label: _t(ar, 'Try again', 'إعادة المحاولة'),
        onPressed: _noop,
      ),
    ),
  ],
);

Widget _cost() => _Section(
  children: [
    const KitNotice.cost([
      'About 208 MB',
      'about 4 min',
      'uses battery while it installs',
    ], title: 'Before you start'),
    SizedBox(height: 12),
    const KitButton.primary(label: 'Install', onPressed: _noop),
  ],
);

Widget _offer({bool ar = false, bool wrapped = false}) => _Section(
  children: [
    KitNotice.offer(
      message: wrapped
          ? _t(
              ar,
              'This server also runs an AI team. Turn it on to hand it '
                  'bigger jobs?',
              'يشغّل هذا الخادم فريق ذكاء اصطناعي أيضًا. هل تريد تشغيله '
                  'لتسليمه مهام أكبر؟',
            )
          : _t(ar, 'Pin it to Work?', 'تثبيته في العمل؟'),
      action: KitAction(
        label: wrapped ? _t(ar, 'Turn on', 'تشغيل') : _t(ar, 'Pin', 'تثبيت'),
        onPressed: _noop,
      ),
      onDismiss: _noop,
      dismissLabel: _t(ar, 'Not now', 'ليس الآن'),
    ),
  ],
);

/// Registers a report handler for one shot, so Report a problem shows.
void _withHandler() {
  KitReportHook.handler = (_, _) async {};
  addTearDown(() => KitReportHook.handler = null);
}

/// Opens [child] as the body of a page, framed as `kitGalleryPart` frames a
/// part (the reading width, the safe area, a scrolling body), so the shot
/// goes through `kitGalleryShot`, which gate G4 reads.
FutureOr<void> Function(BuildContext) _page(Widget child) =>
    (context) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  const phone = Size(412, 915);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // Every declared state and form at 412×915.
    testWidgets('[states] kit_notice_default · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_default', phone, light: light),
        size: phone,
        light: light,
        open: _page(_default()),
      );
    });
    testWidgets('[states] kit_notice_ok · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_ok', phone, light: light),
        size: phone,
        light: light,
        open: _page(_tone(AppStatusTone.ok, 'The server answered in 120 ms.')),
      );
    });
    testWidgets('[states] kit_notice_warning · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_warning', phone, light: light),
        size: phone,
        light: light,
        open: _page(
          _tone(
            AppStatusTone.attention,
            'Battery saver is on. Android may pause agents after a few '
            'minutes in the background.',
          ),
        ),
      );
    });
    testWidgets('[states] kit_notice_working · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_working', phone, light: light),
        size: phone,
        light: light,
        open: _page(_tone(AppStatusTone.progress, 'Checking the server…')),
      );
    });
    testWidgets('[states] kit_notice_error_network · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_error_network', phone, light: light),
        size: phone,
        light: light,
        open: _page(_errorNetwork()),
      );
    });
    testWidgets('[states] kit_notice_error_other · $mode', (tester) async {
      _withHandler();
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_error_other', phone, light: light),
        size: phone,
        light: light,
        open: _page(_errorOther()),
      );
    });
    testWidgets('[states] kit_notice_cost · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_cost', phone, light: light),
        size: phone,
        light: light,
        open: _page(_cost()),
      );
    });
    testWidgets('[states] kit_notice_offer · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_offer', phone, light: light),
        size: phone,
        light: light,
        open: _page(_offer()),
      );
    });
    testWidgets('[states] kit_notice_offer_wrapped · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_notice_offer_wrapped', phone, light: light),
        size: phone,
        light: light,
        open: _page(_offer(wrapped: true)),
      );
    });

    // The default at the other window sizes, and a phone in landscape.
    for (final size in [
      for (final size in kitGallerySizes)
        if (size != phone) size,
      const Size(915, 412),
    ]) {
      final at = kitGallerySize(size);
      testWidgets('[sizes] kit_notice default · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_notice_default', size, light: light),
          size: size,
          light: light,
          open: _page(_default()),
        );
      });
    }

    // 2.0 text and Arabic for the default, the error and the offer.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('[text2] kit_notice_default · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_notice_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _page(_default()),
        );
      });
      testWidgets('[text2] kit_notice_error_other · $at · $mode', (
        tester,
      ) async {
        _withHandler();
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_notice_error_other',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _page(_errorOther()),
        );
      });
      testWidgets('[text2] kit_notice_offer · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_notice_offer',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _page(_offer()),
        );
      });
      testWidgets('[arabic] kit_notice_default · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_notice_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          open: _page(_default(ar: true)),
        );
      });
      testWidgets('[arabic] kit_notice_error_other · $at · $mode', (
        tester,
      ) async {
        _withHandler();
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_notice_error_other',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          open: _page(_errorOther(ar: true)),
        );
      });
      testWidgets('[arabic] kit_notice_offer · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_notice_offer',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          open: _page(_offer(ar: true)),
        );
      });
    }
  }
}
