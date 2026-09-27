// Shared fixtures for screen-library-3's behaviour and golden tests: a
// connected Laptop profile whose repository reports providers with saved
// accounts and a server-side sign-in command, a controller that records
// what the sheets ask it to do, the tool inventory of the Tools page, and
// the Plugins page with a probe that never finds a team.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/plugin_inventory.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_probe.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/pending_auth.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/settings/plugins_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Library3Repository
    implements
        ProductRepository,
        IntegrationCredentialGateway,
        IntegrationCommandGateway,
        IntegrationAuthRecoveryGateway,
        PluginGateway {
  List<IntegrationInfo> integrations = library3Providers;
  List<CodingToolInfo> tools = library3Tools;
  List<String> registered = const ['bash', 'read', 'edit', 'task'];
  List<PluginInfo> plugins = const [
    PluginInfo(
      id: 'reviewer',
      status: PluginStatus.active,
      source: PluginSourceKind.package,
      packageName: '@example/reviewer',
      terminalUi: false,
    ),
  ];

  @override
  void setLocation({String? directory, String? workspace}) {}

  @override
  Future<List<IntegrationInfo>> listIntegrations() async => integrations;

  @override
  Future<List<McpServerInfo>> listMcpServers() async => const [];

  @override
  Future<List<McpResourceInfo>> listMcpResources() async => const [];

  @override
  Future<List<CodingToolInfo>> listCodingTools({
    required String providerID,
    required String modelID,
  }) async => tools;

  @override
  Future<List<String>> listCodingToolIDs() async => registered;

  @override
  Future<ExperimentalServerCapabilities> loadExperimentalCapabilities() async =>
      const ExperimentalServerCapabilities(backgroundSubagents: false);

  @override
  Future<List<PluginInfo>> listPlugins() async => plugins;

  @override
  Future<List<CommandInfo>> listCommands() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what the sheets ask for instead of reaching a server.
class Library3Controller extends ConnectionController {
  Library3Controller(super.store);

  final started = <String>[];
  final activated = <String>[];
  final renamed = <String>[];
  final removed = <String>[];
  int forgotten = 0;
  bool renameFails = false;
  List<PendingAuthAttempt> pending = const [];
  List<({String integrationID, PendingAuthKind kind})> uncertain = const [];

  @override
  ServerCapabilities get capabilities => const ServerCapabilities(
    integrationCredentials: true,
    integrationCommandAuth: true,
    pluginInventory: true,
  );

  @override
  Future<void> refreshCatalog() async {}

  @override
  String? pendingIntegrationCommand(
    String integrationID, {
    required int locationRevision,
  }) => null;

  @override
  Future<IntegrationAuthLaunch> startIntegrationCommand(
    String integrationID,
    String methodID, {
    String? label,
    required int locationRevision,
  }) async {
    started.add('$integrationID/$methodID');
    return const IntegrationAuthLaunch(
      attemptID: 'attempt-1',
      url: '',
      instructions: '',
      mode: IntegrationAuthMode.auto,
    );
  }

  @override
  Future<void> activateIntegrationCredential(
    String integrationID,
    String credentialID, {
    required int locationRevision,
  }) async => activated.add(credentialID);

  @override
  Future<void> renameIntegrationCredential(
    String integrationID,
    String credentialID,
    String label, {
    required int locationRevision,
  }) async {
    renamed.add(label);
    if (renameFails) throw StateError('synthetic');
  }

  @override
  Future<void> removeIntegrationCredential(
    String integrationID,
    String credentialID, {
    required int locationRevision,
  }) async => removed.add(credentialID);

  @override
  List<PendingAuthAttempt> get pendingIntegrationAuth => pending;

  @override
  List<({String integrationID, PendingAuthKind kind})>
  get uncertainIntegrationAuth => uncertain;

  @override
  Future<void> forgetIntegrationAuth(
    PendingAuthAttempt entry, {
    required int locationRevision,
  }) async => forgotten++;
}

const library3Providers = [
  IntegrationInfo(
    id: 'anthropic',
    name: 'Anthropic',
    methods: [IntegrationMethodInfo(type: 'key', label: 'API key')],
    connections: [
      IntegrationConnectionInfo(
        type: 'credential',
        id: 'cred-1',
        label: 'Work',
      ),
      IntegrationConnectionInfo(
        type: 'credential',
        id: 'cred-2',
        label: 'Personal',
      ),
      IntegrationConnectionInfo(type: 'env', label: 'ANTHROPIC_API_KEY'),
    ],
    connectionCount: 3,
  ),
  IntegrationInfo(
    id: 'cloud',
    name: 'Cloud',
    methods: [
      IntegrationMethodInfo(type: 'command', id: 'login', label: 'Cloud CLI'),
    ],
    connectionCount: 0,
  ),
];

const library3Tools = [
  CodingToolInfo(
    id: 'bash',
    description: 'Run a shell command in the active project.',
    parameters: {
      'type': 'object',
      'properties': {
        'command': {'type': 'string', 'description': 'The command to run'},
        'timeout': {'type': 'integer'},
        'background': {'type': 'boolean'},
      },
      'required': ['command'],
    },
  ),
  CodingToolInfo(
    id: 'read',
    description: 'Read a file from the project filesystem.',
    parameters: {
      'type': 'object',
      'properties': {
        'filePath': {'type': 'string'},
      },
      'required': ['filePath'],
    },
  ),
  CodingToolInfo(
    id: 'edit',
    description: 'Replace text in a file.',
    parameters: {
      'type': 'object',
      'properties': {
        'filePath': {'type': 'string'},
        'edits': {'type': 'array'},
      },
    },
  ),
];

/// A pending browser sign-in this device can pick up again.
PendingAuthAttempt library3Pending() => PendingAuthAttempt(
  attemptID: 'attempt-9',
  integrationID: 'cloud',
  kind: PendingAuthKind.oauth,
  mode: IntegrationAuthMode.code,
  profileID: 'library-3',
  origin: 'https://laptop.example',
  expiresAt: DateTime(2100).millisecondsSinceEpoch,
);

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'https://laptop.example');
  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(pluginInventory: true);
}

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Mocks the secure-storage channel ProfileStore reads (AGENTS.md trap).
void mockLibrary3SecureStorage() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null);
  });
}

Future<Library3Controller> library3Server({
  Library3Repository? repository,
}) async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'library-3',
        'name': 'Laptop',
        'baseUrl': 'https://laptop.example',
      },
    ]),
    'oc.activeProfile': 'library-3',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final controller = Library3Controller(store)
    ..api = _Api()
    ..repository = repository ?? Library3Repository()
    ..status = StreamStatus.connected
    ..selectedModel = ModelRef(providerID: 'anthropic', modelID: 'sonnet-4')
    ..catalog = const CatalogSnapshot(
      providers: [
        CatalogProvider(id: 'anthropic', name: 'Anthropic', enabled: true),
      ],
      models: [
        CatalogModel(
          providerID: 'anthropic',
          id: 'sonnet-4',
          name: 'Claude Sonnet 4',
          enabled: true,
          status: 'active',
          contextLimit: 200000,
          outputLimit: 64000,
          reasoning: true,
          attachments: true,
          tools: true,
          variants: [],
        ),
      ],
      agents: [],
    );
  return controller;
}

/// The Plugins page with a probe that never finds a team and never touches
/// the network.
Widget library3Plugins(ConnectionController controller) =>
    PluginsSettingsScreen(
      controller: controller,
      probe: (url, {city}) async => const ProbeUnreachable(error: 'no answer'),
    );
