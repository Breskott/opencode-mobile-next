import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/desktop/desktop_interaction.dart';
import 'package:opencode_mobile/ui/kit/kit_layout.dart';
import 'package:opencode_mobile/ui/screens/files_screen.dart';
import 'package:opencode_mobile/ui/widgets/markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FilesApi extends OpenCodeApi {
  _FilesApi() : super(baseUrl: 'http://localhost');

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [
    FileNode(name: 'lib', path: 'lib', isDir: true),
    FileNode(name: 'main.dart', path: 'main.dart', isDir: false),
  ];
}

Future<ConnectionController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ConnectionController(ProfileStore(prefs: prefs))
    ..api = _FilesApi()
    ..status = StreamStatus.connected;
}

/// A widget test that runs with the platform reported as Linux desktop. The
/// override must be cleared inside the body: flutter_test asserts no
/// foundation debug variable outlives the test, so tearDown runs too late.
void desktopTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _linkHost() => MaterialApp(
  scrollBehavior: const AppScrollBehavior(),
  home: Scaffold(
    body: MarkdownFileLinks(
      validate: (_) async => true,
      open: (_) {},
      child: const MarkdownText('See `lib/a/b.dart` for details.'),
    ),
  ),
);

Future<MouseCursor?> _cursorOver(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
  return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  desktopTest('a live file link takes the click cursor', (tester) async {
    await tester.pumpWidget(_linkHost());
    await tester.pumpAndSettle();

    final cursor = await _cursorOver(
      tester,
      find.byKey(const Key('path-link-lib/a/b.dart')),
    );
    expect(cursor, SystemMouseCursors.click);
  });

  // KitMarkdown (79d941e4) draws file links for every host: a mouse is a
  // fine pointer wherever it is (kit-v2 §8.1 KitLayout.finePointer:
  // desktop, or a mouse seen by MouseTracker), so a mouse on Android gets
  // the same click cursor as on a PC, and touch never sees a cursor at all.
  testWidgets('a mouse on Android also takes the click cursor on a file link', (
    tester,
  ) async {
    await tester.pumpWidget(_linkHost());
    await tester.pumpAndSettle();

    final cursor = await _cursorOver(
      tester,
      find.byKey(const Key('path-link-lib/a/b.dart')),
    );
    expect(cursor, SystemMouseCursors.click);
  });

  desktopTest('an editable field still reports the text cursor', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final cursor = await _cursorOver(tester, find.byType(TextField));
    expect(cursor, SystemMouseCursors.text);
  });

  desktopTest('a ListTile row reports the click cursor and hovers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListTile(title: const Text('row'), onTap: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cursor = await _cursorOver(tester, find.byType(ListTile));
    expect(cursor, SystemMouseCursors.click);
    // InkWell paints a hover overlay while the pointer is inside it.
    expect(find.byType(InkWell), findsOneWidget);
  });

  desktopTest('the scroll wheel scrolls a list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: 40, child: Text('row $index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(ListView)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 320)));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  // Files is a KitScreen.twoPane since its kit rebuild (6f21d378): the list
  // pane sits at KitLayout.paneListWidth with one hairline seam, the same
  // on every platform (kit-v2 §8.2); the Files-only drag splitter
  // ('files-split-handle') went with it.
  Future<void> pumpWideFiles(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final connection = await _controller();
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(body: FilesScreen(controller: connection)),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectKitPanes(WidgetTester tester) {
    final list = tester.getRect(find.byKey(const ValueKey('files-list-pane')));
    final detail = tester.getRect(
      find.byKey(const ValueKey('files-detail-pane')),
    );
    expect(list.width, KitLayout.paneListWidth);
    // One hairline between the panes, not a grab strip.
    expect(detail.left - list.right, inInclusiveRange(0.5, 1));
    expect(find.byKey(const ValueKey('files-split-handle')), findsNothing);
  }

  desktopTest('the Files panes keep the kit list width with a hairline seam', (
    tester,
  ) async {
    await pumpWideFiles(tester);
    expectKitPanes(tester);
    final seam = Offset(
      tester.getRect(find.byKey(const ValueKey('files-list-pane'))).right,
      400,
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(seam);
    await tester.pumpAndSettle();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      isNot(SystemMouseCursors.resizeColumn),
    );
  });

  testWidgets('android keeps the plain Files hairline divider', (tester) async {
    await pumpWideFiles(tester);
    expectKitPanes(tester);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  desktopTest('mouse drag selects text rather than scrolling the list', (
    tester,
  ) async {
    // Mouse is deliberately absent from dragDevices: drag-to-scroll would
    // take the gesture desktop users select transcript text with.
    expect(
      const AppScrollBehavior().dragDevices.contains(PointerDeviceKind.mouse),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
