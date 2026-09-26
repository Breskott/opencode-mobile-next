// Gallery (gate G4) for KitWorkLine (docs/ux-system/kit-api/KitWorkLine.md):
// every state at 412x915 in dark and light, each over a transcript-like
// ground with a line of prose above it; the default (done) state at
// 1280x800 and at 2.0 text. Phone and one wide size only, English only
// (owner decision 2026-09-27: no Arabic or RTL shots).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_work_line_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_work_line.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

const _counts = KitWorkCounts(read: 3, edited: 1, ran: 2);

/// Three KitToolRow-like steps (KitToolRow is a later unit's part; plain
/// kit text stands in for it here).
const _steps = <Widget>[
  KitText('Read lib/main.dart', role: KitTextRole.mono),
  KitText('Edited lib/ui/kit/chat/kit_work_line.dart', role: KitTextRole.mono),
  KitText('Ran flutter test test/kit', role: KitTextRole.mono),
];

/// A reply's prose, the work line under it, and the reply's next line.
Widget _scene(KitWorkLine line) => Padding(
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const KitText(
        'I will look at how the app starts, then fix the failing test.',
      ),
      const SizedBox(height: 8),
      line,
      const SizedBox(height: 8),
      const KitText('The test passes now; the change is one line.'),
    ],
  ),
);

KitWorkLine _line(KitWorkState state, {bool? expanded, String? now}) =>
    KitWorkLine(
      counts: _counts,
      state: state,
      steps: _steps,
      now: now,
      expanded: expanded,
    );

final _states = <String, KitWorkLine>{
  'running': _line(KitWorkState.running, now: 'Editing lib/main.dart'),
  'waiting_for_you': _line(KitWorkState.waitingForYou),
  'done': _line(KitWorkState.done),
  'done_expanded': _line(KitWorkState.done, expanded: true),
  'ended_failed': _line(KitWorkState.endedFailed),
  'stopped': _line(KitWorkState.stopped),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final entry in _states.entries) {
      testWidgets('kit_work_line ${entry.key} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_work_line_${entry.key}',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: _scene(entry.value),
        );
      });
    }

    testWidgets('kit_work_line default · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_line_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _scene(_line(KitWorkState.done)),
      );
    });

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_work_line default · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_work_line_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _scene(_line(KitWorkState.done)),
        );
      });
    }
  }
}
