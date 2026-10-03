// Fakes behind the `e-workspace` census scenes: the "shopfront" project on
// the laptop server, with its sessions, projects, worktrees, cloud
// environments, health, server-wide search, Console organizations and
// managed shell commands. Invented data only; nothing reaches a network.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';

import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart' show StreamStatus;
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures.dart';

const eApiDirectory = '$projectDirectory/packages/api';
const eStorefront = '/home/dev/storefront-api';
const eDesignSystem = '/home/dev/design-system';
const eWorktreeRoot = '/home/dev/.local/share/opencode/worktree/shopfront';
const eArchivedID = 'ses_banner';
const eOnboardingID = 'ses_onboarding';

final _now = DateTime.now().millisecondsSinceEpoch;
const _minute = 60 * 1000;
const _hour = 60 * _minute;

Session eSession(
  String id,
  String title, {
  String directory = projectDirectory,
  int ago = 5 * _minute,
  int? archivedAgo,
  String? workspaceID,
  String? projectID,
  String? parentID,
  String? shareUrl,
  double? cost,
  SessionDiffSummary? summary,
}) => Session(
  id: id,
  title: title,
  directory: directory,
  workspaceID: workspaceID,
  projectID: projectID,
  parentID: parentID,
  shareUrl: shareUrl,
  cost: cost,
  summary: summary,
  model: 'anthropic/claude-sonnet-4',
  agent: 'build',
  time: SessionTime(
    created: _now - ago - 25 * _minute,
    updated: _now - ago,
    archived: archivedAgo == null ? null : _now - archivedAgo,
  ),
);

/// The shopfront sessions: the busy checkout run, three recent ones, one
/// more to pin, and two archived.
Map<String, Session> eSessions({bool archived = true, bool shared = false}) {
  final sessions = sampleSessions();
  if (shared) {
    final dark = sessions[darkModeSessionID]!;
    sessions[darkModeSessionID] = Session(
      id: dark.id,
      title: dark.title,
      directory: dark.directory,
      time: dark.time,
      cost: dark.cost,
      summary: dark.summary,
      model: dark.model,
      agent: dark.agent,
      shareUrl: 'https://opncd.ai/share/k3v9Qd2m',
    );
  }
  return {
    ...sessions,
    eOnboardingID: eSession(
      eOnboardingID,
      'Draft the onboarding checklist',
      ago: 2 * 24 * _hour,
    ),
    if (archived) ...{
      eArchivedID: eSession(
        eArchivedID,
        'Remove the old promo banner',
        ago: 9 * 24 * _hour,
        archivedAgo: 8 * 24 * _hour,
      ),
      'ses_fonts': eSession(
        'ses_fonts',
        'Try a variable font for headings',
        ago: 12 * 24 * _hour,
        archivedAgo: 11 * 24 * _hour,
      ),
    },
  };
}

const eProject = WorkspaceProject(
  id: 'project_shopfront',
  name: 'shopfront',
  directory: projectDirectory,
  worktrees: ['$eWorktreeRoot/checkout-retry'],
  updatedAt: 3,
);

const eProjects = [
  eProject,
  WorkspaceProject(
    id: 'project_storefront_api',
    name: 'storefront-api',
    directory: eStorefront,
    worktrees: [],
    updatedAt: 2,
  ),
  WorkspaceProject(
    id: 'project_design_system',
    name: 'design-system',
    directory: eDesignSystem,
    worktrees: [],
    updatedAt: 1,
  ),
];

/// The server behind every e-workspace scene. Each list can be replaced,
/// failed ([Object] errors) or held back ([Completer]s that never complete)
/// to show a loading state.
class ERepository extends CaptureRepository implements SessionReadStateGateway {
  List<WorkspaceProject> projects = List.of(eProjects);
  Object? projectsError;
  Completer<void>? holdProjects;

  List<WorkspaceInfo> workspaces = const [
    WorkspaceInfo(
      id: 'wrk_ci',
      projectID: 'project_shopfront',
      name: 'ci-sandbox',
      type: 'daytona',
      branch: 'opencode/ci-sandbox',
      directory: '/workspace/shopfront',
      status: 'connected',
    ),
  ];

