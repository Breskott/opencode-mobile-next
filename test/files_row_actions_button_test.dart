import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/files_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UX plan 5.8 item 2: the file row's actions (Attach, Open review, Copy
/// path, ...) used to be reachable only by a long press or a right click.
/// The trailing button is the visible door to the very same sheet.
class _FilesApi extends OpenCodeApi {
  _FilesApi() : super(baseUrl: 'http://localhost');

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [
    FileNode(name: 'lib', path: 'lib', isDir: true),
    FileNode(name: 'README.md', path: 'README.md', isDir: false),
  ];

  @override
  Future<List<String>> findFile(String query) async => const [];

  @override
  Future<FileContent> fileContent(String path) async =>
      const FileContent('content');

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};
}

Future<ConnectionController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ConnectionController(ProfileStore(prefs: prefs))
    ..api = _FilesApi()
    ..status = StreamStatus.connected;
}

List<String> _sheetActionKeys(WidgetTester tester) => [
  for (final key in const [
    'file-menu-open',
    'file-menu-attach',
    'file-menu-reference',
    'file-menu-review',
    'file-menu-copy-path',
  ])
    if (find.byKey(ValueKey(key)).evaluate().isNotEmpty) key,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester, {
    ProjectFileAttachment? onAttachFile,
  }) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilesScreen(controller: controller, onAttachFile: onAttachFile),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every file and folder row shows a labeled actions button', (
    tester,
  ) async {
    await pump(tester);

    for (final (path, name) in const [
      ('lib', 'lib'),
      ('README.md', 'README.md'),
    ]) {
      final button = find.byKey(ValueKey('project-file-actions-$path'));
      expect(button, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('project-file-$path')),
          matching: button,
        ),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(button).tooltip, 'Actions for $name');
      // The product's 48dp touch floor, in both directions.
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the button opens the same sheet as the long press', (
    tester,
  ) async {
    await pump(tester, onAttachFile: (_, _) async {});

    await tester.longPress(find.text('README.md'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('file-row-actions-sheet')),
      findsOneWidget,
    );
    final fromGesture = _sheetActionKeys(tester);
    expect(fromGesture, contains('file-menu-attach'));
    expect(fromGesture, contains('file-menu-copy-path'));
    Navigator.of(
      tester.element(find.byKey(const ValueKey('file-row-actions-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('file-row-actions-sheet')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('project-file-actions-README.md')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('file-row-actions-sheet')),
      findsOneWidget,
    );
    expect(_sheetActionKeys(tester), fromGesture);
  });

  testWidgets(
    'an action chosen from the button runs, and the row tap is kept',
    (tester) async {
      String? attached;
      await pump(tester, onAttachFile: (path, _) async => attached = path);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('project-file-actions-README.md')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('file-menu-attach')));
      await tester.pumpAndSettle();
      expect(attached, 'README.md');

      // A folder has no other visible Copy path; the button supplies it.
      await tester.tap(find.byKey(const ValueKey('project-file-actions-lib')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('file-menu-copy-path')));
      await tester.pumpAndSettle();
      expect(copied, 'lib');

      // Tapping the button did not open the file or enter the folder.
      expect(
        find.byKey(const ValueKey('project-file-README.md')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('project-file-lib')), findsOneWidget);
    },
  );
}
