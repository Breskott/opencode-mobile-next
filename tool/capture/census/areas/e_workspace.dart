// Census scenes for the ledger part `e-workspace`
// (docs/design/ui-ledger/parts/e-workspace.json). See tool/capture/census_test.dart.
//
// The Work tab is rendered inside the real HomeScreen; its sheets and dialogs
// are opened by tapping the real openers. Project management screens are
// pushed over the Work tab, and the chat-launched sheets (move session,
// Console organizations, Tasks) are opened over the real ChatScreen. All
// data is the invented "shopfront" project (support/e_workspace_fakes.dart).
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/builtin/builtin_folders.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/global_sessions_screen.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/manage_project_screen.dart';
import 'package:opencode_mobile/ui/screens/managed_workspaces_screen.dart';
import 'package:opencode_mobile/ui/screens/project_folder_actions.dart';
import 'package:opencode_mobile/ui/screens/project_health_screen.dart';
import 'package:opencode_mobile/ui/screens/projects_screen.dart';
import 'package:opencode_mobile/ui/screens/running_work_sheet.dart';
import 'package:opencode_mobile/ui/screens/session_destination_sheet.dart';
import 'package:opencode_mobile/ui/screens/worktrees_screen.dart';
import 'package:opencode_mobile/ui/widgets/folder_browser.dart';

import '../../fixtures.dart';
import '../census_core.dart';
import '../support/e_workspace_fakes.dart';

// ---------------------------------------------------------------------------
// Scene helpers
// ---------------------------------------------------------------------------

/// The Work tab inside the shell, as the person sees it.
Future<EController> _work(
  CensusKit kit, {
  EController? controller,
  Duration settleFor = const Duration(seconds: 2),
}) async {
  final conn = controller ?? await eController(otherProjects: true);
  kit.onDispose(conn.dispose);
  // Tab 0 explicitly: with something waiting the shell would open on Inbox.
  await kit.pumpApp(
    const HomeScreen(initialTab: 0),
    controller: conn,
    settleFor: settleFor,
  );
  return conn;
}

/// The Work tab with no project folder open yet: the folder chooser.
Future<EController> _chooser(
  CensusKit kit, {
  bool canCreate = true,
  Object? projectsError,
}) async {
  // Folders can be created only on a server this app runs: the phone's.
  ProjectFolderActions.canCreateOverride = canCreate;
  kit.onDispose(() => ProjectFolderActions.canCreateOverride = null);
  final repository = ERepository()
    ..projects = const []
    ..projectsError = projectsError;
  final conn = await eController(
    directory: null,
    sessions: const {},
    busy: const {},
    repository: repository,
    phone: canCreate,
  );
  await _work(kit, controller: conn);
  kit.expectText('Choose a project folder');
  return conn;
}

/// Opens the overflow menu of the Work tab row for [sessionID] and picks
/// [item].
Future<void> _rowMenu(CensusKit kit, String sessionID, String item) async {
  final row = find.byKey(ValueKey('session-dismiss-$sessionID'));
  await kit.scrollTo(row);
  await kit.tap(
    find.descendant(of: row, matching: find.byTooltip('Conversation actions')),
  );
  await kit.tap(find.text(item).last);
}

/// Pushes [page] over the Work tab.
Future<EController> _overWork(
  CensusKit kit,
  Widget Function(EController conn) page, {
  EController? controller,
}) async {
  final conn = await _work(kit, controller: controller);
  await kit.push(page(conn), settleFor: const Duration(seconds: 2));
  return conn;
}

/// The real chat screen for the (finished) checkout conversation.
Future<EController> _chat(
  CensusKit kit, {
  ERepository? repository,
  Set<String> busy = const {},
  List<MessageWithParts> Function()? transcript,
}) async {
  final api = EApi()
    ..messagesHandler = (_) async => (transcript ?? sampleTranscript)();
  final conn = await eController(
    api: api,
    repository: repository,
    busy: busy,
    sessions: {
      ...eSessions(archived: false),
      for (final child in (repository ?? ERepository()).children)
        child.id: child,
    },
  );
  kit.onDispose(conn.dispose);
  await kit.pumpApp(
    const ChatScreen(sessionID: checkoutSessionID),
    controller: conn,
    settleFor: const Duration(seconds: 3),
  );
  return conn;
}

