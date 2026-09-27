// Workspace tab hierarchy: a session that is blocked on a permission,
// question or form appears once, under "Needs you", above Pinned, Active
// and Recent; the row names the blocker; and the Recent caption's actions
// stay reachable on a narrow phone at large text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/entrance.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api({this.terminal = true}) : super(baseUrl: 'http://localhost');

  final bool terminal;

  @override
  ServerCapabilities get capabilities => ServerCapabilities(terminal: terminal);

  @override
  Future<List<Session>> sessions() async => const [];

  @override
  Future<Map<String, String>> sessionStatuses() async => const {};

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

class _Repository extends ProductRepository {
  @override
  Future<List<WorkspaceProject>> listProjects() async => [
    const WorkspaceProject(
      id: 'project-1',
      name: 'OpenCode Mobile',
      directory: '/work/app',
      worktrees: [],
      updatedAt: 1,
    ),
  ];

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  int createCalls = 0;

  @override
  Future<Session> createSession() async {
    createCalls++;
    return Session(id: 'created', directory: directory);
  }

  // Pins are scoped to a server profile; the bare controller has none.
  @override
  ServerProfile get profile =>
      ServerProfile(id: 'server-a', name: 'A', baseUrl: 'http://localhost');

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;

  @override
  Future<void> refreshPendingPermissions() async {}

  @override
  Future<void> refreshPendingQuestions() async {}
}

Session _session(String id, int updated) => Session(
  id: id,
  title: id,
  directory: '/work/app',
  time: SessionTime(created: 1, updated: updated),
);

PermissionRequest _permission(String sessionID) => PermissionRequest(
  id: 'perm-$sessionID',
  sessionID: sessionID,
  permission: 'bash',
  patterns: const ['git status'],
);

PendingQuestion _question(String sessionID) => PendingQuestion(
  id: 'question-$sessionID',
  sessionID: sessionID,
  prompts: const [
    QuestionPrompt(
      title: 'Deployment',
      question: 'Which target?',
      multiple: false,
      custom: true,
      choices: [QuestionChoice(label: 'Staging', description: 'Test')],
    ),
  ],
);

Api2FormInfo _form(String sessionID) => Api2FormInfo(
  id: 'form-$sessionID',
  sessionID: sessionID,
  title: 'Connect to Sentry',
);

/// Five sessions covering every section: two pinned, two busy, one idle.
/// Newest first by `updated` inside each group, matching the sort.
Future<_Controller> _controller({bool terminal = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = _Controller(ProfileStore(prefs: prefs))
    ..api = _Api(terminal: terminal)
    ..repository = _Repository()
    ..directory = '/work/app'
    ..status = StreamStatus.connected;
  controller.sessionsById = {
    'pinned-blocked': _session('pinned-blocked', 50),
    'pinned-idle': _session('pinned-idle', 40),
    'busy-blocked': _session('busy-blocked', 30),
    'busy-working': _session('busy-working', 20),
    'recent-idle': _session('recent-idle', 10),
  };
  controller.busySessions.addAll({'busy-blocked', 'busy-working'});
  for (final id in ['pinned-blocked', 'pinned-idle']) {
    await controller.setSessionPinned(
      id,
      true,
      locationRevision: controller.locationRevision,
    );
  }
  return controller;
}

Widget _app(
  ConnectionController controller, {
  double textScale = 1,
  bool dark = false,
  bool rtl = false,
  Map<String, WidgetBuilder> routes = const {},
}) => MaterialApp(
  routes: routes,
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: child!,
    ),
  ),
  home: Scaffold(body: WorkspaceScreen(controller: controller)),
);

