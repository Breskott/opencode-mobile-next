// Work tab cleanup (docs/design/work-tab-cleanup-2026-09-24.md): the states
// the owner's phone screenshots showed, as widget tests.
//
// This file only uses what the Work tab had before the cleanup (the screen,
// the shell, the saved-server card and controller state), so it compiles
// against the old code too: each test here that names a spec item fails
// there (see docs/qa/work-tab-cleanup-2026-09-24/README.md). The tests of
// the new modules themselves are in work_tab_status_line_test.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/saved_server_connection_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart'
    show CaptureApi, CaptureController, CaptureRepository, SeededProfileStore;

const _root = '/root/projects';
const _current = '$_root/FinanceHub3';
const _other = '$_root/FinanceHub';
const _third = '$_root/Tradebook';

final _now = DateTime.now().millisecondsSinceEpoch;
const _minute = 60 * 1000;

Session _session(
  String id,
  String title, {
  String directory = _current,
  int ago = 5 * _minute,
  int? idle,
}) => Session(
  id: id,
  title: title,
  directory: directory,
  time: SessionTime(
    created: _now - ago - _minute,
    updated: _now - ago,
    idle: idle,
  ),
);

class _Repository extends CaptureRepository implements SessionReadStateGateway {
  Completer<void>? holdProjects;
  List<WorkspaceProject>? projects;
  final views = <String>[];

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    await holdProjects?.future;
    return List.of(
      projects ??
          const [
            WorkspaceProject(
              id: 'p-fh3',
              name: 'FinanceHub3',
              directory: _current,
              worktrees: [],
              updatedAt: 3,
            ),
            WorkspaceProject(
              id: 'p-fh',
              name: 'FinanceHub',
              directory: _other,
              worktrees: [],
              updatedAt: 2,
            ),
          ],
    );
  }

  @override
  Future<void> viewSession(String sessionID, int idle) async =>
      views.add(sessionID);
}

class _Controller extends CaptureController {
  _Controller(super.store);

  List<ProfileLocation> recents = const [];
  List<ElsewhereConversation> elsewhere = const [];
  bool holdSelection = false;
  final selected = <String?>[];

  @override
  List<ProfileLocation> get recentLocations => recents;

  @override
  Future<List<ElsewhereConversation>> conversationsElsewhere({
    int limit = 6,
  }) async => elsewhere;

  @override
  Future<void> refreshSessions() async {}

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;

  @override
  Future<void> selectInitialLocation({
    String? directory,
    String? workspace,
  }) async {
    selected.add(directory);
    if (holdSelection) await Completer<void>().future;
  }

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    selected.add(directory);
    if (holdSelection) await Completer<void>().future;
    this.directory = directory;
    notifyListeners();
  }
}

