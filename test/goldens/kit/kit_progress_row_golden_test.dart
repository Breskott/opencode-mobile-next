// Gallery (gate G4) for KitProgressRow, docs/ux-system/kit-api/KitProgressRow.md
// "Galleries required": the declared states at 412x915, and the default
// (loaded) state at 1280x800 — the owner decision 2026-09-27 (STANDARDS.md
// header) drops Arabic/RTL galleries and narrows this wave's gallery sizes
// to the phone and one wide size, both in light and dark; the default is
// also shot at text 2.0 at both sizes (TEST-9, G4).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_progress_row_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_progress_row.dart';

import 'kit_gallery.dart';

const _contextSegments = [
  KitProgressSegment(
    label: 'Conversation',
    value: 0.41,
    valueLabel: '41k tokens',
  ),
  KitProgressSegment(
    label: 'System prompt',
    value: 0.12,
    valueLabel: '12k tokens',
  ),
  KitProgressSegment(label: 'Tools', value: 0.09, valueLabel: '9k tokens'),
  KitProgressSegment(label: 'History', value: 0.09, valueLabel: '9k tokens'),
  // The fifth folds into "Other" (the "4 + Other" gallery state).
  KitProgressSegment(label: 'Cache', value: 0.05, valueLabel: '5k tokens'),
];

const _loaded = KitProgressRow(
  title: 'Claude · 5-hour window',
  value: 0.62,
  valueLabel: '62 % · resets in 3 h',
);

/// KitProgressRow.md "Galleries required": the seven declared states.
Map<String, Widget> _states() => {
  'loading': const KitProgressRow(title: 'Claude · 5-hour window', value: null),
  'loaded': _loaded,
  'near_limit': const KitProgressRow(
    title: 'Provider quota',
    value: 0.85,
    valueLabel: '85 % · resets in 40 min',
  ),
  'at_limit': const KitProgressRow(
    title: 'Provider quota',
    value: 1.0,
    valueLabel: '100 % · resets in 40 min',
  ),
  'stale': KitProgressRow(
    title: 'Usage',
    value: 0.4,
    valueLabel: '40 % used',
    asOf: DateTime(2026, 9, 27, 10, 42),
  ),
  'segments': const KitProgressRow.segments(
    title: 'Context used',
    segments: _contextSegments,
    valueLabel: '76 % of 200k tokens',
  ),
  'empty': const KitProgressRow(
    title: 'Usage',
    value: 0,
    valueLabel: 'Nothing used yet',
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: row) in _states().entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_progress_row_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: row,
        );
      });
    }

    // Default (loaded) at the one wide size the owner kept for this wave.
    testWidgets('loaded · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_progress_row_loaded',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _loaded,
      );
    });

    for (final size in kitGalleryScaledSizes) {
      testWidgets('loaded · text 2.0 · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_progress_row_loaded',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _loaded,
        );
      });
    }
  }
}
