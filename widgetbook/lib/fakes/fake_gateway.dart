// A reusable fake server for the screens that list or open conversations.
//
// The app's screens read a [ConnectionController], which talks to a server
// through two seams: the transport ([OpenCodeApi], OpenCode 1's shape) and the
// operations gateway ([ProductRepository]). This file replaces both with
// in-memory versions over one [FakeServer], so any use-case can ask for
// "connected to a server with this data" and never reaches the network.
//
// What is real, what throws:
//   * Real, answered from [FakeServer]: sessions, session status, messages
//     (with text, reasoning, tool and file parts), prompts (recorded), abort,
//     rename, delete, projects, the model catalog, pending permissions and
//     questions, answering a permission.
//   * Empty lists: todos, diffs, files, commands, references, MCP servers,
//     integrations, terminals, workspaces.
//   * Everything else on [ProductRepository] keeps the app's own default (a
//     plain "unavailable on this server" failure) or, for members it does not
//     implement, throws NoSuchMethodError. Add a member here when a new
//     use-case needs it.
//
// [capabilities] is any [ServerCapabilities]: pass [ServerCapabilities.allV1]
// for an OpenCode 1 server, or a narrowed set to show an OpenCode 2 shape.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';

import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/state/connection.dart';

import 'fake_app.dart';

/// The folder every fake conversation lives in unless it names another.
const fakeProjectDirectory = '/home/dev/shopfront';

/// What a fake server holds. Mutable on purpose: a use-case builds one, then
/// the scene hands it to [FakeServer.connect].
class FakeServer {
  FakeServer({
    Map<String, Session>? sessions,
    Map<String, List<MessageWithParts>>? messages,
    Set<String>? busy,
    List<PermissionRequest>? permissions,
    List<PendingQuestion>? questions,
    List<WorkspaceProject>? projects,
    CatalogSnapshot? catalog,
    this.capabilities = ServerCapabilities.allV1,
    this.directory = fakeProjectDirectory,
  }) : sessions = sessions ?? {},
       messages = messages ?? {},
       busy = busy ?? {},
       permissions = permissions ?? [],
       questions = questions ?? [],
       projects = projects ?? [fakeProject()],
       catalog = catalog ?? fakeCatalog();

  final Map<String, Session> sessions;
  final Map<String, List<MessageWithParts>> messages;
  final Set<String> busy;
  final List<PermissionRequest> permissions;
  final List<PendingQuestion> questions;
  final List<WorkspaceProject> projects;
  final CatalogSnapshot catalog;
  final ServerCapabilities capabilities;
  final String directory;

  /// Held back: when set, loading a conversation never finishes (the
  /// "loading" state).
  Completer<void>? holdMessages;

  /// When set, loading a conversation fails with this text (a server that
  /// cannot be reached).
  String? messagesFailure;

  /// A send fails with this text.
  String? sendFailure;

  /// Prompts the screen sent, newest last.
  final prompts = <String>[];

  /// Replies the screen gave to permission requests.
  final answered = <({String id, String reply})>[];

  /// A real [ConnectionController] reporting a live connection to this
  /// server, on the shared fake app scope.
  Future<FakeApp> connect({List<FakeProfile>? profiles}) async {
    final app = await FakeApp.create(
      profiles: profiles ?? const [FakeProfile('main', 'Workstation')],
      connected: true,
      capabilities: capabilities,
      api: FakeServerApi(this),
      repository: FakeServerRepository(this),
      controllerFactory: (store) => FakeServerController(store, this),
    );
    app.connection
      ..directory = directory
      ..sessionsById = Map.of(sessions)
      ..busySessions = Set.of(busy)
      ..permissions = {for (final p in permissions) p.id: p}
      ..questions = {for (final q in questions) q.id: q};
    return app;
  }
}

/// OpenCode 1's transport over a [FakeServer].
class FakeServerApi extends OpenCodeApi {
  FakeServerApi(this.server) : super(baseUrl: 'http://localhost:4096');

  final FakeServer server;

  @override
  ServerCapabilities get capabilities => server.capabilities;

  @override
  Future<List<Session>> sessions() async => server.sessions.values.toList();

  @override
  Future<Map<String, String>> sessionStatuses() async => {
    for (final id in server.sessions.keys)
      id: server.busy.contains(id) ? 'busy' : 'idle',
  };

  @override
  Future<Session> session(String id) async =>
      server.sessions[id] ?? Session(id: id, directory: server.directory);

