// Census scenes for the ledger part `j2-library`
// (docs/design/ui-ledger/parts/j2-library.json). See tool/capture/census_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/mcp_oauth.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/pending_auth.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/screens/mcp_setup_screen.dart';
import 'package:opencode_mobile/ui/screens/tools_screen.dart';

import '../../fixtures.dart';
import '../census_core.dart';

// ---------------------------------------------------------------------------
// Fixture data
// ---------------------------------------------------------------------------

List<IntegrationInfo> _fixtureIntegrations() => const [
  IntegrationInfo(
    id: 'anthropic',
    name: 'Anthropic',
    methods: [IntegrationMethodInfo(type: 'key', id: 'key', label: 'API key')],
    connections: [
      IntegrationConnectionInfo(
        type: 'credential',
        id: 'cred-1',
        label: 'Primary key',
      ),
    ],
    connectionCount: 1,
  ),
  IntegrationInfo(
    id: 'openai',
    name: 'OpenAI',
    methods: [IntegrationMethodInfo(type: 'key', id: 'key', label: 'API key')],
    connectionCount: 0,
  ),
  IntegrationInfo(
    id: 'google',
    name: 'Google',
    methods: [
      IntegrationMethodInfo(type: 'key', id: 'key', label: 'API key'),
      IntegrationMethodInfo(
        type: 'oauth',
        id: 'oauth',
        label: 'Sign in with Google',
      ),
    ],
    connectionCount: 0,
  ),
  IntegrationInfo(
    id: 'groq',
    name: 'Groq',
    methods: [
      IntegrationMethodInfo(
        type: 'oauth',
        id: 'oauth',
        label: 'Sign in with Groq',
        prompts: [
          {
            'key': 'workspace',
            'type': 'text',
            'message': 'Workspace URL',
            'required': true,
          },
        ],
      ),
    ],
    connectionCount: 0,
  ),
  IntegrationInfo(
    id: 'ollama',
    name: 'Ollama',
    methods: [
      IntegrationMethodInfo(
        type: 'command',
        id: 'signin',
        label: 'Sign in from the server',
      ),
    ],
    connectionCount: 0,
  ),
];

List<McpServerInfo> _fixtureMcpServers() => const [
  McpServerInfo(name: 'docs', status: 'connected'),
  McpServerInfo(name: 'linear', status: 'needs_auth'),
  McpServerInfo(name: 'search', status: 'failed', error: 'Connection refused'),
];

List<McpResourceInfo> _fixtureMcpResources() => const [
  McpResourceInfo(
    name: 'README',
    server: 'docs',
    uri: 'docs://readme',
    description: 'Project overview',
    mimeType: 'text/markdown',
  ),
];

const _mcpOAuthUrl = 'https://mcp.example.com/oauth/authorize?client_id=demo';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _LibraryApi extends CaptureApi {
  @override
  ServerCapabilities get capabilities => const ServerCapabilities(
    integrationCommandAuth: true,
    integrationCredentials: true,
    mcpRuntimeRemovals: true,
  );
}

