// Gallery (gate G4) for KitProgress v2, docs/ux-system/kit-api/KitProgress.md
// "Galleries required": the six declared states at 412×915, the default
// (staged) state at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000,
// and at 2.0 text and in Arabic.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_progress_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_layout.dart';
import 'package:opencode_mobile/ui/kit/kit_progress.dart';

import 'kit_gallery.dart';

/// KitProgress.md "renders KitProgressView inside an inline KitStateView-
/// sized host": the host caps the bar's width, it does not fix it.
Widget _host(KitProgress progress) => ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: KitLayout.stateMaxWidth),
  child: KitProgressView(progress: progress),
);

/// KitProgress.md "Galleries required": the default (staged) state at
/// these sizes besides 412×915. Listed here rather than read from
/// `kitGallerySizes`, which has no 915×412 (the landscape phone).
const _defaultSizes = <Size>[
  Size(360, 800),
  Size(915, 412),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

const _stagedEn = KitProgress.staged(
  step: 3,
  of: 5,
  label: 'Installing',
  eta: Duration(minutes: 2),
);

const _stagedAr = KitProgress.staged(
  step: 3,
  of: 5,
  label: 'يثبّت',
  eta: Duration(minutes: 2),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // Declared states (KIT-12), 412×915, dark and light.
    final states = <String, KitProgress>{
      'waiting': const KitProgress.waiting(),
      'known': const KitProgress.known(
        0.62,
        caption: '29 of 30 MB',
        eta: Duration(seconds: 50),
      ),
      'staged': _stagedEn,
      'staged_measured': const KitProgress.staged(
        step: 2,
        of: 4,
        label: 'Downloading',
        stepValue: 0.4,
        caption: '12 of 30 MB',
      ),
      'stopped': const KitProgress.known(
        0.4,
        caption: '18 of 30 MB',
        tone: AppStatusTone.neutral,
      ),
      'failed': const KitProgress.known(
        0.4,
        caption: '18 of 30 MB',
        tone: AppStatusTone.failure,
      ),
    };
    for (final MapEntry(key: state, value: progress) in states.entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_progress_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: _host(progress),
        );
      });
    }

    // Default (staged) at the other LAY-4 sizes, the landscape phone included.
    for (final size in _defaultSizes) {
      testWidgets('staged · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_progress_staged', size, light: light),
          size: size,
          light: light,
          child: _host(_stagedEn),
        );
      });
    }

    // Default (staged) at 2.0 text and in Arabic, at the two TEST-9 sizes.
    for (final size in kitGalleryScaledSizes) {
      testWidgets('staged · text2 · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_progress_staged',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _host(_stagedEn),
        );
      });
      testWidgets('staged · Arabic · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_progress_staged',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          child: _host(_stagedAr),
        );
      });
    }
  }
}