/// The Tasks sheet over the chat, then the running command's output screen.
///
/// The output is set in the generic `monospace` family, which flutter_test
/// does not have (it would draw boxes); the device draws its system mono, so
/// the scene lends that family the app's own mono face.
Future<void> _shellOutput(CensusKit kit) async {
  await kit.tester.runAsync(() async {
    final bytes = File(
      'assets/fonts/geist/GeistMono-Variable.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('monospace')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });
  final conn = await _chat(kit, busy: const {checkoutSessionID});
  await kit.present(
    (context) => showRunningWorkSheet(
      context,
      controller: conn,
      sessionID: checkoutSessionID,
      shellIDs: const {},
    ),
    settleFor: const Duration(seconds: 2),
  );
  await kit.tapKey(
    'work-shell-sh_tests',
    settleFor: const Duration(seconds: 2),
  );
  kit.expectText('Command output');
}

List<FolderEntry> _entries(String path, List<(String, bool)> names) => [
  for (final (name, git) in names)
    FolderEntry(name: name, path: '$path/$name', isGit: git),
];

/// The folder browser over the chooser, on a server on this phone.
Future<void> _folderBrowser(
  CensusKit kit,
  FolderLister list, {
  String start = '/root/projects',
  Duration settleFor = const Duration(seconds: 2),
}) async {
  await _chooser(kit);
  await kit.present(
    (context) => showModalBottomSheet<FolderBrowserChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FolderBrowserSheet(
        list: list,
        knownProjects: () async => {'/root/projects/shopfront'},
        start: start,
      ),
    ),
    settleFor: settleFor,
  );
  kit.expectText('Open a project');
}

MessageWithParts _todoTurn() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return MessageWithParts(
    info: messageInfo(
      'msg_assistant',
      'assistant',
      created: now - 60 * 1000,
      completed: now - 5 * 1000,
    ),
    parts: [
      textPart(
        'part_plan',
        'Here is the plan for the flaky checkout test. I will work through '
            'it in order:',
      ),
      Part(
        id: 'tool_todo',
        messageID: 'msg_assistant',
        type: 'tool',
        callID: 'tool_todo',
        toolName: 'todowrite',
        toolState: ToolState(
          status: 'completed',
          input: const {
            'todos': [
              {
                'content': 'Reproduce the flaky coupon test',
                'status': 'completed',
                'priority': 'high',
              },
              {
                'content': 'Wait on the settled cart state',
                'status': 'completed',
                'priority': 'high',
              },
              {
                'content': 'Run the checkout suite 20 times',
                'status': 'in_progress',
                'priority': 'medium',
              },
              {
                'content': 'Update the checkout README',
                'status': 'pending',
                'priority': 'low',
              },
              {
                'content': 'Mock the payment gateway',
                'status': 'cancelled',
                'priority': 'low',
              },
            ],
          },
        ),
      ),
    ],
  );
}

List<MessageWithParts> _todoTranscript() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    MessageWithParts(
      info: messageInfo(
        'msg_user',
        'user',
        created: now - 90 * 1000,
        completed: now - 90 * 1000,
      ),
      parts: [
        Part(
          id: 'part_user',
          messageID: 'msg_user',
          type: 'text',
          text: userPrompt,
        ),
      ],
    ),
    _todoTurn(),
  ];
}

// ---------------------------------------------------------------------------
// Shots
// ---------------------------------------------------------------------------

