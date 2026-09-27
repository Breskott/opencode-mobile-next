// Fakes shared by screen-work-3's behaviour tests and goldens: a server
// with cloud environments and their providers, a project's health, and a
// connection whose folder moves are recorded.
import 'package:flutter/material.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sw3Project = WorkspaceProject(
  id: 'project-1',
  name: 'loyalty-app',
  directory: '/work/loyalty-app',
  worktrees: [],
  updatedAt: 1,
);

class Sw3Repository implements ProductRepository {
  List<WorkspaceInfo> workspaces = [
    const WorkspaceInfo(
      id: 'wrk_ci',
      projectID: 'project-1',
      name: 'ci-sandbox',
      type: 'daytona',
      branch: 'main',
      directory: '/remote/ci',
      status: 'connected',
    ),
    const WorkspaceInfo(
      id: 'wrk_perf',
      projectID: 'project-1',
      name: 'perf-lab',
      type: 'daytona',
      branch: 'perf/cache',
      directory: '/remote/perf',
      status: 'error',
    ),
  ];
  List<WorkspaceAdapterInfo> adapters = const [
    WorkspaceAdapterInfo(
      type: 'daytona',
      name: 'Daytona',
      description: 'A sandbox in Daytona with its own copy of the project',
    ),
  ];
  Object? workspacesError;
  Object? createError;
  Object? removeError;
  int listCalls = 0;
  String? removedID;
  String? createdType;

  VersionControlHealth versionControl = const VersionControlHealth(
    branch: 'feature/loyalty',
    defaultBranch: 'main',
    changes: [
      VersionControlFile(
        path: 'lib/points.dart',
        status: 'modified',
        additions: 24,
        deletions: 3,
      ),
      VersionControlFile(
        path: 'test/points_test.dart',
        status: 'added',
        additions: 40,
        deletions: 0,
      ),
    ],
  );
  Object? versionControlError;
  List<LanguageServiceHealth> languageServices = const [
    LanguageServiceHealth(
      id: 'dart',
      name: 'Dart analysis server',
      root: '/work/loyalty-app',
      status: 'connected',
    ),
    LanguageServiceHealth(
      id: 'yaml',
      name: 'YAML language server',
      root: '/work/loyalty-app',
      status: 'error',
    ),
  ];
  List<FormatterHealth> formatters = const [
    FormatterHealth(name: 'dart format', extensions: ['.dart'], enabled: true),
    FormatterHealth(name: 'prettier', extensions: ['.md'], enabled: false),
  ];

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<WorkspaceInfo>> listManagedWorkspaces({
    required String projectDirectory,
  }) async {
    listCalls += 1;
    if (workspacesError case final error?) throw error;
    return List.of(workspaces);
  }

  @override
  Future<List<WorkspaceAdapterInfo>> listWorkspaceAdapters({
    required String projectDirectory,
  }) async => List.of(adapters);

  @override
  Future<WorkspaceInfo> createManagedWorkspace({
    required String projectDirectory,
    required String type,
    String? branch,
  }) async {
    createdType = type;
    if (createError case final error?) throw error;
    return WorkspaceInfo(
      id: 'wrk_new',
      projectID: 'project-1',
      name: 'new',
      type: type,
      branch: branch,
      directory: '/remote/new',
      status: 'connected',
    );
  }

  @override
  Future<void> removeManagedWorkspace({
    required String projectDirectory,
    required String id,
  }) async {
    if (removeError case final error?) throw error;
    removedID = id;
    workspaces = workspaces.where((w) => w.id != id).toList();
  }

  @override
  Future<VersionControlHealth> loadVersionControlHealth() async {
    if (versionControlError case final error?) throw error;
    return versionControl;
  }

  @override
  Future<void> initializeGitRepository() async {}

  @override
  Future<List<LanguageServiceHealth>> listLanguageServices() async =>
      languageServices;

  @override
  Future<List<FormatterHealth>> listFormatters() async => formatters;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Sw3Controller extends ConnectionController {
  Sw3Controller(super.store, this.fake) {
    repository = fake;
  }

  final Sw3Repository fake;
  final locations = <({String? directory, String? workspace})>[];
  String? probeProblem;

  @override
  Future<ProductRepository?> prepareActionRepository() async => fake;

  @override
  Future<void> selectLocation({String? directory, String? workspace}) async {
    locations.add((directory: directory, workspace: workspace));
    this.directory = directory;
    this.workspace = workspace;
    locationError = null;
    notifyListeners();
  }

  @override
  Future<String?> probeProjectFolder(String directory) async => probeProblem;
}

Future<Sw3Controller> sw3Controller([Sw3Repository? repository]) async {
  SharedPreferences.setMockInitialValues({});
  return Sw3Controller(
    ProfileStore(prefs: await SharedPreferences.getInstance()),
    repository ?? Sw3Repository(),
  );
}

/// [screen] pushed over a plain home, as the app pushes it.
Widget sw3Host(
  Widget screen, {
  ThemeData? theme,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: theme ?? AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Center(
      child: GestureDetector(
        key: const ValueKey('sw3-open'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => screen)),
        child: const SizedBox.square(dimension: 48),
      ),
    ),
  ),
);