  List<WorkspaceInfo> managed = const [
    WorkspaceInfo(
      id: 'wrk_ci',
      projectID: 'project_shopfront',
      name: 'ci-sandbox',
      type: 'daytona',
      branch: 'opencode/ci-sandbox',
      directory: '/workspace/shopfront',
      status: 'connected',
    ),
    WorkspaceInfo(
      id: 'wrk_perf',
      projectID: 'project_shopfront',
      name: 'perf-lab',
      type: 'daytona',
      branch: 'opencode/perf-lab',
      directory: '/workspace/shopfront',
      status: 'disconnected',
    ),
    WorkspaceInfo(
      id: 'wrk_preview',
      projectID: 'project_shopfront',
      name: 'preview-env',
      type: 'modal',
      directory: '/workspace/shopfront',
      status: 'error',
    ),
  ];
  Object? managedError;
  List<WorkspaceAdapterInfo> adapters = const [
    WorkspaceAdapterInfo(
      type: 'daytona',
      name: 'Daytona',
      description: 'Cloud sandboxes with a full dev container',
    ),
    WorkspaceAdapterInfo(
      type: 'modal',
      name: 'Modal',
      description: 'Short-lived GPU and CPU sandboxes',
    ),
  ];

  List<WorktreeInfo> worktrees = const [
    WorktreeInfo(
      name: 'checkout-retry',
      directory: '$eWorktreeRoot/checkout-retry',
      branch: 'opencode/checkout-retry',
    ),
    WorktreeInfo(
      name: 'dark-mode',
      directory: '$eWorktreeRoot/dark-mode',
      branch: 'opencode/dark-mode',
    ),
  ];
  List<VersionControlFile> worktreeChanges = const [
    VersionControlFile(
      path: 'lib/checkout/checkout_bloc.dart',
      status: 'modified',
      additions: 6,
      deletions: 2,
    ),
    VersionControlFile(
      path: 'test/checkout_test.dart',
      status: 'modified',
      additions: 5,
      deletions: 2,
    ),
  ];
  Completer<WorktreeInfo>? createWorktreeHold;

  VersionControlHealth health = const VersionControlHealth(
    branch: 'fix/flaky-checkout',
    defaultBranch: 'main',
    setupState: VersionControlSetupState.git,
    changes: [
      VersionControlFile(
        path: 'lib/checkout/checkout_bloc.dart',
        status: 'modified',
        additions: 6,
        deletions: 2,
      ),
      VersionControlFile(
        path: 'test/checkout_test.dart',
        status: 'modified',
        additions: 5,
        deletions: 2,
      ),
      VersionControlFile(
        path: 'lib/checkout/coupon_banner.dart',
        status: 'added',
        additions: 48,
        deletions: 0,
      ),
    ],
  );
  Object? healthError;
  List<LanguageServiceHealth> languageServices = const [
    LanguageServiceHealth(
      id: 'dart',
      name: 'Dart analysis server',
      root: projectDirectory,
      status: 'connected',
    ),
    LanguageServiceHealth(
      id: 'yaml',
      name: 'YAML language server',
      root: projectDirectory,
      status: 'error',
    ),
  ];
  List<FormatterHealth> formatters = const [
    FormatterHealth(name: 'dart format', extensions: ['.dart'], enabled: true),
    FormatterHealth(
      name: 'prettier',
      extensions: ['.json', '.yaml', '.md'],
      enabled: false,
    ),
  ];

  List<GlobalSessionResult> global = [
    for (final session in eSessions(archived: false).values)
      GlobalSessionResult(
        session: session,
        projectName: 'shopfront',
        projectDirectory: projectDirectory,
      ),
    GlobalSessionResult(
      session: eSession(
        'ses_rate_limit',
        'Add rate limiting to the orders endpoint',
        directory: eStorefront,
        ago: 40 * _minute,
      ),
      projectName: 'storefront-api',
      projectDirectory: eStorefront,
    ),
    GlobalSessionResult(
      session: eSession(
        'ses_tokens',
        'Rename the spacing tokens',
        directory: eDesignSystem,
        ago: 30 * _hour,
      ),
      projectName: 'design-system',
      projectDirectory: eDesignSystem,
    ),
    GlobalSessionResult(
      session: eSession(
        'ses_sandbox',
        'Profile the image pipeline',
        directory: '/workspace/shopfront',
        workspaceID: 'wrk_perf',
        ago: 5 * _hour,
      ),
      projectName: 'shopfront',
      projectDirectory: projectDirectory,
    ),
  ];
  Object? globalError;
  String? globalCursor;

