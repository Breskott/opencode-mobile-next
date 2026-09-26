// Gallery (gate G4) for KitBreadcrumb, docs/ux-system/kit-api/KitBreadcrumb.md
// "Galleries required": the declared states and the keyboard focus at
// 412x915, and the default at 1280x800, in light and dark. The owner
// decision of 2026-09-27 (STANDARDS.md header) drops the Arabic/RTL shots
// and narrows this wave's sizes to the phone and one wide size. The
// fixture path is lib/ui/screens/settings/advanced under the root "oc_app".
// The spec's "under a top bar" scene waits for KitTopBar (not merged yet):
// the trail sits on ground within the 16 dp rails.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_breadcrumb_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_breadcrumb.dart';

import 'kit_gallery.dart';

const _root = 'oc_app';
const _default = ['lib', 'ui', 'screens'];
const _collapsed = [
  'lib',
  'ui',
  'screens',
  'settings',
  'advanced',
  'network',
  'proxy',
];
const _truncated = [
  'a-very-long-folder-name-somebody-chose-for-this-work',
  'advanced',
];

final _focusKey = GlobalKey(debugLabel: 'focused crumb');

Widget _trail(List<String> segments, {bool focusAncestor = false}) {
  final trail = KitBreadcrumb(
    rootLabel: _root,
    segments: segments,
    onSelected: (_) {},
    crumbKey: focusAncestor
        ? (index) => index == 1 ? _focusKey : ValueKey(index)
        : null,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: focusAncestor ? _KeyboardFocus(child: trail) : trail,
  );
}

/// Puts keyboard focus (with its ring) on the crumb under [_focusKey] once
/// the first frame is laid out.
class _KeyboardFocus extends StatefulWidget {
  const _KeyboardFocus({required this.child});

  final Widget child;

  @override
  State<_KeyboardFocus> createState() => _KeyboardFocusState();
}

class _KeyboardFocusState extends State<_KeyboardFocus> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final crumb = _focusKey.currentContext;
      if (crumb != null) Focus.of(crumb).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Map<String, Widget Function()> _states() => {
  'default': () => _trail(_default),
  'collapsed': () => _trail(_collapsed),
  'root_only': () => _trail(const []),
  'truncated': () => _trail(_truncated),
  'focused': () => _trail(_default, focusAncestor: true),
};

void main() {
  setUpAll(loadKitGalleryFonts);
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: build) in _states().entries) {
      testWidgets('$state · 412x915 · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_breadcrumb_$state',
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
          'kit_breadcrumb_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _trail(_default),
      );
    });
  }
}
