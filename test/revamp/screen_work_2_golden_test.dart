// Golden renders of screen-work-2's pages (wave 2b): All conversations
// (with its Archived filter and the Continue here question), Import
// conversation (with its destination chooser) and Worktrees (with its
// create, reset and delete questions), rebuilt from kit parts. Phone
// 412x915 and one wide window (1280x800), dark and light (owner decision
// 2026-09-27: no Arabic), with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_work_2_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/screens/global_sessions_screen.dart';
import 'package:opencode_mobile/ui/screens/session_import_screen.dart';
import 'package:opencode_mobile/ui/screens/worktrees_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureApp, loadCaptureFonts;

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

// --- fixtures ---------------------------------------------------------------

class _Repository extends ProductRepository implements SessionImportGateway {
  _Repository({
    this.sessions = const [],
    this.sessionsError,
    this.worktrees = const [],
    this.worktreesError,
  });

  final List<GlobalSessionResult> sessions;
  final Object? sessionsError;
  final List<WorktreeInfo> worktrees;
  final Object? worktreesError;

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async {
    if (sessionsError case final error?) throw error;
    return ServerPage(
      items: [
        for (final result in sessions)
          if (includeArchived || !result.session.archived) result,
      ],
    );
  }

  @override
  Future<List<WorktreeInfo>> listWorktrees({
    required String projectDirectory,
    String? projectID,
  }) async {
    if (worktreesError case final error?) throw error;
    return List.of(worktrees);
  }

  @override
  Future<List<VersionControlFile>> listWorktreeFileStatuses(
    String directory,
  ) async => const [
    VersionControlFile(
      path: 'lib/main.dart',
      status: 'modified',
      additions: 4,
      deletions: 1,
    ),
    VersionControlFile(
      path: 'lib/app.dart',
      status: 'modified',
      additions: 2,
      deletions: 0,
    ),
  ];

  @override
  bool get sessionImportSupported => true;

  @override
  Future<Session> importSession(
    SessionImportDocument document,
    SessionImportDestination destination,
  ) async => Session(id: document.id, directory: destination.directory);