Future<_Controller> _controller({
  String? directory = _current,
  StreamStatus status = StreamStatus.connected,
  Map<String, Session> sessions = const {},
  bool savedLocation = true,
  String baseUrl = 'http://127.0.0.1:4096',
  _Repository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SeededProfileStore(
    prefs: prefs,
    seeded: [
      ServerProfile(
        id: 'phone',
        name: 'This device (Termux)',
        baseUrl: baseUrl,
      ),
    ],
  );
  if (savedLocation) await store.setLocation('phone', directory: _current);
  return _Controller(store)
    ..api = CaptureApi()
    ..repository = repository ?? _Repository()
    ..status = status
    ..directory = directory
    ..sessionsById = Map.of(sessions)
    ..busySessions = <String>{};
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

void _viewport(WidgetTester tester, {Size size = const Size(412, 915)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text('route ${settings.name}')),
  ),
  home: home,
);

Future<void> _pumpWork(WidgetTester tester, _Controller controller) async {
  await tester.pumpWidget(
    _app(Scaffold(body: WorkspaceScreen(controller: controller))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpShell(
  WidgetTester tester,
  _Controller controller, {
  double scale = 1,
}) async {
  _mockSecureStorage(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connProvider.overrideWithValue(controller)],
      child: _app(const HomeScreen(initialTab: 0), scale: scale),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _dispose(WidgetTester tester, _Controller controller) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  await tester.pump();
}

Finder get _chooser => find.byKey(const ValueKey('workspace-folder-chooser'));

Finder _textContaining(String part) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data ?? widget.textSpan?.toPlainText() ?? '').contains(part),
  description: 'text containing "$part"',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('item 1: restoring the saved project', () {
    testWidgets('no folder chooser; the header names the saved project', (
      tester,
    ) async {
      _viewport(tester);
      final controller = await _controller(directory: null)
        ..holdSelection = true;
      await _pumpWork(tester, controller);

      expect(_chooser, findsNothing);
      expect(find.text('Choose a project folder'), findsNothing);
      expect(find.text('Create a new folder'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('current-project-name')))
            .data,
        'FinanceHub3',
      );
      // The saved one is opened, never another project.
      expect(controller.selected, [_current]);
      await _dispose(tester, controller);
    });

    testWidgets('a project picked for a fresh connection opens without the '
        'chooser flashing first', (tester) async {
      _viewport(tester);
      final controller =
          await _controller(directory: null, savedLocation: false)
            ..holdSelection = true;
      await _pumpWork(tester, controller);

      expect(_chooser, findsNothing);
      expect(controller.selected, [_current]);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('current-project-name')))
            .data,
        'FinanceHub3',
      );
      await _dispose(tester, controller);
    });

    testWidgets('the chooser shows once there really is no project', (
      tester,
    ) async {
      _viewport(tester);
      final controller = await _controller(
        directory: null,
        savedLocation: false,
        repository: _Repository()..projects = const [],
      );
      await _pumpWork(tester, controller);
      expect(_chooser, findsOneWidget);
      await _dispose(tester, controller);
    });
  });

  testWidgets('item 2: the project is named from the first frame, before the '
      'project list arrives', (tester) async {
    _viewport(tester);
    final controller = await _controller(
      repository: _Repository()..holdProjects = Completer<void>(),
    );
    await _pumpWork(tester, controller);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('current-project-name')))
          .data,
      'FinanceHub3',
    );
    await _dispose(tester, controller);
  });

  group('items 3 and 4: first load', () {
    testWidgets('one loading bar, skeleton rows, and nothing contradicting '
        'them', (tester) async {
      _viewport(tester);
      final controller =
          await _controller(
              repository: _Repository()..holdProjects = Completer<void>(),
            )
            ..sessionsLoading = true;
      await _pumpWork(tester, controller);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('kit-skeleton-rows')), findsOneWidget);
      expect(
        find.text('No recent conversations in loaded results'),
        findsNothing,
      );
      expect(find.textContaining('Older conversations may'), findsNothing);
      expect(find.text('Loading conversations…'), findsNothing);
      expect(find.text('Load more conversations'), findsNothing);
      expect(find.text('Archived conversations'), findsNothing);
      await _dispose(tester, controller);
    });

    testWidgets('a reconnect on the Work tab shows the one bar, not the '
        'shell banner', (tester) async {
      _viewport(tester);
      final controller = await _controller(
        status: StreamStatus.reconnecting,
        sessions: {'a': _session('a', 'Reconcile the ledger')},
      );
      await _pumpShell(tester, controller);
      expect(
        find.byKey(const ValueKey('connection-status-banner')),
        findsNothing,
      );
      final work = find.byType(WorkspaceScreen);
      expect(
        find.descendant(
          of: work,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: work,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await _dispose(tester, controller);
    });

    testWidgets('the empty state shows only once the load has finished', (
      tester,
    ) async {
      _viewport(tester);
      final controller = await _controller();
      await _pumpWork(tester, controller);
      expect(find.byKey(const ValueKey('work-empty-teaching')), findsOneWidget);
      expect(find.byKey(const ValueKey('kit-skeleton-rows')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Archived conversations'), findsNothing);
      await _dispose(tester, controller);
    });
  });

  testWidgets('item 5: an unreviewed result is marked in its own row; no '
      'separate card', (tester) async {
    _viewport(tester);
    final controller = await _controller(
      sessions: {
        'done': _session(
          'done',
          'Reconcile the March ledger import',
          idle: _now - 2 * _minute,
        ),
      },
    );
    await _pumpWork(tester, controller);
    expect(find.text('Unreviewed work'), findsNothing);
    expect(find.textContaining('Dismissing keeps'), findsNothing);
    expect(_textContaining('Unreviewed'), findsOneWidget);
    await _dispose(tester, controller);
  });

  group('item 8: other projects', () {
    testWidgets('each other project is listed once', (tester) async {
      _viewport(tester);
      final controller = await _controller()
        ..recents = const [
          ProfileLocation(directory: _current),
          ProfileLocation(directory: _other),
          ProfileLocation(directory: _third),
        ]
        ..elsewhere = [
          ElsewhereConversation(
            session: _session(
              'e1',
              'building modern financehub',
              directory: _other,
            ),
            directory: _other,
            running: true,
          ),
          ElsewhereConversation(
            session: _session('e2', 'Sales research', directory: _third),
            directory: _third,
            running: false,
          ),
        ];
      await _pumpWork(tester, controller);
      await tester.pump(const Duration(milliseconds: 100));

      expect(_textContaining('Tradebook'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              RegExp(
                r'FinanceHub(?!3)',
              ).hasMatch(w.data ?? w.textSpan?.toPlainText() ?? ''),
        ),
        findsOneWidget,
      );
      // The current project is the header's, not an "other" one.
      expect(
        find.descendant(
          of: find.byKey(const Key('other-projects-panel')),
          matching: _textContaining('FinanceHub3'),
        ),
        findsNothing,
      );
      await _dispose(tester, controller);
    });

    testWidgets('at most three, then All projects', (tester) async {
      _viewport(tester, size: const Size(412, 1400));
      final controller = await _controller()
        ..recents = [
          const ProfileLocation(directory: _current),
          for (final name in ['A1', 'B2', 'C3', 'D4', 'E5'])
            ProfileLocation(directory: '$_root/$name'),
        ];
      await _pumpWork(tester, controller);
      for (final name in ['A1', 'B2', 'C3']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('D4'), findsNothing);
      expect(find.text('E5'), findsNothing);
      expect(find.text('All projects'), findsOneWidget);
      await _dispose(tester, controller);
    });
  });

  group('item 9: New conversation and the tab bar cover nothing', () {
    Map<String, Session> many() => {
      for (var i = 0; i < 16; i++)
        's$i': _session('s$i', 'Conversation $i', ago: (i + 1) * _minute),
    };

    /// Visible text of the list (clipped to the list's viewport) that
    /// overlaps [cover].
    List<String> underneath(WidgetTester tester, Rect cover) {
      final scroll = find.byKey(const PageStorageKey('workspace-scroll'));
      final viewport = tester.getRect(scroll);
      final hidden = <String>[];
      for (final element
          in find
              .descendant(of: scroll, matching: find.byType(Text))
              .evaluate()) {
        final box = element.renderObject;
        if (box is! RenderBox || !box.hasSize || !box.attached) continue;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final visible = rect.intersect(viewport);
        if (visible.isEmpty || visible.width <= 0 || visible.height <= 0) {
          continue;
        }
        final overlap = visible.intersect(cover);
        if (overlap.width > 0.5 && overlap.height > 0.5) {
          hidden.add((element.widget as Text).data ?? '(rich)');
        }
      }
      return hidden;
    }

    testWidgets('at rest and at the end of the list', (tester) async {
      _viewport(tester);
      final controller = await _controller(sessions: many());
      await _pumpShell(tester, controller);
      final button = tester.getRect(
        find.byKey(const ValueKey('workspace-quick-ask')),
      );
      final tabs = tester.getRect(find.byType(NavigationBar));
      expect(underneath(tester, button), isEmpty, reason: 'under the button');
      expect(underneath(tester, tabs), isEmpty, reason: 'under the tab bar');

      await tester.drag(
        find.byKey(const PageStorageKey('workspace-scroll')),
        const Offset(0, -5000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(underneath(tester, button), isEmpty, reason: 'end, button');
      expect(underneath(tester, tabs), isEmpty, reason: 'end, tab bar');
      // The last row is on screen and clear of both.
      final last = tester.getRect(find.text('Conversation 15'));
      expect(last.bottom, lessThanOrEqualTo(button.top));
      await _dispose(tester, controller);
    });
  });

  group('item 10: a server that does not answer', () {
    testWidgets('the Work tab says so after 8 s, with Try again and Restart', (
      tester,
    ) async {
      _viewport(tester);
      final controller = await _controller(
        status: StreamStatus.reconnecting,
        sessions: {'a': _session('a', 'Reconcile the ledger')},
      );
      await _pumpShell(tester, controller);
      expect(find.text("OpenCode on this phone isn't answering"), findsNothing);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text("OpenCode on this phone isn't answering"), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text("OpenCode on this phone isn't answering"),
        findsOneWidget,
      );
      // Restart is the way out the app cannot take alone; Try again is one
      // tap further, in the line's menu.
      expect(find.text('Restart'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kit-status-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Try again'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump(const Duration(milliseconds: 300));
      // Never a claim the app cannot back up.
      expect(find.textContaining('memory'), findsNothing);

      controller
        ..status = StreamStatus.connected
        ..notifyListeners();
      await tester.pump();
      expect(find.text("OpenCode on this phone isn't answering"), findsNothing);
      await _dispose(tester, controller);
    });

    testWidgets('the connecting card says so after 8 s and offers the ways '
        'out', (tester) async {
      _viewport(tester);
      var restarts = 0;
      var retries = 0;
      var changes = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SavedServerConnectionCard(
              profileName: 'This device (Termux)',
              baseUrl: 'http://127.0.0.1:4096',
              error: null,
              attempts: 1,
              supportsTermux: true,
              onChangeServer: () => changes++,
              onRetry: () => retries++,
              onStartPhoneServer: () => restarts++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 7));
      expect(find.text("OpenCode on this phone isn't answering"), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text("OpenCode on this phone isn't answering"),
        findsOneWidget,
      );
      expect(
        find.text('The app keeps trying in the background.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
      await tester.tap(find.text('Choose another server'));
      expect(changes, 1);
      await tester.tap(find.text('Restart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // A confirm first: a turn in progress stops.
      expect(find.textContaining('A running agent turn will stop'), findsOne);
      expect(restarts, 0);
      await tester.tap(
        find.byKey(const ValueKey('work-server-restart-confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(restarts, 1);
    });
  });

  testWidgets('text scale 2 at 320 dp: nothing overflows', (tester) async {
    _viewport(tester, size: const Size(320, 700));
    final controller =
        await _controller(
            status: StreamStatus.reconnecting,
            sessions: {
              'done': _session(
                'done',
                'Reconcile the March ledger import',
                idle: _now - 2 * _minute,
              ),
              'b': _session('b', 'Explain the budget rules engine'),
            },
          )
          ..recents = const [
            ProfileLocation(directory: _current),
            ProfileLocation(directory: _other),
          ]
          ..elsewhere = [
            ElsewhereConversation(
              session: _session(
                'e1',
                'building modern financehub',
                directory: _other,
              ),
              directory: _other,
              running: true,
            ),
          ];
    await _pumpShell(tester, controller, scale: 2);
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const PageStorageKey('workspace-scroll')),
      const Offset(0, -3000),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    await _dispose(tester, controller);
  });
}