  List<ProjectDirectoryInfo> directories = const [
    ProjectDirectoryInfo(directory: projectDirectory),
    ProjectDirectoryInfo(directory: eApiDirectory),
    ProjectDirectoryInfo(directory: '$projectDirectory/packages/web'),
    ProjectDirectoryInfo(directory: '$eWorktreeRoot/checkout-retry'),
  ];

  List<ConsoleOrganization> organizations = const [
    ConsoleOrganization(
      accountID: 'acc_1',
      accountEmail: 'dev@shopfront.example',
      accountUrl: 'https://opencode.ai',
      orgID: 'org_personal',
      orgName: 'Personal',
      active: true,
    ),
    ConsoleOrganization(
      accountID: 'acc_1',
      accountEmail: 'dev@shopfront.example',
      accountUrl: 'https://opencode.ai',
      orgID: 'org_shopfront',
      orgName: 'Shopfront Inc.',
      active: false,
    ),
    ConsoleOrganization(
      accountID: 'acc_2',
      accountEmail: 'contractor@agency.example',
      accountUrl: 'https://opencode.ai',
      orgID: 'org_agency',
      orgName: 'Northwind Agency',
      active: false,
    ),
  ];

  List<ManagedShell> shells = [
    ManagedShell(
      id: 'sh_tests',
      command:
          'FLUTTER_TEST=1 /usr/local/flutter/bin/flutter test test/checkout',
      status: ManagedShellStatus.running,
      sessionID: checkoutSessionID,
      startedAt: DateTime.now().subtract(
        const Duration(minutes: 2, seconds: 14),
      ),
    ),
    ManagedShell(
      id: 'sh_analyze',
      command: 'flutter analyze lib/checkout',
      status: ManagedShellStatus.exited,
      exitCode: 0,
      sessionID: checkoutSessionID,
      startedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      completedAt: DateTime.now().subtract(
        const Duration(minutes: 5, seconds: 21),
      ),
    ),
    ManagedShell(
      id: 'sh_build',
      command: 'flutter build web --release',
      status: ManagedShellStatus.exited,
      exitCode: 1,
      sessionID: checkoutSessionID,
      startedAt: DateTime.now().subtract(const Duration(minutes: 9)),
      completedAt: DateTime.now().subtract(const Duration(minutes: 7)),
    ),
  ];
  List<Session> children = [
    eSession(
      'ses_child_review',
      'Review the coupon edge cases',
      parentID: checkoutSessionID,
      ago: _minute,
    ),
    eSession(
      'ses_child_docs',
      'Update the checkout README',
      parentID: checkoutSessionID,
      ago: 3 * _minute,
    ),
  ];
  String shellOutput =
      '00:01 +0: loading test/checkout/checkout_test.dart\n'
      '00:03 +1: applies a coupon to the total\n'
      '00:04 +2: keeps the total when the coupon is invalid\n'
      '00:05 +3: clears the cart after payment\n'
      '00:06 +4: shows the settled price after a refresh\n'
      '00:07 +5: retries a declined card once\n'
      '00:09 +6: coupon banner hides after checkout\n'
      '00:11 +7: loading test/checkout/cart_repository_test.dart\n'
      '00:12 +8: merges duplicate cart lines\n'
      '00:14 +9: keeps quantities within stock\n';

  @override
  Future<List<WorkspaceProject>> listProjects() async {
    await holdProjects?.future;
    if (projectsError case final error?) throw error;
    return List.of(projects);
  }

  @override
  Future<WorkspaceProject?> loadCurrentProject() async => eProject;