  @override
  Future<List<WorkspaceProject>> listProjects() async => const [
    WorkspaceProject(
      id: 'mobile',
      name: 'opencode-mobile',
      directory: '/home/dev/Code/opencode-mobile',
      worktrees: ['/home/dev/.worktrees/opencode-mobile/wake-fix'],
      updatedAt: 1,
    ),
    WorkspaceProject(
      id: 'site',
      name: 'marketing-site',
      directory: '/home/dev/Code/marketing-site',
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

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;
}

Future<_Controller> _controller(
  _Repository repository, {
  String directory = '/home/dev/Code/opencode-mobile',
  Set<String> busy = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = ProfileStore(prefs: preferences);
  await store.upsert(
    ServerProfile(id: 'server', name: 'Studio PC', baseUrl: 'http://pc:4096'),
  );
  await store.setActiveId('server');
  return _Controller(store)
    ..repository = repository
    ..directory = directory
    ..busySessions = {...busy}
    ..status = StreamStatus.connected;
}

final _now = DateTime.now().millisecondsSinceEpoch;
const _hour = 3600 * 1000;

GlobalSessionResult _session(
  String id,
  String title, {
  required String directory,
  required String project,
  required int hoursAgo,
  bool archived = false,
  String? workspace,
}) => GlobalSessionResult(
  session: Session(
    id: id,
    title: title,
    directory: directory,
    workspaceID: workspace,
    time: SessionTime(
      created: _now - hoursAgo * _hour - _hour,
      updated: _now - hoursAgo * _hour,
      archived: archived ? _now - hoursAgo * _hour : null,
    ),
  ),
  projectName: project,
  projectDirectory: directory,
);

const _mobile = '/home/dev/Code/opencode-mobile';
const _site = '/home/dev/Code/marketing-site';

List<GlobalSessionResult> _sessions() => [
  _session(
    'ses_wake',
    'Fix the wake lock on Android 15',
    directory: _mobile,
    project: 'opencode-mobile',
    hoursAgo: 1,
  ),
  _session(
    'ses_voice',
    'Voice model download resumes after a restart',
    directory: _mobile,
    project: 'opencode-mobile',
    hoursAgo: 5,
  ),
  _session(
    'ses_hero',
    'New hero section and pricing table',
    directory: _site,
    project: 'marketing-site',
    hoursAgo: 3,
    workspace: 'wrk_site',
  ),
  _session(
    'ses_copy',
    'Tighten the landing page copy',
    directory: _site,
    project: 'marketing-site',
    hoursAgo: 30,
  ),
  _session(
    'ses_old',
    'Spike: offline queue on SQLite',
    directory: _mobile,
    project: 'opencode-mobile',
    hoursAgo: 80,
    archived: true,
  ),
];

const _project = WorkspaceProject(
  id: 'mobile',
  name: 'opencode-mobile',
  directory: _mobile,
  worktrees: ['/home/dev/.worktrees/opencode-mobile/wake-fix'],
  updatedAt: 1,
);

const _worktrees = [
  WorktreeInfo(
    name: 'wake-fix',
    directory: '/home/dev/.worktrees/opencode-mobile/wake-fix',
    branch: 'opencode/wake-fix',
  ),
  WorktreeInfo(
    name: 'voice-resume',
    directory: '/home/dev/.worktrees/opencode-mobile/voice-resume',
    branch: 'opencode/voice-resume',
  ),
];

Map<String, dynamic> _transfer() => {
  'info': {
    'id': 'ses_transfer',
    'projectID': 'source_project',
    'title': 'Release checklist for 1.0.45',
    'location': {'directory': '/source/private'},
    'time': {'created': 1, 'updated': 2},
    'cost': 0,
    'tokens': {
      'input': 0,
      'output': 0,
      'reasoning': 0,
      'cache': {'read': 0, 'write': 0},
    },
  },
  'messages': [
    for (var i = 0; i < 12; i++)
      {
        'id': 'msg_$i',
        'type': 'user',
        'time': {'created': i + 1},
        'text': 'Step $i',
      },
  ],
};

SessionImportFile _file(List<int> bytes, {String name = 'release.json'}) =>
    SessionImportFile(
      name: name,
      length: () async => bytes.length,
      read: () => Stream.value(bytes),
    );

// --- harness ----------------------------------------------------------------

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

String _name(String page, String state, Size size, bool light) {
  final sized = size == _phone
      ? ''
      : '_${size.width.toInt()}x${size.height.toInt()}';
  return 'work_${page}_$state${sized}_${light ? 'light' : 'dark'}';
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(KitMotion.entrance);
}

Future<void> _golden(
  WidgetTester tester, {
  required String page,
  required String state,
  required bool light,
  required Widget Function(ConnectionController controller) screen,
  required _Controller controller,
  Size size = _phone,
  Future<void> Function()? before,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(
      captureApp(
        home: screen(controller),
        boundaryKey: boundary,
        controller: controller,
        light: light,
      ),
    );
    await _settle(tester);
    if (before != null) {
      await before();
      await _settle(tester);
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(page, state, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  // ProfileStore.upsert reads secure storage (AGENTS.md testing traps).
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null),
  );

  Widget sessions(ConnectionController c) =>
      GlobalSessionsScreen(controller: c);
  Widget worktrees(ConnectionController c) =>
      WorktreesScreen(controller: c, project: _project);
  Widget import(ConnectionController c, {List<int>? bytes}) =>
      SessionImportScreen(
        controller: c,
        pickFile: () async =>
            _file(bytes ?? utf8.encode(jsonEncode(_transfer()))),
      );

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // All conversations ------------------------------------------------------
    for (final size in [_phone, _wide]) {
      testWidgets('global sessions · loaded · ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _golden(
          tester,
          page: 'global_sessions',
          state: 'loaded',
          light: light,
          size: size,
          screen: sessions,
          controller: await _controller(
            _Repository(sessions: _sessions()),
            busy: {'ses_wake'},
          ),
        );
      });
    }

    testWidgets('global sessions · archived · $mode', (tester) async {
      await _golden(
        tester,
        page: 'global_sessions',
        state: 'archived',
        light: light,
        screen: sessions,
        controller: await _controller(_Repository(sessions: _sessions())),
        before: () async {
          await tester.tap(
            find.byKey(const ValueKey('include-archived-sessions')),
          );
        },
      );
    });

    testWidgets('global sessions · empty · $mode', (tester) async {
      await _golden(
        tester,
        page: 'global_sessions',
        state: 'empty',
        light: light,
        screen: sessions,
        controller: await _controller(_Repository()),
      );
    });

    testWidgets('global sessions · error · $mode', (tester) async {
      await _golden(
        tester,
        page: 'global_sessions',
        state: 'error',
        light: light,
        screen: sessions,
        controller: await _controller(
          _Repository(
            sessionsError: const ProductException(
              'OpenCode is unreachable. Try again.',
            ),
          ),
        ),
      );
    });

    testWidgets('global sessions · continue here · $mode', (tester) async {
      await _golden(
        tester,
        page: 'global_sessions',
        state: 'move_confirm',
        light: light,
        screen: sessions,
        controller: await _controller(_Repository(sessions: _sessions())),
        before: () async {
          await tester.longPress(
            find.byKey(const ValueKey('global-session-ses_hero')),
          );
          await _settle(tester);
          await tester.tap(
            find.byKey(const ValueKey('steal-session-ses_hero')),
          );
        },
      );
    });

    // Import conversation ---------------------------------------------------
    testWidgets('import · empty · $mode', (tester) async {
      await _golden(
        tester,
        page: 'session_import',
        state: 'empty',
        light: light,
        screen: import,
        controller: await _controller(_Repository()),
      );
    });

    for (final size in [_phone, _wide]) {
      testWidgets('import · review · ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _golden(
          tester,
          page: 'session_import',
          state: 'review',
          light: light,
          size: size,
          screen: import,
          controller: await _controller(_Repository()),
          before: () async {
            await tester.tap(find.byKey(const ValueKey('import-choose-file')));
          },
        );
      });
    }

