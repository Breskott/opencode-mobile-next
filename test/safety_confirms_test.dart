// Interrupting actions ask before they act (UX plan rule 6). Each test proves
// both halves: nothing happens when the sheet is cancelled or dismissed, and
// the action runs once it is confirmed.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api({this.sessionList = const []}) : super(baseUrl: 'http://localhost');

  final List<Session> sessionList;

  @override
  Future<List<Session>> sessions() async => sessionList;

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => [];
}

class _Repository implements ProductRepository {
  final unshared = <String>[];

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<void> unshareSession(String id) async => unshared.add(id);

  @override
  Future<List<WorkspaceProject>> listProjects() async => const [
    WorkspaceProject(
      id: 'p1',
      name: 'p1',
      directory: '/tmp/p1',
      worktrees: [],
      updatedAt: 1,
    ),
  ];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => [];

  @override
  Future<List<TerminalProcess>> listTerminals() async => [];

  @override
  Future<CatalogSnapshot> loadCatalog() async =>
      const CatalogSnapshot(providers: [], models: [], agents: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends ProfileStore {
  _Store({required super.prefs});

  final _profile = ServerProfile(
    id: 'local',
    name: 'Studio box',
    baseUrl: 'http://localhost:4096',
  );

  @override
  List<ServerProfile> get profiles => [_profile];

  @override
  String? get activeId => _profile.id;
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  int disconnects = 0;

  @override
  Future<void> disconnect({bool keepActive = false, bool silent = false}) {
    disconnects += 1;
    return super.disconnect(keepActive: keepActive, silent: silent);
  }
}

Future<_Controller> _controller({
  List<Session> sessions = const [],
  _Repository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return _Controller(_Store(prefs: prefs))
    ..api = _Api(sessionList: sessions)
    ..repository = repository ?? _Repository()
    ..status = StreamStatus.connected;
}

Widget _app(Widget home, {ConnectionController? provided}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {'/servers': (_) => const Scaffold(body: Text('servers-route'))},
    home: home,
  );
  if (provided == null) return app;
  return ProviderScope(
    overrides: [connProvider.overrideWithValue(provided)],
    child: app,
  );
}

const _sheet = ValueKey('disconnect-confirm-sheet');
const _confirm = ValueKey('confirm-disconnect');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Disconnect', () {
    Future<void> openOverflowDisconnect(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
    }

    testWidgets('shell overflow asks first and stays put on cancel', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(const HomeScreen(), provided: controller));
      await tester.pumpAndSettle();

      await openOverflowDisconnect(tester);
      expect(find.byKey(_sheet), findsOneWidget);
      expect(find.text('Disconnect from Studio box?'), findsOneWidget);
      expect(find.textContaining('No queued prompts.'), findsOneWidget);
      expect(find.textContaining('No unsent drafts.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 0);
      expect(controller.status, StreamStatus.connected);
      expect(find.text('servers-route'), findsNothing);

      // Dismissing by the scrim is also a "no".
      await openOverflowDisconnect(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(_sheet), findsNothing);
      expect(controller.disconnects, 0);
    });

    testWidgets('shell overflow disconnects once confirmed', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(const HomeScreen(), provided: controller));
      await tester.pumpAndSettle();

      await openOverflowDisconnect(tester);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 1);
      expect(find.text('servers-route'), findsOneWidget);
    });

    Future<void> tapSettingsDisconnect(WidgetTester tester) async {
      final button = find.byKey(const ValueKey('settings-disconnect'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('Settings shows the same sheet and honours cancel', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
      await tester.pumpAndSettle();

      await tapSettingsDisconnect(tester);
      expect(find.byKey(_sheet), findsOneWidget);
      expect(find.text('Disconnect from Studio box?'), findsOneWidget);
      expect(find.textContaining('No queued prompts.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 0);
      expect(find.text('servers-route'), findsNothing);
    });

    testWidgets('Settings disconnects once confirmed', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(SettingsScreen(controller: controller)));
      await tester.pumpAndSettle();

      await tapSettingsDisconnect(tester);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(controller.disconnects, 1);
      expect(find.text('servers-route'), findsOneWidget);
    });
  });

  group('Workspace Stop sharing', () {
    final shared = Session(
      id: 's1',
      title: 'Ship it',
      shareUrl: 'https://share.example/s1',
      time: SessionTime(created: 1),
    );

    Future<_Repository> pumpWorkspace(WidgetTester tester) async {
      // The share flow reads the clipboard channel on some paths; keep it
      // answered so nothing hangs.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final repository = _Repository();
      final controller = await _controller(
        sessions: [shared],
        repository: repository,
      );
      controller.directory = '/tmp/p1';
      addTearDown(controller.dispose);
      await controller.refreshSessions();
      await tester.pumpWidget(
        _app(Scaffold(body: WorkspaceScreen(controller: controller))),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> expectConfirmGates(
      WidgetTester tester,
      _Repository repository,
      Future<void> Function() choose,
    ) async {
      await choose();
      expect(
        find.byKey(const ValueKey('stop-sharing-confirm-sheet')),
        findsOneWidget,
      );
      expect(
        find.textContaining('The link stops working for anyone who has it.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep sharing'));
      await tester.pumpAndSettle();
      expect(repository.unshared, isEmpty);

      await choose();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(repository.unshared, isEmpty);

      await choose();
      await tester.tap(find.byKey(const ValueKey('confirm-stop-sharing')));
      await tester.pumpAndSettle();
      expect(repository.unshared, ['s1']);
    }

    testWidgets('session actions menu asks first', (tester) async {
      final repository = await pumpWorkspace(tester);
      await expectConfirmGates(tester, repository, () async {
        await tester.tap(find.byTooltip('Session actions').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stop sharing'));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('desktop context menu asks first', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final repository = await pumpWorkspace(tester);
        await expectConfirmGates(tester, repository, () async {
          await tester.tapAt(
            tester.getCenter(find.text('Ship it')),
            buttons: kSecondaryMouseButton,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('session-menu-share')));
          await tester.pumpAndSettle();
        });
      } finally {
        // flutter_test asserts no debug override outlives the test body.
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