  @override
  Future<WorkspaceProject> renameProject({
    required String projectID,
    required String projectDirectory,
    required String name,
  }) async => projects.firstWhere((p) => p.id == projectID);

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => List.of(workspaces);

  @override
  Future<List<WorkspaceInfo>> listManagedWorkspaces({
    required String projectDirectory,
  }) async {
    if (managedError case final error?) throw error;
    return List.of(managed);
  }

  @override
  Future<List<WorkspaceAdapterInfo>> listWorkspaceAdapters({
    required String projectDirectory,
  }) async => List.of(adapters);

  @override
  Future<void> syncWorkspaceList({required String projectDirectory}) async {}

  @override
  Future<List<WorktreeInfo>> listWorktrees({
    required String projectDirectory,
    String? projectID,
  }) async => List.of(worktrees);

  @override
  Future<WorktreeInfo> createWorktree({
    required String projectDirectory,
    String? name,
  }) =>
      createWorktreeHold?.future ??
      Future.value(
        WorktreeInfo(
          name: name ?? 'fresh-tree',
          directory: '$eWorktreeRoot/${name ?? 'fresh-tree'}',
          branch: 'opencode/${name ?? 'fresh-tree'}',
        ),
      );

  @override
  Future<List<VersionControlFile>> listWorktreeFileStatuses(
    String directory,
  ) async => worktreeChanges;

  @override
  Future<VersionControlHealth> loadVersionControlHealth() async {
    if (healthError case final error?) throw error;
    return health;
  }

  @override
  Future<void> initializeGitRepository() async {}

  @override
  Future<List<LanguageServiceHealth>> listLanguageServices() async =>
      languageServices;

  @override
  Future<List<FormatterHealth>> listFormatters() async => formatters;

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async {
    if (globalError case final error?) throw error;
    final query = search?.trim().toLowerCase() ?? '';
    return ServerPage(
      items: [
        for (final result in global)
          if (query.isEmpty ||
              (result.session.title ?? '').toLowerCase().contains(query))
            result,
      ],
      nextCursor: globalCursor,
    );
  }

  @override
  Future<Session> getSessionDetails(String id) async {
    for (final session in eSessions().values) {
      if (session.id == id) {
        return Session(
          id: session.id,
          title: session.title,
          projectID: eProject.id,
          directory: session.directory,
          time: session.time,
        );
      }
    }
    for (final result in global) {
      if (result.session.id == id) return result.session;
    }
    return Session(id: id, projectID: eProject.id, directory: projectDirectory);
  }

  @override
  Future<List<Session>> listSessionChildren(String id) async =>
      children.where((child) => child.parentID == id).toList();

  @override
  Future<List<ProjectDirectoryInfo>> listProjectDirectories(
    String projectID,
  ) async => directories;

  @override
  Future<List<ConsoleOrganization>> listConsoleOrganizations() async =>
      organizations;

  @override
  Future<ManagedShellList> loadRunningShells() async => ManagedShellList(
    supported: true,
    shells: shells.where((shell) => shell.running).toList(),
  );

  @override
  Future<ManagedShell?> getManagedShell(String id) async {
    for (final shell in shells) {
      if (shell.id == id) return shell;
    }
    return null;
  }

  @override
  Future<ManagedShellOutput> readManagedShellOutput(
    String id, {
    required int cursor,
    int limit = 65536,
  }) async {
    final bytes = utf8.encode(shellOutput);
    final start = cursor.clamp(0, bytes.length);
    return ManagedShellOutput(
      text: utf8.decode(bytes.sublist(start)),
      cursor: bytes.length,
      size: bytes.length,
      truncated: false,
    );
  }

  @override
  Future<void> stopManagedShell(String id) async {}

  @override
  Future<ManagedShell> setManagedShellTimeout(
    String id,
    Duration? timeout,
  ) async => shells.firstWhere((shell) => shell.id == id);

  @override
  Future<String?> managedShellServerIdentity() async => 'laptop-server';

  @override
  Future<void> viewSession(String sessionID, int idle) async {}
}

/// The capture API with the history as one page (the chat reads pages).
class EApi extends CaptureApi {
  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);
}