final eWorkspaceArea = CensusArea(
  'e-workspace',
  shots: [
    // -- The Work tab --------------------------------------------------------
    CensusShot(
      'workspace',
      state: 'loaded',
      (kit) async {
        final conn = await eController(otherProjects: true);
        await conn.setSessionPinned(
          eOnboardingID,
          true,
          locationRevision: conn.locationRevision,
        );
        await _work(kit, controller: conn);
        kit.expectText('Fix flaky checkout test');
      },
      note:
          'Laptop server on shopfront: one run in progress, a pinned '
          'conversation, recent ones; archived row and other projects '
          'below the fold.',
    ),
    CensusShot('workspace', state: 'needs-you', (kit) async {
      final conn = await eController(otherProjects: true);
      conn
        ..permissions = {samplePermission().id: samplePermission()}
        ..questions = {sampleQuestion().id: sampleQuestion()};
      await _work(kit, controller: conn);
      kit.expectText('Fix flaky checkout test');
    }, note: 'A command permission and a question are waiting.'),
    CensusShot('workspace', state: 'empty', (kit) async {
      final conn = await eController(sessions: const {}, busy: const {});
      await _work(kit, controller: conn, settleFor: const Duration(seconds: 3));
      kit.expectText('shopfront');
    }, note: 'A project with no conversations yet (teaching state).'),
    CensusShot('workspace', state: 'loading', (kit) async {
      final repository = ERepository()..holdProjects = Completer<void>();
      final conn =
          await eController(
              sessions: const {},
              busy: const {},
              repository: repository,
              otherProjects: true,
            )
            ..sessionsLoading = true;
      await _work(kit, controller: conn);
      kit.expectText('shopfront');
    }, note: 'First load: the project list and conversations are on the way.'),
    CensusShot('workspace-folder-chooser', state: 'phone-server', (kit) async {
      await _chooser(kit);
      kit.expectText('Create a new folder');
    }, note: 'A server this app runs: Create a new folder comes first.'),
    CensusShot('workspace-folder-chooser', state: 'remote-server', (kit) async {
      await _chooser(kit, canCreate: false);
      kit.expectText('Open a project folder');
    }, note: 'Any other server: folders can only be opened by path.'),
    CensusShot('workspace-folder-chooser', state: 'error', (kit) async {
      await _chooser(
        kit,
        projectsError: const ProductException(
          'Could not load projects: the connection was reset',
        ),
      );
    }, note: 'The project list could not load.'),
    CensusShot(
      'workspace-directory-details-dialog',
      (kit) async {
        final conn = await eController(
          directory: eApiDirectory,
          otherProjects: true,
        );
        await _work(kit, controller: conn);
        await kit.tapKey('active-session-directory');
        kit.expectVisible(find.byType(AlertDialog));
        kit.expectText('api');
      },
      note:
          'Work open in packages/api inside shopfront; the folder row opened.',
    ),
    CensusShot('workspace-context-sheet', (kit) async {
      await _work(kit);
      await kit.tapKey('current-project-entry');
      kit.expectVisible(find.byKey(const ValueKey('workspace-context-sheet')));
      kit.expectText('Switch project');
    }, note: 'Project header tapped; one cloud workspace listed.'),
    CensusShot('workspace-session-details-sheet', (kit) async {
      final conn = await eController(
        otherProjects: true,
        sessions: eSessions(shared: true),
      );
      await _work(kit, controller: conn);
      await _rowMenu(kit, darkModeSessionID, 'Details');
      kit.expectTextContaining('opncd.ai/share/k3v9Qd2m');
    }, note: 'Row menu › Details on a shared conversation.'),
    CensusShot('workspace-rename-session-dialog', (kit) async {
      await _work(kit);
      await _rowMenu(kit, darkModeSessionID, 'Rename');
      kit.expectText('Rename conversation');
    }),
    CensusShot('workspace-archive-session-sheet', (kit) async {
      await _work(kit);
      await _rowMenu(kit, darkModeSessionID, 'Archive');
      kit.expectText('Archive conversation?');
    }),
    CensusShot('workspace-share-session-sheet', (kit) async {
      await _work(kit);
      await _rowMenu(kit, darkModeSessionID, 'Share');
      kit.expectText('Share this conversation?');
    }),
    CensusShot('workspace-delete-session-sheet', (kit) async {
      await _work(kit);
      await _rowMenu(kit, darkModeSessionID, 'Delete');
      kit.expectText('Delete conversation?');
    }),
    CensusShot('workspace-archived-sheet', (kit) async {
      await _work(kit);
      await kit.tapKey('workspace-archived');
      kit.expectVisible(
        find.byKey(const ValueKey('archived-session-$eArchivedID')),
      );
    }),

    // -- Projects -------------------------------------------------------------
    CensusShot('projects', state: 'loaded', (kit) async {
      await _overWork(
        kit,
        (conn) =>
            ProjectsScreen(controller: conn, selectedProjectID: eProject.id),
      );
      kit.expectText('storefront-api');
    }),
    CensusShot('projects', state: 'error', (kit) async {
      final repository = ERepository();
      final conn = await eController(repository: repository);
      await _work(kit, controller: conn);
      repository.projectsError = const ProductException(
        'Could not load projects: the server took too long to answer',
      );
      await kit.push(
        ProjectsScreen(controller: conn, selectedProjectID: eProject.id),
        settleFor: const Duration(seconds: 2),
      );
      kit.expectTextContaining('took too long');
    }),
    CensusShot('projects', state: 'read-only', (kit) async {
      final conn = await eController(otherProjects: true)
        ..capabilityOverride = const ServerCapabilities(
          projectManagement: false,
        );
      await _overWork(
        kit,
        (conn) => ProjectsScreen(controller: conn, selectedProjectID: null),
        controller: conn,
      );
      kit.expectVisible(find.byKey(const ValueKey('projects-context-list')));
    }, note: 'A server that cannot manage projects: the read-only context.'),
    CensusShot('projects-rename-dialog', (kit) async {
      await _overWork(
        kit,
        (conn) =>
            ProjectsScreen(controller: conn, selectedProjectID: eProject.id),
      );
      await kit.tapKey('rename-project-${eProject.id}');
      kit.expectVisible(find.byKey(const ValueKey('project-name-input')));
    }),
    CensusShot('manage-project', (kit) async {
      await _overWork(
        kit,
        (conn) => ManageProjectScreen(controller: conn, project: eProject),
      );
      kit.expectText('Manage project');
      kit.expectText('Worktrees');
    }),
    CensusShot('project-folder-new-dialog', (kit) async {
      await _chooser(kit);
      await kit.tapKey('workspace-create-folder');
      await kit.enterText(
        find.byKey(const ValueKey('new-folder-name')),
        'loyalty-app',
      );
      kit.expectVisible(find.byKey(const ValueKey('new-folder-create')));
    }, note: 'From the folder chooser, a name typed.'),
    CensusShot('project-folder-open-dialog', state: 'filled', (kit) async {
      await _chooser(kit, canCreate: false);
      await kit.tapKey('workspace-open-folder');
      await kit.enterText(
        find.byKey(const ValueKey('open-folder-path')),
        '/home/dev/loyalty-app',
      );
      kit.expectVisible(find.byKey(const ValueKey('open-folder-confirm')));
    }, note: 'From the folder chooser on a remote server, a path typed.'),
    CensusShot('project-folder-open-dialog', state: 'missing', (kit) async {
      final conn = await _chooser(kit, canCreate: false);
      conn.folderProblem = 'There is no folder at /home/dev/loyalty-app.';
      await kit.tapKey('workspace-open-folder');
      await kit.enterText(
        find.byKey(const ValueKey('open-folder-path')),
        '/home/dev/loyalty-app',
      );
      await kit.tapKey('open-folder-confirm');
      kit.expectTextContaining('no folder at');
    }, note: 'The server says the typed folder does not exist.'),
    CensusShot('project-folder-browser', state: 'projects', (kit) async {
      await _folderBrowser(
        kit,
        (path) async => _entries(path, [
          ('design-system', true),
          ('notes', false),
          ('scratch', false),
          ('shopfront', true),
          ('storefront-api', true),
        ]),
      );
      kit.expectText('shopfront');
    }, note: 'Server on this phone, at its projects folder.'),
    CensusShot('project-folder-browser', state: 'inside', (kit) async {
      await _folderBrowser(
        kit,
        (path) async => _entries(path, [
          ('android', false),
          ('assets', false),
          ('docs', false),
          ('lib', false),
          ('test', false),
          ('web', false),
        ]),
        start: '/root/projects/shopfront',
      );
      kit.expectText('lib');
    }),
    CensusShot('project-folder-browser', state: 'loading', (kit) async {
      await _folderBrowser(
        kit,
        (_) => Completer<List<FolderEntry>>().future,
        settleFor: const Duration(seconds: 1),
      );
    }),
    CensusShot('project-folder-browser', state: 'error', (kit) async {
      await _folderBrowser(
        kit,
        (path) async => throw FolderListException(
          FolderListProblem.denied,
          "PathAccessException: Directory listing failed, path = '$path' "
          '(OS Error: Permission denied, errno = 13)',
        ),
      );
    }),

    // -- Project health -------------------------------------------------------
    CensusShot('project-health', state: 'loaded', (kit) async {
      final repository = ERepository();
      await _overWork(
        kit,
        (conn) => ProjectHealthScreen(
          repository: repository,
          capabilities: conn.capabilities,
        ),
        controller: await eController(repository: repository),
      );
      kit.expectText('fix/flaky-checkout');
    }),
    CensusShot('project-health', state: 'no-git', (kit) async {
      final repository = ERepository()
        ..health = const VersionControlHealth(
          setupState: VersionControlSetupState.absent,
          changes: [],
        );
      await _overWork(
        kit,
        (conn) => ProjectHealthScreen(
          repository: repository,
          capabilities: conn.capabilities,
        ),
        controller: await eController(repository: repository),
      );
      kit.expectVisible(
        find.byKey(const ValueKey('initialize-git-repository')),
      );
    }),
    CensusShot('project-health', state: 'error', (kit) async {
      final repository = ERepository()
        ..healthError = const ProductException(
          'Version control status is unavailable on this server',
        );
      await _overWork(
        kit,
        (conn) => ProjectHealthScreen(
          repository: repository,
          capabilities: conn.capabilities,
        ),
        controller: await eController(repository: repository),
      );
      kit.expectTextContaining('unavailable on this server');
    }, note: 'Version control failed; language services still listed.'),
    CensusShot('project-health-git-init-dialog', (kit) async {
      final repository = ERepository()
        ..health = const VersionControlHealth(
          setupState: VersionControlSetupState.absent,
          changes: [],
        );
      await _overWork(
        kit,
        (conn) => ProjectHealthScreen(
          repository: repository,
          capabilities: conn.capabilities,
        ),
        controller: await eController(repository: repository),
      );
      await kit.tapKey('initialize-git-repository');
      kit.expectVisible(
        find.byKey(const ValueKey('confirm-git-initialization')),
      );
    }),

    // -- Cloud environments ---------------------------------------------------
    CensusShot('managed-workspaces', state: 'loaded', (kit) async {
      final conn = await eController()
        ..workspace = 'wrk_ci';
      await _overWork(
        kit,
        (conn) => ManagedWorkspacesScreen(controller: conn, project: eProject),
        controller: conn,
      );
      kit.expectText('perf-lab');
    }, note: 'ci-sandbox is the open workspace.'),
    CensusShot('managed-workspaces', state: 'empty', (kit) async {
      final conn = await eController(repository: ERepository()..managed = []);
      await _overWork(
        kit,
        (conn) => ManagedWorkspacesScreen(controller: conn, project: eProject),
        controller: conn,
      );
      kit.expectText('Cloud environments');
    }),
    CensusShot('managed-workspaces', state: 'error', (kit) async {
      final conn = await eController(
        repository: ERepository()
          ..managedError = const ProductException(
            'Could not list environments: adapter daytona is not configured',
          ),
      );
      await _overWork(
        kit,
        (conn) => ManagedWorkspacesScreen(controller: conn, project: eProject),
        controller: conn,
      );
      kit.expectTextContaining('not configured');
    }),
    CensusShot('managed-workspaces-create-dialog', (kit) async {
      await _overWork(
        kit,
        (conn) => ManagedWorkspacesScreen(controller: conn, project: eProject),
      );
      await kit.tapKey('create-managed-workspace');
      kit.expectVisible(
        find.byKey(const ValueKey('confirm-create-managed-workspace')),
      );
    }),
    CensusShot('managed-workspaces-remove-dialog', (kit) async {
      await _overWork(
        kit,
        (conn) => ManagedWorkspacesScreen(controller: conn, project: eProject),
      );
      // The row's rarer acts open on long-press (screen-work-3, KIT-28).
      await kit.tester.longPress(
        find.byKey(const ValueKey('managed-workspace-wrk_perf')),
      );
      await kit.tester.pumpAndSettle();
      await kit.tapKey('environment-menu-remove');
      kit.expectVisible(
        find.byKey(const ValueKey('confirm-remove-managed-workspace')),
      );
    }),

    // -- Worktrees ------------------------------------------------------------
    CensusShot('worktrees', state: 'loaded', (kit) async {
      await _overWork(
        kit,
        (conn) => WorktreesScreen(controller: conn, project: eProject),
      );
      kit.expectText('dark-mode');
    }),
    CensusShot('worktrees', state: 'empty', (kit) async {
      await _overWork(
        kit,
        (conn) => WorktreesScreen(controller: conn, project: eProject),
        controller: await eController(
          repository: ERepository()..worktrees = [],
        ),
      );
      kit.expectText('Worktrees');
    }),
    CensusShot('worktrees-create-dialog', (kit) async {
      await _overWork(
        kit,
        (conn) => WorktreesScreen(controller: conn, project: eProject),
      );
      await kit.tapKey('create-worktree');
      kit.expectVisible(find.byKey(const ValueKey('confirm-create-worktree')));
    }),
    CensusShot('worktrees-reset-dialog', (kit) async {
      await _overWork(
        kit,
        (conn) => WorktreesScreen(controller: conn, project: eProject),
      );
      await kit.tap(
        find.descendant(
          of: find.byKey(const ValueKey('worktree-$eWorktreeRoot/dark-mode')),
          matching: find.byTooltip('Worktree actions'),
        ),
      );
      await kit.tap(find.text('Reset').last);
      kit.expectVisible(find.byKey(const ValueKey('confirm-reset-worktree')));
    }, note: 'The worktree has two changed files, listed as a warning.'),
    CensusShot('worktrees-remove-dialog', (kit) async {
      await _overWork(
        kit,
        (conn) => WorktreesScreen(controller: conn, project: eProject),
      );
      await kit.tap(
        find.descendant(
          of: find.byKey(const ValueKey('worktree-$eWorktreeRoot/dark-mode')),
          matching: find.byTooltip('Worktree actions'),
        ),
      );
      await kit.tap(find.text('Delete').last);
      kit.expectVisible(find.byKey(const ValueKey('confirm-remove-worktree')));
    }),

    // -- All conversations ----------------------------------------------------
    CensusShot('global-sessions', state: 'loaded', (kit) async {
      await _overWork(kit, (conn) => GlobalSessionsScreen(controller: conn));
      kit.expectText('Rename the spacing tokens');
    }, note: 'Conversations from three folders and a cloud environment.'),
    CensusShot('global-sessions', state: 'search', (kit) async {
      await _overWork(kit, (conn) => GlobalSessionsScreen(controller: conn));
      await kit.enterText(
        find.byKey(const ValueKey('global-session-search')),
        'checkout',
      );
      await kit.settle(const Duration(seconds: 1));
      kit.expectText('Fix flaky checkout test');
    }),
    CensusShot('global-sessions', state: 'error', (kit) async {
      await _overWork(
        kit,
        (conn) => GlobalSessionsScreen(controller: conn),
        controller: await eController(
          repository: ERepository()
            ..globalError = const ProductException(
              'Could not search sessions: the server took too long to answer',
            ),
        ),
      );
      kit.expectTextContaining('took too long');
    }),
    CensusShot('global-sessions-continue-here-sheet', (kit) async {
      await _overWork(kit, (conn) => GlobalSessionsScreen(controller: conn));
      await kit.tapKey('global-session-actions-ses_sandbox');
      await kit.tap(find.text('Continue here').last);
      kit.expectText('Continue this conversation here?');
    }, note: 'A conversation in the perf-lab cloud environment.'),

    // -- From the chat ----------------------------------------------------------
    CensusShot('session-destination-sheet', state: 'move', (kit) async {
      final conn = await _chat(kit);
      await kit.present(
        (context) => showSessionDestinationSheet(
          context,
          controller: conn,
          sessionID: checkoutSessionID,
          mode: SessionDestinationMode.move,
        ),
        settleFor: const Duration(seconds: 2),
      );
      kit.expectText('Move conversation');
      kit.expectText('api');
    }, note: 'Opened over the chat (command /move).'),
    CensusShot('session-destination-sheet', state: 'warp', (kit) async {
      final repository = ERepository()
        ..workspaces = [
          ...ERepository().workspaces,
          const WorkspaceInfo(
            id: 'wrk_perf',
            projectID: 'project_shopfront',
            name: 'perf-lab',
            type: 'daytona',
            directory: '/workspace/shopfront',
            status: 'disconnected',
          ),
        ];
      final conn = await _chat(kit, repository: repository);
      await kit.present(
        (context) => showSessionDestinationSheet(
          context,
          controller: conn,
          sessionID: checkoutSessionID,
          mode: SessionDestinationMode.warp,
        ),
        settleFor: const Duration(seconds: 2),
      );
      kit.expectText('ci-sandbox');
    }, note: 'Opened over the chat (command /warp).'),
    CensusShot('session-destination-confirm-dialog', (kit) async {
      final conn = await _chat(kit);
      await kit.present(
        (context) => showSessionDestinationSheet(
          context,
          controller: conn,
          sessionID: checkoutSessionID,
          mode: SessionDestinationMode.move,
        ),
        settleFor: const Duration(seconds: 2),
      );
      await kit.tapKey('move-destination-$eApiDirectory');
      kit.expectText('Move conversation?');
    }, note: 'Three uncommitted changes, so both move choices are offered.'),
    CensusShot('console-organization-sheet', (kit) async {
      final conn = await _chat(kit);
      await kit.present(
        (context) => showConsoleOrganizationSheet(context, controller: conn),
        settleFor: const Duration(seconds: 2),
      );
      kit.expectText('Shopfront Inc.');
    }, note: 'Opened over the chat (command /org).'),
    CensusShot('console-organization-switch-dialog', (kit) async {
      final conn = await _chat(kit);
      await kit.present(
        (context) => showConsoleOrganizationSheet(context, controller: conn),
        settleFor: const Duration(seconds: 2),
      );
      await kit.tapKey('console-org-acc_1-org_shopfront');
      kit.expectText('Switch organization?');
    }),

    // -- Isolated task ----------------------------------------------------------
    CensusShot('isolated-task-sheet', state: 'form', (kit) async {
      await _work(kit);
      await kit.tapKey('workspace-isolated-task');
      await kit.enterText(
        find.byKey(const ValueKey('isolated-task-name')),
        'coupon-banner',
      );
      kit.expectText('New task in a fresh worktree');
    }),
    CensusShot('isolated-task-sheet', state: 'creating', (kit) async {
      final repository = ERepository()
        ..createWorktreeHold = Completer<WorktreeInfo>();
      await _work(kit, controller: await eController(repository: repository));
      await kit.tapKey('workspace-isolated-task');
      await kit.tapKey('isolated-task-start');
      kit.expectText('Creating the worktree…');
    }),
    CensusShot('isolated-task-sheet', state: 'preparing', (kit) async {
      final hold = Completer<WorktreeInfo>();
      final repository = ERepository()..createWorktreeHold = hold;
      await _work(kit, controller: await eController(repository: repository));
      await kit.tapKey('workspace-isolated-task');
      await kit.enterText(
        find.byKey(const ValueKey('isolated-task-name')),
        'coupon-banner',
      );
      await kit.tapKey('isolated-task-start');
      hold.complete(
        const WorktreeInfo(
          name: 'coupon-banner',
          directory: '$eWorktreeRoot/coupon-banner',
          branch: 'opencode/coupon-banner',
        ),
      );
      await kit.settle();
      kit.expectTextContaining('OpenCode is preparing it');
    }),
    CensusShot('isolated-task-sheet', state: 'failed', (kit) async {
      final hold = Completer<WorktreeInfo>();
      final repository = ERepository()..createWorktreeHold = hold;
      final conn = await eController(repository: repository);
      await _work(kit, controller: conn);
      await kit.tapKey('workspace-isolated-task');
      await kit.enterText(
        find.byKey(const ValueKey('isolated-task-name')),
        'coupon-banner',
      );
      await kit.tapKey('isolated-task-start');
      hold.complete(
        const WorktreeInfo(
          name: 'coupon-banner',
          directory: '$eWorktreeRoot/coupon-banner',
          branch: 'opencode/coupon-banner',
        ),
      );
      await kit.settle();
      conn.handleEventForTesting(
        EventEnvelope(
          type: 'worktree.failed',
          directory: '$eWorktreeRoot/coupon-banner',
          project: eProject.id,
          properties: const {'message': 'setup: npm install exited 1'},
        ),
      );
      await kit.settle();
      kit.expectText('OpenCode could not prepare the worktree.');
    }),

    // -- Tasks and command output ----------------------------------------------
    CensusShot('running-work-sheet', state: 'loaded', (kit) async {
      final conn = await _chat(
        kit,
        busy: const {checkoutSessionID, 'ses_child_review'},
      );
      await kit.present(
        (context) => showRunningWorkSheet(
          context,
          controller: conn,
          sessionID: checkoutSessionID,
          shellIDs: const {'sh_analyze', 'sh_build'},
          onBackground: () async => null,
        ),
        settleFor: const Duration(seconds: 2),
      );
      kit.expectText('Tasks');
      kit.expectVisible(find.byKey(const ValueKey('work-shell-sh_tests')));
    }, note: 'Opened over the chat: one agent and one command running.'),
    CensusShot('running-work-sheet', state: 'empty', (kit) async {
      final repository = ERepository()
        ..shells = []
        ..children = [];
      final conn = await _chat(kit, repository: repository);
      await kit.present(
        (context) => showRunningWorkSheet(
          context,
          controller: conn,
          sessionID: checkoutSessionID,
          shellIDs: const {},
        ),
        settleFor: const Duration(seconds: 2),
      );
      kit.expectText('Tasks');
    }),
    CensusShot(
      'shell-output',
      (kit) async {
        await _shellOutput(kit);
        kit.expectText('Command output');
      },
      note:
          'A running flutter test, followed live. The output uses the '
          'generic "monospace" family; the census lends it JetBrains Mono '
          '(a device draws its system mono).',
    ),
    CensusShot('shell-output-stop-dialog', (kit) async {
      await _shellOutput(kit);
      await kit.tapText('Stop command');
      kit.expectText('Stop this command?');
    }),
    CensusShot('shell-output-timeout-sheet', (kit) async {
      await _shellOutput(kit);
      await kit.tapText('Change timeout');
      kit.expectText('The new timeout starts now.');
    }),

    // -- Embedded parts -----------------------------------------------------------
    CensusShot('embedded-session-inventory-footer', state: 'more', (kit) async {
      final conn = await eController()
        ..moreSessions = true;
      await _work(kit, controller: conn);
      final more = find.byKey(const ValueKey('session-inventory-more'));
      await kit.scrollTo(more);
      await kit.settle();
      kit.expectVisible(more);
    }, note: 'Host: the Work tab, scrolled to the end of a partial list.'),
    CensusShot('embedded-session-inventory-footer', state: 'error', (
      kit,
    ) async {
      final conn = await eController()
        ..moreSessions = true
        ..sessionsMoreError =
            'Could not load older conversations: the server took too long';
      await _work(kit, controller: conn);
      final more = find.byKey(const ValueKey('session-inventory-more'));
      await kit.scrollTo(more);
      await kit.settle();
      kit.expectTextContaining('older conversations');
    }, note: 'Host: the Work tab; the next page failed.'),
    CensusShot('embedded-mobile-task-list', (kit) async {
      await _chat(kit, transcript: _todoTranscript);
      final tasks = find.text('Tasks');
      await kit.scrollTo(tasks);
      await kit.tap(tasks.last);
      kit.expectVisible(find.byKey(const ValueKey('mobile-tasks-copy-all')));
    }, note: 'Host: the chat, the agent\'s task list tool card opened.'),
  ],
  notRendered: {},
);
