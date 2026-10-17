// Gallery (gate G4) for KitHandoffRecord, docs/design/agent-handoff-contract.md.
//
// Galleries are phone 412x915 and one wide size 1280x800, light and dark
// (owner decision 2026-09-27); each state also at 2.0 text on both sizes.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_handoff_record_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _record({required bool expanded}) => KitHandoffRecord(
  sizeBytes: 48200,
  omittedMessages: 12,
  redacted: true,
  markdown:
      '# Conversation record\n\nFix the login redirect on the finance hub.\n\n'
      '- Checked the callback\n- Found the cause in the session cookie',
  path: '.opencode/handoff/finance-hub-login-redirect-record.md',
  initiallyExpanded: expanded,
);

final _states = <String, Widget Function()>{
  'folded': () => _record(expanded: false),
  'open': () => _record(expanded: true),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      for (final MapEntry(key: state, value: build) in _states.entries) {
        testWidgets('kit_handoff_record $state · $at · $mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_handoff_record_$state',
              size,
              light: light,
            ),
            size: size,
            light: light,
            child: build(),
          );
        });

        testWidgets('kit_handoff_record $state · 2.0 text · $at · $mode', (
          tester,
        ) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_handoff_record_$state',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            child: build(),
          );
        });
      }
    }
  }
}