/// Busy rows animate forever (breathing dot), so settle by hand.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _row(String id) => find.byKey(ValueKey('session-dismiss-$id'));

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final rtl in [false, true]) {
    testWidgets(
      '320dp 2.5x ${rtl ? 'RTL' : 'LTR'} Workspace keeps search and session creation reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await _controller();
        addTearDown(controller.dispose);
        controller.sessionsById.clear();
        controller.busySessions.clear();
        await tester.pumpWidget(
          _app(
            controller,
            textScale: 2.5,
            rtl: rtl,
            routes: {
              '/chat/created': (_) =>
                  const Scaffold(body: Text('Created conversation')),
            },
          ),
        );
        await _pumpFrames(tester);
        expect(
          find.byTooltip(
            'Search conversation titles across every project on this server',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(FilledButton, 'New conversation'));
        await _pumpFrames(tester);
        expect(find.text('Created conversation'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'recent rows are immediately visible when recycled after scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.busySessions.clear();
      controller.sessionsById = {
        for (var i = 0; i < 40; i++)
          'recent-$i': _session('recent-$i', 100 - i),
      };
      await tester.pumpWidget(_app(controller));
      await _pumpFrames(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
      await _pumpFrames(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await tester.pump();
      expect(find.text('recent-0'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('recent-0'),
          matching: find.byType(EntranceReveal),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty Workspace has one New session action that opens a session',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.sessionsById.clear();
      controller.busySessions.clear();
      await tester.pumpWidget(
        _app(
          controller,
          textScale: 2,
          routes: {
            '/chat/created': (_) =>
                const Scaffold(body: Text('New session opened')),
          },
        ),
      );
      await _pumpFrames(tester);
      expect(find.text('New conversation'), findsOneWidget);
      final action = find.widgetWithText(FilledButton, 'New conversation');
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getTopLeft(action).dx, 16);
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      await _pumpFrames(tester);
      expect(controller.createCalls, 1);
      expect(find.text('New session opened'), findsOneWidget);
    },
  );

  testWidgets(
    'a two-line session name remains readable and opens that session',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.busySessions.clear();
      controller.sessionsById = {
        'resume': Session(
          id: 'resume',
          title: 'Fix checkout layout',
          directory: '/work/app',
        ),
      };
      await tester.pumpWidget(
        _app(
          controller,
          textScale: 2,
          routes: {
            '/chat/resume': (_) =>
                const Scaffold(body: Text('Existing session opened')),
          },
        ),
      );
      await _pumpFrames(tester);
      final title = find.text('Fix checkout layout');
      expect(tester.widget<Text>(title).maxLines, 2);
      // 16 rail + 30 icon tile + 12 gap (VL §4).
      expect(tester.getTopLeft(title).dx, 58);
      expect(tester.getSize(title).height, greaterThan(40));
      expect(tester.takeException(), isNull);
      await tester.tap(title);
      await _pumpFrames(tester);
      expect(find.text('Existing session opened'), findsOneWidget);
      expect(controller.createCalls, 0);
    },
  );

  testWidgets(
    'an unlisted selected folder is not labelled as another project',
    (tester) async {
      final controller = await _controller();
      controller.directory = '/work/selected-b';
      await tester.pumpWidget(_app(controller));
      await _pumpFrames(tester);
      final context = find.byKey(const ValueKey('current-project-entry'));
      expect(
        find.descendant(of: context, matching: find.text('selected-b')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: context, matching: find.text('OpenCode Mobile')),
        findsNothing,
      );
      expect(find.textContaining('/work/selected-b'), findsNothing);
      await tester.tap(context);
      await _pumpFrames(tester);
      // The path is under the project sheet's Details, last and collapsed.
      await tester.tap(find.text('Details'));
      await _pumpFrames(tester);
      expect(find.textContaining('/work/selected-b'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'project path is compact and its complete value can be inspected',
    (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      const path = '/work/app/very-long-project-folder/nested/directory';
      controller.directory = path;
      await tester.pumpWidget(_app(controller));
      await _pumpFrames(tester);
      final project = find.byKey(const ValueKey('current-project-entry'));
      expect(find.text(path), findsNothing);
      await tester.tap(project);
      await _pumpFrames(tester);
      expect(find.text('Switch project'), findsOneWidget);
      // The whole path, once, under Details (KIT-33), copyable.
      final inSheet = find.descendant(
        of: find.byKey(const ValueKey('workspace-context-sheet')),
        matching: find.textContaining(path),
      );
      expect(inSheet, findsNothing);
      await tester.tap(find.text('Details'));
      await _pumpFrames(tester);
      expect(inSheet, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final textScale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        final label =
            '${width.toInt()}px, ${textScale}x text, ${dark ? 'dark' : 'light'}';
        testWidgets('$label: one Conversations list, blocked sessions once '
            'at the top above running, pinned and recent, and nothing '
            'overflows', (tester) async {
          // Tall enough that every section is laid out; width is what the
          // caption row and the menu have to fit.
          tester.view.physicalSize = Size(width, 2400 * textScale);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = await _controller();
          addTearDown(controller.dispose);
          controller.permissions['perm-busy-blocked'] = _permission(
            'busy-blocked',
          );
          controller.questions['question-pinned-blocked'] = _question(
            'pinned-blocked',
          );

          await tester.pumpWidget(
            _app(controller, textScale: textScale, dark: dark),
          );
          await _pumpFrames(tester);
          expect(tester.takeException(), isNull);

          // One list under one header; no state sections (owner decision
          // 2026-09-27). Both blocked rows are in it, each once.
          expect(
            find.byKey(const ValueKey('workspace-conversations')),
            findsOneWidget,
          );
          expect(find.text('Conversations'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('workspace-needs-you')),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('workspace-running')), findsNothing);
          expect(find.text('Pinned'), findsNothing);
          expect(find.text('Recent conversations'), findsNothing);
          expect(_row('pinned-blocked'), findsOneWidget);
          expect(_row('busy-blocked'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('session-attention-icon-busy-blocked')),
            findsOneWidget,
          );

          // The row leads with the one "Needs you" word (KitNeedsYou, in
          // the attention tone), then names the blocker (STATE-9).
          final permission = find.textContaining('Permission needed');
          expect(permission, findsOneWidget);
          final theme = Theme.of(tester.element(permission));
          final span = tester.widget<Text>(permission).textSpan! as TextSpan;
          expect((span.children!.first as TextSpan).text, 'Needs you · ');
          expect(
            (span.children!.first as TextSpan).style?.color,
            AppTheme.statusColor(theme, AppStatusTone.attention),
          );
          expect((span.children![1] as TextSpan).text, 'Permission needed');
          expect(find.textContaining('Answer needed'), findsOneWidget);

          // Row order top to bottom (UX plan 5.7): needs me, running,
          // pinned, recent. Blocked rows lead whatever their pin or busy
          // state.
          final header = _top(
            tester,
            find.byKey(const ValueKey('workspace-conversations')),
          );
          final running = _top(tester, _row('busy-working'));
          final pinned = _top(tester, _row('pinned-idle'));
          final recent = _top(tester, _row('recent-idle'));
          expect(find.text('Active conversations'), findsNothing);
          expect(_top(tester, _row('busy-blocked')), greaterThan(header));
          expect(_top(tester, _row('pinned-blocked')), greaterThan(header));
          expect(_top(tester, _row('busy-blocked')), lessThan(running));
          expect(_top(tester, _row('pinned-blocked')), lessThan(running));
          expect(running, lessThan(pinned));
          expect(pinned, lessThan(recent));

          // The caption's actions still fit and open a labelled menu.
          expect(
            find.byKey(const ValueKey('search-all-sessions')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const ValueKey('workspace-section-menu')),
          );
          await _pumpFrames(tester);
          expect(tester.takeException(), isNull);
          expect(find.text('Refresh recent conversations'), findsOneWidget);
          // Terminal is a Project tool now, not a Work menu entry.
          expect(
            find.byKey(const ValueKey('workspace-terminal')),
            findsNothing,
          );
          expect(find.text('Terminal'), findsNothing);
        });
      }
    }
  }

  testWidgets('one session with every blocker shows permission, then question, '
      'then form as each is answered', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.permissions['perm-busy-blocked'] = _permission('busy-blocked');
    controller.questions['question-busy-blocked'] = _question('busy-blocked');
    controller.forms['form-busy-blocked'] = _form('busy-blocked');

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    expect(_row('busy-blocked'), findsOneWidget);
    expect(find.textContaining('Permission needed'), findsOneWidget);
    expect(find.textContaining('Answer needed'), findsNothing);
    expect(find.textContaining('Form response needed'), findsNothing);

    controller.handleEventForTesting(
      EventEnvelope(
        type: 'permission.replied',
        properties: {'requestID': 'perm-busy-blocked', 'reply': 'once'},
      ),
    );
    await _pumpFrames(tester);
    expect(find.textContaining('Permission needed'), findsNothing);
    expect(find.textContaining('Answer needed'), findsOneWidget);

    controller.handleEventForTesting(
      EventEnvelope(
        type: 'question.replied',
        properties: {'requestID': 'question-busy-blocked'},
      ),
    );
    await _pumpFrames(tester);
    expect(find.textContaining('Answer needed'), findsNothing);
    expect(find.textContaining('Form response needed'), findsOneWidget);
    // Still at the top of the one list, above the running row.
    expect(
      _top(tester, _row('busy-blocked')),
      lessThan(_top(tester, _row('busy-working'))),
    );
    // Still one row, still busy underneath: it never fell into Active.
    expect(_row('busy-blocked'), findsOneWidget);
    expect(find.textContaining('Working'), findsOneWidget); // busy-working
  });

  testWidgets('answering the request returns a pinned session among the pins '
      'in pin order and a busy one among the running rows', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    expect(find.textContaining('Needs you'), findsNothing);
    final pinnedBefore = _top(tester, _row('pinned-blocked'));
    expect(pinnedBefore, lessThan(_top(tester, _row('pinned-idle'))));

    controller.handleEventForTesting(
      EventEnvelope(
        type: 'permission.asked',
        properties: {
          'id': 'perm-pinned',
          'sessionID': 'pinned-blocked',
          'permission': 'bash',
          'patterns': ['git status'],
          'metadata': <String, Object?>{},
          'always': <String>[],
        },
      ),
    );
    controller.handleEventForTesting(
      EventEnvelope(
        type: 'permission.asked',
        properties: {
          'id': 'perm-busy',
          'sessionID': 'busy-blocked',
          'permission': 'bash',
          'patterns': ['git status'],
          'metadata': <String, Object?>{},
          'always': <String>[],
        },
      ),
    );
    await _pumpFrames(tester);
    // Both now say "Needs you" and sit above the running row.
    expect(find.textContaining('Needs you'), findsNWidgets(2));
    final runningRow = _row('busy-working');
    expect(
      _top(tester, _row('pinned-blocked')),
      lessThan(_top(tester, runningRow)),
    );
    expect(
      _top(tester, _row('busy-blocked')),
      lessThan(_top(tester, runningRow)),
    );
    // The pin is still a pin: its menu (long-press, KIT-28) offers Unpin.
    await tester.longPress(
      find.descendant(
        of: _row('pinned-blocked'),
        matching: find.text('pinned-blocked'),
      ),
    );
    await _pumpFrames(tester);
    expect(find.text('Unpin'), findsOneWidget);
    // Close the menu without acting: a tap on the barrier.
    await tester.tapAt(const Offset(4, 4));
    await _pumpFrames(tester);
    expect(find.text('Unpin'), findsNothing);
    expect(controller.isSessionPinned('pinned-blocked'), isTrue);

    for (final id in ['perm-pinned', 'perm-busy']) {
      controller.handleEventForTesting(
        EventEnvelope(
          type: 'permission.replied',
          properties: {'requestID': id, 'reply': 'once'},
        ),
      );
    }
    await _pumpFrames(tester);
    expect(find.textContaining('Needs you'), findsNothing);
    expect(_row('pinned-blocked'), findsOneWidget);
    expect(_row('busy-blocked'), findsOneWidget);
    // Back among the pins, first by recency among pins, as before; the
    // busy one back among the running rows, above every pin.
    expect(
      _top(tester, _row('pinned-blocked')),
      greaterThan(_top(tester, runningRow)),
    );
    expect(
      _top(tester, _row('pinned-blocked')),
      lessThan(_top(tester, _row('pinned-idle'))),
    );
    expect(
      _top(tester, _row('busy-blocked')),
      lessThan(_top(tester, _row('pinned-blocked'))),
    );
    expect(find.textContaining('Working'), findsNWidgets(2));
  });

  testWidgets('a pinned conversation that is running sits once among the '
      'running rows and returns among the pins when the run ends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.busySessions.add('pinned-idle');

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    expect(_row('pinned-idle'), findsOneWidget);
    // Running rows first, then the pins: the idle pin (newer) now sits
    // below the running pin (older).
    expect(
      _top(tester, _row('pinned-idle')),
      lessThan(_top(tester, _row('pinned-blocked'))),
    );
    // No section header, so no count.
    expect(find.byKey(const ValueKey('workspace-running')), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(controller.isSessionPinned('pinned-idle'), isTrue);

    controller.busySessions.remove('pinned-idle');
    controller.notifyListeners();
    await _pumpFrames(tester);
    expect(_row('pinned-idle'), findsOneWidget);
    expect(
      _top(tester, _row('pinned-idle')),
      greaterThan(_top(tester, _row('pinned-blocked'))),
    );
    expect(
      _top(tester, _row('pinned-idle')),
      greaterThan(_top(tester, _row('busy-working'))),
    );
    expect(
      _top(tester, _row('pinned-idle')),
      lessThan(_top(tester, _row('recent-idle'))),
    );
  });

  testWidgets('one list: a needs-you row sorts above a running row above a '
      'finished row, and the needs-you row says "Needs you" in words', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    // Newest first by time is the opposite of the urgency order, so only
    // the urgency order can put them the right way round.
    controller.sessionsById = {
      'finished': _session('finished', 90),
      'running': _session('running', 60),
      'waiting': _session('waiting', 30),
    };
    controller.busySessions
      ..clear()
      ..add('running');
    controller.permissions['perm-waiting'] = _permission('waiting');

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);

    final header = find.byKey(const ValueKey('workspace-conversations'));
    expect(header, findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-needs-you')), findsNothing);
    expect(find.byKey(const ValueKey('workspace-running')), findsNothing);
    final waiting = _top(tester, _row('waiting'));
    final running = _top(tester, _row('running'));
    final finished = _top(tester, _row('finished'));
    expect(_top(tester, header), lessThan(waiting));
    expect(waiting, lessThan(running));
    expect(running, lessThan(finished));

    // Never colour only: the needs-you row names its state in words, and
    // the running row says it is working.
    expect(
      find.descendant(
        of: _row('waiting'),
        matching: find.textContaining('Needs you'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('session-attention-icon-waiting')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row('running'),
        matching: find.textContaining('Working'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row('finished'),
        matching: find.textContaining('Needs you'),
      ),
      findsNothing,
    );
  });

  testWidgets('the project switcher and New conversation stay put while the '
      'list scrolls', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.busySessions.clear();
    controller.sessionsById = {
      for (var i = 0; i < 30; i++) 'recent-$i': _session('recent-$i', 100 - i),
    };

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    final header = find.byKey(const ValueKey('current-project-entry'));
    final create = find.byKey(const ValueKey('workspace-quick-ask'));
    expect(header, findsOneWidget);
    // In the header, not in the scroll (UX plan 5.7).
    expect(
      find.ancestor(of: header, matching: find.byType(CustomScrollView)),
      findsNothing,
    );
    expect(
      find.ancestor(of: create, matching: find.byType(CustomScrollView)),
      findsNothing,
    );
    final headerBefore = tester.getRect(header);
    final createBefore = tester.getRect(create);
    expect(headerBefore.top, 0);
    // Thumb reach: the primary action sits in the bottom third.
    expect(createBefore.top, greaterThan(700 * 2 / 3));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await _pumpFrames(tester);
    expect(_row('recent-0').hitTestable(), findsNothing);
    expect(tester.getRect(header), headerBefore);
    expect(tester.getRect(create), createBefore);

    await tester.tap(header);
    await _pumpFrames(tester);
    expect(
      find.byKey(const ValueKey('workspace-context-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('Archived closes the list, after Recent', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.sessionsById['old'] = Session(
      id: 'old',
      title: 'old',
      directory: '/work/app',
      time: SessionTime(created: 1, updated: 2, archived: 3),
    );

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    final archived = find.text('Archived conversations');
    expect(archived, findsOneWidget);
    expect(_row('old'), findsNothing);
    expect(
      _top(tester, archived),
      greaterThan(_top(tester, _row('recent-idle'))),
    );
  });

  testWidgets('the section menu reloads sessions and omits Terminal when the '
      'server has none', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(terminal: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    // Menu entries exist only while the menu is open, so absence has to be
    // checked with it open.
    await tester.tap(find.byKey(const ValueKey('workspace-section-menu')));
    await _pumpFrames(tester);
    expect(find.text('Refresh recent conversations'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-terminal')), findsNothing);
    expect(find.text('Terminal'), findsNothing);
    await tester.tap(find.text('Refresh recent conversations'));
    await _pumpFrames(tester);
    expect(find.text('Refresh recent conversations'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
