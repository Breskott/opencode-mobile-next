// Revamp unit screen-work-1: the Work tab rebuilt from kit parts. These
// tests cover what the unit's acceptance and map records ask for:
// archive is one path from the swipe and the menu (act, then Undo, the
// server told only when the window closes); delete, share and rename keep
// their failures in place; the folder chooser's failure says so in its
// title; and from expanded Work is two panes, a row opening beside the list.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart'
    show CaptureApi, SeededProfileStore, captureApp;
import '../support/work_tab_fixture.dart';

class _Repository extends WorkRepository {
  final archived = <String>[];
  final shared = <String>[];
  String? shareLink = 'https://opncd.ai/s/abc';

  @override
  Future<void> archiveSession(String id) async => archived.add(id);

  @override
  Future<String?> shareSession(String id) async {
    shared.add(id);
    return shareLink;
  }

  @override
  Future<void> unshareSession(String id) async {}
}

class _Controller extends WorkController {
  _Controller(super.store);

  final deleted = <String>[];
  final renamed = <String, String>{};
  Object? deleteError;
  Object? renameError;

  @override
  Future<void> deleteSession(String sessionID) async {
    if (deleteError case final error?) throw error;
    deleted.add(sessionID);
    sessionsById.remove(sessionID);
    notifyListeners();
  }

  @override
  Future<void> renameSession(String sessionID, String title) async {
    if (renameError case final error?) throw error;
    renamed[sessionID] = title;
  }
}

Future<_Controller> _controller({
  Map<String, Session>? sessions,
  _Repository? repository,
  String? directory = workCurrent,
  bool savedLocation = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SeededProfileStore(
    prefs: prefs,
    seeded: [
      ServerProfile(
        id: 'phone',
        name: 'Laptop',
        baseUrl: 'http://127.0.0.1:4096',
      ),
    ],
  );
  if (savedLocation) await store.setLocation('phone', directory: workCurrent);
  return _Controller(store)
    ..api = CaptureApi()
    ..repository = repository ?? _Repository()
    ..status = StreamStatus.connected
    ..directory = directory
    ..sessionsById = Map.of(
      sessions ??
          {
            'a': workSession('a', 'Fix the checkout test', ago: workMinute),
            'b': workSession('b', 'Explain the ledger', ago: 9 * workMinute),
          },
    );
}

void _mockSecureStorage(WidgetTester tester) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
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
}

Future<void> _pump(
  WidgetTester tester,
  _Controller controller, {
  Size size = const Size(412, 915),
}) async {
  _mockSecureStorage(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    captureApp(
      home: Scaffold(body: WorkspaceScreen(controller: controller)),
      boundaryKey: GlobalKey(),
      controller: controller,
      routes: {
        '/chat/a': (_) => const Scaffold(body: Text('Chat page a')),
        '/chat/b': (_) => const Scaffold(body: Text('Chat page b')),
      },
    ),
  );
  await _frames(tester);
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _dispose(WidgetTester tester, _Controller controller) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(KitUndo.window);
  controller.dispose();
}

