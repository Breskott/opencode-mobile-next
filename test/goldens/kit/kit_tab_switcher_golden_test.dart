// Gallery (gate G4) for KitTabSwitcher v2 and its KitTabStrip
// (docs/ux-system/kit-api/KitTabSwitcher.md "Galleries required"), the strip
// over a page stub: default, counts_loading, needs_you and overflowing at
// 412x915 and 1280x800, dark and light, plus focused (keyboard) at 412x915.
//
// Owner decision 2026-09-27: phone 412x915 and one wide size (1280x800)
// only, light and dark; no Arabic (Arabic is dropped). The default is also
// shot at text 2.0 at both sizes (TEST-9, G4).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_tab_switcher_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_tab_switcher.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

enum _State { defaults, countsLoading, needsYou, overflowing }

String _stateName(_State state) => switch (state) {
  _State.defaults => 'default',
  _State.countsLoading => 'counts_loading',
  _State.needsYou => 'needs_you',
  _State.overflowing => 'overflowing',
};

const _columns = ['Backlog', 'Ready', 'Working', 'Review', 'Done'];
const _eight = [..._columns, 'Blocked', 'Archived', 'Waiting on review'];

List<KitTab> _tabs(_State state) => switch (state) {
  _State.defaults => [
    for (final (i, word) in _columns.indexed)
      KitTab(label: word, count: const [4, 2, 4, 2, 12][i]),
  ],
  _State.countsLoading => [for (final word in _columns) KitTab(label: word)],
  _State.needsYou => [
    for (final (i, word) in _columns.indexed)
      KitTab(
        label: word,
        count: const [4, 2, 4, 2, 12][i],
        needsYou: i == 2 ? 1 : 0,
      ),
  ],
  _State.overflowing => [
    for (final (i, word) in _eight.indexed)
      KitTab(label: word, count: const [4, 2, 4, 2, 12, 1, 38, 3][i]),
  ],
};

Widget _scene(_State state) {
  final tabs = _tabs(state);
  final selected = state == _State.overflowing ? tabs.length - 1 : 2;
  return SizedBox(
    height: 320,
    child: KitTabSwitcher.tabs(
      tabs: tabs,
      index: selected,
      onSelected: (_) {},
      semanticsLabel: 'Columns',
      children: [for (final tab in tabs) _PageStub(tab.label)],
    ),
  );
}

/// A page under the strip: its name and two placeholder lines.
class _PageStub extends StatelessWidget {
  const _PageStub(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitText(name, role: KitTextRole.headline),
        const SizedBox(height: 8),
        const KitText(
          'Cards in this column keep their place when you switch.',
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
      ],
    ),
  );
}

/// The focused state needs a real key press, which [kitGalleryPart] has no
/// hook for: it pumps its own app, tabs into the strip and moves focus one
/// tab along (the same technique as kit_tappable_golden_test.dart).
Future<void> _focusedShot(
  WidgetTester tester, {
  required String name,
  required bool light,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _scene(_State.defaults),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  } finally {
    debugDefaultTargetPlatformOverride = null;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      for (final state in _State.values) {
        testWidgets(
          'kit_tab_switcher ${_stateName(state)} · ${kitGallerySize(size)} · '
          '$mode',
          (tester) async {
            await kitGalleryPart(
              tester,
              name: kitGalleryName(
                'kit_tab_switcher_${_stateName(state)}',
                size,
                light: light,
              ),
              size: size,
              light: light,
              child: _scene(state),
            );
          },
        );
      }
    }

    testWidgets('kit_tab_switcher focused · $mode', (tester) async {
      await _focusedShot(
        tester,
        name: kitGalleryName(
          'kit_tab_switcher_focused',
          const Size(412, 915),
          light: light,
        ),
        light: light,
      );
    });

    for (final size in kitGalleryScaledSizes) {
      testWidgets(
        'kit_tab_switcher default · text 2.0 · ${kitGallerySize(size)} · $mode',
        (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_tab_switcher_default',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            child: _scene(_State.defaults),
          );
        },
      );
    }
  }
}
