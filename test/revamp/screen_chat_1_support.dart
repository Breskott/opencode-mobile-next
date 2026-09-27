// Fixtures shared by screen-chat-1's behaviour tests and goldens: a saved
// server whose project has two folders and two cloud machines, working
// changes, and two Console accounts. Synthetic only; nothing reaches a
// server.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart' show StreamStatus;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/capture/fixtures.dart' show captureTheme;

class ChatOneRepository extends ProductRepository {
  List<ProjectDirectoryInfo> directories = const [
    ProjectDirectoryInfo(directory: '/work/acme'),
    ProjectDirectoryInfo(
      directory: '/work/checkout-retry',
      strategy: 'git_worktree',
    ),
  ];
  List<WorkspaceInfo> workspaces = const [
    WorkspaceInfo(
      id: 'ws-review',
      projectID: 'project-1',
      name: 'Review machine',
      type: 'cloud',
      directory: '/remote/review',
      status: 'connected',
    ),
    WorkspaceInfo(
      id: 'ws-offline',
      projectID: 'project-1',
      name: 'Night build',
      type: 'cloud',
      status: 'disconnected',
    ),
  ];
  List<VersionControlFile> changes = const [
    VersionControlFile(
      path: 'lib/checkout.dart',
      status: 'modified',
      additions: 4,
      deletions: 1,
    ),
    VersionControlFile(
      path: 'test/checkout_test.dart',
      status: 'modified',
      additions: 12,
      deletions: 0,
    ),
  ];
  List<ConsoleOrganization> organizations = const [
    ConsoleOrganization(
      accountID: 'acct-1',
      accountEmail: 'sam@example.com',
      accountUrl: 'https://console.example.com',
      orgID: 'org-shop',
      orgName: 'Shopfront Inc.',
      active: true,
    ),
    ConsoleOrganization(
      accountID: 'acct-1',
      accountEmail: 'sam@example.com',
      accountUrl: 'https://console.example.com',
      orgID: 'org-side',
      orgName: 'Side projects',
      active: false,
    ),
    ConsoleOrganization(
      accountID: 'acct-2',
      accountEmail: 'sam@agency.example',
      accountUrl: 'https://console.example.com',
      orgID: 'org-client',
      orgName: 'Client work',
      active: false,
    ),
  ];

  @override
  Future<Session> getSessionDetails(String id) async => Session(
    id: id,
    title: 'Fix flaky checkout test',
    projectID: 'project-1',
    directory: '/work/acme',
  );

  @override
  Future<List<WorkspaceProject>> listProjects() async => const [
    WorkspaceProject(
      id: 'project-1',
      name: 'Acme',
      directory: '/work/acme',
      worktrees: ['/work/checkout-retry'],
      updatedAt: 1,
    ),
  ];

  @override
  Future<List<ProjectDirectoryInfo>> listProjectDirectories(
    String projectID,
  ) async => directories;

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => workspaces;

  @override
  Future<VersionControlHealth> loadVersionControlHealth() async =>
      VersionControlHealth(branch: 'fix/checkout', changes: changes);

  @override
  Future<List<ConsoleOrganization>> listConsoleOrganizations() async =>
      organizations;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records moves and switches instead of reconnecting; [refuse] makes each
/// of them fail as a server would.
class ChatOneConnection extends ConnectionController {
  ChatOneConnection(super.store, this.repo) {
    repository = repo;
    status = StreamStatus.connected;
  }
  final ChatOneRepository repo;
  Object? refuse;
  final moves = <(String, bool)>[];
  final warps = <(String?, bool)>[];
  final switched = <String>[];

  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async => repo;

  @override
  Future<void> moveSessionToDirectory(
    String sessionID, {
    required String directory,
    required bool moveChanges,
  }) async {
    if (refuse case final error?) throw error;
    moves.add((directory, moveChanges));
  }

  @override
  Future<void> warpSessionToWorkspace(
    String sessionID, {
    required String directory,
    required String? workspaceID,
    required bool copyChanges,
  }) async {
    if (refuse case final error?) throw error;
    warps.add((workspaceID, copyChanges));
  }

  @override
  Future<void> switchConsoleOrganization(
    ConsoleOrganization organization,
  ) async {
    if (refuse case final error?) throw error;
    switched.add(organization.orgID);
  }
}

/// A connection on a saved profile (the move sheet pins it).
Future<ChatOneConnection> chatOneConnection([ChatOneRepository? repo]) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'p1',
        'name': 'Laptop',
        'baseUrl': 'http://localhost',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'p1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final connection = ChatOneConnection(store, repo ?? ChatOneRepository());
  connection
    ..directory = '/work/acme'
    ..sessionsById = {
      'ses_a': Session(
        id: 'ses_a',
        title: 'Fix flaky checkout test',
        projectID: 'project-1',
        directory: '/work/acme',
      ),
    };
  addTearDown(connection.dispose);
  return connection;
}

Widget chatOneApp(
  Widget home, {
  bool light = false,
  double scale = 1,
  GlobalKey? boundary,
  GlobalKey<NavigatorState>? navigator,
}) {
  final app = MaterialApp(
    navigatorKey: navigator,
    debugShowCheckedModeBanner: false,
    theme: captureTheme(light: light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
  return boundary == null ? app : RepaintBoundary(key: boundary, child: app);
}

/// A blank page with one button that runs [open] from a context under the
/// app's navigator.
Widget opener(Future<void> Function(BuildContext context) open) => Builder(
  builder: (context) => Center(
    child: TextButton(
      onPressed: () => open(context),
      child: const Text('Open'),
    ),
  ),
);
