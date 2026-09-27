// Stable workspace at phone widths and large text (2026-09-13). Returning
// to a project and starting or resuming a session stays visually clear at
// 320dp with 2x and 2.5x text: the header gives the project name the full
// row with secondary actions in its project sheet; session rows keep
// status and time by wrapping instead of cutting; the docked New
// conversation never clips and is the dock's only control (its chooser,
// slice-P4.5, holds Solo, Team and the separate copy); and the scroll end
// clears the dock by its real height. The normal 390dp/1x layout keeps its
// row header.
//
// flutter_test paints with a 1em-per-glyph test font, so assertions here are
// about structure and geometry, not glyph widths, except the last group,
// which loads the real fonts for the 390dp/1x side-by-side dock;
// tool/capture/stable_workspace_test.dart checks painted text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/screens/projects_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart' show loadCaptureFonts;

const _directory = '/home/dev/shopfront';

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'http://localhost');

  /// Every default on: project management, worktree creation (the isolated
  /// task action), server-wide search and the terminal.
  @override
  ServerCapabilities get capabilities => const ServerCapabilities();

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
  _Repository(this.projectName);

  final String projectName;

  @override
  Future<List<WorkspaceProject>> listProjects() async => [
    WorkspaceProject(
      id: 'project-1',
      name: projectName,
      directory: _directory,
      worktrees: const [],
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

Session _session(
  String id,
  String title,
  int updated, {
  double? cost,
  String? shareUrl,
  SessionDiffSummary? summary,
}) => Session(
  id: id,
  title: title,
  directory: _directory,
  time: SessionTime(created: 1, updated: updated),
  cost: cost,
  shareUrl: shareUrl,
  summary: summary,
);

/// One working session carrying cost and diff facts, five recent ones: the
/// shape of the capture that showed the cramped 320dp/2.5x page.
Future<_Controller> _controller({String projectName = 'shopfront'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = _Controller(ProfileStore(prefs: prefs))
    ..api = _Api()
    ..repository = _Repository(projectName)
    ..directory = _directory
    ..status = StreamStatus.connected;
  controller.sessionsById = {
    'busy': _session(
      'busy',
      'Fix flaky checkout test',
      100,
      cost: 0.42,
      shareUrl: "https://example.test/shared/checkout",
      summary: const SessionDiffSummary(
        additions: 120,
        deletions: 34,
        files: 6,
      ),
    ),
    for (var i = 1; i <= 5; i++)
      'recent-$i': _session('recent-$i', 'Recent task $i', 50 - i, cost: 0.1),
  };
  controller.busySessions.add('busy');
  return controller;
}

Widget _app(
  ConnectionController controller, {
  double textScale = 1,
  bool dark = false,
  bool rtl = false,
}) => MaterialApp(
  routes: {
    '/chat/created': (_) => const Scaffold(body: Text('Created conversation')),
  },
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

void _phone(WidgetTester tester, double width, {double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _row(String id) => find.byKey(ValueKey('session-dismiss-$id'));
final _header = find.byKey(const ValueKey('current-project-entry'));
final _name = find.byKey(const ValueKey('current-project-name'));
final _manage = find.byKey(const ValueKey('manage-project-entry'));
final _switch = find.byKey(const ValueKey('context-switch-project'));
final _pill = find.byKey(const ValueKey('workspace-quick-ask'));
final _isolated = find.byKey(const ValueKey('workspace-isolated-task'));
final _primary = find.widgetWithText(FilledButton, 'New conversation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final textScale in [2.0, 2.5]) {
    for (final dark in [false, true]) {
      final label = '320dp, ${textScale}x text, ${dark ? 'dark' : 'light'}';
      testWidgets('$label: the project, its actions, session state and the '
          'docked New session stay clear', (tester) async {
        _phone(tester, 320);
        final controller = await _controller();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(controller, textScale: textScale, dark: dark),
        );
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);

        // One project entry keeps secondary controls off the conversation list.
        expect(_header, findsOneWidget);
        expect(_name, findsOneWidget);
        expect(tester.getTopLeft(_name).dx, 16);
        expect(tester.getSize(_name).width, 256);
        expect(tester.widget<KitText>(_name).maxLines, 3);
        expect(find.text(_directory), findsNothing);
        expect(_manage, findsNothing);
        expect(_switch, findsNothing);
        expect(find.textContaining(r'$0.42'), findsNothing);

        // The working row's facts wrap to three lines at large text rather
        // than cutting "Working · 2m ago · $0.42 …" to one.
        final facts = find.descendant(
          of: _row('busy'),
          matching: find.textContaining('Working'),
        );
        expect(facts, findsOneWidget);
        expect(tester.widget<Text>(facts).maxLines, 3);

        // The primary action has the whole dock width and is the dock's
        // only control (R2): the task in a separate copy is a choice of
        // its chooser, which names the project.
        expect(_primary, findsOneWidget);
        expect(tester.getTopLeft(_primary).dx, 16);
        expect(tester.getSize(_primary).width, 288);
        expect(tester.getSize(_primary).height, greaterThanOrEqualTo(48));
        expect(_isolated, findsNothing);
        // The kit pins the block 8 dp above the shell's bottom inset.
        expect(tester.getBottomLeft(_pill).dy, 900 - 8);

        // The end of the list clears the dock by the dock's real height.
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -4000),
        );
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
        expect(_row('recent-5'), findsOneWidget);
        expect(
          tester.getBottomLeft(_row('recent-5')).dy,
          lessThanOrEqualTo(tester.getTopLeft(_pill).dy),
        );

        // And the primary action still starts a session: its chooser
        // fits the phone at this text size, and Solo starts it.
        await tester.tap(_primary);
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('new-conversation-sheet')), findsOne);
        await tester.tap(find.byKey(const ValueKey('new-conversation-solo')));
        await _pumpFrames(tester);
        expect(controller.createCalls, 1);
        expect(find.text('Created conversation'), findsOneWidget);
      });
    }
  }

  testWidgets('320dp 2.5x RTL: the header and dock lay out without overflow', (
    tester,
  ) async {
    _phone(tester, 320);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, textScale: 2.5, rtl: true));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(_name, findsOneWidget);
    expect(tester.getTopRight(_name).dx, 320 - 16);
    expect(tester.getSize(_name).width, 256);
    expect(_switch, findsNothing);
    expect(_manage, findsNothing);
    expect(_primary, findsOneWidget);
    expect(tester.getSize(_primary).width, 288);
    expect(_isolated, findsNothing);
  });

  // The test font paints every glyph 1em wide. At 2.5x the rungs are 60, 50
  // and 40dp per glyph; a 339dp phone gives the name a 275dp row, so four
  // letters fit the large title, a five-letter segment ("shop-") only the
  // middle rung, and nine letters no rung at all, each with a 25dp margin.
  for (final (name, fontSize) in [
    ('shop', 24.0),
    ('shop-front', 20.0),
    ('shopfront', 16.0),
  ]) {
    testWidgets(
      '339dp 2.5x: "$name" keeps the largest title size whose longest '
      'segment fits the row ($fontSize)',
      (tester) async {
        _phone(tester, 339);
        final controller = await _controller(projectName: name);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(controller, textScale: 2.5));
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(_name);
        expect(text.data, name);
        expect(text.style?.fontSize, fontSize);
        // The scale itself is untouched: the painted text is 2.5x the base.
        expect(
          MediaQuery.textScalerOf(tester.element(_name)).scale(fontSize),
          fontSize * 2.5,
        );
      },
    );
  }

  testWidgets('320dp 2x: Switch project opens the project list and the '
      'name still opens the context sheet', (tester) async {
    _phone(tester, 320);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, textScale: 2));
    await _pumpFrames(tester);

    await tester.tap(_name);
    await _pumpFrames(tester);
    await tester.tap(_switch);
    await _pumpFrames(tester);
    expect(find.byType(ProjectsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ProjectsScreen))).pop();
    await _pumpFrames(tester);
    expect(find.byType(ProjectsScreen), findsNothing);

    await tester.tap(_name);
    await _pumpFrames(tester);
    expect(
      find.byKey(const ValueKey('workspace-context-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-switch-project')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('session details disclose usage without cluttering the list', (
    tester,
  ) async {
    _phone(tester, 390);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await _pumpFrames(tester);
    expect(find.textContaining(r'$0.42'), findsNothing);
    expect(find.textContaining('+120'), findsNothing);
    expect(
      find.textContaining('https://example.test/shared/checkout'),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: _row('busy'),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await _pumpFrames(tester);
    expect(find.text('Rename'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await _pumpFrames(tester);
    expect(find.textContaining(r'$0.42'), findsOneWidget);
    expect(find.textContaining('+120'), findsOneWidget);
    expect(find.textContaining('6 files'), findsOneWidget);
    expect(
      find.textContaining('https://example.test/shared/checkout'),
      findsOneWidget,
    );
    expect(find.text(_directory), findsOneWidget);
    expect(controller.createCalls, 0);
    expect(tester.takeException(), isNull);
  });

  // Whether "New conversation" shares the row with the isolated icon is a
  // question of glyph widths: with the 1em test font the button role's
  // 16 px label (LOOK-12) is 256 dp and can never fit a compact row, so this
  // case paints with the real Geist, as a phone does. Last in the file: the
  // fonts stay loaded for the rest of the isolate.
  group('with the real fonts', () {
    setUpAll(loadCaptureFonts);

    testWidgets('390dp 1x keeps the row header, a two-line facts line and the '
        'side-by-side dock', (tester) async {
      _phone(tester, 390);
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);

      // Normal text uses the same single project entry as enlarged text.
      expect(_header, findsOneWidget);
      expect(_name, findsOneWidget);
      expect(_switch, findsNothing);
      expect(_manage, findsNothing);
      expect(
        find.descendant(of: _header, matching: find.text('shopfront')),
        findsOneWidget,
      );

      final facts = find.descendant(
        of: _row('busy'),
        matching: find.textContaining('Working'),
      );
      expect(tester.widget<Text>(facts).maxLines, 2);

      // The dock holds New conversation alone, across the gutter (R2).
      expect(_primary, findsOneWidget);
      expect(_isolated, findsNothing);
      expect(find.text('Isolated task'), findsNothing);
      expect(tester.getTopRight(_primary).dx, 390 - 16);
      expect(tester.getSize(_primary).height, greaterThanOrEqualTo(48));

      // The task in a separate copy is no longer on the project's sheet:
      // it is a choice of New conversation, naming the project and what it
      // does (slice-P4.5).
      await tester.tap(_header);
      await _pumpFrames(tester);
      expect(_isolated, findsNothing);
      await tester.tapAt(const Offset(8, 8));
      await _pumpFrames(tester);
      await tester.tap(_primary);
      await _pumpFrames(tester);
      expect(
        find.byKey(const ValueKey('new-conversation-copy')),
        findsOneWidget,
      );
      expect(find.textContaining('In a separate copy of '), findsOneWidget);
      expect(
        find.textContaining(
          'Works on a separate copy so your main folder stays untouched.',
        ),
        findsOneWidget,
      );
    });
  });
}