    testWidgets('import · invalid file · $mode', (tester) async {
      await _golden(
        tester,
        page: 'session_import',
        state: 'error',
        light: light,
        screen: (c) => import(c, bytes: utf8.encode('# Markdown transcript')),
        controller: await _controller(_Repository()),
        before: () async {
          await tester.tap(find.byKey(const ValueKey('import-choose-file')));
        },
      );
    });

    testWidgets('import · destination sheet · $mode', (tester) async {
      await _golden(
        tester,
        page: 'session_import',
        state: 'destination_sheet',
        light: light,
        screen: import,
        controller: await _controller(_Repository()),
        before: () async {
          await tester.tap(find.byKey(const ValueKey('import-destination')));
        },
      );
    });

    // Worktrees --------------------------------------------------------------
    for (final size in [_phone, _wide]) {
      testWidgets('worktrees · loaded · ${size.width.toInt()} · $mode', (
        tester,
      ) async {
        await _golden(
          tester,
          page: 'worktrees',
          state: 'loaded',
          light: light,
          size: size,
          screen: worktrees,
          controller: await _controller(
            _Repository(worktrees: _worktrees),
            directory: '/home/dev/.worktrees/opencode-mobile/wake-fix',
          ),
        );
      });
    }

    testWidgets('worktrees · empty · $mode', (tester) async {
      await _golden(
        tester,
        page: 'worktrees',
        state: 'empty',
        light: light,
        screen: worktrees,
        controller: await _controller(_Repository()),
      );
    });

    testWidgets('worktrees · error · $mode', (tester) async {
      await _golden(
        tester,
        page: 'worktrees',
        state: 'error',
        light: light,
        screen: worktrees,
        controller: await _controller(
          _Repository(
            worktreesError: const ProductException(
              'OpenCode is unreachable. Try again.',
            ),
          ),
        ),
      );
    });

    testWidgets('worktrees · create dialog · $mode', (tester) async {
      await _golden(
        tester,
        page: 'worktrees',
        state: 'create_dialog',
        light: light,
        screen: worktrees,
        controller: await _controller(_Repository(worktrees: _worktrees)),
        before: () async {
          await tester.tap(find.byKey(const ValueKey('create-worktree')));
        },
      );
    });

    for (final (state, item) in const [
      ('remove_confirm', 'Delete'),
      ('reset_confirm', 'Reset'),
    ]) {
      testWidgets('worktrees · $state · $mode', (tester) async {
        await _golden(
          tester,
          page: 'worktrees',
          state: state,
          light: light,
          screen: worktrees,
          controller: await _controller(_Repository(worktrees: _worktrees)),
          before: () async {
            await tester.longPress(
              find.byKey(
                const ValueKey(
                  'worktree-/home/dev/.worktrees/opencode-mobile/voice-resume',
                ),
              ),
            );
            await _settle(tester);
            await tester.tap(find.text(item));
          },
        );
      });
    }
  }
}
