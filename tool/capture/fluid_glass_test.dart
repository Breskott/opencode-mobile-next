// Renders of fluid glass for docs/qa/kit-fluid-glass-2026-09-28: the shell
// (top controls, colourful content, the dock) at 412x915, dark and light,
// at rest and frozen mid-motion — the lens stretching after a tap, the lens
// lifted under a dragging finger, the server pill pressed, search joining
// the pill as the page scrolls, and joined.
//
// It uses only KitNav, KitTopBar.shell and KitShellControls, so the same
// script renders the base commit too (before) — there the lens slides and
// nothing joins or gives:
//
//   flutter test --enable-impeller --concurrency=1 tool/capture/fluid_glass_test.dart
//   FLUID_GLASS_OUT=<abs path>/before flutter test --enable-impeller ...   (base)
//
// Liquid needs Impeller (--enable-impeller); without it the frosted look is
// rendered and the files are named frosted-*.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'fixtures.dart';

final _out =
    Platform.environment['FLUID_GLASS_OUT'] ??
    'docs/qa/kit-fluid-glass-2026-09-28/renders/after';
const _size = Size(412, 915);

List<KitNavDestination> _destinations() => const [
  KitNavDestination(
    label: 'Work',
    icon: AppIconography.workspace,
    selectedIcon: AppIconography.workspaceSelected,
    key: ValueKey('nav-work'),
  ),
  KitNavDestination(
    label: 'Inbox',
    icon: AppIconography.activity,
    selectedIcon: AppIconography.activitySelected,
    needsYou: 1,
    key: ValueKey('nav-inbox'),
  ),
  KitNavDestination(
    label: 'Project',
    icon: AppIconography.files,
    selectedIcon: AppIconography.filesSelected,
    key: ValueKey('nav-project'),
  ),
  KitNavDestination(
    label: 'Settings',
    icon: AppIconography.settings,
    key: ValueKey('nav-settings'),
  ),
];

const _swatches = [
  Color(0xFFE5484D),
  Color(0xFFF76B15),
  Color(0xFFFFC53D),
  Color(0xFF30A46C),
  Color(0xFF0090FF),
  Color(0xFF8E4EC6),
];

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: KitNav(
        destinations: _destinations(),
        selected: _selected,
        onSelected: (i) => setState(() => _selected = i),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: KitTopBar.shell(
                controls: KitShellControls(
                  server: 'Laptop',
                  serverStatus: 'Connected',
                  serverTone: AppStatusTone.ok,
                  onServer: () {},
                  onSearch: () {},
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('content'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: 40,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _swatches[i % _swatches.length],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Conversation ${i + 1}: fix the reconnect loop '
                          'in the chat and add a test',
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Then = Future<void> Function(WidgetTester tester);

final Map<String, _Then> _states = {
  'rest': (tester) async {},
  'lens-stretch': (tester) async {
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  },
  'lens-lift': (tester) async {
    final from = tester.getCenter(find.byKey(const ValueKey('nav-work')));
    final to = tester.getCenter(find.byKey(const ValueKey('nav-inbox')));
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset((to.dx - from.dx) * .8 / 6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    addTearDown(gesture.up);
  },
  'pressed': (tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.textContaining('Laptop', findRichText: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    addTearDown(gesture.up);
  },
  'joining': (tester) async {
    await tester.drag(
      find.byKey(const ValueKey('content')),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
  },
  'joined': (tester) async {
    await tester.drag(
      find.byKey(const ValueKey('content')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  },
};

void main() {
  setUpAll(loadCaptureFonts);
  tearDown(KitGlassShader.debugReset);
  final liquid = ui.ImageFilter.isShaderFilterSupported;
  final look = liquid ? 'liquid' : 'frosted';

  for (final light in [false, true]) {
    for (final MapEntry(key: state, value: then) in _states.entries) {
      final name = '$look-$state-${light ? 'light' : 'dark'}';
      testWidgets(name, (tester) async {
        tester.view
          ..physicalSize = _size * captureDevicePixelRatio
          ..devicePixelRatio = captureDevicePixelRatio;
        addTearDown(tester.view.reset);
        if (liquid) {
          KitGlassShader.program.value = await tester.runAsync(
            () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
          );
        } else {
          KitGlassShader.debugSupportedOverride = false;
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: light ? AppTheme.light() : AppTheme.dark(),
              home: const KitEffectsScope(
                effects: KitEffects.defaults,
                child: _Shell(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await then(tester);
        await writePng('$_out/$name.png', await capturePng(tester, boundary));
      });
    }
  }
}
