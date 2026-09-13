// Deterministic captures for progressive workspace disclosure (2026-09-13): the
// Workspace tab inside the real shell, light and dark, at 390dp/1x,
// 320dp/2x and 320dp/2.5x, plus a hyphenated long project name and the
// scrolled end of the list at 320dp/2.5x.
//
// Real fonts are loaded, so unlike test/workspace_stable_layout_test.dart
// the assertions here are about painted text: the project name and the
// primary action never fall back to an ellipsis at any of these sizes.
//
// Run: flutter test --concurrency=1 tool/capture/calm_workspace_test.dart
// Output: docs/qa/calm-workspace-2026-09-13/*.png
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';

import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

/// The shopfront project under a different display name.
class _NamedRepository extends CaptureRepository {
  _NamedRepository(this.name);

  final String name;

  @override
  Future<List<WorkspaceProject>> listProjects() async => [
    WorkspaceProject(
      id: 'project_shopfront',
      name: name,
      directory: projectDirectory,
      worktrees: const [],
      updatedAt: 1,
    ),
  ];
}

const _scenarios = [
  (width: 390.0, scale: 1.0, name: 'shopfront', end: false),
  (width: 320.0, scale: 2.0, name: 'shopfront', end: false),
  (width: 320.0, scale: 2.5, name: 'shopfront', end: false),
  (width: 320.0, scale: 2.5, name: 'shopfront-mobile-checkout', end: false),
  (width: 320.0, scale: 2.5, name: 'shopfront', end: true),
];

/// Fails when the paragraph behind the [text] widget had to cut its text.
/// [text] must match one `Text`; its own RichText is the paragraph (icons
/// paint through RichText too, so a wider finder would be ambiguous).
void _expectPaintedWhole(WidgetTester tester, Finder text, String what) {
  expect(text, findsOneWidget, reason: what);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse, reason: '$what was cut');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final light in [false, true]) {
    for (final scenario in _scenarios) {
      final theme = light ? 'light' : 'dark';
      final suffix =
          '${scenario.name == 'shopfront' ? '' : '-long-name'}'
          '${scenario.end ? '-end' : ''}';
      final name =
          'workspace-$theme-${scenario.width.toInt()}-'
          '${scenario.scale}x$suffix';
      testWidgets('calm workspace $name', (tester) async {
        const secure = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            secure,
            null,
          ),
        );
        tester.view.physicalSize = Size(scenario.width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = await setupCapturePreferences();
        final controller = await captureController(
          prefs: prefs,
          repository: _NamedRepository(scenario.name),
        );
        final boundary = GlobalKey();
        try {
          await tester.pumpWidget(
            captureApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: const HomeScreen(initialTab: 0),
                ),
              ),
              boundaryKey: boundary,
              controller: controller,
              light: light,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          if (scenario.end) {
            await tester.drag(
              find.byKey(const PageStorageKey<String>('workspace-scroll')),
              const Offset(0, -3000),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          }
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(tester.takeException(), isNull);

          if (!scenario.end) {
            _expectPaintedWhole(
              tester,
              find.byKey(const ValueKey('current-project-name')),
              'project name "${scenario.name}"',
            );
          }
          _expectPaintedWhole(tester, find.text('New session'), 'New session');
          if (scenario.width == 320 && scenario.scale == 2.5) {
            // The label cannot share a row with the icon here, so the
            // isolated action is a labelled button above the primary.
            expect(find.text('Isolated task'), findsOneWidget);
          }
          expect(
            find.byKey(const ValueKey('manage-project-entry')),
            findsNothing,
          );
          expect(find.textContaining(r'$0.42'), findsNothing);
          expect(find.text('Review status unknown'), findsNothing);
          await writePng(
            'docs/qa/calm-workspace-2026-09-13/$name.png',
            await capturePng(tester, boundary, pixelRatio: 1),
          );
          if (!scenario.end && scenario.name == 'shopfront') {
            await tester.tap(
              find.byKey(const ValueKey('current-project-entry')),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            expect(find.text('Review status unknown'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('manage-project-entry')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await writePng(
              'docs/qa/calm-workspace-2026-09-13/$name-project-details.png',
              await capturePng(tester, boundary, pixelRatio: 1),
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          await tester.pump();
        }
      });
    }
  }
}