class _LibraryRepository extends CaptureRepository
    implements
        IntegrationCommandGateway,
        IntegrationCredentialGateway,
        McpRemovalGateway {
  _LibraryRepository() {
    integrations = _fixtureIntegrations();
  }

  @override
  Future<List<CommandInfo>> listCommands() async => const [
    CommandInfo(
      name: 'review',
      description: 'Review the current diff for bugs',
      subtask: false,
    ),
    CommandInfo(
      name: 'deploy',
      description: 'Ship the current build to staging',
      subtask: true,
    ),
  ];

  @override
  Future<List<SkillInfo>> listSkills() async => const [
    SkillInfo(
      id: 'code-review',
      name: 'Code review',
      description: 'Reviews a diff for correctness and style',
      location: '.opencode/skills/code-review/SKILL.md',
      content:
          '# Code review\n\nChecklist for reviewing a diff:\n'
          '- Correctness\n- Tests\n- Style',
      slashCommand: false,
    ),
    SkillInfo(
      id: 'release-notes',
      name: 'Release notes',
      description: 'Drafts release notes from recent commits',
      location: '~/.config/opencode/skills/release-notes/SKILL.md',
      content: '# Release notes\n\nSummarize commits since the last tag.',
      slashCommand: false,
    ),
  ];

  @override
  Future<List<ReferenceInfo>> listReferences() async => const [
    ReferenceInfo(
      name: 'design-system',
      path: 'docs/design/design-standard.md',
      description: "The app-wide design language",
    ),
    ReferenceInfo(name: 'api-contract', path: 'contracts/openapi.yaml'),
  ];

  @override
  Future<List<McpServerInfo>> listMcpServers() async => _fixtureMcpServers();

  @override
  Future<List<McpResourceInfo>> listMcpResources() async =>
      _fixtureMcpResources();

  @override
  Future<List<CodingToolInfo>> listCodingTools({
    required String providerID,
    required String modelID,
  }) async => const [
    CodingToolInfo(
      id: 'bash',
      description: 'Run a shell command in the project',
      parameters: {
        'type': 'object',
        'properties': {
          'command': {'type': 'string'},
        },
      },
    ),
    CodingToolInfo(
      id: 'edit',
      description: 'Edit a file',
      parameters: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'diff': {'type': 'string'},
        },
      },
    ),
  ];

  @override
  Future<List<String>> listCodingToolIDs() async => const ['bash', 'edit'];

  @override
  Future<ExperimentalServerCapabilities> loadExperimentalCapabilities() async =>
      const ExperimentalServerCapabilities(backgroundSubagents: true);

  // -- provider connect/disconnect -----------------------------------------

  @override
  Future<void> connectIntegrationKey(
    String id,
    String key, {
    String? label,
  }) async {}

  @override
  Future<void> disconnectIntegration(IntegrationInfo integration) async {}

  @override
  Future<void> refreshProviderRuntime() async {}

  @override
  Future<IntegrationAuthLaunch> startIntegrationOAuth(
    String id,
    String methodID, {
    Map<String, String>? inputs,
    String? label,
  }) async => const IntegrationAuthLaunch(
    attemptID: 'attempt-oauth-1',
    url: _mcpOAuthUrl,
    instructions: 'Approve access, then return here.',
    mode: IntegrationAuthMode.code,
  );

  @override
  Future<IntegrationAuthStatus> integrationOAuthStatus(
    String attemptID,
  ) async => const IntegrationAuthStatus(state: IntegrationAuthState.pending);

  @override
  Future<void> completeIntegrationOAuth(
    String attemptID, {
    String? code,
  }) async {}

  @override
  Future<void> cancelIntegrationOAuth(String attemptID) async {}

  // -- IntegrationCommandGateway --------------------------------------------

  @override
  Future<IntegrationAuthLaunch> startIntegrationCommand(
    String integrationID,
    String methodID, {
    String? label,
  }) async => const IntegrationAuthLaunch(
    attemptID: 'attempt-cmd-1',
    url: '',
    instructions: '',
    mode: IntegrationAuthMode.auto,
  );

  @override
  Future<IntegrationAuthStatus> integrationCommandStatus(
    String integrationID,
    String attemptID,
  ) async => const IntegrationAuthStatus(state: IntegrationAuthState.pending);

  @override
  Future<void> cancelIntegrationCommand(
    String integrationID,
    String attemptID,
  ) async {}

  // -- IntegrationCredentialGateway ------------------------------------------

  @override
  Future<void> renameCredential(String id, String label) async {}

  @override
  Future<void> activateCredential(String id) async {}

  @override
  Future<void> removeCredential(String id) async {}

  // -- MCP server actions -----------------------------------------------------

  @override
  Future<void> removeMcpServer(String name) async {}

  @override
  Future<void> connectMcp(String name) async {}

  @override
  Future<void> disconnectMcp(String name) async {}

  @override
  Future<McpAuthLaunch> startMcpAuthentication(String name) async =>
      McpAuthLaunch(
        authorizationUrl: Uri.parse(_mcpOAuthUrl),
        oauthState: 'state-1',
      );

  @override
  Future<McpServerInfo> completeMcpAuthentication(
    String name,
    String code,
  ) async => const McpServerInfo(name: 'linear', status: 'connected');

  @override
  Future<void> cancelMcpAuthentication(String name) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<CaptureController> _libraryController(CensusKit kit) async {
  return kit.connected(api: _LibraryApi(), repository: _LibraryRepository());
}

Future<CaptureController> _integrationsHost(
  CensusKit kit, {
  IntegrationsMode mode = IntegrationsMode.all,
}) async {
  final controller = await _libraryController(kit);
  await kit.pumpApp(
    IntegrationsScreen(
      controller: controller,
      mode: mode,
      authorizationLauncher: (_) async => true,
    ),
    controller: controller,
  );
  return controller;
}

// ---------------------------------------------------------------------------
// Area
// ---------------------------------------------------------------------------