  @override
  Future<List<MessageWithParts>> messages(String id) async {
    await server.holdMessages?.future;
    final failure = server.messagesFailure;
    if (failure != null) throw ApiException(failure);
    return server.messages[id] ?? const [];
  }

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);

  @override
  Future<Session> createSession() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = Session(
      id: 'ses_new_${server.sessions.length + 1}',
      directory: server.directory,
      time: SessionTime(created: now, updated: now),
    );
    server.sessions[session.id] = session;
    return session;
  }

  @override
  Future<List<FileDiff>> diff(String id) async => const [];

  @override
  Future<List<Todo>> todos(String id) async => const [];

  @override
  Future<List<FileNode>> listFiles([String path = '']) async => const [];

  @override
  Future<FileContent> fileContent(String path) =>
      Future.error(ApiException('No such file in the fake server: $path'));

  @override
  Future<void> promptAsync(
    String sessionID, {
    required String text,
    ModelRef? model,
    String? agent,
    String? variant,
    List<PromptAttachment> attachments = const [],
    List<PromptAgentMention> agentMentions = const [],
    PromptDelivery? delivery,
  }) async {
    final failure = server.sendFailure;
    if (failure != null) throw ApiException(failure, statusCode: 503);
    server.prompts.add(text);
  }

  @override
  Future<void> abort(String sessionID) async => server.busy.remove(sessionID);

  @override
  Future<void> renameSession(String id, String title) async {}

  @override
  Future<void> deleteSession(String id) async => server.sessions.remove(id);
}

/// The operations gateway over a [FakeServer].
class FakeServerRepository implements ProductRepository {
  FakeServerRepository(this.server);

  final FakeServer server;

  @override
  void setLocation({String? directory, String? workspace}) {}

  // Growable on purpose: callers sort the list they get.
  @override
  Future<List<WorkspaceProject>> listProjects() async => [...server.projects];

  @override
  Future<ServerPage<GlobalSessionResult>> listGlobalSessions({
    String? search,
    bool includeArchived = false,
    String? cursor,
    int limit = 50,
  }) async {
    final query = (search ?? '').trim().toLowerCase();
    final found = [
      for (final session in server.sessions.values)
        if ((includeArchived || !session.archived) &&
            (query.isEmpty ||
                (session.title ?? '').toLowerCase().contains(query)))
          GlobalSessionResult(
            session: session,
            projectName: _nameOf(session.directory),
            projectDirectory: session.directory,
          ),
    ];
    return ServerPage(items: cursor == null ? found : const []);
  }

  String _nameOf(String? directory) {
    final parts = (directory ?? '').split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'project' : parts.last;
  }

  @override
  Future<List<WorkspaceInfo>> listWorkspaces() async => const [];

  @override
  Future<List<TerminalProcess>> listTerminals() async => const [];

  @override
  Future<CatalogSnapshot> loadCatalog() async => server.catalog;

  @override
  Future<List<CommandInfo>> listCommands() async => const [];

  @override
  Future<List<ReferenceInfo>> listReferences() async => const [];

  @override
  Future<List<McpServerInfo>> listMcpServers() async => const [];

  @override
  Future<List<McpResourceInfo>> listMcpResources() async => const [];

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A connection that never reaches for the network: reads that would ask the
/// server are answered from [FakeServer], and answering a permission clears it.
class FakeServerController extends ConnectionController {
  FakeServerController(super.store, this.server);

  final FakeServer server;

  @override
  Future<void> refreshPendingPermissions() async {}

  @override
  Future<void> refreshPendingQuestions() async {}

  @override
  Future<void> refreshPendingForms() async {}

  @override
  Future<void> refreshCatalog() async {}

  @override
  Future<void> answerPermission(
    String requestID,
    String response, {
    String? message,
    PendingRequestIdentity? expectedRequest,
  }) async {
    server.answered.add((id: requestID, reply: response));
    permissions.remove(requestID);
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Builders for sample data
// ---------------------------------------------------------------------------

WorkspaceProject fakeProject({
  String name = 'shopfront',
  String directory = fakeProjectDirectory,
}) => WorkspaceProject(
  id: 'project_$name',
  name: name,
  directory: directory,
  worktrees: const [],
  updatedAt: 1,
  isGit: true,
);

Session fakeSession(
  String id,
  String title, {
  Duration ago = const Duration(minutes: 5),
  String directory = fakeProjectDirectory,
  double? cost,
}) {
  final updated = DateTime.now().millisecondsSinceEpoch - ago.inMilliseconds;
  return Session(
    id: id,
    title: title,
    directory: directory,
    time: SessionTime(created: updated - 25 * 60 * 1000, updated: updated),
    cost: cost,
    model: 'anthropic/claude-sonnet-4',
    agent: 'build',
  );
}

/// Five providers' worth of models, two connected.
CatalogSnapshot fakeCatalog() {
  CatalogModel model(String providerID, String id, String name) => CatalogModel(
    id: id,
    providerID: providerID,
    name: name,
    enabled: true,
    status: 'active',
    contextLimit: 200000,
    outputLimit: 32000,
    reasoning: true,
    attachments: true,
    tools: true,
    variants: const [],
    cost: const ModelCost(inputPerMillion: 3, outputPerMillion: 15),
  );
  return CatalogSnapshot(
    providers: const [
      CatalogProvider(id: 'anthropic', name: 'Anthropic', enabled: true),
      CatalogProvider(id: 'openai', name: 'OpenAI', enabled: true),
    ],
    models: [
      model('anthropic', 'claude-sonnet-4', 'Claude Sonnet 4'),
      model('anthropic', 'claude-opus-4', 'Claude Opus 4'),
      model('openai', 'gpt-4-1', 'GPT-4.1'),
      model('openai', 'o3', 'o3'),
    ],
    agents: const [],
  );
}
