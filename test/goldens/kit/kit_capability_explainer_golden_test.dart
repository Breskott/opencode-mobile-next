// Gallery (gate G4) for KitCapabilityExplainer,
// docs/ux-system/kit-api/KitCapabilityExplainer.md "Galleries required": the
// declared states at 412x915 and the default (row-enable) at 1280x800, in
// light and dark, DPR 3, rendered as Android, with a fake handler registered
// for the enable scenes. The owner decision of 2026-09-27 (STANDARDS.md
// header) drops the Arabic/RTL and text-2.0 shots and narrows this wave's
// sizes to the phone and one wide size.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_capability_explainer_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_capability_explainer.dart';

import 'kit_gallery.dart';

Widget _inset(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

Map<String, Widget Function()> _states() => {
  // Files on Codex: no flow, so it only explains where it works.
  'row_explains': () => const KitCapabilityExplainer.row(
    capability: 'flag:fileBrowsing+terminal',
    host: KitHost.codex,
    serverName: 'laptop',
  ),
  'row_enable': () =>
      const KitCapabilityExplainer.row(capability: 'voice.model'),
  'state_explains': () => _inset(
    const KitCapabilityExplainer.state(
      capability: 'flag:sessionDiff',
      host: KitHost.paseo,
    ),
  ),
  'state_enable': () => _inset(
    const KitCapabilityExplainer.state(
      capability: 'voice.model',
      cost: ['About 160 MB', 'about 2 min', 'uses Wi-Fi if you allow it'],
    ),
  ),
  'offer': () => _inset(
    KitCapabilityExplainer.offer(capability: 'team.on', onNotNow: () {}),
  ),
  'offer_folded': () => KitCapabilityExplainer.offer(
    capability: 'team.on',
    folded: true,
    onNotNow: () {},
  ),
};

void _registerFakeHandlers() {
  for (final flow in KitEnableFlows.all) {
    KitCapabilities.registerFlow(flow, (context, request) async {});
  }
}

void main() {
  setUpAll(loadKitGalleryFonts);
  setUp(_registerFakeHandlers);
  tearDown(KitCapabilities.debugReset);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: build) in _states().entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_capability_explainer_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: build(),
        );
      });
    }

    testWidgets('default · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_capability_explainer_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _states()['row_enable']!(),
      );
    });
  }
}