final j2LibraryArea = CensusArea(
  'j2-library',
  shots: [
    // ---- Commands --------------------------------------------------------
    CensusShot('commands', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        CommandsScreen(controller: controller),
        controller: controller,
      );
      kit.expectText('/review');
    }),

    // ---- Skills ------------------------------------------------------------
    CensusShot('skills', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        SkillsScreen(controller: controller),
        controller: controller,
      );
      kit.expectText('Code review');
    }),
    CensusShot('skills-preview-sheet', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        SkillsScreen(controller: controller),
        controller: controller,
      );
      await kit.tapText('Code review');
      kit.expectVisible(find.byKey(const ValueKey('skill-content-preview')));
    }),
    CensusShot('skill-activation-sheet', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        SkillsScreen(controller: controller, sessionID: checkoutSessionID),
        controller: controller,
      );
      await kit.tapText('Code review');
      kit.expectVisible(find.byKey(const ValueKey('skill-activate')));
    }),

    // ---- References --------------------------------------------------------
    CensusShot('references', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        ReferencesScreen(controller: controller),
        controller: controller,
      );
      kit.expectVisible(find.byKey(const ValueKey('reference-design-system')));
    }),

    // ---- Tools ---------------------------------------------------------------
    CensusShot('tools', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        ToolsScreen(
          controller: controller,
          initialModel: ModelRef(
            providerID: 'anthropic',
            modelID: 'claude-sonnet-4',
          ),
        ),
        controller: controller,
      );
      kit.expectVisible(find.byKey(const ValueKey('coding-tool-bash')));
    }),
    CensusShot('tools-detail-sheet', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        ToolsScreen(
          controller: controller,
          initialModel: ModelRef(
            providerID: 'anthropic',
            modelID: 'claude-sonnet-4',
          ),
        ),
        controller: controller,
      );
      await kit.tapKey('coding-tool-bash');
      kit.expectVisible(find.byTooltip('Copy parameter schema'));
    }),

    // ---- Integrations: the screen itself -------------------------------------
    CensusShot('integrations', state: 'loaded', (kit) async {
      await _integrationsHost(kit);
      kit.expectVisible(
        find.byKey(const ValueKey('disconnect-provider-anthropic')),
      );
      kit.expectVisible(find.byKey(const ValueKey('connect-provider-openai')));
    }),

    // ---- Connect flows -------------------------------------------------------
    CensusShot('integrations-connect-method-sheet', (kit) async {
      await _integrationsHost(kit);
      await kit.tapKey('connect-provider-google');
      kit.expectText('API key');
      kit.expectText('Sign in with Google');
    }),
    CensusShot('integrations-connect-key-dialog', (kit) async {
      await _integrationsHost(kit);
      await kit.tapKey('connect-provider-openai');
      kit.expectText('Connect OpenAI');
    }),
    CensusShot('integrations-oauth-inputs-dialog', (kit) async {
      await _integrationsHost(kit);
      await kit.tapKey('connect-provider-groq');
      kit.expectVisible(find.byKey(const ValueKey('oauth-prompt-workspace')));
    }),
    CensusShot('integrations-authorization-launch-dialog', (kit) async {
      await _integrationsHost(kit);
      await kit.tapKey('connect-provider-groq');
      await kit.enterText(
        find.byKey(const ValueKey('oauth-prompt-workspace')),
        'https://example.opencode.dev',
      );
      await kit.tap(find.widgetWithText(FilledButton, 'Continue'));
      kit.expectText('Open authorization page?');
    }),

    // ---- Disconnect / manage / remove -----------------------------------
    CensusShot('integrations-disconnect-provider-sheet', (kit) async {
      await _integrationsHost(kit);
      await kit.tapKey('disconnect-provider-anthropic');
      kit.expectVisible(
        find.byKey(const ValueKey('confirm-provider-disconnect')),
      );
    }),
    CensusShot('credential-management-sheet', (kit) async {
      await _integrationsHost(kit);
      await kit.tap(find.widgetWithText(TextButton, 'Manage accounts'));
      kit.expectText('Primary key');
    }),
    CensusShot('credential-management-sheet-rename-dialog', (kit) async {
      await _integrationsHost(kit);
      await kit.tap(find.widgetWithText(TextButton, 'Manage accounts'));
      await kit.tap(find.widgetWithText(TextButton, 'Rename account'));
      kit.expectText('Account label');
    }),
    CensusShot('credential-management-sheet-remove-sheet', (kit) async {
      await _integrationsHost(kit);
      await kit.tap(find.widgetWithText(TextButton, 'Manage accounts'));
      await kit.tap(
        find.descendant(
          of: find.byType(Card),
          matching: find.widgetWithText(TextButton, 'Remove'),
        ),
      );
      kit.expectText('Remove Primary key?');
    }),
    CensusShot(
      'integrations-remove-mcp-sheet',
      (kit) async {
        await _integrationsHost(kit);
        await kit.tap(find.widgetWithText(TextButton, 'Remove'));
        kit.expectVisible(find.widgetWithText(FilledButton, 'Remove'));
      },
      note: 'Removes the first MCP server (docs).',
    ),

    // ---- MCP OAuth -------------------------------------------------------
    CensusShot('integrations-mcp-oauth-code-dialog', (kit) async {
      await _integrationsHost(kit);
      await kit.tap(find.widgetWithText(TextButton, 'Authenticate'));
      await kit.tap(find.widgetWithText(FilledButton, 'Open browser'));
      await kit.tap(find.widgetWithText(FilledButton, 'Open link'));
      await kit.tapKey('enter-mcp-oauth-code');
      kit.expectVisible(find.byKey(const ValueKey('mcp-oauth-code-input')));
    }),

    // ---- Pending / uncertain sign-ins -----------------------------------
    CensusShot('integrations-forget-pending-auth-sheet', (kit) async {
      // A saved-server pending-auth record only validates when the profile's
      // origin itself passes the (HTTPS-or-loopback) URL policy, so this
      // needs its own https profile rather than the shared fixture's LAN one.
      const origin = 'https://laptop.example.ts.net';
      final prefs = await kit.prefs({
        'oc.pendingAuth.laptop': jsonEncode([
          PendingAuthAttempt(
            attemptID: 'attempt-pending-1',
            integrationID: 'openai',
            kind: PendingAuthKind.oauth,
            mode: IntegrationAuthMode.auto,
            profileID: 'laptop',
            origin: origin,
            directory: projectDirectory,
            // The store rejects anything stored past its own 24h retention
            // window as forged, so this must stay inside it.
            expiresAt: DateTime.now()
                .add(const Duration(hours: 12))
                .millisecondsSinceEpoch,
          ).toJson(),
        ]),
      });
      final store = SeededProfileStore(
        prefs: prefs,
        seeded: [ServerProfile(id: 'laptop', name: 'Laptop', baseUrl: origin)],
      );
      final api = _LibraryApi();
      final controller = CaptureController(store)
        ..api = api
        ..repository = _LibraryRepository()
        ..status = StreamStatus.connected
        ..directory = projectDirectory
        ..sessionsById = Map.of(api.sessionsById)
        ..busySessions = Set.of(api.busy);
      kit.onDispose(controller.dispose);
      await kit.pumpApp(
        IntegrationsScreen(
          controller: controller,
          mode: IntegrationsMode.providers,
          authorizationLauncher: (_) async => true,
        ),
        controller: controller,
      );
      await kit.tap(find.widgetWithText(TextButton, 'Forget on this device'));
      kit.expectText('Forget on this device');
    }),

    // ---- MCP setup ---------------------------------------------------------
    CensusShot('mcp-setup', (kit) async {
      final controller = await _libraryController(kit);
      await kit.pumpApp(
        McpSetupScreen(controller: controller),
        controller: controller,
      );
      kit.expectText('Add MCP server');
    }),
  ],
  notRendered: {
    'integrations-forget-uncertain-auth-sheet':
        'no seeding seam: the uncertain-dispatch marker is set only in memory '
        'when a live OAuth/command start truly returns no attempt id, with no '
        'public API or stored format to fake it outside a real network race.',
    'integrations-oauth-code-dialog':
        'reachable up to "Open browser" (see integrations-authorization-'
        'launch-dialog), but the legacy OAuth branch throws and cancels the '
        'pending row right after the stubbed authorizationLauncher answers — '
        'the identical shared _openAuthorization/openExternalLink path used '
        'by the MCP OAuth flow (which does render) — for a reason not '
        'isolated within the census budget; a real fake-server integration '
        'test would be the next step.',
    'command-auth-sheet':
        'the sheet gates its Start-sign-in button on ConnectionController\'s '
        'private "actually-connected profile" (_connectedProfile), which the '
        'CaptureController fixture never sets; driving it through the real '
        'ConnectionController(apiFactory:, repositoryFactory:, '
        'eventStreamFactory:) + connect() seam (proven in '
        'test/integration_auth_recovery_test.dart) leaves the provider list '
        'empty instead, for a reason not isolated within budget.',
    'command-auth-sheet-confirm-sheet':
        'reached only via command-auth-sheet; see its notRendered reason.',
  },
);