/// A connected controller that never reaches for the network: locations are
/// switched in memory, the session inventory is what the scene hands it, and
/// the other projects and servers are fixed.
class EController extends CaptureController {
  EController(super.store);

  List<ProfileLocation> recents = const [];
  List<ElsewhereConversation> elsewhere = const [];

  /// Never completes: the saved project stays "being restored".
  bool holdSelection = false;

  /// Replaces [hasMoreSessions] (a private cursor in the real controller).
  bool? moreSessions;

  /// What [probeProjectFolder] answers for any path.
  String? folderProblem;

  /// Narrows the server's features (e.g. a server that cannot manage
  /// projects).
  ServerCapabilities? capabilityOverride;

  @override
  ServerCapabilities get capabilities =>
      capabilityOverride ?? super.capabilities;

  @override
  bool get hasMoreSessions => moreSessions ?? super.hasMoreSessions;

  @override
  List<ProfileLocation> get recentLocations => recents;

  @override
  Future<List<ElsewhereConversation>> conversationsElsewhere({
    int limit = 6,
  }) async => elsewhere;

  @override
  Future<void> refreshSessions() async {}

  @override
  Future<void> loadMoreSessions() async {}

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;

  @override
  Future<void> selectInitialLocation({
    String? directory,
    String? workspace,
  }) async {
    if (holdSelection) await Completer<void>().future;
  }

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    if (holdSelection) await Completer<void>().future;
    if (this.directory != directory || this.workspace != workspace) {
      locationRevision++;
    }
    this.directory = directory;
    this.workspace = workspace;
    notifyListeners();
  }

  @override
  Future<String?> probeProjectFolder(String directory) async => folderProblem;

  @override
  Future<void> switchConsoleOrganization(
    ConsoleOrganization organization,
  ) async {}
}

/// The laptop server, open on shopfront (or on no folder when [directory] is
/// null), with [sessions] listed and [busy] running.
Future<EController> eController({
  String? directory = projectDirectory,
  Map<String, Session>? sessions,
  Set<String> busy = const {checkoutSessionID},
  ERepository? repository,
  CaptureApi? api,
  bool otherProjects = false,
  bool savedLocation = false,
  bool phone = false,
  bool adopt = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  // [phone]: the OpenCode server this app runs on the phone (folders can be
  // created and browsed there).
  final profile = phone
      ? ServerProfile(
          id: 'phone',
          name: 'This phone',
          baseUrl: 'http://127.0.0.1:4096',
        )
      : ServerProfile(
          id: 'laptop',
          name: 'Laptop',
          baseUrl: 'http://192.168.1.20:4096',
        );
  final store = SeededProfileStore(prefs: prefs, seeded: [profile]);
  if (savedLocation) {
    await store.setLocation(profile.id, directory: projectDirectory);
  }
  final activeApi = api ?? CaptureApi();
  final listed = sessions ?? eSessions();
  activeApi.sessionsById = Map.of(listed);
  activeApi.busy = Set.of(busy);
  final controller = EController(store)
    ..api = activeApi
    ..repository = repository ?? ERepository()
    ..status = StreamStatus.connected
    ..directory = directory
    ..sessionsById = Map.of(listed)
    ..busySessions = Set.of(busy);
  if (adopt) controller.adoptConnectedProfileForTesting(profile);
  if (otherProjects) {
    controller
      ..recents = const [
        ProfileLocation(directory: projectDirectory),
        ProfileLocation(directory: eStorefront),
        ProfileLocation(directory: eDesignSystem),
      ]
      ..elsewhere = [
        ElsewhereConversation(
          session: eSession(
            'ses_rate_limit',
            'Add rate limiting to the orders endpoint',
            directory: eStorefront,
            ago: 40 * _minute,
          ),
          directory: eStorefront,
          running: true,
        ),
        ElsewhereConversation(
          session: eSession(
            'ses_tokens',
            'Rename the spacing tokens',
            directory: eDesignSystem,
            ago: 30 * _hour,
          ),
          directory: eDesignSystem,
          running: false,
        ),
      ];
  }
  return controller;
}