Future<void> _openMenu(WidgetTester tester, String title) async {
  await tester.longPress(find.text(title));
  await _frames(tester, 4);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('archive is one path from the menu and the swipe (P3.12)', () {
    testWidgets('the menu archives at once with Undo and no confirmation; '
        'the server hears of it only when the window closes', (tester) async {
      final repository = _Repository();
      final controller = await _controller(repository: repository);
      await _pump(tester, controller);

      await _openMenu(tester, 'Fix the checkout test');
      await tester.tap(find.text('Archive'));
      await _frames(tester, 4);

      // No confirmation sheet: the act happens, Undo stands.
      expect(find.text('Archive conversation?'), findsNothing);
      expect(find.text('Fix the checkout test'), findsNothing);
      expect(find.text('Archived “Fix the checkout test”'), findsOneWidget);
      expect(repository.archived, isEmpty);

      await tester.pump(KitUndo.window);
      await _frames(tester, 4);
      expect(repository.archived, ['a']);
      await _dispose(tester, controller);
    });

    testWidgets('Undo brings the row back and the server is never told', (
      tester,
    ) async {
      final repository = _Repository();
      final controller = await _controller(repository: repository);
      await _pump(tester, controller);

      await _openMenu(tester, 'Explain the ledger');
      await tester.tap(find.text('Archive'));
      await _frames(tester, 4);
      expect(find.text('Explain the ledger'), findsNothing);
      await tester.tap(find.text('Undo'));
      await _frames(tester, 4);
      expect(find.text('Explain the ledger'), findsOneWidget);

      await tester.pump(KitUndo.window);
      await _frames(tester, 2);
      expect(repository.archived, isEmpty);
      await _dispose(tester, controller);
    });

    testWidgets('a swipe runs the same act, never a confirmation', (
      tester,
    ) async {
      final repository = _Repository();
      final controller = await _controller(repository: repository);
      await _pump(tester, controller);

      await tester.drag(
        find.byKey(const ValueKey('session-dismiss-a')),
        const Offset(-400, 0),
      );
      await _frames(tester, 6);
      expect(find.text('Archive conversation?'), findsNothing);
      expect(find.text('Archived “Fix the checkout test”'), findsOneWidget);
      expect(find.text('Fix the checkout test'), findsNothing);
      await tester.pump(KitUndo.window);
      await _frames(tester, 4);
      expect(repository.archived, ['a']);
      await _dispose(tester, controller);
    });

    testWidgets('without archive on this server there is no swipe and no '
        'Archive item', (tester) async {
      final controller = await _controller();
      controller.api = _NoArchiveApi();
      await _pump(tester, controller);
      expect(find.byKey(const ValueKey('session-dismiss-a')), findsNothing);
      await _openMenu(tester, 'Fix the checkout test');
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
      await _dispose(tester, controller);
    });
  });

  group('acts that confirm keep failures in place', () {
    testWidgets('delete of a shared conversation says its link stops working, '
        'and a failure stays in the confirmation', (tester) async {
      final controller =
          await _controller(
              sessions: {
                'a': Session(
                  id: 'a',
                  title: 'Fix the checkout test',
                  directory: workCurrent,
                  shareUrl: 'https://opncd.ai/s/abc',
                ),
              },
            )
            ..deleteError = Exception('server said no');
      await _pump(tester, controller);

      await _openMenu(tester, 'Fix the checkout test');
      await tester.tap(find.text('Delete'));
      await _frames(tester, 6);
      expect(find.text('Delete conversation?'), findsOneWidget);
      expect(find.text('Its shared link stops working.'), findsOneWidget);

      final confirm = find.byKey(
        const ValueKey('workspace-delete-confirm-button'),
      );
      await tester.tap(confirm);
      await _frames(tester, 6);
      // Still open, with the failure said inside it (DATA-14).
      expect(find.text('Delete conversation?'), findsOneWidget);
      expect(controller.deleted, isEmpty);

      controller.deleteError = null;
      await tester.tap(confirm);
      await _frames(tester, 8);
      expect(controller.deleted, ['a']);
      expect(find.text('Delete conversation?'), findsNothing);
      await _dispose(tester, controller);
    });

    testWidgets('share says the link is copied, then copies it', (
      tester,
    ) async {
      final repository = _Repository();
      final controller = await _controller(repository: repository);
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
      await _pump(tester, controller);

      await _openMenu(tester, 'Fix the checkout test');
      await tester.tap(find.text('Share'));
      await _frames(tester, 6);
      expect(find.text('Share this conversation?'), findsOneWidget);
      expect(
        find.text('The link is copied once sharing starts.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-share-confirm-button')),
      );
      await _frames(tester, 8);
      expect(repository.shared, ['a']);
      expect(copied, 'https://opncd.ai/s/abc');
      await _dispose(tester, controller);
    });

    testWidgets('rename: a failure stays under the field, success closes', (
      tester,
    ) async {
      final controller = await _controller()
        ..renameError = Exception('title rejected');
      await _pump(tester, controller);

      await _openMenu(tester, 'Fix the checkout test');
      await tester.tap(find.text('Rename'));
      await _frames(tester, 6);
      expect(find.text('Rename conversation'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Checkout fix');
      await tester.tap(find.text('Save'));
      await _frames(tester, 6);
      expect(find.text('Rename conversation'), findsOneWidget);
      expect(controller.renamed, isEmpty);

      controller.renameError = null;
      await tester.tap(find.text('Save'));
      await _frames(tester, 8);
      expect(controller.renamed, {'a': 'Checkout fix'});
      expect(find.text('Rename conversation'), findsNothing);
      await _dispose(tester, controller);
    });
  });

  testWidgets('the project sheet is titled with the project and its server, '
      'offers New project, and keeps the path under Details', (tester) async {
    final controller = await _controller();
    await _pump(tester, controller);
    await tester.tap(find.byKey(const ValueKey('current-project-entry')));
    await _frames(tester, 6);
    final sheet = find.byKey(const ValueKey('workspace-context-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('FinanceHub3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('On ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining(workCurrent)),
      findsNothing,
    );
    await tester.tap(find.text('Details'));
    await _frames(tester, 4);
    expect(
      find.descendant(of: sheet, matching: find.textContaining(workCurrent)),
      findsOneWidget,
    );
    await _dispose(tester, controller);
  });

  testWidgets('a project list that failed says so in the chooser title, '
      'with Try again first', (tester) async {
    final repository = _FailingRepository();
    final controller = await _controller(
      repository: repository,
      directory: null,
      savedLocation: false,
    );
    await _pump(tester, controller);
    expect(find.byKey(const ValueKey('workspace-folder-chooser')), findsOne);
    expect(find.text("Couldn't load your projects"), findsOneWidget);
    expect(find.text('Choose a project folder'), findsNothing);
    final retry = find.byKey(const ValueKey('workspace-chooser-retry'));
    expect(retry, findsOneWidget);
    repository.fail = false;
    await tester.tap(retry);
    await _frames(tester, 6);
    expect(repository.lists, 2);
    await _dispose(tester, controller);
  });

  group('two panes from expanded (C37)', () {
    testWidgets('at 1280x800 the list sits beside an empty detail, and a row '
        'opens beside the list instead of pushing a page', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller, size: const Size(1280, 800));
      expect(find.byKey(const ValueKey('work-list-pane')), findsOneWidget);
      expect(find.text('Choose a conversation'), findsOneWidget);

      await tester.tap(find.text('Explain the ledger'));
      await _frames(tester, 6);
      expect(find.text('Chat page b'), findsNothing);
      expect(find.byKey(const ValueKey('work-detail-b')), findsOneWidget);
      expect(find.text('Choose a conversation'), findsNothing);
      await _dispose(tester, controller);
    });

    testWidgets('at 412x915 a row still opens its page', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);
      expect(find.byKey(const ValueKey('work-list-pane')), findsNothing);
      await tester.tap(find.text('Explain the ledger'));
      await _frames(tester, 6);
      expect(find.text('Chat page b'), findsOneWidget);
      await _dispose(tester, controller);
    });
  });
}

class _NoArchiveApi extends CaptureApi {
  @override
  ServerCapabilities get capabilities =>
      ServerCapabilities(sessionArchive: false);
}

class _FailingRepository extends _Repository {
  bool fail = true;
  int lists = 0;

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    lists++;
    if (fail) throw Exception('connection reset');
    return super.listProjects();
  }
}
